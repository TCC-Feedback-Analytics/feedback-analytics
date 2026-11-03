# Arquitetura do Sistema

## Arquitetura Serverless (Macro)

A infraestrutura do projeto roda integralmente na **Vercel**, sem servidores dedicados. Cada serviço é uma unidade independente que dorme até receber uma requisição — o modelo **Serverless Functions** da Vercel.

| Serviço (repositório) | Builder | Tipo de Deploy | `maxDuration` |
|---|---|---|---|
| `feedback-analytics-web` | `@vercel/static-build` | Site estático via CDN | — |
| `feedback-analytics-api-gateway` | `@vercel/node` | Serverless Function | 300s |
| `feedback-analytics-ia-analyze` | `@vercel/node` | Serverless Function | 300s |

- **Frontend (web):** arquivos estáticos (HTML, CSS, JS) gerados no build e servidos diretamente pela CDN da Vercel. Em produção, a Web chama `/api/*` no próprio domínio e o `vercel.json` dela repassa ao Gateway, para o cookie de sessão ser do próprio site. O React 19 acompanha os jobs de IA por polling resiliente via `useIaOperation`.
- **API-Gateway:** ponto central em Node.js/Express. Além de tratar autenticação (Better Auth) e regras de negócio, hospeda o **Worker Assíncrono**, que consome a fila `ia_analysis_job` via `SELECT ... FOR UPDATE SKIP LOCKED`. Fora da Vercel, o worker roda em loop junto com o servidor; na Vercel, ele anda um passo depois de cada pedido (`kickWorker`, com `waitUntil`), no polling de status e pelo cron de reserva `ia-worker.yml` (a cada 5 minutos).
- **IA-Analyze:** microsserviço isolado de inferência, sem banco. Recebe do Worker, por chamadas HTTP internas protegidas por token, os lotes de feedbacks, a síntese dos insights, o diagnóstico do escopo e a geração das perguntas da empresa, e chama o OpenRouter com a chave e o modelo da empresa, via padrão Strategy (o adaptador do Gemini fica só como reserva legada).

> **Nota — bundle do Gateway:** antes do deploy, o workflow de deploy do repo `feedback-analytics-api-gateway` roda uma etapa de esbuild que empacota o entrypoint em um `_bundle.cjs`. É esse bundle que o `vercel.json` do Gateway aponta como `src`.

A escalabilidade é automática: quando várias empresas disparam análises simultaneamente, a Vercel sobe múltiplas instâncias do `ia-analyze` em paralelo. Quando a demanda cai, as instâncias encerram e param de consumir recursos.

---

## Multi-repo — Organização (Micro)

Cada serviço vive em seu **próprio repositório**, com escopo, responsabilidade e ciclo de deploy independentes. Os tipos e contratos compartilhados são publicados como um pacote versionado (`@feedback/lib-shared`), consumido por todos os serviços. O projeto começou como monorepo e foi separado — veja [Arquitetura distribuída (evolução do monorepo)](historico-de-decisoes/decisao-monorepo-vs-monolito.md).

| Repositório | Tipo | Descrição |
|---|---|---|
| `feedback-analytics-web` | React SPA | Interface do usuário — área pública (formulário por QR Code, link ou NFC) e painel da empresa |
| `feedback-analytics-api-gateway` | API Gateway / BFF | Hub central — autenticação, regras de negócio, orquestração |
| `feedback-analytics-contracts` | Pacote compartilhado | `@feedback/lib-shared` — tipos, interfaces e contratos entre serviços |
| `feedback-analytics-ia-analyze` | Serviço serverless | Processamento de IA com escopo e volume próprios |
| `feedback-analytics` (este) | Documentação | Concepção, produto, decisões e requisitos (o schema do banco vive no gateway, em `drizzle/`) |

O pacote de contratos resolve a sincronização de tipos: quando o formato de comunicação entre Gateway e IA-Analyze muda, uma nova versão do `@feedback/lib-shared` propaga o contrato e o TypeScript avisa imediatamente se algum lado quebrou. Cada serviço fixa a versão por **tag do Git**: hoje o Gateway e a Web estão na `v1.8.0` e o IA-Analyze na `v1.7.0`.

A partir daqui, cada serviço tem sua própria arquitetura interna — veja os links em **Veja Também**.

---

## Responsabilidades por Camada

**Frontend React SPA**
Responsável pela experiência do usuário, navegação via React Router (loaders/actions), e consumo das APIs do Gateway. Nunca acessa o banco ou serviços de IA diretamente.

**API Gateway (padrão BFF)**
Ponto único de entrada para o frontend. Concentra autenticação (sessão via **Better Auth**, entregue em cookie httpOnly), orquestração das regras de negócio, integração com o banco de dados (Postgres via Drizzle, com o papel `feedback_app`, que só lê e escreve dados; o isolamento por `enterprise_id` fica na aplicação e a RLS barra os demais papéis — ver [ORM × RLS](orm-rls-decisao.md)) e coordenação das chamadas aos serviços externos.

**Contratos Compartilhados (`@feedback/lib-shared`)**
Pacote versionado importado por múltiplos serviços. Evita duplicação de tipos TypeScript — contratos de API, interfaces de entidades e tipos de integração vivem aqui e são a fonte de verdade para todos os serviços.

**Serviços Serverless**
Cada serviço de grande volume ou complexidade (como o IA Analyze) tem repositório e deploy próprios, para escalar e evoluir de forma independente sem afetar os demais.

---

## Como os Serviços se Conectam

O sistema tem uma topologia **hub-and-spoke**: o API Gateway é o hub central. O frontend nunca fala diretamente com o banco ou com o serviço de IA — tudo passa pelo Gateway.

### Área Pública (sem login)

1. O cliente abre o formulário pelo QR Code, por um link compartilhado ou por uma etiqueta NFC — a URL leva o ID da empresa, o ponto de coleta ou o item do catálogo e a marca do canal
2. O Frontend pede ao Gateway os dados daquele escopo (nome da empresa, perguntas ativas e campo de comentário)
3. O cliente preenche e submete; o Gateway calcula o **fingerprint do dispositivo** (anti-spam: um envio por dia por ponto de coleta) e grava o feedback com o canal de coleta

### Área Protegida (empresa logada)

1. O Frontend chama os endpoints de autenticação do Gateway (`/api/public/auth/login|register|logout|...`), que usam **Better Auth** por baixo; a entrada com o Google passa pelo handler nativo do Better Auth (`/api/auth/*`). A sessão é mantida em um **cookie httpOnly** definido pelo Gateway
2. Todas as requisições ao Gateway são enviadas com `credentials: 'include'`, levando o cookie de sessão automaticamente
3. O middleware `requireAuth` valida a sessão via **Better Auth** (a partir do cookie) e injeta `req.user` e `req.enterpriseId` na request
4. O Gateway lê/escreve no banco (Postgres via Drizzle, sempre filtrando por `enterprise_id`) e, quando há trabalho de IA, enfileira um job



### Fluxo de Análise IA (100% Assíncrono)

Todo trabalho de IA passa pela fila `ia_analysis_job`, que é ao mesmo tempo a fila e o status de progresso. São quatro tipos de job: `analyze_raw` (analisar os pendentes), `regenerate_insights` (relatório de insights, que também pode analisar os pendentes antes), `generate_scope_diagnosis` (diagnóstico do escopo) e `generate_company_questions` (as perguntas da empresa, geradas sozinhas quando o contexto e a IA ficam configurados).

1. **Enfileiramento imediato (POST -> 202 Accepted):**
   - O gestor clica em *"Analisar feedbacks"* ou *"Gerar insights"* no painel.
   - O Gateway cria um registro na tabela `ia_analysis_job` com status `queued` e retorna instantaneamente status HTTP `202 Accepted` acompanhado do `jobId`. Um índice parcial único impede dois jobs ativos iguais (duplo clique).
   - O frontend libera a interface, exibe barra global de progresso e inicia polling resiliente de status, permitindo ao usuário navegar ou recarregar a tela sem cancelar a operação.

2. **Acionamento e lease pelo Worker:**
   - O worker anda por quatro caminhos: `kickWorker()` logo depois do pedido (na Vercel, `waitUntil` mantém a função viva até o passo terminar); `kickWorkerIfPending()` no polling de status e ao carregar páginas; o cron de reserva do GitHub Actions (`ia-worker.yml`, a cada 5 minutos), que chama `POST /api/internal/worker/tick` com o token `WORKER_TICK_TOKEN`; e, fora da Vercel, um loop local.
   - O Worker pega o job com `SELECT ... FOR UPDATE SKIP LOCKED`, sem concorrência destrutiva entre instâncias. O status passa para `running` e o job ganha um lease de 10 minutos, renovado por heartbeat; um job abandonado pode ser retomado depois que o lease vence.
   - Antes de cada chamada à IA, o Worker reserva orçamento no `ia_rate_budget` (por minuto e por dia, por empresa). Sem orçamento, o job fica em `waiting_budget` até a próxima janela.

3. **Fracionamento de Lotes e Headers Dinâmicos:**
   - O Worker busca os feedbacks não analisados da empresa e os fatia em lotes (`IA_MAX_FEEDBACKS_PER_BATCH`, padrão 20 feedbacks).
   - O Gateway recupera as credenciais da empresa em `enterprise_ia_config` (decifrando a chave via AES-256-GCM) e envia ao `ia-analyze` através de headers internos (`x-llm-provider`, `x-llm-model`, `x-llm-api-key`), junto com o token interno.

4. **Processamento no `ia-analyze` (Multi-Provedor):**
   - A fábrica `createProvider` instancia o adaptador apropriado (**OpenRouter**; o **Gemini** só como legado).
   - O modelo LLM classifica sentimento, intensidade, aspectos (ABSA), categorias e palavras-chave; palavras-chave, categorias e aspectos são saneados contra o texto original do cliente.
   - A resposta do lote é validada (formato e um resultado por feedback enviado), e o texto exibido ao usuário precisa estar em pt-BR — fora disso, ganha uma única nova tentativa.

5. **Persistência Incremental e Conclusão:**
   - O Worker salva as análises de cada lote em `feedback_analysis` (uma por feedback) e grava o progresso (`done`/`total`) e o checkpoint no próprio job (`options.checkpoint`), para retomar de onde parou.
   - No relatório (*"Gerar insights"*), o Worker junta os insights parciais de todos os lotes do escopo (sem corte em 100) e chama a síntese final no `ia-analyze`; o resumo e as recomendações vão para `feedback_insights_report`.
   - O diagnóstico do escopo vai para `scope_diagnosis`, e as perguntas geradas pela IA substituem as padrão em `questions_of_feedbacks` enquanto a empresa não as editou.
   - Ao finalizar, o job passa para `completed` (ou `failed`, depois das retentativas), e a interface do frontend exibe os dados atualizados.

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
| `scope-diagnosis.contract.ts` | Pedido e resposta do diagnóstico do escopo |
| `company-question-suggestions.contract.ts` | Pedido e resposta da geração das perguntas da empresa |

---

## Tecnologias

| Camada | Tecnologia | Versão |
|---|---|---|
| Frontend | React | 19.x |
| Roteamento / Data Fetching | React Router DOM | 7.x |
| Formulários | React Hook Form + Zod | 7.x / 4.x |
| Estilo | Tailwind CSS | 4.x |
| Build | Vite | 7.x |
| Backend Runtime | Node.js | 20.x |
| Backend Framework | Express | 5.x |
| Autenticação | Better Auth (sessão em cookie httpOnly) | — |
| ORM / Acesso a dados | Drizzle ORM (SQL-first) | — |
| Banco de Dados | PostgreSQL (hospedado no Supabase, acessado direto via `DATABASE_URL`) | — |
| E-mail transacional | SMTP (Brevo em produção · Mailpit no local) | — |
| IA | OpenRouter com chave e modelo configurados por empresa no perfil (BYO-key); credencial cifrada no Gateway e enviada ao IA Analyze por headers internos | — |
| Testes | Vitest + Testing Library | — |
| Distribuição | Multi-repo + pacote `@feedback/lib-shared` | — |

---

## Veja Também

- [Backend — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/arquitetura-estrutura.md)
- [Frontend — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/docs/arquitetura-estrutura.md)
- [IA Analyze — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/docs/arquitetura-estrutura.md)
- [Banco de Dados — Visão Geral e Arquitetura](../referencia/banco-de-dados/visao-geral.md)
- [CI/CD — Workflows e Deploys](../guias/workflows.md)
