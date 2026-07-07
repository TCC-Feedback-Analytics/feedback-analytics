# 00 — Diagnóstico do timeout da análise de IA (~60s)

> **Em uma frase:** confirmar, com evidência de código + medição nos logs, que a análise de IA falha por **estourar o teto de duração de função do plano free da Vercel** (da ordem de ~60s) ao rodar **síncrona dentro da requisição HTTP** — o que justifica formalmente as etapas [03 — Análise assíncrona](./03-analise-assincrona.md) e [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md).

| Campo | Valor |
|---|---|
| **Parte** | 00-F (entrega da [Estabilização](./00-estabilizacao.md)) |
| **Tipo** | Diagnóstico / documentação (não reescreve arquitetura) |
| **Status** | 🟢 Causa confirmada por código · ⏳ aguardando colar a medição de produção |
| **Depende de** | Logs da Vercel (coleta manual no painel) |

## Para qualquer leitor

Quando o gestor pede uma análise de muitos feedbacks, o sistema tenta fazer **tudo de uma vez, enquanto ele espera** numa tela de carregamento. O servidor onde isso roda (Vercel, plano gratuito) tem uma regra rígida: **toda tarefa que passa de ~1 minuto é cortada no meio**. Como analisar dezenas de comentários com a IA leva tempo, a tarefa bate nesse teto e é interrompida — o gestor recebe um erro de "tempo esgotado".

Este documento **não conserta** isso (a cura é estrutural, nas etapas 03 e 08). Ele **prova a causa**: mostra, no código, por que a tarefa demora, e mostra, nos logs, que a interrupção acontece exatamente perto dos ~60s. É a evidência que fundamenta a decisão de mover a análise para um "trabalhador sempre ligado".

## A causa, no código (evidência verificável)

**1. Toda a análise roda síncrona, dentro da requisição HTTP serverless.** A cadeia é:

```
[gateway] iaAnalyze.controller.ts  →  iaAnalyze.service.ts  →  providers/iaAnalyze.provider.ts (fetch HTTP)
                                                                        │
                                                                        ▼
[ia-analyze] services/iaAnalyze.service.ts (runIaAnalyzeService)  →  providers/gemini.provider.ts (analyzeBatch)
```

O controller só responde **depois** que a última chamada ao Gemini volta. São **duas funções serverless empilhadas** (o gateway e o serviço `ia-analyze`), e **cada uma** tem o próprio teto de duração.

**2. O teto configurado é ignorado no plano free.** Os `vercel.json` (um por serviço) pedem `maxDuration: 300` (300s):

- [`feedback-analytics-api-gateway/vercel.json`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/vercel.json) · [`feedback-analytics-web/vercel.json`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/vercel.json) · [`feedback-analytics-ia-analyze/vercel.json`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/vercel.json)

Porém, no **plano Hobby (free) da Vercel**, o teto real de duração de função é **muito menor** (da ordem de **~60s**; confirmar o limite vigente do plano na documentação atual da Vercel). Ou seja: `maxDuration: 300` **excede o permitido pelo plano e é limitado/ignorado** pela plataforma — a função é cortada bem antes dos 300s.

**3. O tempo cresce com o volume — por design.** Quanto mais feedbacks, mais a análise demora:

| Fator | Onde | Valor | Efeito no tempo |
|---|---|---|---|
| Feedbacks por execução | [`iaAnalyze.service.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/services/iaAnalyze.service.ts) (`analyzeRawFeedbacks`) | default **50** (máx. 100) | mais feedbacks → mais lotes |
| Tamanho do lote | [`libs/iaAnalyze/build.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/libs/iaAnalyze/build.ts) (`DEFAULT_MAX_FEEDBACKS_PER_BATCH`) | **20** por lote | N feedbacks ⇒ ⌈N/20⌉ chamadas ao Gemini |
| Concorrência | [`feedback-analytics-ia-analyze/src/services/iaAnalyze.service.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/services/iaAnalyze.service.ts) (`DEFAULT_GEMINI_CONCURRENCY`) | **3** em paralelo | os lotes correm de 3 em 3, em ondas |
| Retry/backoff | [`gemini.provider.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/providers/gemini.provider.ts) (`MAX_ATTEMPTS`) | até **4** tentativas, backoff até 20s | cada falha transitória **soma `sleep`** ao tempo decorrido |

> A latência típica de uma chamada ao Gemini fica em ~20–30s ([comentário em `readEnvs.ts:14`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/libs/iaAnalyze/readEnvs.ts)). Com vários lotes em ondas de 3, mais qualquer retry com backoff, é fácil ultrapassar 60s — e aí a função é cortada.

**4. O timeout interno do gateway (280s) só dispara DEPOIS do corte da Vercel.** O gateway aborta a chamada remota em `DEFAULT_REMOTE_TIMEOUT_MS = 280_000` ([`readEnvs.ts:16`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/libs/iaAnalyze/readEnvs.ts)) — pensado para ficar abaixo do `maxDuration: 300`. Mas como o teto **real** do plano é ~60s, **a Vercel mata a função muito antes** de o abort de 280s acontecer. Por isso o erro chega como um corte opaco de infraestrutura (502/504), não como o "demorou demais" tipado que o código tentaria devolver.

**5. O instrumento de medição já existe.** O gateway já loga o tempo decorrido de cada execução de IA em `logIaAnalyzeFailure` ([`iaAnalyze.controller.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/controllers/protected/iaAnalyze.controller.ts)):

```
[ia-analyze:analyze-raw] code=... status=... mode=... baseUrl=... elapsedMs=<N>
[ia-analyze:regenerate-insights] code=... status=... mode=... baseUrl=... elapsedMs=<N>
```

Basta correlacionar o `elapsedMs` registrado (e a **duração da função** mostrada no painel da Vercel) com o ponto de corte.

## Como medir (passo a passo na Vercel)

> Esta é a parte que precisa ser feita por quem tem acesso ao painel da Vercel (produção/developer).

1. No painel da Vercel, abrir o projeto do **gateway** e do **ia-analyze** → aba **Logs** (Runtime Logs) / **Observability**.
2. Reproduzir uma análise **grande** (ex.: um escopo com ≥ 40 feedbacks) para forçar o estouro.
3. Procurar nos logs do gateway as linhas `[ia-analyze:analyze-raw] ... elapsedMs=` e anotar o `elapsedMs` das execuções que falharam.
4. No painel, anotar a **Duration** da invocação da função que falhou (a Vercel mostra a duração e marca timeouts).
5. Confirmar o padrão: as falhas concentram-se quando a duração chega perto do teto do plano (~60s), enquanto análises pequenas (poucos lotes) terminam abaixo dele e têm sucesso.

### Planilha de medição (preencher com dados reais)

| Data | Função | Nº feedbacks | Nº lotes (⌈N/20⌉) | `elapsedMs` logado | Duration (painel) | Resultado | Código de erro |
|---|---|---|---|---|---|---|---|
| _a preencher_ | analyze-raw | | | | | ✅/⏱️ timeout | |
| _a preencher_ | analyze-raw | | | | | | |
| _a preencher_ | regenerate-insights | | | | | | |

**Limite de plano observado (preencher):** ~_____ s · **Plano Vercel ativo:** _____

## Conclusão

- **Causa confirmada:** a análise estoura o teto de duração de função do plano free porque roda **síncrona dentro da requisição**, e o tempo cresce com o número de lotes (× latência do Gemily × retries).
- **Não é problema de código de aplicação** — é uma **incompatibilidade entre carga de trabalho longa e o modelo serverless free**. Mexer em `maxDuration` não resolve (o plano ignora).
- **Justifica formalmente:**
  - **[Etapa 03 — Análise assíncrona](./03-analise-assincrona.md):** tirar a análise do ciclo da requisição (fila + worker), eliminando a exposição ao teto.
  - **[Etapa 08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md):** hospedar o worker num processo **sempre ligado**, sem teto de ~60s.

## Mitigação-ponte (opcional, paliativa)

Enquanto a etapa 03 não chega, dá para **reduzir o nº default de feedbacks por execução** para caber na janela de ~60s:

- `analyzeRawFeedbacks` — default `limit = 50` ([`iaAnalyze.service.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/services/iaAnalyze.service.ts)).
- `fetchAlreadyAnalyzedFeedbacks` — default `limit = 100` ([`iaAnalyze.repository.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/repositories/iaAnalyze.repository.ts)).

> ⚠️ **É paliativo — mascara o sintoma, não resolve.** Reduz a cobertura da análise (menos feedbacks por rodada) e só é aceitável **como ponte** até a etapa 03. Não aplicar sem necessidade; se aplicar, registrar o valor escolhido e o motivo.

## Relacionado

- [⟵ 00 — Estabilização](./00-estabilizacao.md)
- [03 — Análise assíncrona](./03-analise-assincrona.md) — solução estrutural (fila + worker)
- [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) — worker always-on sem teto de duração
