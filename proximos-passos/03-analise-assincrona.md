# 03 — Análise assíncrona da IA (worker + fila)

> **Em uma frase:** em vez de fazer o usuário esperar a IA terminar (e travar no meio do caminho), o sistema passa a *anotar o pedido* e processá-lo em segundo plano, no ritmo certo.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
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
- **O trabalhador** (em inglês, *worker*) é o *cozinheiro*: um programa que fica **sempre ligado**, pega os pedidos da comanda um a um e os executa em segundo plano.
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
  O TRABALHADOR (sempre ligado) pega o pedido da fila
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

### O problema, no código de hoje

O fluxo inteiro roda **síncrono, dentro da requisição HTTP serverless**:

`iaAnalyze.controller.ts` → `iaAnalyze.service.ts` (`analyzeRawFeedbacks` / `regenerateFeedbackInsights`) → `iaAnalyze.provider.ts` (`runIaAnalyzeAnalysis`, faz `fetch` para o serviço `ia-analyze`) → `feedback-analytics-ia-analyze/.../iaAnalyze.service.ts` (`runIaAnalyzeService`) → `gemini.provider.ts` (`createIaApiClient` → `analyzeBatch`).

Pontos concretos que causam o timeout e o estouro de cota:

- **Tudo dentro do request HTTP.** O controller só responde depois que a última chamada ao Gemini volta. Em `vercel.json` há `"maxDuration": 300`, mas o **plano free (Hobby) corta em ~60s** — é a causa provável do "tempo esgotado".
- **Várias chamadas ao Gemini por clique.** `buildAnalysisBatches` fatia em lotes de ≤20 feedbacks por escopo; `runIaAnalyzeService` dispara os lotes com concorrência limitada (`mapWithConcurrency`, padrão 3). São N chamadas em sequência/paralelo dentro do mesmo request.
- **O retry multiplica o consumo.** Em `gemini.provider.ts`, `MAX_ATTEMPTS = 4` re-tenta em 429/503/5xx com backoff. Cada retry é **mais um pedido contra a cota** — e o relógio do timeout continua correndo durante os `sleep()` do backoff.
- **"Gerar insights" reprocessa tudo.** `fetchAlreadyAnalyzedFeedbacks` busca até **100 feedbacks** (`limit = 100`) e `regenerateFeedbackInsights` **não tem cache**: cada clique remonta os lotes e **reconsulta o Gemini do zero**.

### A solução: fila no Postgres + worker always-on

**Fila — `pg-boss`.** Usar [`pg-boss`](https://github.com/timgit/pg-boss), uma fila de jobs que vive **dentro do próprio Postgres** (cria um schema `pgboss` com as tabelas de jobs). Vantagem decisiva para um TCC com orçamento zero: **nenhuma infraestrutura nova** — sem Redis, sem SQS, sem outro serviço para pagar/manter. Reaproveita o Postgres que já temos no Supabase. O `pg-boss` já entrega de fábrica: persistência durável, retry com backoff, `expireInSeconds`, agendamento (`throttle`/`singletonKey`) e *archiving* de jobs concluídos.

**Contrato do job.** Um único tipo de job, com payload neutro:

```ts
// job: "ia-analyze"
type IaAnalyzeJob = {
  enterprise_id: string;
  scope_type: IaAnalyzeScopeType;          // COMPANY | PRODUCT | SERVICE | DEPARTMENT
  catalog_item_id: string | null;          // null = escopo empresa
  job_type: 'analyze_raw' | 'regenerate_insights'; // qual operação enfileirar
  requested_by: string;                    // userId, para auditoria/RLS
};
```

O `enqueue` substitui a chamada síncrona nos controllers: o controller passa a **só inserir o job e responder 202 Accepted** com um identificador (o `id` do job do `pg-boss`, ou uma linha própria de status — ver abaixo).

**Rate limiter (controle de ritmo) — *token bucket* duplo.** Um limitador em duas janelas, alinhado às cotas reais do Gemini free:
- **por minuto** (requisições/minuto, o RPM do modelo); e
- **por dia** (requisições/dia, a cota diária que hoje estoura).

Implementação simples e durável: uma tabela `ia_rate_budget (enterprise_id?, window_day date, minute_bucket, tokens_used, ...)` consultada/atualizada **dentro de uma transação** antes de cada chamada ao Gemini; se não houver "ficha" (token) disponível, o worker **não falha** — ele **re-agenda o job** (`pg-boss` `retry`/`delay`) para a próxima janela. Isso é *back-pressure*: a pressão da fila não vira pressão na IA; o ritmo é ditado pelo orçamento, não pelo número de cliques.

**Idempotência.** Reaproveitar o que já existe: `feedback_analysis` já é a fonte da verdade do "o que já foi analisado", e o service já filtra via `fetchAlreadyAnalyzedFeedbackIds`. Somar a isso:
- `singletonKey` do `pg-boss` por `(enterprise_id, scope_type, catalog_item_id, job_type)` → **não enfileira duas vezes** o mesmo pedido enquanto um está pendente/ativo (resolve o "duplo clique" e o "clica de novo porque travou");
- um `INSERT ... ON CONFLICT DO NOTHING` em `feedback_analysis` (ou checagem de `already analyzed` por lote) → mesmo que um job rode duas vezes, **não duplica linhas**.

**Retomada / resiliência.** Se o worker cair no meio, o `pg-boss` devolve o job à fila (visibilidade/`expireInSeconds`) e ele **continua de onde parou** — como os lotes são fatiados e a persistência é por lote, o reprocessamento pula o que já foi gravado (idempotência acima). Backoff exponencial nos jobs (`retryBackoff: true`) para 429/503, em vez do retry *dentro* do request de hoje.

**Status para o polling.** Tabela leve `ia_analysis_job (id, enterprise_id, scope_type, catalog_item_id, status, total, done, error_code, created_at, updated_at)` com **RLS multi-tenant** (mesmo padrão `auth.uid()` das outras 13 tabelas). O front faz `GET /api/protected/ia-analyze/jobs/:id` a cada poucos segundos e lê `done`/`total`/`status`. O worker atualiza essa linha a cada lote concluído.

**Onde o worker roda (always-on).** O `pg-boss` precisa de um **processo de longa duração** consumindo a fila — o que **não cabe em função serverless** (que é efêmera por natureza). Esta é a ponte direta com a etapa de infraestrutura: o serviço `ia-analyze` (ou um novo processo `worker`) precisa rodar como container/processo sempre-ligado. Ver **[08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md)** para a decisão de hospedagem (ex.: container free-tier em Railway/Render/Fly, ou um host barato), incluindo como o worker e o serviço HTTP convivem.

### Por camada

| Camada | O que muda |
|---|---|
| **Backend (gateway)** | Controllers de `analyze`/`regenerate` passam a **enfileirar** (202 + id) em vez de executar. Novo endpoint `GET .../jobs/:id` para o polling. |
| **Backend (worker)** | Novo consumidor `pg-boss` que chama a lógica **já existente** (`runIaAnalyzeService`), porém sob o rate limiter e gravando progresso. |
| **Banco** | Schema do `pg-boss`; tabelas `ia_analysis_job` e `ia_rate_budget` (com RLS); migrações versionadas em `database/sql/`. |
| **Infra** | Worker always-on (ver etapa 08). Variáveis: limites por minuto/dia, modelo, concorrência. |
| **Frontend** | Trocar "esperar resposta" por "enfileirar + polling de progresso". (Mudança pequena de UX; detalhe fora do escopo deste doc.) |

## Riscos e decisões em aberto

- **Worker always-on tem custo/operação.** É a maior mudança de infra do projeto e depende da etapa 08. Risco mitigado por usar `pg-boss` (sem Redis) e free-tiers de container — mas exige um processo de pé, não apenas serverless.
- **Polling vs. tempo real.** O polling é simples e suficiente, mas gera requisições periódicas. Para o TCC é adequado; *server-sent events*/websocket fica como melhoria futura, **fora do escopo**.
- **Calibrar os limites do *rate limiter*.** Os números exatos de RPM/dia do Gemini free podem mudar; os limites precisam ser **configuráveis por variável de ambiente**, não fixos no código (lição do `gemini-2.5-flash` *hardcoded*).
- **Conexões ao Postgres.** `pg-boss` mantém conexões; em Supabase free há teto de conexões. Avaliar usar o **pooler** e um pool pequeno e dedicado ao worker.
- **Migração suave.** Manter, por trás de uma *feature flag*, o caminho síncrono antigo até o assíncrono estar validado — para não quebrar o fluxo durante a transição.
- **Acoplamento com o provedor de IA.** O worker deve chamar a IA pela **porta** `IaApiClient`, não direto pelo Gemini, para já nascer compatível com a **[04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md)**.

## Como vamos saber que deu certo

- [ ] Clicar "Analisar"/"Gerar insights" responde em **menos de 2s** com status "em processamento" (202), **sem** esperar a IA.
- [ ] Uma análise com **40+ feedbacks** conclui **sem nenhum erro de tempo esgotado**.
- [ ] Em um dia de uso normal de teste, a **cota diária do Gemini não estoura** (o rate limiter segura o ritmo; jobs excedentes são re-agendados, não falhados).
- [ ] **Duplo clique** (ou clicar de novo após travar) **não cria** trabalho duplicado nem linhas duplicadas em `feedback_analysis` (idempotência).
- [ ] Derrubar o worker **no meio** de um job e religá-lo: o job **retoma e conclui**, sem reprocessar o que já foi gravado.
- [ ] A tela mostra **progresso real** ("X de Y") que avança até "concluído".
- [ ] O endpoint de status respeita **RLS**: um gestor não enxerga o job de outra empresa.

## Etapas de entrega

1. **Fila mínima.** Subir `pg-boss` no Postgres; mover `analyze_raw` para um job; controller passa a enfileirar (202 + id). Worker roda **sem** rate limiter ainda (só tira o trabalho do request).
2. **Status + polling.** Tabela `ia_analysis_job` com RLS; worker grava `done/total`; endpoint `GET .../jobs/:id`; front mostra progresso.
3. **Rate limiter.** *Token bucket* por minuto e por dia (`ia_rate_budget`); jobs sem orçamento são re-agendados (back-pressure). Limites por variável de ambiente.
4. **Idempotência + retomada.** `singletonKey` por escopo; `ON CONFLICT DO NOTHING`; backoff; testar queda do worker no meio.
5. **`regenerate_insights` assíncrono + cache.** Mover "Gerar insights" para a fila e evitar reprocessar quando nada mudou desde o último relatório.
6. **Limpeza.** Remover (ou esconder atrás de flag) o caminho síncrono antigo; documentar variáveis e operação do worker.

## O que isso demonstra no TCC

Esta é a **peça central de arquitetura** do trabalho. Rende um capítulo forte sobre:

- **Arquitetura assíncrona** e o padrão **produtor–consumidor** (fila + worker), com justificativa de *por que* o modelo síncrono falha em ambiente serverless.
- **Filas de mensagens/jobs** e a escolha de projeto de usar o **próprio banco como fila** (`pg-boss`) para custo zero — uma decisão arquitetural defensável e mensurável.
- **Rate limiting** com *token bucket* e **back-pressure**: como proteger um recurso externo escasso (a cota da IA) sem derrubar o sistema.
- **Idempotência** e **resiliência/retomada**: garantias de "exatamente-uma-vez-do-ponto-de-vista-do-resultado" diante de falhas e retentativas.
- Um **antes/depois mensurável** (taxa de timeout, consumo de cota, latência percebida) — material ideal para a seção de resultados.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [00 — Estabilização](./00-estabilizacao.md) — conserta os sintomas (timeout, retry, cota) na superfície; **esta etapa resolve a causa raiz**.
- [04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md) — o worker chama a IA pela **porta** `IaApiClient`, ficando agnóstico de provedor.
- [05 — Feedback por áudio](./05-feedback-por-audio.md) — a transcrição de áudio é mais um trabalho pesado que se **encaixa naturalmente nesta mesma fila/worker**.
- [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) — onde hospedar o **worker always-on** que esta etapa exige.
