# Testes — Frontend (`feedback-analytics-web`)

Este documento detalha a arquitetura, estrutura e especificação dos testes na aplicação Web (Frontend). Nele, você encontrará a distribuição exata dos testes separados por sua granularidade: **Unidade**, **Integração** (ambos automatizados no CI via Vitest) e **Fim a Fim (E2E)** — esta última **não é mais automatizada**: a suíte Playwright foi removida e virou o runbook manual [Testes manuais — Web](./manuais-web.md).

---


## Cobertura de Testes (Vitest Coverage)

### O que é e por que usamos

**Vitest Coverage** é a ferramenta de cobertura nativa do Vitest, alimentada pelo motor **V8**. Ela instrumenta o código em tempo de execução e rastreia quais linhas, funções e ramificações condicionais (*branches*) foram executadas durante os testes.

Usamos a geração automática de cobertura para **evitar desinformação**. O comando de cobertura extrai dados reais e dinâmicos do código executado em vez de estimativas manuais que perdem a validade rapidamente.

### Como executar a cobertura

Para rodar a suíte completa de testes unitários/integração com relatório de cobertura:

```bash
cd feedback-analytics-web
powershell -ExecutionPolicy Bypass -Command "npm run test:coverage"
```

O relatório é gerado em dois formatos principais:
1. **Terminal** — Tabela imediata com percentuais e linhas não cobertas.
2. **HTML** — Relatório interativo detalhado gerado em [index.html](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/coverage/index.html).

---

## Setup Global (`tests/setup.ts`)

O arquivo [setup.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/tests/setup.ts) é executado antes de cada arquivo de testes do Vitest para emular o ambiente de navegador (*jsdom*):

| Mock / Setup | Por quê |
|---|---|
| `useRouteLoaderData` | O *jsdom* não possui contexto do React Router; este mock evita quebras de hooks de dados em páginas protegidas. |
| `window.matchMedia` | A API de media queries não é nativa do *jsdom*; esse mock impede erros na renderização de componentes responsivos. |

---

## Critério de Classificação

O que define se um teste é classificado como **Unidade** ou **Integração** é o escopo e o cruzamento de fronteiras dos módulos, e não simplesmente o arquivo ser um utilitário ou componente:

* **Unidade:** Todos os colaboradores ou serviços externos do arquivo/função em teste são substituídos por mocks (`vi.mock` ou `vi.spyOn`). O teste valida o comportamento isolado daquela unidade isolada de código.
* **Integração:** Valida contratos entre diferentes peças ou módulos reais. O fluxo de dados transita de forma real entre múltiplos módulos (ex: da *Action* do React Router que processa dados estruturados até as validações internas, mockando apenas a comunicação HTTP com a API externa).
* **E2E (End-to-End):** O fluxo roda a aplicação inteira integrada (Frontend, API-Gateway, IA-Analyze e banco de dados real), simulando a interação visual de um usuário real em um browser. Esta camada **não é mais automatizada** — é executada **manualmente** pelo runbook [Testes manuais — Web](./manuais-web.md).

---

## 1. Testes de Unidade (`Unit Tests`)

> **Total: 110 testes em 19 arquivos**
>
> Validam funções de utilidade pura, parsers, validadores locais e componentes de página e layout isolados (com seus componentes filhos mockados).

| Arquivo de Teste | Propósito do Arquivo | Qtd. Testes |
| :--- | :--- | :---: |
| [userLayout.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/layouts/tests/userLayout.test.tsx) | Valida a renderização e interatividade estrutural do layout base do gestor (`UserLayout`), incluindo menus de navegação lateral (Sidebar), recolhimento/colapso do menu, links, cabeçalhos contextuais e os skeletons de carregamento por rota (com `SectionTabs` e `InsightsActionBar` mockados; removidas as rotas de skeleton `/user/qrcode/{products,services,departments}`). | **16** |
| [truncateText.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/truncateText.test.ts) | Garante o truncamento correto de strings longas, adicionando reticências (`...`) baseadas no limite de caracteres especificado, cobrindo cenários com valores nulos ou curtos. | **11** |
| [formtPhone.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/formtPhone.test.ts) | Valida a formatação estática de números de telefone comerciais no padrão brasileiro (`(DD) XXXXX-XXXX` ou `(DD) XXXX-XXXX`) para exibição visual estática. | **10** |
| [publicQrFeedbackValidation.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/publicQrFeedbackValidation.test.ts) | Testa as validações de payload no lado do cliente antes do envio do formulário de feedback do QR Code (ausência de dados essenciais, notas zeradas, etc.). | **10** |
| [register.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/register.test.tsx) | Valida a renderização e o comportamento isolado da página de criação de conta (Registro do Gestor), incluindo campos de entrada de dados, regras de botões e links. | **8** |
| [login.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/login.test.tsx) | Valida o comportamento e a estrutura da página de login do gestor, garantindo a exibição de títulos, links de termos de uso e a renderização do formulário. | **7** |
| [profile.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/profile.test.tsx) | Testa a renderização da página de gerenciamento de dados do perfil do gestor, validando a integridade dos inputs de texto estruturados. | **7** |
| [mapEditorQuestionsToPublic.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/mapEditorQuestionsToPublic.test.ts) | Valida o mapeamento das perguntas do editor do gestor para o formato público de coleta (`FeedbackQuestionPublic[]`), filtrando textos vazios ou inativos, usado pela prévia ao vivo do formulário. | **7** |
| [publicQrFeedbackForm.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/publicQrFeedbackForm.test.ts) | Valida as funções auxiliares que gerenciam o formulário de feedback público (ordenação de respostas de subperguntas, identificação de tipos de catálogo e perguntas válidas). | **5** |
| [formatDocument.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/formatDocument.test.ts) | Testa a formatação estática de CPFs e CNPJs para exibição amigável ao usuário. | **4** |
| [publicQrFeedbackErrorMessage.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/publicQrFeedbackErrorMessage.test.ts) | Valida o mapeamento de códigos de erro de validação em strings legíveis em português para serem exibidas em alertas do formulário de feedback. | **4** |
| [publicQrFeedbackTemplateEngine.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/publicQrFeedbackTemplateEngine.test.ts) | Testa a interpolação de variáveis dinâmicas em perguntas customizáveis (ex: substituição de `{{nome_empresa}}`). | **4** |
| [formatDocumentInput.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/formatDocumentInput.test.ts) | Testa a máscara progressiva de CPF/CNPJ aplicada em tempo real à medida que o usuário digita nos campos de texto. | **3** |
| [formatPhoneInputBR.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/formatPhoneInputBR.test.ts) | Valida a máscara dinâmica de telefone brasileiro de 8 ou 9 dígitos aplicada progressivamente durante a digitação no input. | **3** |
| [passwordStrength.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/passwordStrength.test.ts) | Testa a engine de cálculo da força de senhas (Zod base), que retorna progresso percentual, cor visual da barra e o rótulo de complexidade. | **3** |
| [dashboard.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/dashboard.test.tsx) | Valida a estrutura inicial e renderização dos cartões de métrica e elementos gráficos do painel de controle principal do gestor. | **3** |
| [home.test.tsx](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/pages/tests/home.test.tsx) | Valida o carregamento estrutural e o estado da página principal de boas-vindas do sistema. | **2** |
| [digitsOnly.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/digitsOnly.test.ts) | Valida a função utilitária que remove todos os caracteres não numéricos de uma string para processamento limpo. | **2** |
| [sentiment.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/lib/utils/tests/sentiment.test.ts) | Valida o mapeamento amigável de categorias de sentimentos da IA (`positive`, `neutral`, `negative`) para português (`Positivo`, `Neutro`, `Negativo`). | **1** |

---

## 2. Testes de Integração (`Integration Tests`)

> **Total: 18 testes em 4 arquivos**
>
> Validam os handlers de rota do React Router (Actions e Loaders) que fazem a ponte entre os dados preenchidos nos formulários da interface e a chamada dos serviços que conversam com a API Gateway.

| Arquivo de Teste | Propósito do Arquivo | Qtd. Testes |
| :--- | :--- | :---: |
| [actionCollectingData.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionCollectingData.test.ts) | Testa a `action` de persistência das configurações de coleta e catálogos (produtos, serviços e departamentos), garantindo a conversão correta dos dados enviados para JSON e preservação de perguntas. | **6** |
| [actionFeedbackSettings.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionFeedbackSettings.test.ts) | Testa a `action` centralizada de configurações de feedback baseada no campo `intent`, validando fluxos válidos de alteração, erros de validação local de strings vazias e mapeamento incorreto de ações. | **5** |
| [actionPublicQrCodeFeedback.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/actions/actionPublicQrCodeFeedback.test.ts) | Testa a integração do envio do formulário público do QR Code pela `action`, validando a conversão de campos, preenchimento de obrigatórios e envio final aos serviços. | **4** |
| [loadPublicQrCodeEnterprise.test.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/src/routes/load/loadPublicQrCodeEnterprise.test.ts) | Valida o comportamento do `loader` responsável por buscar os dados estruturados e perguntas da empresa ao carregar a página pública de coleta de feedback via QR Code. | **3** |

---

## 3. Testes Fim a Fim (E2E) — agora manuais

> A suíte **E2E automatizada (Playwright)** do `feedback-analytics-web` — os specs `e2e/*.spec.ts`, as fixtures (incluindo o `auth.setup.ts`), o `playwright.config.ts` e os scripts npm `test:e2e`/`:ui`/`:report` — foi **removida** do projeto e do CI.

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
