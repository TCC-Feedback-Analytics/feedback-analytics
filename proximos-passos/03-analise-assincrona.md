# 03 — Análise assíncrona da IA (worker + fila)

> **Em uma frase:** em vez de fazer o usuário esperar a IA terminar (e travar no meio do caminho), o sistema passa a *anotar o pedido* e processá-lo em segundo plano, no ritmo certo.

| Campo | Valor |
|---|---|
| **Status** | 🟢 Em andamento — planejamento detalhado concluído e verificado contra o código (ago/2026); ver "Plano de execução detalhado" no fim |
| **Quando** | Mês 2-3 |
| **Esforço** | Alto |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | [00 — Estabilização](./00-estabilizacao.md) |
| **Camadas afetadas** | Backend · Banco · Infra |

## Para qualquer leitor

Hoje, quando o gestor clica em **"Analisar feedbacks"** ou **"Gerar insights"**, o sistema tenta fazer **tudo na hora**, com a pessoa olhando para uma telinha de carregamento: ele junta os comentários, manda para a inteligência artificial (o Google Gemini), espera a IA pensar, recebe a resposta e só então libera a tela. O problema é que "pensar" sobre dezenas de comentários leva tempo — e a infraestrutura onde o sistema roda **desliga a tarefa se ela passar de cerca de 1 minuto**. Resultado: a tela trava, dá erro de "tempo esgotado" e o gestor não recebe nada. Pior: a IA gratuita tem uma **cota diária** (um número máximo de pedidos por dia); como o sistema tenta de novo quando falha, ele gasta essa cota rápido e, no fim do dia, simplesmente **para de funcionar para todo mundo**.

A solução é mudar a forma de trabalhar. Em vez de "faça tudo agora enquanto eu espero", o sistema vai dizer: **"anotei seu pedido, pode deixar que eu te aviso quando terminar"**. Pense num restaurante movimentado. No modelo antigo, você faz o pedido no balcão e **fica plantado ali** até o prato ficar pronto — se demorar demais, o gerente te manda embora ("deu tempo limite") e você sai sem comer. No modelo novo, você faz o pedido, recebe uma **senha**, senta e relaxa; a cozinha vai preparando os pedidos **na ordem e no ritmo que dá conta**, e a sua senha é chamada quando fica pronto. Ninguém fica preso no balcão, e a cozinha não pega mais pedidos do que consegue cozinhar.

Para isso, três peças entram em cena, e vale entender cada uma em palavras simples:

- **A fila** é a *comanda de pedidos*: uma lista durável de tarefas a fazer. Quando você clica "Analisar", o sistema só **anota** o pedido nessa lista e já te responde "processando". Se faltar luz ou o sistema reiniciar, a comanda continua lá — nenhum pedido se perde.
- **O trabalhador** (em inglês, *worker*) é o *cozinheiro*: um programa que **trabalha em segundo plano** (acordado de tempos em tempos), pega os pedidos da comanda um a um e os executa.
- **O controle de ritmo** (em inglês, *rate limiter*) é a *regra da cozinha* de "no máximo X pratos por minuto": ele garante que o sistema nunca peça à IA mais do que a cota gratuita permite — assim a cota não estoura e o serviço não cai.

O benefício é direto: **acabam os erros de "tempo esgotado"**, a **cota diária da IA para de estourar**, e o gestor passa a **acompanhar o progresso** ("analisando 12 de 40...") em vez de encarar uma tela travada que não diz nada.

## O que muda para quem usa o sistema

**Para o gestor (quem pede a análise):**
- O clique em "Analisar" ou "Gerar insights" responde **na hora**, com um aviso claro de "em processamento" — nada de tela congelada por um minuto.
- Aparece um **indicador de progresso** ("12 de 40 analisados") que avança sozinho até concluir.
- A análise **não falha mais por tempo esgotado**, mesmo quando há muitos comentários.
- Se ele **fechar a aba** e voltar depois, a análise continua acontecendo nos bastidores — ao reabrir, ele vê o resultado ou o progresso atual.

**Para o cliente que dá o feedback:**
- Nenhuma mudança direta — ele continua respondendo o formulário normalmente. Mas, indiretamente, ganha um sistema mais estável: como a cota da IA deixa de estourar, as análises do dia a dia voltam a funcionar de forma confiável.

## Como vai funcionar

**Antes (hoje):**

```
Gestor clica "Analisar"
        │
        ▼
  [ tela travada, rodando o "relógio de ampulheta" ]
        │   o servidor: junta feedbacks → chama a IA → espera → chama de novo → espera...
        │   (tudo dentro do mesmo pedido HTTP, com o gestor esperando)
        ▼
  ✗ passou de ~60s → a infra corta → ERRO "tempo esgotado"
  ✗ tentou de novo várias vezes → ESTOUROU a cota diária da IA
```

**Depois (com fila + trabalhador):**

```
Gestor clica "Analisar"
        │
        ▼
  Sistema ANOTA o pedido na fila  ──►  responde NA HORA: "processando" (+ um nº de acompanhamento)
        │
        ▼
  O TRABALHADOR (em segundo plano) pega o pedido da fila
        │   processa os feedbacks aos poucos, RESPEITANDO o limite da IA
        │   (ex.: no máximo N pedidos por minuto e M por dia)
        ▼
  Tela do gestor PERGUNTA de tempos em tempos: "já terminou?"  ← isso se chama "polling"
        │   recebe: "12 de 40..." → "30 de 40..." → "concluído!"
        ▼
  ✓ sem tempo esgotado   ✓ sem estourar a cota   ✓ gestor acompanha o progresso
```

O "perguntar de tempos em tempos" (em inglês, *polling*) é como **olhar o painel de senhas** na praça de alimentação: a cada poucos segundos a tela do gestor faz uma pergunta curtinha ao servidor — "o pedido tal já terminou?" — e mostra o andamento. É barato e simples, e é o suficiente para esta etapa. (Uma versão mais sofisticada, em que o servidor *avisa sozinho* assim que termina, é uma melhoria futura, não necessária agora.)

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

> ⚠️ **Revisão de ago/2026 (verificado contra o código):** o mecanismo abaixo foi **refinado** após a verificação. As premissas originais que **mudaram** (detalhes na seção "Plano de execução detalhado" no fim):
> - **Fila própria com `SELECT ... FOR UPDATE SKIP LOCKED`** no lugar do `pg-boss` (evita o atrito com o pooler em modo transação e é a demonstração de banco mais forte).
> - **Worker no `feedback-analytics-api-gateway`**, não no `ia-analyze` (que é stateless, sem `DATABASE_URL`); o `ia-analyze` segue como o serviço de compute que o worker *chama*.
> - **Execução por *drain* via cron** (endpoint `/internal/worker/tick`), que roda na **infra Vercel atual sem host always-on** → desacopla esta etapa da [08](./08-infraestrutura-e-custo.md).
> - **Isolamento por `enterprise_id` + `tenantScope`** (app-level), pois a **RLS/`auth.uid()` foi removida** no cutover — não há mais o "padrão das 13 tabelas".
> - **Migrations no Drizzle** (`drizzle/*.sql`, próxima `0002`), não em `database/sql/`.

### O problema, no código de hoje

O fluxo inteiro roda **síncrono, dentro da requisição HTTP serverless**:

`iaAnalyze.controller.ts` → `iaAnalyze.service.ts` (`analyzeRawFeedbacks` / `regenerateFeedbackInsights`) → `iaAnalyze.provider.ts` (`runIaAnalyzeAnalysis`, faz `fetch` para o serviço `ia-analyze`) → `feedback-analytics-ia-analyze/.../iaAnalyze.service.ts` (`runIaAnalyzeService`) → `gemini.provider.ts` (`createIaApiClient` → `analyzeBatch`).

Pontos concretos que causam o timeout e o estouro de cota:

- **Tudo dentro do request HTTP.** O controller só responde depois que a última chamada ao Gemini volta. Em `vercel.json` há `"maxDuration": 300`, mas o **plano free (Hobby) corta em ~60s** — é a causa provável do "tempo esgotado".
- **Várias chamadas ao Gemini por clique.** `buildAnalysisBatches` fatia em lotes de ≤20 feedbacks por escopo; `runIaAnalyzeService` dispara os lotes com concorrência limitada (`mapWithConcurrency`, padrão 3). São N chamadas em sequência/paralelo dentro do mesmo request.
- **O retry multiplica o consumo.** Em `gemini.provider.ts`, `MAX_ATTEMPTS = 4` re-tenta em 429/503/5xx com backoff. Cada retry é **mais um pedido contra a cota** — e o relógio do timeout continua correndo durante os `sleep()` do backoff.
- **"Gerar insights" reprocessa quando há novidade.** `fetchAlreadyAnalyzedFeedbacks` busca até **100 feedbacks** (`limit = 100`). Hoje já existe um **cache de leitura** (entregue na etapa 00): se nenhum feedback é mais novo que o relatório salvo, devolve do banco **sem chamar o LLM**. Mas quando há novidade (ou `force`), o `regenerateFeedbackInsights` **remonta os lotes e reconsulta a IA de forma síncrona** — o mesmo risco de timeout que esta etapa resolve.

### A solução: fila própria no Postgres + drain por cron

**Fila própria (sem dependência nova).** Uma tabela `ia_analysis_job` no próprio Postgres é **a fila E o status**. O worker puxa o próximo job com `SELECT ... FOR UPDATE SKIP LOCKED` — o padrão clássico de fila em SQL, que evita dois workers pegarem o mesmo job sem travar a tabela. Zero infra nova (sem Redis, sem SQS, **sem `pg-boss`**), reaproveitando o Postgres do Supabase — e é a demonstração de banco mais forte (responde diretamente à crítica da banca).

**Contrato do job.** Um único tipo de job, com payload neutro:

```ts
// job: "ia-analyze"
type IaAnalyzeJob = {
  enterprise_id: string;
  scope_type: IaAnalyzeScopeType;          // COMPANY | PRODUCT | SERVICE | DEPARTMENT
  catalog_item_id: string | null;          // null = escopo empresa
  job_type: 'analyze_raw' | 'regenerate_insights'; // qual operação enfileirar
  requested_by: string;                    // userId, para auditoria
};
```

O `enqueue` substitui a chamada síncrona nos controllers: o controller passa a **só inserir o job e responder 202 Accepted** com o `jobId` (a própria linha de `ia_analysis_job`).

**Rate limiter (controle de ritmo) — *token bucket* duplo.** Um limitador em duas janelas, alinhado às cotas reais do Gemini free:
- **por minuto** (requisições/minuto, o RPM do modelo); e
- **por dia** (requisições/dia, a cota diária que hoje estoura).

Implementação simples e durável: uma tabela `ia_rate_budget` (janela de minuto e de dia) reservada **atomicamente** antes de cada chamada à IA; se não houver "ficha" (token) disponível, o worker **não falha** — ele **re-agenda o job** (`status=waiting_budget`, `next_run_at`) para a próxima janela. Isso é *back-pressure*: a pressão da fila não vira pressão na IA; o ritmo é ditado pelo orçamento, não pelo número de cliques.

**Idempotência.** Reaproveitar o que já existe: `feedback_analysis` já é a fonte da verdade do "o que já foi analisado", e o service já filtra via `fetchAlreadyAnalyzedFeedbackIds`. Somar a isso:
- um **índice parcial único** em `ia_analysis_job` por `(enterprise_id, job_type, scope_type, catalog_item_id)` enquanto o job está ativo → **não enfileira duas vezes** o mesmo pedido (resolve o "duplo clique" e o "clica de novo porque travou");
- `unique(feedback_id)` em `feedback_analysis` + `INSERT ... ON CONFLICT DO NOTHING` → mesmo que um job rode duas vezes, **não duplica linhas** (esse `unique` **não existe hoje** e entra na migration `0002`).

**Retomada / resiliência.** A persistência é por lote e o service já pula os já-analisados (`fetchAlreadyAnalyzedFeedbackIds`); se o worker parar no meio, o próximo tick **continua de onde parou**. Backoff exponencial via `attempts`/`next_run_at` para 429/5xx, em vez do retry *dentro* do request de hoje.

**Status para o polling.** A própria linha `ia_analysis_job (id, enterprise_id, scope_type, catalog_item_id, status, total, done, error_code, ...)` — isolada por **`enterprise_id` + `tenantScope`** (app-level; a RLS/`auth.uid()` foi removida no cutover). O front faz `GET /api/protected/ia-analyze/jobs/:id` a cada poucos segundos e lê `done`/`total`/`status`. O worker atualiza essa linha a cada lote concluído.

**Onde o worker roda — na infra atual, sem host always-on.** O worker mora no **`feedback-analytics-api-gateway`** (único repo com acesso ao banco e à orquestração; o `ia-analyze` é stateless e segue como o serviço de compute que o worker *chama*). Em vez de um processo sempre-ligado, um endpoint interno `POST /internal/worker/tick` é chamado por **cron externo** (~1 min) e drena um lote por invocação — cabe no serverless da Vercel e **desacopla esta etapa da [08](./08-infraestrutura-e-custo.md)**. O mesmo núcleo `drainJobs()` pode virar um loop always-on num host externo depois (etapa 08), sem reescrita.

### Por camada

| Camada | O que muda |
|---|---|
| **Backend (gateway)** | Controllers de `analyze`/`regenerate` passam a **enfileirar** (202 + `jobId`) atrás da flag `IA_ASYNC_ENABLED`. Novos endpoints: `GET .../jobs/:id` (polling) e `POST /internal/worker/tick` (drain). |
| **Worker (no gateway)** | `drainJobs()` reusa a lógica existente (`buildAnalysisBatches`, `runIaAnalyzeAnalysis`, `insertFeedbackAnalysisRows`), sob o rate limiter e gravando progresso. |
| **Banco** | Migration Drizzle `0002`: tabelas `ia_analysis_job` e `ia_rate_budget` (isoladas por `enterprise_id`), e `unique(feedback_id)` em `feedback_analysis`. |
| **Infra** | Nenhum host novo: cron externo bate no `/internal/worker/tick`. Variáveis: limites por minuto/dia, lotes por tick, flag. |
| **Frontend** | Trocar "esperar resposta" por "enfileirar + polling de progresso" (preservando o contrato de transição de flag dos hooks scoped). |

## Riscos e decisões em aberto

- **Execução do worker.** No MVP, um **cron externo** bate no `/internal/worker/tick` (roda na Vercel atual, sem host novo) → **não depende da etapa 08**. Um worker always-on num host externo (Oracle/Fly) fica como **upgrade futuro** (mesmo `drainJobs()`), aí com pool dedicado em modo sessão.
- **Polling vs. tempo real.** O polling é simples e suficiente, mas gera requisições periódicas. Para o TCC é adequado; *server-sent events*/websocket fica como melhoria futura, **fora do escopo**.
- **Calibrar os limites do *rate limiter*.** Os números exatos de RPM/dia do Gemini free podem mudar; os limites precisam ser **configuráveis por variável de ambiente**, não fixos no código (lição do `gemini-2.5-flash` *hardcoded*).
- **Conexões ao Postgres.** No modelo cron-drain cada tick é uma invocação curta que reusa o **pooler em modo transação** já configurado (`prepare:false`) — `FOR UPDATE SKIP LOCKED` funciona nele. Só o upgrade para worker always-on precisaria de um pool dedicado em modo sessão (teto de conexões do Supabase free).
- **Migração suave.** Manter, por trás de uma *feature flag*, o caminho síncrono antigo até o assíncrono estar validado — para não quebrar o fluxo durante a transição.
- **Acoplamento com o provedor de IA.** O worker deve chamar a IA pela **porta** `IaApiClient`, não direto pelo Gemini, para já nascer compatível com a **[04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md)**.

## Plano de execução detalhado (revisado ago/2026)

> Verificado contra o código dos repositórios. Decisões travadas: **fila própria (SKIP LOCKED)** + **drain por cron**. Status geral: 🟢 Em andamento.

### Arquitetura alvo

```
CLIQUE (serverless, rápido)
  Web → Gateway POST /api/protected/ia-analyze/analyze-raw|regenerate-insights
      → enfileira em ia_analysis_job (INSERT + dedup) → 202 { jobId }

DRAIN (serverless, curto, ~1 min)
  Cron externo → POST /internal/worker/tick (token)
      → drainJobs(limit): claim SKIP LOCKED → por lote: checa rate budget →
        runIaAnalyzeAnalysis(1 lote) → insert idempotente → job.done++
      → sem orçamento: reschedule (status=waiting_budget, next_run_at)

POLLING (progresso)
  Web → GET /api/protected/ia-analyze/jobs/:id → { status, done, total }
      → ao concluir, dispara a transição de flag que os hooks scoped já observam
```

O drain roda como invocação serverless curta usando o `getDb()` atual (pooler transação, `prepare:false`) — `FOR UPDATE SKIP LOCKED` funciona dentro de transação no pooler; **não precisa de conexão modo sessão**.

### Camada 1 — Banco (gateway, migration `0002`)

Editar o schema Drizzle (novo `drizzle/schema/iaJobs.ts` re-exportado no barrel `drizzle/schema.ts`) → `db:generate` → `db:migrate`/`db:check`. Trigger `set_updated_at` e índice parcial entram como SQL manual na migration custom (padrão do `0001`).

- **`ia_analysis_job`** (espelha `feedback_insights_report`): `id`, `enterprise_id` FK cascade, `job_type` check (`analyze_raw|regenerate_insights`), `scope_type` check, `catalog_item_id` FK, `status` check (`queued|running|waiting_budget|completed|failed`), `total`/`done`, `options jsonb`, `attempts`, `next_run_at`, `error_code`, `requested_by`, timestamps. Índice **parcial único** `(enterprise_id, job_type, scope_type, catalog_item_id) WHERE status IN ('queued','running','waiting_budget')` (dedup do duplo-clique) + índice `(status, next_run_at)` (claim).
- **`ia_rate_budget`**: token bucket durável (`window_kind` minute/day, `window_start`, `used`, `unique(window_kind, window_start)`); reserva atômica via `INSERT ... ON CONFLICT DO UPDATE ... WHERE used < limite`.
- **`feedback_analysis`**: adicionar `unique(feedback_id)` (idempotência real — hoje não existe).

### Camada 2 — Fila + worker (gateway)

- `[NEW] src/repositories/iaJob.repository.ts` — `enqueue` (dedup pelo índice parcial), `getByIdScoped` (`scopedByEnterprise`), `claimNext` (SKIP LOCKED), `updateProgress`, `complete`, `fail`, `reschedule`.
- `[NEW] src/libs/iaJob/rateBudget.ts` — token bucket; envs `IA_RPM_LIMIT`/`IA_RPD_LIMIT`.
- `[NEW] src/libs/iaJob/drainJobs.ts` — núcleo: claim ≤N jobs; por job, processa lote a lote sob o budget, persiste e atualiza `done`; sem orçamento → `reschedule`. Bound por `IA_WORKER_BATCHES_PER_TICK`.
- `[MODIFY] src/services/iaAnalyze.service.ts` — extrair `prepareAnalyzeRawJob` (fetch+filtros+dedup+`buildAnalysisBatches`) e `runOneBatch` (`runIaAnalyzeAnalysis` + `insertFeedbackAnalysisRows` idempotente) para reuso do worker; as funções síncronas atuais seguem para o caminho flag-off.

### Camada 3 — Endpoints (gateway)

- `[MODIFY] src/controllers/protected/iaAnalyze.controller.ts` — atrás da flag `IA_ASYNC_ENABLED`, enfileirar e responder **202 `{ jobId }`** (flag off = síncrono atual).
- `[NEW] getIaJobController` → `GET /protected/ia-analyze/jobs/:id` (escopado por `resolveEnterpriseId`).
- `[NEW] workerTickController` → `POST /internal/worker/tick` (token `WORKER_TICK_TOKEN`, sem `requireAuth`) → `drainJobs`.
- `[MODIFY] .env.example` — `IA_ASYNC_ENABLED`, `WORKER_TICK_TOKEN`, `IA_RPM_LIMIT`, `IA_RPD_LIMIT`, `IA_WORKER_BATCHES_PER_TICK`.

### Camada 4 — Frontend (web)

Preservar o contrato de transição de flag `true → false` — os 3 hooks scoped (`useScopedPendingCount`/`useScopedInsightsReport`/`useScopedFeedbackAnalysis`) já refazem o fetch nessa transição.

- `[MODIFY] src/services/serviceFeedbacks.ts` — retornam `{ jobId }`; `[NEW]` `ServiceGetAnalysisJob(jobId)`.
- `[MODIFY] src/routes/actions/actionFeedbackInsightsReport.ts` — não `await` a IA; retorna `{ ok, jobId }`.
- `[NEW] src/lib/hooks/useAnalysisJobPolling.ts` — polling ~3s até `completed|failed`; aciona a transição de flag ao concluir.
- `[MODIFY] layouts/user.tsx` + `src/lib/context/insightsControls.tsx` + `components/user/layout/InsightsActionBar.tsx` — iniciar polling, expor `progress {done,total}`, labels "Analisando 12 de 40".
- Tipos async definidos **localmente** (evita bump de tag do `@feedback/lib-shared`).

### Camada 5 — Infra/cron (sem host novo)

- Cron externo (cron-job.org ~1 min, ou GitHub Actions ~5 min) faz `POST /internal/worker/tick` com o token — só um "pinger" HTTP, sem host always-on nem Dockerfile.
- **Upgrade futuro (etapa 08):** o mesmo `drainJobs()` vira um loop always-on num host externo, aí com pool dedicado em modo sessão. Sem reescrita.

### Esforço estimado

| Item | Esforço |
|---|---|
| Migration + schema (jobs, budget, unique) | ~3h |
| Repositório de fila + enqueue + polling | ~5h |
| drain + tick + refactor do pipeline por lote | ~8h |
| Rate limiter + reschedule | ~3h |
| Frontend (polling + progresso) | ~5h |
| regenerate assíncrono + cron + docs + testes | ~5h |
| **Total** | **~27–30h** |

## Como vamos saber que deu certo

> Estado em ago/2026: **backend (gateway) implementado e validado** (branch `analise-assincrona`, migration `0002`, worker/drain, rate limiter; 136 testes verdes, incl. o e2e do drain com fake ia-analyze). O frontend (consumir 202 + polling + barra "X de Y") está em **handoff** (Etapa 5).

- [x] Clicar "Analisar"/"Gerar insights" responde na hora com **202 + `jobId`** (backend ✓; a percepção na tela depende do frontend).
- [x] Uma análise com **40+ feedbacks** conclui **sem timeout** — validado localmente (lotes processados por tick, fora da requisição).
- [x] A **cota não estoura**: rate limiter (token bucket minuto/dia); jobs excedentes viram `waiting_budget` e são re-agendados, não falhados.
- [x] **Duplo clique** não cria trabalho duplicado (índice parcial único) nem linhas duplicadas em `feedback_analysis` (`unique(feedback_id)` + `ON CONFLICT`).
- [x] Derrubar o worker **no meio** e religá-lo: o job **retoma de onde parou** (validado — retomada entre ticks).
- [ ] A tela mostra **progresso real** ("X de Y") — **Etapa 5 (frontend)**.
- [x] O endpoint de status respeita o **isolamento por `enterprise_id`** (app-level): um gestor não enxerga o job de outra empresa.

## Etapas de entrega

1. **Migration `0002`.** Tabelas `ia_analysis_job` e `ia_rate_budget` + `unique(feedback_id)` em `feedback_analysis`; schema Drizzle + trigger `set_updated_at`.
2. **Fila mínima.** `iaJob.repository` (enqueue com dedup pelo índice parcial); controllers enfileiram (202 + `jobId`) atrás da flag `IA_ASYNC_ENABLED`; `GET .../jobs/:id` (polling).
3. **Worker/drain.** `drainJobs()` + `POST /internal/worker/tick`; refactor do pipeline (`prepareAnalyzeRawJob`/`runOneBatch`) para progresso por lote.
4. **Rate limiter.** *Token bucket* por minuto e por dia (`ia_rate_budget`); jobs sem orçamento viram `waiting_budget` e são re-agendados (back-pressure). Limites por variável de ambiente.
5. **Frontend.** Action retorna `jobId`; `useAnalysisJobPolling`; progresso "X de Y" na UI (preservando os hooks scoped).
6. **`regenerate_insights` assíncrono.** Mover "Gerar insights" para a fila (reusa o cache de leitura já existente).
7. **Cron + limpeza.** Ligar o cron externo; documentar variáveis/operação; manter o síncrono atrás da flag até validar.

## O que isso demonstra no TCC

Esta é a **peça central de arquitetura** do trabalho. Rende um capítulo forte sobre:

- **Arquitetura assíncrona** e o padrão **produtor–consumidor** (fila + worker), com justificativa de *por que* o modelo síncrono falha em ambiente serverless.
- **Filas de jobs** e a escolha de projeto de usar o **próprio banco como fila** com `SELECT ... FOR UPDATE SKIP LOCKED` (custo zero, sem dependência) — uma decisão arquitetural defensável que exercita concorrência e bloqueio em SQL.
- **Rate limiting** com *token bucket* e **back-pressure**: como proteger um recurso externo escasso (a cota da IA) sem derrubar o sistema.
- **Idempotência** e **resiliência/retomada**: garantias de "exatamente-uma-vez-do-ponto-de-vista-do-resultado" diante de falhas e retentativas.
- Um **antes/depois mensurável** (taxa de timeout, consumo de cota, latência percebida) — material ideal para a seção de resultados.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [00 — Estabilização](./00-estabilizacao.md) — conserta os sintomas (timeout, retry, cota) na superfície; **esta etapa resolve a causa raiz**.
- [04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md) — o worker chama a IA pela **porta** `IaApiClient`, ficando agnóstico de provedor.
- [05 — Feedback por áudio](./05-feedback-por-audio.md) — a transcrição de áudio é mais um trabalho pesado que se **encaixa naturalmente nesta mesma fila/worker**.
- [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) — **upgrade futuro** (opcional): trocar o cron-drain por um worker always-on num host externo. Esta etapa **não depende** mais da 08.
