# Testes — Backend (`feedback-analytics-api-gateway`)

Este documento detalha a arquitetura, a estrutura e a especificação dos testes automatizados do serviço **API Gateway**. Os testes cobrem as rotas, os controladores (*controllers*), as validações de esquema (*Zod schemas*) e a integração com serviços adjacentes, isolando o banco de dados e as chamadas externas por meio de mocks.

---

## Status da Cobertura

Os testes do API Gateway utilizam o **Vitest** como motor de testes e o **Supertest** para simular requisições HTTP reais diretamente contra a aplicação Express. O banco de dados Supabase é completamente mockado em memória nas fixtures de teste para garantir a velocidade e a repetibilidade das asserções.

> **Total geral de testes do API Gateway: 77 testes distribuídos em 8 arquivos**

---

## Como Executar os Testes

No repositório do API Gateway (`feedback-analytics-api-gateway`):

```bash
npm test
# ou, explicitamente:
npx vitest run
```

---

## Testes Automatizados

Abaixo está o detalhamento sistemático de cada arquivo de teste presente no serviço, especificando sua finalidade técnica e o volume de asserções executadas.

| Arquivo de Teste | Propósito Técnico | Qtd. Testes |
| :--- | :--- | :---: |
| [auth.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/auth.test.ts) | **Fluxo de Autenticação e Gestão de Contas:** Valida os endpoints de Login (`/login`), Registro de Conta (`/register`), Recuperação de Senha (`/forgot-password`) e Logout (`/logout`). Garante regras como bloqueio de payloads inválidos por Zod, erro de CPFs inválidos, recusa de senhas divergentes, tratamento de e-mails não verificados e a política de **privacidade anti-enumeração** (retornando status 200 de sucesso quando o e-mail inserido já estiver cadastrado). | **15** |
| [feedbacks.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/feedbacks.test.ts) | **Histórico e Estatísticas de Feedbacks:** Testa a consulta protegida de feedbacks (`GET /api/protected/user/feedbacks`) e a agregação de dados para os cards do dashboard (`GET /api/protected/user/feedbacks/stats`). Valida a paginação padrão, proteção contra requisições anônimas (retorna 401), filtros de busca por categoria do catálogo/nota e tratamento de empresas não existentes. | **7** |
| [ia-analyze.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/ia-analyze.test.ts) | **Integração com Serviço Serverless de IA:** Valida as pontes de comunicação com a IA (`/analyze-raw` e `/regenerate-insights`). Garante o tratamento correto de erros específicos do motor de IA (`IaAnalyzeServiceError` retornando códigos de erro tipados ao frontend), falhas genéricas de conexão HTTP (retornando status 500) e restrição de tokens de acesso JWT. | **6** |
| [qrcode-feedback.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/qrcode-feedback.test.ts) | **Coleta de Feedback via QR Code Público:** Valida a ingestão pública de dados de feedbacks via QR Code (`POST /api/public/qrcode/feedback`) e a leitura dos metadados da empresa (`GET /api/public/enterprise/:id`). Cobre regras como bloqueio contra múltiplos envios diários de um mesmo dispositivo (*fingerprint anti-spam*), validações de campos obrigatórios e tratamento de ID empresarial inválido. | **8** |
| [health.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/health.test.ts) | **Verificação de Integridade (Liveness/Readiness):** Valida a resposta do endpoint de healthcheck (`GET /api/health`), garantindo que o gateway responda com sucesso e status `{ ok: true }`. | **1** |
| [statistics.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/statistics.test.ts) | **Funções Estatísticas Puras (`src/libs/statistics`):** Cobre as funções determinísticas e sem efeitos colaterais que alimentam as lentes de Satisfação e Sentimento: `wilsonInterval`, `wilsonLowerBound` e `pctInterval` (intervalos de confiança de Wilson para proporções), `netSentimentScore` (NSS), `netSatisfaction` (top-2 menos bottom-2), `confidenceTier` (faixas de Cochran), `ratingStats` (média de notas com IC t e *clamp* em [1,5]), `csatTopTwoBox` (CSAT Top-2-Box) e `bayesianAverage` (encolhimento estilo IMDb). | **22** |
| [classifierEval.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/classifierEval.test.ts) | **Métricas de Avaliação de Classificador (`src/libs/eval/classifierEval.ts`):** Valida o cálculo de `cohensKappa` (concordância corrigida pelo acaso), `classMetrics`/macro-F1 (precision, recall e F1 por classe agregados), `buildConfusionMatrix` (matriz de confusão humano × modelo) e `interpretKappa` (rotulagem do kappa nas faixas de Landis & Koch). | **12** |
| [ia-analyze-scope.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/ia-analyze-scope.test.ts) | **Regressão do Bug de Escopo nos Repositórios de IA (`iaAnalyze.repository`):** Cobre `fetchAlreadyAnalyzedFeedbacks` e `fetchFeedbacksForAnalysis`, garantindo que a filtragem por `collection_point_id` do escopo seja aplicada **antes** do `LIMIT` (a janela de `limit` vale dentro do escopo) e que, sem escopo, o comportamento por empresa seja preservado. | **6** |

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

Para manter os testes unitários isolados de redes externas ou do banco Supabase real, é configurado um mock global para o Supabase no arquivo de fixture:

* **[supabase-mock.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/tests/helpers/supabase-mock.ts):** Mocka as funções do cliente `createSupabaseServerClient`, interceptando chamadas de autenticação e persistência (como chamadas a `auth.signUp`, `auth.signInWithPassword`, `from().select()`, `from().insert()`, etc.) e retornando dados estáticos previsíveis definidos para teste.

---

## Veja Também

* [Plano Estratégico de Testes](./plano-estrategico.md)
* [Visão Geral dos Testes](./visao-geral.md)
* [Testes da Aplicação Web (Frontend)](./web.md)
* [Testes do Serviço de IA](./ia-analyze.md)
