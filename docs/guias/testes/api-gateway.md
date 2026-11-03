# Testes — Backend (`feedback-analytics-api-gateway`)

Este documento detalha a arquitetura, a estrutura e a especificação dos testes automatizados do serviço **API Gateway**. Os testes cobrem as rotas, os controladores (*controllers*), os serviços, os repositórios (o SQL que o Drizzle monta), a fila e o worker da IA, isolando o banco de dados e as chamadas externas por meio de mocks. As suítes que exigiam um **banco/ambiente real** (integração e e2e de *cutover*) foram removidas do CI e passaram a ser um [runbook manual](./manuais-api-gateway.md).

!!! info "Conferido em 03/11/2026"
    Inventário refeito contra o repositório: **48 arquivos** em `src/tests/*.test.ts`. A tabela antiga, de 8 arquivos e 77 testes, citava suítes que não existem mais (`auth.test.ts`) e um mock do Supabase que saiu com a migração para Better Auth e Drizzle. O número de testes muda a cada PR; o total atual sai no fim do `npm test`.

---

## Status da Cobertura

Os testes do API Gateway utilizam o **Vitest** como motor de testes (`vitest.config.ts`: ambiente `node`, arquivos `src/tests/**/*.test.ts`) e o **Supertest** para simular requisições HTTP reais diretamente contra a aplicação Express (14 dos 48 arquivos). O banco não é consultado: os testes mockam o cliente Drizzle (`../db/client.js`), os repositórios, o middleware de autenticação e os providers do IA Analyze. Os testes de SQL usam `drizzle.mock()`, que monta a consulta sem conectar, e conferem o texto e os parâmetros gerados.

> **Total: 48 arquivos de teste em `src/tests/`**

!!! info "O que roda no CI (e o que virou manual)"
    Os arquivos abaixo são testes **unitários/de rota mockados** e **seguem automatizados no CI** (job `unit-tests` do `ci.yml`). Além deles, o CI mantém o **smoke de migrations** (`schema-migrations.yml`): sobe um Postgres efêmero no runner, **sem credenciais**, aplica as migrations e o seed e roda `drizzle-kit check` para validar o schema versus as migrations.

    A única suíte contra **Postgres real** que restou é `onboarding.database.test.ts`, opt-in: só roda com `ONBOARDING_TEST_DATABASE_URL` definida e fica pulada no `npm test` comum e no CI.

    As antigas suítes que dependiam de um **banco/ambiente real** — os testes de **integração** (`src/tests/integration/*.itest.ts`) e o **e2e de cutover** (`src/tests/e2e/authCutover.e2e.ts`), com os configs `vitest.integration.config.ts`/`vitest.e2e.config.ts` e os scripts `test:integration`/`test:e2e` — foram **removidas** do repositório e do CI. Sua cobertura passou a ser **manual**: veja o runbook **[Testes manuais — API Gateway](./manuais-api-gateway.md)**.

---

## Como Executar os Testes

No repositório do API Gateway (`feedback-analytics-api-gateway`):

```bash
npm test                # vitest run (execução única)
npm run test:watch      # modo watch
npm run test:coverage   # com cobertura (V8)
```

A suíte contra Postgres real roda à parte, apontando para um banco de teste (o local do `npm run db:local:up` serve):

```bash
ONBOARDING_TEST_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5433/feedback npm test -- src/tests/onboarding.database.test.ts
```

---

## Testes Automatizados

Abaixo, os 48 arquivos agrupados pelo que cobrem. Todos ficam em [`src/tests/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/src/tests).

| Área | Arquivos de teste | O que cobre |
| :--- | :--- | :--- |
| **Conta e autenticação** | `registerPassword`, `googleSignup`, `accountDeletion`, `email`, `onboarding`, `onboarding.database` | Força da senha no cadastro (zxcvbn), configuração do "Entrar com Google", o que é apagado antes de excluir a conta, envio de e-mail na Vercel e a API do guia de primeiros passos (esta última também contra Postgres real, opt-in). |
| **Isolamento multi-tenant** | `tenantScope` | O filtro por `enterprise_id` que a aplicação força em toda consulta. |
| **Empresa e coleta (QR Code, link e NFC)** | `enterprise-controller`, `collection-points-qr-controller`, `qrcode-feedback`, `commentField` | Controllers da empresa e dos pontos de coleta, a coleta pública de feedback (`POST /api/public/qrcode/feedback`, com o canal de chegada e o anti-spam por dispositivo) e o campo de comentário por escopo. |
| **Feedbacks e métricas** | `feedbacks`, `customers`, `customersSql`, `channelBreakdown`, `commentParticipation`, `heatmap`, `heatmapSql`, `timeline`, `timelineSql`, `period`, `scopeMetrics`, `questionsRatingWeight` | Listagem protegida de feedbacks, clientes que voltam, canais de chegada, participação nos comentários, dias e horários de pico, movimento no tempo, período das métricas, métricas do escopo e o peso de cada pergunta na nota — os arquivos `*Sql` conferem o SQL gerado. |
| **Estatística e avaliação** | `statistics`, `classifierEval` | Funções puras de `src/libs/statistics` (intervalos de Wilson, NSS, CSAT, média bayesiana etc.) e as métricas do avaliador do classificador (`src/libs/eval/classifierEval.ts`: kappa de Cohen, macro-F1, matriz de confusão). |
| **Análise de IA** | `ia-analyze`, `iaAnalyze-async`, `iaAnalyze-cache`, `iaAnalyze-completion`, `iaAnalyze-pending`, `iaAnalyze-provider-errors`, `iaAnalyzeRepository`, `insightsCache`, `insightsJob` | Rotas da análise e do relatório, enfileiramento sempre assíncrono, cache dos insights, recusa de resposta incompleta do IA Analyze, seleção dos pendentes do escopo, repasse dos códigos de erro seguros e a síntese do relatório. |
| **Diagnóstico do escopo** | `scopeDiagnosis`, `scopeDiagnosisJob`, `scopeDiagnosisRoutes`, `scopeDiagnosisService` | Período anterior e intervalo do movimento, o job na fila, as rotas e o serviço que faz o pedido. |
| **Perguntas da empresa** | `companyQuestionsAutoGenerate`, `companyQuestionsFailureNotice` | Geração automática das perguntas e o aviso quando ela falha. |
| **Configuração de IA (BYO-key)** | `iaConfig`, `iaConfigRepository`, `requireUserIaKey`, `openRouterModels` | Rotas de configuração da chave OpenRouter, atualização atômica do modelo, a exigência da chave da empresa e o catálogo de modelos do OpenRouter. |
| **Fila e worker** | `drainJobs`, `iaJobRepository`, `workerLoop` | Worker assíncrono e retomável, posse e isolamento dos jobs no SQL e o loop local que drena a fila fora da Vercel. |
| **Saúde** | `health` | `GET /api/health` responde `{ ok: true }`. |

---

## Avaliação Offline do Classificador (gold set)

Além da suíte automatizada, o serviço dispõe de uma ferramenta de avaliação *offline* que mede a qualidade do classificador de sentimento da IA contra rótulos humanos (*gold set*). Diferente dos testes do Vitest, esse script não roda no pipeline padrão — é executado sob demanda para validar uma mudança de *prompt* ou de modelo antes de promovê-la.

* **[scripts/eval-classifier.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/scripts/eval-classifier.ts):** Compara o `feedback_analysis.sentiment` gravado pela IA com os rótulos atribuídos manualmente a uma amostra de feedbacks. A partir desses pares, reaproveita as funções de `src/libs/eval/classifierEval.ts` para reportar **Cohen's kappa**, **acurácia**, **macro-F1** e a **matriz de confusão** (humano × modelo), além das métricas por classe (precision, recall, F1 e suporte). A **meta de qualidade é kappa ≥ 0,6** (concordância substancial pelas faixas de Landis & Koch).
* **[scripts/gold-sentiment.sample.json](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/scripts/gold-sentiment.sample.json):** *Fixture* de exemplo do formato esperado pelo script — um array de pares `{ "human": "...", "model": "..." }`, onde `human` é o rótulo humano e `model` é o sentimento que a IA gravou para o mesmo feedback.

Para executar a avaliação (no repositório do API Gateway), apontando para o arquivo de pares rotulados:

```bash
npx tsx scripts/eval-classifier.ts scripts/gold-sentiment.sample.json
```

---

## Estrutura de Mocks

Não há mais fixture global de banco: cada arquivo declara os próprios `vi.mock`. Os mais comuns:

* **`../db/client.js`** — substitui o `getDb()` do Drizzle, para nenhum teste abrir conexão.
* **`../repositories/*.repository.js`** — os repositórios devolvem dados fixos definidos no teste.
* **`../middlewares/auth.js`** — o `requireAuth` injeta um usuário e uma empresa de teste, sem passar pelo Better Auth.
* **`../providers/*.provider.js`** e **`../libs/iaJob/kickWorker.js`** — cortam as chamadas ao IA Analyze e o disparo do worker.

O `vitest.config.ts` define `DATABASE_URL`, `BETTER_AUTH_SECRET` e `BETTER_AUTH_URL` de teste, porque o `index.ts` monta o Better Auth no import; o `DATABASE_URL` só serve para o `getDb()` instanciar sem erro.

---

## Veja Também

* [Plano Estratégico de Testes](./plano-estrategico.md)
* [Visão Geral dos Testes](./visao-geral.md)
* [Testes manuais — API Gateway](./manuais-api-gateway.md)
* [Testes da Aplicação Web (Frontend)](./web.md)
* [Testes do Serviço de IA](./ia-analyze.md)
