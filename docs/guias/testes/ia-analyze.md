# Testes — IA Analyze (`feedback-analytics-ia-analyze`)

Este documento detalha a arquitetura, a estrutura e a especificação dos testes automatizados do serviço Serverless **IA Analyze**. O serviço é responsável por se conectar aos modelos de linguagem da Google (Gemini API) para extrair sentimentos estruturados, palavras-chave de feedback e recomendações automáticas para os gestores.

---

## Status da Cobertura

Os testes do serviço IA utilizam o **Vitest** como motor de execução e o **Supertest** para validar os endpoints locais simulando chamadas HTTP internas vindas da API Gateway. A comunicação externa com as APIs do Gemini é mockada em tempo de teste para evitar latência e custos de infraestrutura.

> **Total geral de testes do IA Analyze: 46 testes distribuídos em 6 arquivos**

---

## Como Executar os Testes

No repositório do serviço de IA (`feedback-analytics-ia-analyze`):

```bash
npm test
# ou, explicitamente:
npx vitest run
```

---

## Testes Automatizados

Abaixo está o detalhamento sistemático de cada arquivo de teste presente no serviço, especificando sua finalidade e a quantidade de asserções executadas.

| Arquivo de Teste | Propósito Técnico | Qtd. Testes |
| :--- | :--- | :---: |
| [termProcessing.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/lib/termProcessing.test.ts) | **Sanitização e Processamento de Termos:** Valida exaustivamente os algoritmos que limpam e qualificam os termos e tags sugeridos pela IA. Cobre funções como `normalizeForComparison` (remoção de acentos/pontuações e colapso de espaços), `isGroundedInMessage` (garantia de que as palavras extraídas existem no comentário real para prevenir alucinações), `sanitizeTermList` (limpeza de duplicatas e limites de contagem) e `buildForbiddenTerms` (geração de blacklist contendo termos estruturados). | **14** |
| [sentiment.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/sentiment.test.ts) | **Validação de Sentimento e Integridade de Dados:** Garante que a classificação qualitativa atende ao padrão esperado pelo banco (`positive`, `neutral`, `negative`). Valida se o ID de feedback fornecido é válido, rejeita tipos incompatíveis e impede o processamento de registros cujos identificadores não estejam no mapa de cache. | **9** |
| [categoryTaxonomy.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/lib/categoryTaxonomy.test.ts) | **Canonicalização da Taxonomia de Categorias:** Valida a função `canonicalizeCategories`, que mapeia as categorias saneadas ao termo canônico da taxonomia fixa de cada escopo (`COMPANY`/`PRODUCT`/`SERVICE`/`DEPARTMENT`). Cobre o mapeamento de sinônimos ao canônico, o casamento por token quando não há match exato, a deduplicação de termos que recaem no mesmo canônico, a preservação de termos sem match como "emergentes" (normalizados) e o respeito ao escopo. Verifica também `getTaxonomyLabels`, que retorna os rótulos canônicos usados no nudge do prompt. | **7** |
| [aspectExtraction.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/services/aspectExtraction.test.ts) | **Extração de Aspectos (ABSA):** Valida a função `extractAspects`, garantindo que os aspectos permaneçam ancorados no texto da mensagem (anti-alucinação), com descarte de aspectos ausentes, duplicados ou com sentimento inválido, aplicação do clamp de `sentiment_score` e respeito ao limite máximo de 6 aspectos. Cobre ainda os helpers `clampScore` (limita ao intervalo `[-1, 1]`), `normalizeConfidence` (limita ao intervalo `[0, 1]`) e `scoreFromSentiment` (mapeia a classe de sentimento ao escore numérico). | **6** |
| [analyze.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/routes/analyze.test.ts) | **Endpoint de Análise de Lotes (/analyze):** Testa a rota principal do serviço (`POST /internal/ia-analyze/analyze`). Cobre a segurança de cabeçalhos por token de autenticação interna, validações Zod do payload, processamento bem-sucedido com chamadas mockadas à IA do Gemini, resposta a lotes sem feedback e o repasse correto de erros da API do Gemini (status 502) ou erros inesperados (status 500). | **8** |
| [health.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/src/tests/routes/health.test.ts) | **Verificação de Integridade (Healthcheck):** Valida as rotas de checagem do serviço (`GET /internal/health` e `GET /internal/ia-analyze/health`), garantindo que o servidor Express responda status 200 com `{ ok: true, service: "ia-analyze" }`. | **2** |

---

## Estrutura de Mocks

Para evitar dependências de rede externas durante os testes automatizados, o motor Gemini é mockado no controlador de rotas:

* **Mock do Orquestrador (`iaAnalyze.service.js`):** O módulo orquestrador de IA é interceptado via `vi.mock('../../services/iaAnalyze.service.js')` para substituir o método `runIaAnalyzeService` por um resolvedor simulado. Isso permite testar todos os cenários de sucesso, erro de infraestrutura (`IaAnalyzeServiceError`) ou falha inesperada na chamada da API da Google sem enviar requisições reais à internet.

---

## Veja Também

* [Plano Estratégico de Testes](./plano-estrategico.md)
* [Visão Geral dos Testes](./visao-geral.md)
* [Testes da Aplicação Web (Frontend)](./web.md)
* [Testes do API Gateway (Backend)](./api-gateway.md)
