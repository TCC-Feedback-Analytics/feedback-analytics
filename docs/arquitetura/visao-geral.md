# Arquitetura do Sistema

## Arquitetura Serverless (Macro)

A infraestrutura do projeto roda integralmente na **Vercel**, sem servidores dedicados. Cada serviço é uma unidade independente que dorme até receber uma requisição — o modelo **Serverless Functions** da Vercel.

| Serviço (repositório) | Builder | Tipo de Deploy | `maxDuration` |
|---|---|---|---|
| `feedback-analytics-web` | `@vercel/static-build` | Site estático via CDN | — |
| `feedback-analytics-api-gateway` | `@vercel/node` | Serverless Function | 300s |
| `feedback-analytics-ia-analyze` | `@vercel/node` | Serverless Function | 300s |

- **Frontend (web):** arquivos estáticos (HTML, CSS, JS) gerados no build e servidos diretamente pela CDN da Vercel. Não há servidor — o React roda no navegador do usuário.
- **API-Gateway:** função Node.js que acorda a cada requisição, consulta o banco (Supabase) e encerra. O timeout de 300s cobre com folga as operações de I/O e a orquestração das chamadas à IA — que, em lotes grandes, encadeia várias chamadas ao LLM por requisição.
- **IA-Analyze:** função Node.js de longa duração — recebe feedbacks, chama o LLM externo (pode levar 30–60s) e processa o resultado. Precisa de 300s de timeout, inviável de rodar no mesmo projeto do Gateway.

> **Nota — bundle do Gateway:** antes do deploy, o workflow de deploy do repo `feedback-analytics-api-gateway` roda uma etapa de esbuild que empacota o entrypoint em um `_bundle.cjs`. É esse bundle que o `vercel.json` do Gateway aponta como `src`.

A escalabilidade é automática: quando várias empresas disparam análises simultaneamente, a Vercel sobe múltiplas instâncias do `ia-analyze` em paralelo. Quando a demanda cai, as instâncias encerram e param de consumir recursos.

---

## Multi-repo — Organização (Micro)

Cada serviço vive em seu **próprio repositório**, com escopo, responsabilidade e ciclo de deploy independentes. Os tipos e contratos compartilhados são publicados como um pacote versionado (`@feedback/lib-shared`), consumido por todos os serviços. O projeto começou como monorepo e foi separado — veja [Arquitetura distribuída (evolução do monorepo)](historico-de-decisoes/decisao-monorepo-vs-monolito.md).

| Repositório | Tipo | Descrição |
|---|---|---|
| `feedback-analytics-web` | React SPA | Interface do usuário — área pública (QR Code) e painel da empresa |
| `feedback-analytics-api-gateway` | API Gateway / BFF | Hub central — autenticação, regras de negócio, orquestração |
| `feedback-analytics-contracts` | Pacote compartilhado | `@feedback/lib-shared` — tipos, interfaces e contratos entre serviços |
| `feedback-analytics-ia-analyze` | Serviço serverless | Processamento de IA com escopo e volume próprios |
| `feedback-analytics` (este) | Documentação | Concepção, decisões, requisitos e schema do banco |

O pacote de contratos resolve a sincronização de tipos: quando o formato de comunicação entre Gateway e IA-Analyze muda, uma nova versão do `@feedback/lib-shared` propaga o contrato e o TypeScript avisa imediatamente se algum lado quebrou.

A partir daqui, cada serviço tem sua própria arquitetura interna — veja os links em **Veja Também**.

---

## Responsabilidades por Camada

**Frontend React SPA**
Responsável pela experiência do usuário, navegação via React Router (loaders/actions), e consumo das APIs do Gateway. Nunca acessa o banco ou serviços de IA diretamente.

**API Gateway (padrão BFF)**
Ponto único de entrada para o frontend. Concentra autenticação (JWT via Supabase Auth), orquestração das regras de negócio, integração com o banco de dados (Supabase com RLS) e coordenação das chamadas aos serviços externos.

**Contratos Compartilhados (`@feedback/lib-shared`)**
Pacote versionado importado por múltiplos serviços. Evita duplicação de tipos TypeScript — contratos de API, interfaces de entidades e tipos de integração vivem aqui e são a fonte de verdade para todos os serviços.

**Serviços Serverless**
Cada serviço de grande volume ou complexidade (como o IA Analyze) tem repositório e deploy próprios, para escalar e evoluir de forma independente sem afetar os demais.

---

## Como os Serviços se Conectam

O sistema tem uma topologia **hub-and-spoke**: o API Gateway é o hub central. O frontend nunca fala diretamente com o banco ou com o serviço de IA — tudo passa pelo Gateway.

### Área Pública (sem login)

1. O cliente escaneia o QR Code físico — a URL contém um identificador único do ponto de coleta
2. O Frontend pede ao Gateway os dados daquele ponto (formulário configurado, perguntas)
3. O cliente preenche e submete; o Gateway valida o **fingerprint do dispositivo** (anti-spam) e insere o feedback no banco

### Área Protegida (empresa logada)

1. O Frontend autentica via **Supabase Auth**; a sessão (JWT) é mantida em **cookies httpOnly** definidos pela API
2. Todas as requisições ao Gateway são enviadas com `credentials: 'include'`, levando os cookies de sessão automaticamente
3. O middleware `requireAuth` valida a sessão (`supabase.auth.getUser()`) e injeta `req.user` + `req.supabase` na request
4. O Gateway lê/escreve no banco (Supabase) e, quando necessário, chama o IA Analyze

### Fluxo de Análise IA

1. A empresa clica em "Analisar feedbacks" no painel de insights
2. O Gateway busca feedbacks não analisados (máx. 100), remove IDs já presentes em `feedback_analysis` e agrupa em **batches por escopo** (`COMPANY`, `PRODUCT`, `SERVICE`, `DEPARTMENT`)
3. Em seguida, **sub-divide cada batch por TAMANHO** (`chunkBatchesBySize`): cada lote é fatiado em sub-lotes de no máx. ~20 feedbacks por chamada ao LLM (configurável via `IA_MAX_FEEDBACKS_PER_BATCH`), evitando que a saída JSON estoure o teto de tokens do modelo e seja truncada
4. Envia o payload `{ enterprise_context, batches[] }` ao IA Analyze via HTTP com token interno
5. O IA Analyze chama o **provedor LLM externo** por batch, processa e sanitiza sentimentos, keywords e categorias
6. O Gateway persiste as análises em `feedback_analysis` e os insights em `feedback_insights_report`

---

## Contratos Compartilhados

Os tipos TypeScript que transitam entre Gateway e IA Analyze **não são duplicados**. Vivem no pacote [`@feedback/lib-shared`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts) (em `interfaces/contracts/ia-analyze/`) e são importados pelos dois serviços:

| Arquivo | Propósito |
|---|---|
| `scope.contract.ts` | Tipos base: `IaAnalyzeScopeType`, `IaAnalyzeSentiment` |
| `input.contract.ts` | Contexto de empresa + estrutura de feedback bruto |
| `remote.contract.ts` | Contrato de integração interna Gateway ↔ IA Analyze |
| `run.contract.ts` | Contrato da API pública (requests/responses) |
| `analysis.contract.ts` | Estruturas de saída: itens analisados, insights, contexto |

---

## Tecnologias

| Camada | Tecnologia | Versão |
|---|---|---|
| Frontend | React | 19.x |
| Roteamento / Data Fetching | React Router DOM | 7.x |
| Formulários | React Hook Form + Zod | 7.x / 4.x |
| Estilo | Tailwind CSS | 4.x |
| Build | Vite | — |
| Backend Runtime | Node.js | 20.x |
| Backend Framework | Express | — |
| Autenticação | Supabase JS | 2.x |
| Banco de Dados | Supabase (PostgreSQL) | — |
| IA | Provedor LLM externo — atualmente Google Gemini (`@google/genai`, modelo `gemini-2.5-flash`), configurável via `GEMINI_API_KEY`; trocar de provedor exige alteração de código | — |
| Testes | Vitest + Testing Library | — |
| Distribuição | Multi-repo + pacote `@feedback/lib-shared` | — |

---

## Veja Também

- [Backend — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/arquitetura-estrutura.md)
- [Frontend — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/docs/arquitetura-estrutura.md)
- [IA Analyze — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/docs/arquitetura-estrutura.md)
- [Banco de Dados — Visão Geral e Arquitetura](../referencia/banco-de-dados/visao-geral.md)
- [CI/CD — Workflows e Deploys](../guias/workflows.md)
