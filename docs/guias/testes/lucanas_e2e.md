# Lacunas dos Testes E2E (Playwright)

Este documento mapeia os conflitos, divergências e lacunas entre a documentação de **Casos de Uso (`docs/casos-de-uso/`)** e a implementação dos testes E2E com o **Playwright (`feedback-analytics-web/e2e/`)**. 

O objetivo deste relatório é servir de guia para correções de regras de negócio e expansão da cobertura de testes.

---

## 1. ⚠️ Skipped Intencional (Fluxos Externos ou Execução Manual)

Estes cenários foram desativados nos testes E2E do Playwright (`test.skip(true, '...')`) de forma intencional. Eles dependem de sistemas externos de terceiros (como servidores de e-mail e operadoras de SMS) ou de comportamentos específicos da infraestrutura que inviabilizam a automação contínua clássica no pipeline de CI.

| Identificador | Descrição do Caso de Uso | Arquivo de Teste E2E | Motivo do Skip |
| :--- | :--- | :--- | :--- |
| **[CT-UC01-01]** | Confirmação de e-mail ao criar conta | [uc-01-cadastro-conta.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-01-cadastro-conta.spec.ts) | Exige acessar uma caixa de e-mails real para clicar no link de validação. |
| **[CT-UC02-04]** | Login com conta criada mas pendente de confirmação | [uc-02-login.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-02-login.spec.ts) | Requer manter uma conta no banco de dados fixamente com e-mail não verificado. |
| **[CT-UC11-05]** | Executar nova análise chamando a API de IA | [uc-11-insights-ia.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-11-insights-ia.spec.ts) | A requisição HTTP real para a API do Gemini foi interceptada e mockada para **não consumir créditos financeiros** da conta do projeto. |

---

## 2. 🚫 Não é Possível Testar com Playwright (Limitações do Sandbox)

Estes cenários envolvem integrações com recursos físicos do sistema operacional ou políticas de isolamento de estado do próprio navegador que dificultam ou impedem a simulação robótica.

| Identificador | Descrição do Caso de Uso | Arquivo de Teste E2E | Limitação do Navegador / Playwright |
| :--- | :--- | :--- | :--- |
| **[CT-UC04-02]** | Bloqueio de múltiplos feedbacks do mesmo dispositivo no dia | [uc-04-envio-feedback-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-04-envio-feedback-qrcode.spec.ts) | A validação utiliza fingerprinting persistido. No Playwright, cada teste executa em um *browser context* limpo (sem cookies ou localStorage herdados), permitindo submissões consecutivas sem simular o bloqueio diário. |
| **[CT-UC05-02]** | Download do arquivo `.png` com o nome da empresa | [uc-05-geracao-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-05-geracao-qrcode.spec.ts) *(não implementado)* | Testar o download físico de uma imagem gerada via canvas e validar sua integridade estrutural (e nome do arquivo) é complexo no ambiente headless. |
| **[CT-UC05-04]** | Acionamento da API nativa de compartilhamento (`navigator.share`) | [uc-05-geracao-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-05-geracao-qrcode.spec.ts) *(não implementado)* | A Web Share API necessita de suporte e permissão nativa do sistema operacional (SO) e geralmente falha ou não tem efeito em navegadores de teste. |
| **[CT-UC12-03]** | Envio de código de verificação por SMS para telefone | [uc-12-gestao-perfil.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-12-gestao-perfil.spec.ts) *(não implementado)* | Exige a simulação física de recebimento de SMS e extração do código numérico de 6 dígitos. |

---

## 3. ❌ Cenários Não Cobertos nos Testes E2E (Não Atende)

Esta seção documenta a lista de cenários documentados na pasta `docs/casos-de-uso/` que **não possuem testes equivalentes** implementados nos specs do Playwright, agrupados por use case.

### [UC-01: Cadastro de Conta](../../concepcao/casos-de-uso/uc-01-cadastro-conta.md)
*   **Cadastro com telefone fora do padrão brasileiro:** Não há validação automatizada de regex de telefone incorreto impedindo o envio do formulário.
*   **Reenvio de e-mail de ativação:** Falta cobrir a jornada do usuário solicitando um novo link de confirmação devido a expiração ou extravio.

### [UC-02: Login da Empresa](../../concepcao/casos-de-uso/uc-02-login.md)
*   **Rate limit de tentativas:** Falta simular o bloqueio temporário após múltiplas falhas de autenticação.
*   **Mensagens de erro para campos em branco:** O formulário de login deve validar os campos obrigatórios inline no cliente sem fazer a requisição.

### [UC-03: Recuperação de Senha](../../concepcao/casos-de-uso/uc-03-recuperacao-senha.md)
*   **Sem cobertura E2E:** O UC-03 não possui spec do Playwright (não há `uc-03-recuperacao-senha.spec.ts`). Os fluxos de envio de link de recuperação e de toast de sucesso (CT-UC03-01/02) dependem de caixa de e-mail real e de rate-limit do Supabase Auth, portanto não foram implementados como E2E.
*   **Acesso via link expirado:** Não existe teste para a exibição da tela de erro ao tentar redefinir senha com token expirado.
*   **Comparação de senhas divergentes:** Falta testar o bloqueio visual do formulário de redefinição se a confirmação de senha não bater com a nova senha digitada.

### [UC-04: Envio de Feedback via QR Code](../../concepcao/casos-de-uso/uc-04-envio-feedback-qrcode.md)
*   **Exceção de QR Code inativo:** Se a empresa ou o ponto de coleta estiver desabilitado, o acesso ao link público deve ser bloqueado na tela de carregamento.
*   **Validação de subperguntas obrigatórias:** Se o gestor configurou subperguntas obrigatórias, o formulário público não deve permitir o envio até que todas sejam respondidas.
*   **Validação de comentário obrigatório:** Testar se o sistema impede o envio caso o campo de texto livre esteja totalmente em branco.
*   **Falha de rede/servidor:** Testar a exibição de aviso inline amigável caso ocorra erro 500 no envio final.

### [UC-05: Geração e Compartilhamento de QR Code](../../concepcao/casos-de-uso/uc-05-geracao-qrcode.md)
*   **Fallback do compartilhamento:** Testar se o link é copiado para a área de transferência quando o navegador não suporta `navigator.share` nativamente.

### [UC-06: Ativação de Tipos de Feedback](../../concepcao/casos-de-uso/uc-06-ativacao-tipos-feedback.md)
*   **Comportamento pré-salvamento:** O sistema deve alertar visualmente (badge em âmbar) que as alterações só serão aplicadas após o clique em "Salvar", mantendo o catálogo bloqueado até a confirmação.
*   **Falha de rede ao salvar:** Exibir toast de erro caso a API de atualização de tipos falhe.

### [UC-07: Configuração do Catálogo](../../concepcao/casos-de-uso/uc-07-configuracao-catalogo.md)
*   **Gerenciamento de perguntas dinâmicas por item:** Não existem testes para cadastrar, editar ou desativar perguntas específicas ligadas a um item de catálogo (ex.: perguntas exclusivas para um produto específico).
*   **Habilitar/Desabilitar QR Code por item:** Falta testar se o toggle individual de QR Code de produto/serviço gera sucesso visual e altera o comportamento na ponta.
*   **Exceções de tamanho de caracteres:** Validar o limite de 20 a 150 caracteres para perguntas e subperguntas.

### [UC-08: Configuração de Coleta (Contexto IA)](../../concepcao/casos-de-uso/uc-08-configuracao-coleta-ia.md)
*   **Permissão de campos vazios:** O caso de uso especifica que salvar os campos em branco é permitido (a IA usará contexto padrão). Os testes atuais não cobrem o salvamento de formulário vazio.
*   **Divergência de arquivo:** O teste `[CT-UC08-03]` insere perguntas dinâmicas gerais da empresa, o que pertence funcionalmente ao escopo da tela de perfil (`UC-12`) e não de contexto de IA (`UC-08`).

### [UC-09: Visualização do Dashboard](../../concepcao/casos-de-uso/uc-09-dashboard.md)
*   **Parâmetro `?login=success`:** Testar se o sistema exibe toast de boas-vindas e limpa a URL.
*   **Painel sem feedbacks:** Exibição correta de estados zerados e vazios.
*   **Falhas de carregamento de estatísticas:** Exibir alerta amigável de erro na tela sem derrubar o dashboard.

### [UC-10: Listagem e Filtragem de Feedbacks](../../concepcao/casos-de-uso/uc-10-listagem-feedbacks.md)
*   **Filtro refinado por item:** Falta testar a busca textual digitando o nome específico de um produto/serviço/departamento na listagem.
*   **Empty states:** Testar o visual de listagem vazia por falta de feedbacks gerais ou por filtros restritivos demais.

### [UC-11: Disparo e Visualização de Insights IA](../../concepcao/casos-de-uso/uc-11-insights-ia.md)
*   **Análise por escopos específicos:** Testar a filtragem e relatórios isolados de IA para um produto ou departamento selecionado.
*   **Bloqueio de contexto incompleto:** Os botões de análise devem aparecer desativados com aviso de link se o gestor não configurou os dados de UC-08.
*   **Bloqueio por falta de volume:** Validar que o disparo de análise exige no mínimo 10 feedbacks coletados no escopo selecionado.

### [UC-12: Gestão de Perfil](../../concepcao/casos-de-uso/uc-12-gestao-perfil.md)
*   **Edição e salvamento de Nome e E-mail:** Os testes implementados apenas validam se os dados carregam em modo leitura. A edição efetiva desses campos não está sendo testada E2E.
*   **Cancelamento de edições:** Testar se o clique em cancelar restaura os dados originais na tela sem salvar alterações na base.
*   **Exceções de validação de formulário:** Falta cobrir erros como salvar nome vazio, ou preencher formatos de telefone/email inválidos no painel de perfil.
