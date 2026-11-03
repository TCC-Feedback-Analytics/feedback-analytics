# Testes — Frontend (`feedback-analytics-web`)

Este documento detalha a arquitetura, estrutura e especificação dos testes na aplicação Web (Frontend). Nele, você encontrará a distribuição dos testes separados por sua granularidade: **Unidade**, **Integração** (ambos automatizados no CI via Vitest) e **Fim a Fim (E2E)** — esta última **não é mais automatizada**: a suíte Playwright foi removida em 08/08/2026 e virou o runbook manual [Testes manuais — Web](./manuais-web.md).

!!! info "Conferido em 03/11/2026"
    Inventário refeito contra o repositório: **112 arquivos** de teste (`*.test.ts`/`*.test.tsx`). A versão anterior listava 23 arquivos, vários deles já removidos (como os de formatação de CPF/CNPJ, que saíram com o documento da empresa). Em vez da lista arquivo por arquivo, que envelhece a cada PR, as tabelas abaixo agrupam os testes por pasta. O número de testes sai no fim do `npm run test -- run`.

---


## Cobertura de Testes (Vitest Coverage)

### O que é e por que usamos

**Vitest Coverage** é a ferramenta de cobertura nativa do Vitest, alimentada pelo motor **V8**. Ela instrumenta o código em tempo de execução e rastreia quais linhas, funções e ramificações condicionais (*branches*) foram executadas durante os testes.

Usamos a geração automática de cobertura para **evitar desinformação**. O comando de cobertura extrai dados reais e dinâmicos do código executado em vez de estimativas manuais que perdem a validade rapidamente.

### Como executar a cobertura

Para rodar a suíte completa de testes unitários/integração com relatório de cobertura, no repositório `feedback-analytics-web`:

```bash
npm run test:coverage
```

A cobertura mede `src/lib/utils`, `src/routes`, `pages` e `layouts` (sem os próprios testes) e sai em dois formatos:

1. **Terminal** — Tabela imediata com percentuais e linhas não cobertas.
2. **HTML** — Relatório interativo em `coverage/index.html`, gerado na máquina de quem rodou (a pasta `coverage/` fica fora do git).

Para rodar os testes sem cobertura, use `npm run test -- run` (execução única, como no CI); o `npm test` sozinho fica em modo watch.

---

## Setup Global (`tests/setup.ts`)

O arquivo [setup.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/tests/setup.ts) é executado antes de cada arquivo de testes do Vitest (ambiente *jsdom*, configurado no bloco `test` do `vite.config.ts`):

| Mock / Setup | Por quê |
|---|---|
| `@testing-library/jest-dom` | Matchers de DOM (`toBeInTheDocument` etc.). |
| `URLSearchParams` e `AbortController` do Node | O `Request` que o React Router cria nas submissions vem do Node e rejeita instâncias do jsdom, que são de outro *realm*. |
| `react-router-dom` (só `useRouteLoaderData`) | O *jsdom* não possui contexto do React Router; o mock global evita quebras de hooks de dados. Arquivos que usam `MemoryRouter`, `Link` ou outro export voltam ao módulo real no próprio teste. |
| `window.matchMedia` | A API de media queries não é nativa do *jsdom*; esse mock impede erros na renderização de componentes responsivos. |
| `localStorage` em memória | Estado isolado e previsível entre os testes. |

Os padrões de mock por página estão no [`pages/tests/README.md`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/README.md) do repositório.

---

## Critério de Classificação

O que define se um teste é classificado como **Unidade** ou **Integração** é o escopo e o cruzamento de fronteiras dos módulos, e não simplesmente o arquivo ser um utilitário ou componente:

* **Unidade:** Todos os colaboradores ou serviços externos do arquivo/função em teste são substituídos por mocks (`vi.mock` ou `vi.spyOn`). O teste valida o comportamento isolado daquela unidade isolada de código.
* **Integração:** Valida contratos entre diferentes peças ou módulos reais. O fluxo de dados transita de forma real entre múltiplos módulos (ex: da *Action* do React Router que processa dados estruturados até as validações internas, mockando apenas a comunicação HTTP com a API externa).
* **E2E (End-to-End):** O fluxo roda a aplicação inteira integrada (Frontend, API-Gateway, IA-Analyze e banco de dados real), simulando a interação visual de um usuário real em um browser. Esta camada **não é mais automatizada** — é executada **manualmente** pelo runbook [Testes manuais — Web](./manuais-web.md).

Os blocos `describe` usam o prefixo `[Unidade]` ou `[Integração]`, mas nem todos seguem; a tabela abaixo classifica pela pasta.

---

## 1. Testes de Unidade (`Unit Tests`)

> **Total: 107 arquivos**
>
> Validam funções de utilidade pura, parsers, validadores locais, hooks, services e componentes de página e layout isolados (com seus componentes filhos e dados mockados).

| Onde ficam | Arquivos | O que cobrem |
| :--- | :---: | :--- |
| `components/**/*.test.tsx` | 45 | Componentes, ao lado do arquivo testado: formulários públicos (login, cadastro, "Continuar com Google", reenvio da confirmação, formulário de feedback), páginas legais, onboarding e guia de primeiros passos, layout do gestor (cabeçalho, menu, barra de insights), seções do dashboard (canais, movimento, pico, clientes que voltam, diagnóstico do escopo), comentários, relatório de insights, perfil (exclusão de conta, Configuração de IA), canais de coleta e etiqueta NFC, perguntas do formulário e componentes compartilhados. |
| `pages/tests/` | 11 | Páginas: home, login, cadastro, dashboard, perfil, métricas de estrelas, comparação de itens, histórico de diagnósticos, comentários, pergunta do formulário e volta do OpenRouter. Lista em [`pages/tests/README.md`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/README.md). |
| `layouts/tests/` | 2 | `layouts/public.tsx` e `layouts/user.tsx`. |
| `src/lib/utils/*.test.ts` e `src/lib/utils/tests/` | 37 | Utilitários puros: formatação de telefone, truncamento, força da senha, validação e montagem do formulário público de feedback, mapeamento de erros da IA, períodos e comparação, pico de horários, precisão, rótulos de nota e de sentimento, cliente HTTP, entre outros. |
| `src/lib/hooks/` e `src/lib/mock/` | 5 | Hooks (operação de IA, geração das perguntas da empresa, link de feedback, marcos de feedbacks) e a definição do menu. |
| `src/routes/loaders/` e `src/routes/load/loadFeedbacksAll.test.ts` | 4 | Loaders da conclusão do cadastro e da Configuração de IA e a leitura dos filtros da listagem de feedbacks. |
| `src/routes/actions/actionIaSettings.test.ts` | 1 | Action da Configuração de IA. |
| `src/services/` | 3 | Services de auth (reenvio da confirmação), de configuração de IA e do guia do sistema. |

---

## 2. Testes de Integração (`Integration Tests`)

> **Total: 5 arquivos** (os que levam o prefixo `[Integração]`)
>
> Validam os handlers de rota do React Router (Actions e Loaders) que fazem a ponte entre os dados preenchidos nos formulários da interface e a chamada dos serviços que conversam com a API Gateway.

| Arquivo de Teste | Propósito do Arquivo |
| :--- | :--- |
| [actionCollectingData.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionCollectingData.test.ts) | Testa a `action` de persistência das configurações de coleta e catálogos (produtos, serviços e departamentos), garantindo a conversão correta dos dados enviados para JSON e preservação de perguntas. |
| [actionFeedbackSettings.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionFeedbackSettings.test.ts) | Testa a `action` centralizada de configurações de feedback baseada no campo `intent`, validando fluxos válidos de alteração, erros de validação local de strings vazias e mapeamento incorreto de ações. |
| [actionFeedbackInsightsReport.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionFeedbackInsightsReport.test.ts) | Testa a `action` que pede o relatório de insights ao Gateway: repasse do `force` para refazer o relatório e a orientação para configurar o OpenRouter quando o Gateway exige a chave da empresa. |
| [actionPublicQrCodeFeedback.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionPublicQrCodeFeedback.test.ts) | Testa a integração do envio do formulário público do QR Code pela `action`, validando a conversão de campos, preenchimento de obrigatórios e envio final aos serviços. |
| [loadPublicQrCodeEnterprise.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/load/loadPublicQrCodeEnterprise.test.ts) | Valida o comportamento do `loader` responsável por buscar os dados estruturados e perguntas da empresa ao carregar a página pública de coleta de feedback via QR Code. |

---

## 3. Testes Fim a Fim (E2E) — agora manuais

> A suíte **E2E automatizada (Playwright)** do `feedback-analytics-web` — os specs `e2e/*.spec.ts`, as fixtures (incluindo o `auth.setup.ts`), o `playwright.config.ts` e os scripts npm `test:e2e`/`:ui`/`:report` — foi **removida** do projeto e do CI em 08/08/2026. Hoje o repositório não tem Playwright nem pasta `e2e/`.

Essa suíte rodava em navegador Chrome real contra o ambiente **homolog** deployado — modelo descontinuado junto com o ambiente de homologação (o deploy passou a ser **main-only**, direto para produção). A cobertura ponta a ponta dos 11 Casos de Uso que ela exercitava (UC-01, UC-02 e UC-04 a UC-12; o UC-03 nunca teve roteiro E2E) passou a ser **manual**, reproduzível clicando na aplicação conforme o runbook:

- **[Testes manuais — Web (Casos de Uso)](./manuais-web.md)** — casos UC-01…UC-12 reproduzidos pela UI.

Os testes de **Unidade** e **Integração** (Vitest) descritos acima continuam automatizados no CI.

---

## Veja Também

* [Plano Estratégico de Testes](./plano-estrategico.md)
* [Visão Geral dos Testes](./visao-geral.md)
* [Testes manuais — Web (Casos de Uso)](./manuais-web.md)
* [Testes da API Gateway](./api-gateway.md)
* [Testes do Serviço de IA](./ia-analyze.md)
