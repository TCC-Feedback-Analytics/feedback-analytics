# Lacunas dos Testes E2E (Playwright)

!!! warning "Situação em 03/11/2026: a suíte descrita aqui não existe mais"
    A pasta `e2e/` e o Playwright saíram do `feedback-analytics-web` em 08/08/2026; os arquivos `*.spec.ts` citados abaixo não estão mais no repositório (por isso aparecem sem link). Use esta página só como checklist de cenários difíceis para a execução manual. Os cenários de cada caso de uso não foram reconferidos contra a aplicação atual: confirme no [runbook da Web](./manuais-web.md) e no próprio caso de uso antes de executar.

Este documento mapeia os conflitos, divergências e lacunas entre a documentação de **Casos de Uso (`docs/concepcao/casos-de-uso/`)** e a antiga implementação dos testes E2E com o **Playwright (`feedback-analytics-web/e2e/`)** — hoje executados **manualmente**.

O objetivo deste relatório é servir de guia para correções de regras de negócio e expansão da cobertura de testes.

!!! warning "A automação E2E (Playwright) foi removida — o E2E agora é manual"
    A suíte **Playwright** (`feedback-analytics-web/e2e/`) e o gate `e2e-main.yml` foram **removidos** do projeto e do CI (o deploy passou a ser **main-only**, sem ambiente de homologação). A execução ponta a ponta dos Casos de Uso passou a ser **manual**, documentada em **[Testes manuais — Web](./manuais-web.md)** (UCs) e **[Testes manuais — API Gateway](./manuais-api-gateway.md)** (integração/e2e do gateway).

    As seções abaixo continuam válidas como **mapa dos cenários difíceis** — o que dependia de e-mail/SMS reais, de recursos do sistema operacional ou de estado persistido — só que agora servem de **checklist para a execução manual** em vez de justificar `test.skip` no pipeline. As referências a arquivos `*.spec.ts` e a `test.skip` descrevem a **antiga** suíte automatizada.

---

## 1. ⚠️ Skipped Intencional (Fluxos Externos ou Execução Manual)

Estes cenários eram desativados nos testes E2E do Playwright (`test.skip(true, '...')`) de forma intencional, por dependerem de sistemas externos de terceiros (como servidores de e-mail e operadoras de SMS) ou de comportamentos específicos da infraestrutura que inviabilizavam a automação contínua clássica no pipeline de CI. Na **execução manual** (runbook [Testes manuais — Web](./manuais-web.md)), um testador pode exercitá-los usando e-mail/SMS reais quando necessário.

| Identificador | Descrição do Caso de Uso | Arquivo de Teste E2E | Motivo do Skip |
| :--- | :--- | :--- | :--- |
| **[CT-UC01-01]** | Confirmação de e-mail ao criar conta | `uc-01-cadastro-conta.spec.ts` | Exige acessar uma caixa de e-mails real para clicar no link de validação. |
| **[UC-02, exceção "Conta não ativada"]** | Login com conta criada mas pendente de confirmação | `uc-02-login.spec.ts` | Requer manter uma conta no banco de dados fixamente com e-mail não verificado. |
| **[CT-UC11-05]** | Executar nova análise chamando a API de IA | `uc-11-insights-ia.spec.ts` | A requisição HTTP real para a API do Gemini (o provedor da época; hoje cada empresa usa a própria chave OpenRouter) foi interceptada e mockada para **não consumir créditos financeiros** da conta do projeto. |
| **[CT-UC12-09]** | Troca de e-mail no Perfil | `uc-12-gestao-perfil.spec.ts` *(não implementado)* | Exige acessar a caixa do e-mail novo para clicar no link de confirmação. |

---

## 2. 🚫 Não é Possível Testar com Playwright (Limitações do Sandbox)

Estes cenários envolvem integrações com recursos físicos do sistema operacional ou políticas de isolamento de estado do próprio navegador que dificultam ou impedem a simulação robótica.

| Identificador | Descrição do Caso de Uso | Arquivo de Teste E2E | Limitação do Navegador / Playwright |
| :--- | :--- | :--- | :--- |
| **[CT-UC04-02]** | Bloqueio de múltiplos feedbacks do mesmo dispositivo, no mesmo ponto de coleta, no dia | `uc-04-envio-feedback-qrcode.spec.ts` | A validação utiliza fingerprinting persistido. No Playwright, cada teste executa em um *browser context* limpo (sem cookies ou localStorage herdados), permitindo submissões consecutivas sem simular o bloqueio diário. Hoje o fingerprint é calculado no servidor (MD5 de navegador e IP): uma janela anônima no mesmo navegador e na mesma rede **não** escapa da deduplicação. |
| **[CT-UC05-03]** | Download do arquivo `.png` com o nome da empresa | `uc-05-geracao-qrcode.spec.ts` *(não implementado)* | Testar o download físico de uma imagem gerada via canvas e validar sua integridade estrutural (e nome do arquivo) é complexo no ambiente headless. |
| **[CT-UC05-05]** | Acionamento da API nativa de compartilhamento (`navigator.share`) | `uc-05-geracao-qrcode.spec.ts` *(não implementado)* | A Web Share API necessita de suporte e permissão nativa do sistema operacional (SO) e geralmente falha ou não tem efeito em navegadores de teste. |
---

## 3. ❌ Cenários Não Cobertos nos Testes E2E (Não Atende)

Esta seção documenta a lista de cenários documentados na pasta `docs/concepcao/casos-de-uso/` que **não possuem testes equivalentes** implementados nos specs do Playwright, agrupados por use case.

### [UC-01: Cadastro de Conta](../../concepcao/casos-de-uso/uc-01-cadastro-conta.md)
*   **Cadastro com telefone fora do padrão brasileiro:** Não há validação automatizada de regex de telefone incorreto impedindo o envio do formulário.
*   **Reenvio de e-mail de ativação:** Falta cobrir a jornada do usuário solicitando um novo link de confirmação devido a expiração ou extravio.

### [UC-02: Login da Empresa](../../concepcao/casos-de-uso/uc-02-login.md)
*   **Rate limit de tentativas:** Falta simular o bloqueio temporário após múltiplas falhas de autenticação.
*   **Mensagens de erro para campos em branco:** O formulário de login deve validar os campos obrigatórios inline no cliente sem fazer a requisição.

### [UC-03: Recuperação de Senha](../../concepcao/casos-de-uso/uc-03-recuperacao-senha.md)
*   **Sem cobertura E2E:** O UC-03 não possui spec do Playwright (não há `uc-03-recuperacao-senha.spec.ts`). Os fluxos de envio de link de recuperação e de toast de sucesso (CT-UC03-01/02) dependiam de caixa de e-mail real e do rate limit do Supabase Auth (o provedor de auth da época; hoje é o Better Auth, e no ambiente local os e-mails caem no Mailpit), portanto não foram implementados como E2E.
*   **Acesso via link expirado:** Não existe teste para a exibição da tela de erro ao tentar redefinir senha com token expirado.
*   **Comparação de senhas divergentes:** Falta testar o bloqueio visual do formulário de redefinição se a confirmação de senha não bater com a nova senha digitada.

### [UC-04: Envio de Feedback (QR Code, link ou NFC)](../../concepcao/casos-de-uso/uc-04-envio-feedback-qrcode.md)
*   **Exceção de coleta pausada:** Se a coleta da empresa ou do item estiver pausada, o formulário público não deve abrir, venha o cliente pelo QR Code, pelo link ou pela etiqueta NFC.
*   **Validação de subperguntas obrigatórias:** Se o gestor configurou subperguntas obrigatórias, o formulário público não deve permitir o envio até que todas sejam respondidas.
*   **Comentário opcional:** O comentário deixou de ser obrigatório. Testar que o envio sem comentário é aceito e que, com o campo oculto no escopo, o formulário não pede comentário.
*   **Falha de rede/servidor:** Testar a exibição de aviso inline amigável caso ocorra erro 500 no envio final.

### [UC-05: Canais de coleta (QR Code, link e NFC)](../../concepcao/casos-de-uso/uc-05-geracao-qrcode.md)
*   **Fallback do compartilhamento:** Testar se o link é copiado para a área de transferência quando o navegador não suporta `navigator.share` nativamente.
*   **Gravação da etiqueta NFC:** O "Gravar etiqueta" só aparece no Chrome do Android (Web NFC) e precisa de uma etiqueta física; no computador, dá para conferir só o "Copiar endereço da etiqueta".

### [UC-06: Ativação de Tipos de Feedback](../../concepcao/casos-de-uso/uc-06-ativacao-tipos-feedback.md)
*   **Comportamento pré-salvamento:** O sistema deve alertar visualmente (badge em âmbar) que as alterações só serão aplicadas após o clique em "Salvar", mantendo o catálogo bloqueado até a confirmação.
*   **Falha de rede ao salvar:** Exibir toast de erro caso a API de atualização de tipos falhe.

### [UC-07: Configuração do Catálogo](../../concepcao/casos-de-uso/uc-07-configuracao-catalogo.md)
*   **Gerenciamento de perguntas dinâmicas por item:** Não existem testes para cadastrar, editar ou desativar perguntas específicas ligadas a um item de catálogo (ex.: perguntas exclusivas para um produto específico).
*   **Ativar/pausar a coleta por item:** Falta testar se o interruptor de coleta do produto/serviço, em **Canais de coleta**, gera sucesso visual e altera o comportamento na ponta (QR Code, link e NFC do item).
*   **Exceções de tamanho de caracteres:** Validar o limite de 20 a 150 caracteres para perguntas e subperguntas.

### [UC-08: Configuração de Coleta (Contexto IA)](../../concepcao/casos-de-uso/uc-08-configuracao-coleta-ia.md)
*   **Campos vazios:** Hoje a janela do contexto não deixa salvar com algum dos três campos em branco ("Complete os campos obrigatórios"), e o CT-UC08-03 ficou obsoleto na interface. O gateway ainda aceita os campos nulos no `PATCH /collecting_data`, o que só dá para conferir pela API.
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
