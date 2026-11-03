# Testes — IA Analyze (`feedback-analytics-ia-analyze`)

Este documento detalha a arquitetura, a estrutura e a especificação dos testes automatizados do serviço Serverless **IA Analyze**. O serviço recebe pedidos do API Gateway, chama o LLM da empresa (provedor, chave e modelo chegam nos headers `x-llm-*`; o Gateway configura o **OpenRouter**, e há também um adaptador **Gemini**) e devolve sentimentos estruturados, palavras-chave, aspectos, a síntese dos insights, o diagnóstico do escopo e sugestões de perguntas.

!!! info "Conferido em 03/11/2026"
    Inventário refeito contra o repositório: **13 arquivos** de teste. A versão anterior listava 6 arquivos e 46 testes e tratava o Gemini como único provedor. O número de testes muda a cada PR; o total atual sai no fim do `npm test`.

---

## Status da Cobertura

Os testes do serviço IA utilizam o **Vitest** como motor de execução (`vitest.config.ts`: ambiente `node`, arquivos `src/tests/**/*.test.ts`) e o **Supertest** para validar os endpoints locais simulando chamadas HTTP internas vindas da API Gateway. Nenhum teste chama um LLM de verdade: as rotas mockam os serviços, os serviços mockam a fábrica de provedores, e os testes dos provedores mockam o `fetch` (OpenRouter) e o `@google/genai` (Gemini).

> **Total: 13 arquivos de teste em `src/tests/`**

!!! note "Sem suíte dependente de ambiente"
    Todas as suítes do IA Analyze são **unitárias/de rota mockadas** e **seguem automatizadas no CI** (job `unit-tests` do `ci.yml`). O serviço não tem banco e não possui testes de integração ou e2e que dependam de ambiente real, portanto não foi afetado pela conversão dessas camadas em runbooks manuais — mudança que atingiu apenas o [API Gateway](./manuais-api-gateway.md) e o [Web (Playwright)](./manuais-web.md).

---

## Como Executar os Testes

No repositório do serviço de IA (`feedback-analytics-ia-analyze`):

```bash
npm test                # vitest run (execução única)
npm run test:watch      # modo watch
npm run test:coverage   # com cobertura (V8)
```

---

## Testes Automatizados

Abaixo, os 13 arquivos agrupados pelo que cobrem. Todos ficam em [`src/tests/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/tree/main/src/tests).

| Arquivo de Teste | O que cobre |
| :--- | :--- |
| [routes/analyze.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/routes/analyze.test.ts) | Rotas `POST /internal/ia-analyze/analyze` e `POST /internal/ia-analyze/synthesize-insights`: token interno (`x-ia-analyze-token`), validação do payload, sucesso com o serviço mockado e repasse dos erros. |
| [routes/diagnoseScope.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/routes/diagnoseScope.test.ts) | Rota `POST /internal/ia-analyze/diagnose-scope`. |
| [routes/health.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/routes/health.test.ts) | `GET /internal/health` e `GET /internal/ia-analyze/health` respondem `{ ok: true, service: "ia-analyze" }`. |
| [providers/openrouter.provider.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/providers/openrouter.provider.test.ts) | Adaptador OpenRouter (`analyzeBatch`), com o `fetch` mockado: respostas 2xx e erros HTTP, inclusive `Retry-After`. |
| [providers/gemini.provider.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/providers/gemini.provider.test.ts) | Adaptador Gemini: distinção entre cota diária esgotada e erro que vale nova tentativa. |
| [services/iaAnalyzeCompletion.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/iaAnalyzeCompletion.test.ts) | Conclusão integral da análise, síntese final e schema do lote, que recusa campos inválidos e IDs de feedback que não foram enviados. |
| [services/scopeDiagnosis.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/scopeDiagnosis.test.ts) | Prompt do diagnóstico do escopo e validação do pedido e da resposta. |
| [services/sentiment.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/sentiment.test.ts) | `isValidSentiment` e `canProcessAnalyzedItem`: sentimento no padrão esperado e item com ID conhecido. |
| [services/aspectExtraction.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/aspectExtraction.test.ts) | Extração de aspectos (ABSA) ancorada no texto, com `clampScore`, `normalizeConfidence` e `scoreFromSentiment`. |
| [lib/termProcessing.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/lib/termProcessing.test.ts) | Saneamento dos termos sugeridos pela IA: `normalizeForComparison`, `isGroundedInMessage` (anti-alucinação), `sanitizeTermList` e `buildForbiddenTerms`. |
| [lib/categoryTaxonomy.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/lib/categoryTaxonomy.test.ts) | `canonicalizeCategories` e `getTaxonomyLabels`: categorias mapeadas para a taxonomia fixa de cada escopo. |
| [lib/iaAnalyzePrompt.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/lib/iaAnalyzePrompt.test.ts) | Prompt da análise dos comentários. |
| [validations/ptBrLanguage.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/validations/ptBrLanguage.test.ts) | Validação do idioma (português) do relatório. |

---

## Estrutura de Mocks

Para evitar dependências de rede externas durante os testes automatizados:

* **Rotas** — `vi.mock('../../services/iaAnalyze.service.js')` e `vi.mock('../../services/scopeDiagnosis.service.js')` trocam os serviços por resolvedores simulados, para testar sucesso, erro tipado (`IaAnalyzeServiceError`) e falha inesperada sem chamar a IA.
* **Serviços** — `vi.mock('../../providers/createProvider.js')` troca a fábrica de provedores.
* **Provedores** — o teste do OpenRouter substitui o `fetch` por um mock; o do Gemini mocka o `@google/genai`.

O `vitest.config.ts` define `IA_ANALYZE_INTERNAL_TOKEN=test-internal-token` e `VERCEL=1` para os testes.

---

## Veja Também

* [Plano Estratégico de Testes](./plano-estrategico.md)
* [Visão Geral dos Testes](./visao-geral.md)
* [Testes da Aplicação Web (Frontend)](./web.md)
* [Testes do API Gateway (Backend)](./api-gateway.md)
