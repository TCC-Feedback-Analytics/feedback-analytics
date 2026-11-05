# Testes Manuais — Web (Casos de Uso)

!!! note "Por que este runbook existe"
    A suíte **Playwright (e2e)** do `feedback-analytics-web` — que rodava contra o ambiente **homolog** deployado + Supabase, além do gate `e2e-main.yml` — foi **removida**. A cobertura dos casos de uso (UC-01…UC-12) passou a ser **manual**, reproduzível por este roteiro clicando na aplicação. Os testes **unitários** (Vitest/jsdom) continuam automatizados no CI.

Cada seção corresponde a um caso de uso (UC) e a um ou mais casos de teste (CT). Execute os passos clicando na aplicação e confira os resultados esperados.

## Pré-requisitos

### Ambiente

- **Produção (recomendado):** use a URL do ambiente deployado (Vercel). A URL base é o domínio de produção do web.
- **Local (alternativa):** frontend em `http://localhost:5173` (valor padrão da base) e API em `http://localhost:3000` (com a API rodando; o proxy do Vite repassa `/api` para ela).
- Todas as rotas citadas abaixo são **relativas à URL base** do ambiente escolhido (ex.: `/login` → `https://<base>/login`).
- Navegador recomendado: Chrome/Chromium (desktop). Para cenários de usuário deslogado, use uma janela anônima.

### Conta de teste

- **E-mail:** uma conta de teste da empresa (ex.: `gestor@empresateste.com`).
- **Senha:** a senha do fixture de teste do time — não versionada nesta doc (em dev local, os fixtures usam um default de desenvolvimento).
- **ID da empresa de teste (apenas UC-04):** o `enterprise_id` da conta de teste (não versionado aqui).
- **Celular da conta de teste (apenas CT-UC01-08):** o que aparece no Perfil, em **Telefone**.
- **Dados de apoio para cadastro:**
  - Senha: invente uma frase curta, com pelo menos 10 caracteres, que não contenha o nome do negócio, o e-mail nem o celular. O medidor de força precisa mostrar **"Forte"**; senha abaixo disso não é aceita.
  - Celular: um número que nenhuma conta usa, no formato DDD + número (ex.: `11987654321`). O campo completa o `+55`.

> O cadastro não pede mais CPF/CNPJ: o documento saiu do sistema (o gateway não guarda esse dado). A UC-01 hoje se apoia no e-mail e no celular da conta de teste.

> **Local com a fixture do gateway:** o usuário criado por `npm run db:seed:e2e` já nasce com celular (`E2E_TEST_PHONE` ou um gerado a partir do e-mail), então o login vai direto para o Dashboard, sem passar por "Complete seu cadastro".

### Acesso administrativo ao banco (somente para preparar UC-04)

Os cenários originais usavam acesso admin ao Supabase para: (1) apagar o "device fingerprint" da empresa antes de reenviar feedback e (2) descobrir um ponto de coleta QR ativo. Para o teste manual, veja as pré-condições da UC-04.

### Como fazer login

1. Navegue para `/login`.
2. Preencha **E-mail** com o e-mail de teste.
3. Preencha **Senha** com a senha de teste.
4. Clique no botão **Entrar** (submit).
5. Aguarde o redirecionamento para `/user/dashboard` (a URL passa por `?login=success`, que sai sozinho, e aparece o aviso "Login realizado com sucesso.").

Este login autenticado é **pré-condição para as UCs 05 a 12** (exceto o CT-UC12-07, que exige sessão deslogada). As UCs **01, 02 e 04** são executadas **sem autenticação** (janela anônima ou deslogado).

---

## UC-01 — Cadastro de conta

Rota: `/register` (título "Crie sua conta") · Executar **deslogado**. Campos do formulário: `Nome do negócio`, `E-mail`, `Contato (Celular DDD +55 fixo)`, `Senha` (com medidor de força), `Confirmar senha` e o checkbox de aceite dos Termos de Serviço e da Política de Privacidade. Com o login pelo Google ligado, o botão **"Criar conta com Google"** aparece acima do formulário.

### CT-UC01-02 — E-mail já existente segue para tela de sucesso (prevenção de enumeração)

- **Objetivo:** garantir que, ao cadastrar com e-mail já usado, o sistema **não revela** que o e-mail existe e mostra a mesma tela do cadastro novo.
- **Pré-condições:** deslogado; o e-mail da conta de teste já está cadastrado.
- **Passos:**
  1. Navegue para `/register`.
  2. Preencha **Nome do negócio** com `Usuário Duplicado`.
  3. Preencha **E-mail** com o e-mail da conta de teste (já existente).
  4. Preencha o **celular** com um número que **nenhuma** conta usa (o gateway confere o celular antes do e-mail; um celular repetido cai no CT-UC01-08).
  5. Preencha **Senha** e **Confirmar senha** com a senha de apoio (medidor em "Forte").
  6. Marque o checkbox de **termos**.
  7. Clique em **Criar Conta** (submit).
- **Resultado esperado:** aparece a tela **"Confirme seu e-mail"**, com o e-mail digitado, o botão **"Reenviar e-mail de confirmação"** e o link **"Já confirmei · Ir para login"** (nenhum erro de "e-mail já existe" é exibido).

### CT-UC01-03 — Documento (CPF) já existente exibe erro

- **Obsoleto:** o cadastro não pede mais CPF/CNPJ (o documento saiu do sistema), então o cenário não se aplica. A checagem de duplicidade que existe hoje é a do celular, no CT-UC01-08.

### CT-UC01-07 — Reenvio da confirmação respeita o tempo de espera

- **Objetivo:** confirmar que o reenvio do e-mail de confirmação mostra a contagem e não deixa pedir de novo antes da hora.
- **Pré-condições:** deslogado; um cadastro novo acabou de ser feito (tela "Confirme seu e-mail" aberta), ou acesse `/resend-confirmation`.
- **Passos:**
  1. Na tela "Confirme seu e-mail", clique em **"Reenviar e-mail de confirmação"** (em `/resend-confirmation`, informe o e-mail e clique em **"Reenviar confirmação"**).
  2. Observe o botão logo depois.
- **Resultado esperado:** aparece a resposta genérica ("Se existir uma conta pendente para este e-mail, enviaremos uma nova confirmação."), e o botão fica desabilitado com **"Solicitar novamente em mm:ss"** até a contagem acabar (60 s por padrão). Pedir de novo antes da hora, por outra aba, mostra o aviso "Muitas tentativas" com a mesma contagem.

### CT-UC01-08 — Celular já cadastrado exibe erro

- **Objetivo:** validar que um celular já usado por outra conta é rejeitado com mensagem de erro.
- **Pré-condições:** deslogado; o celular da conta de teste é conhecido (ver "Conta de teste").
- **Passos:**
  1. Navegue para `/register`.
  2. Preencha **Nome do negócio** com `Usuário Celular Dup`.
  3. Preencha **E-mail** com um endereço **novo/único** (ex.: `dup-cel+<timestamp>@teste.com`).
  4. Preencha o **celular** com o da conta de teste.
  5. Preencha **Senha** e **Confirmar senha** com a senha de apoio.
  6. Marque o checkbox de **termos**.
  7. Clique em **Criar Conta** (submit).
- **Resultado esperado:** aparece o aviso de erro **"Telefone ja cadastrado."** (assim, sem acento), com "Informe outro numero para continuar o cadastro.", e o formulário continua na tela.

---

## UC-02 — Login

Rota: `/login` · Executar **deslogado**. Campos: `E-mail`, `Senha`.

### CT-UC02-01 — Credenciais válidas redirecionam para o dashboard

- **Objetivo:** confirmar login bem-sucedido.
- **Pré-condições:** deslogado; conta de teste válida.
- **Passos:**
  1. Navegue para `/login`.
  2. Preencha **E-mail** com o e-mail de teste.
  3. Preencha **Senha** com a senha de teste.
  4. Clique em **Entrar**.
- **Resultado esperado:** a URL muda para `/user/dashboard`, aparece o aviso **"Login realizado com sucesso."** e a saudação **"Olá,"** fica visível.

### CT-UC02-02 — Senha incorreta exibe mensagem de erro

- **Objetivo:** validar tratamento de credenciais inválidas.
- **Pré-condições:** deslogado.
- **Passos:**
  1. Navegue para `/login`.
  2. Preencha **E-mail** com o e-mail de teste.
  3. Preencha **Senha** com `senha-errada-123`.
  4. Clique em **Entrar**.
- **Resultado esperado:** aparece o aviso **"E-mail ou senha incorretos."** ("Revise as credenciais e tente novamente."), a janela **"Problemas para entrar?"** abre sozinha, com **"Redefinir senha"** e **"Reenviar e-mail de confirmação"**, e a URL **permanece em** `/login`. Conta com e-mail ainda não confirmado recebe exatamente a mesma resposta (o sistema não revela se a conta existe).

### CT-UC02-05 — Entrar com o Google (conta nova completa o cadastro)

- **Objetivo:** confirmar a primeira entrada pelo Google e a tela "Complete seu cadastro".
- **Pré-condições:** deslogado; o botão **"Continuar com Google"** só aparece com o Google ligado na Web e no gateway (sem ele, o cenário **não se aplica**); uma conta Google que ainda não entrou no sistema.
- **Passos:**
  1. Navegue para `/login` e clique em **"Continuar com Google"**.
  2. Entre com a conta Google e autorize.
  3. Na volta, em `/auth/complete-signup`, confira o **nome do negócio** (vem preenchido com o nome do Google), informe um **celular** livre, marque os **termos** e clique em **"Concluir cadastro"**.
- **Resultado esperado:** depois do passo 2, a URL é `/auth/complete-signup`; depois do passo 3, vai para `/user/dashboard`. Com um celular já usado, o campo mostra "Este telefone já está em outra conta.". Uma conta Google que já completou o cadastro vai direto para `/user/dashboard`; uma falha no Google volta para `/login?error=google` com "Não deu para entrar com o Google. Tente de novo ou use e-mail e senha."

---

## UC-04 — Envio de feedback (QR Code, link ou NFC)

Área pública de coleta · Executar **deslogado**. Rota: `/feedback/qrcode?enterprise=<ID>&collection_point=<CP_ID>&item=<ITEM_ID>&canal=<qr|link|nfc>`. O mesmo endereço serve a todos os canais; o parâmetro `canal` diz por onde o cliente chegou (os endereços prontos estão em **Canais de coleta**, CT-UC05-04). O submit envia `POST /api/public/qrcode/feedback`, com o canal junto.

### CT-UC04-01 — Envio válido exibe confirmação de feedback recebido

- **Objetivo:** enviar um feedback completo pelo formulário público e ver a confirmação.
- **Pré-condições:**
  - `enterprise_id` da conta de teste disponível (ID de empresa válido).
  - A empresa precisa ter um **ponto de coleta QR ativo** (`type=QR_CODE`, `status=ACTIVE`), ou seja, a coleta ativada em **Canais de coleta**. Prefira o ponto de escopo empresa (sem item de catálogo). Sem um ponto ativo, a página nem mostra o formulário: aparece "QR Code indisponível: não há ponto de coleta ativo para este código. Verifique o QR Code ou contate a empresa."
  - O dispositivo não pode ter enviado feedback **para o mesmo ponto no mesmo dia**: o gateway identifica o aparelho por navegador (User-Agent) e IP, e o dia vira à meia-noite de Brasília. Para reexecutar: use outro navegador, outro ponto de coleta ou espere o dia seguinte (ou limpe o registro em `tracked_devices` no banco local).
- **Passos:**
  1. Monte a URL com o `enterprise` e o `collection_point` (e `item`, se o ponto for específico de um item), acrescente `&canal=qr` e navegue até ela.
  2. Aguarde a página de coleta carregar ("Sua opinião importa").
  3. Clique na **5ª estrela** (nota máxima).
  4. Para **cada** pergunta/subpergunta com escala, clique na opção **"Ótima"**.
  5. Se houver campo de comentário, preencha com um texto, ex.: `Ótimo atendimento, equipe muito prestativa e produto excelente.` O rótulo do campo depende da configuração do escopo (CT-UC05-08): o convite padrão "Conte-nos mais sobre sua experiência", uma pergunta própria ou nenhum campo.
  6. Clique no botão **Enviar Feedback** (submit).
- **Resultado esperado:** a requisição `POST /api/public/qrcode/feedback` retorna **HTTP 200** e aparece a confirmação **"Feedback enviado"**, avisando que o dispositivo poderá enviar um novo feedback amanhã. No Dashboard da empresa, a avaliação entra em "Por onde chegaram" como **QR Code** (CT-UC09-09).

### CT-UC04-02 — Segundo envio no mesmo dia é recusado com aviso

- **Objetivo:** validar a deduplicação diária por aparelho e ponto de coleta.
- **Pré-condições:** deslogado; o CT-UC04-01 acabou de ser executado no mesmo navegador.
- **Passos:**
  1. Abra de novo a mesma URL do CT-UC04-01.
  2. Preencha e envie o formulário outra vez.
- **Resultado esperado:** o `POST /api/public/qrcode/feedback` retorna **HTTP 409** e aparece a tela **"Obrigado por participar"**: "Este dispositivo já enviou uma resposta por aqui hoje. Você poderá compartilhar uma nova opinião amanhã."

### CT-UC04-03 — Enterprise ID inválido exibe "empresa não encontrada"

- **Objetivo:** validar tratamento de QR com empresa inexistente.
- **Pré-condições:** deslogado.
- **Passos:**
  1. Navegue para `/feedback/qrcode?enterprise=id-invalido-que-nao-existe`.
- **Resultado esperado:** aparece a tela **"Não foi possível continuar"** com a mensagem **"Empresa não encontrada. Verifique se o QR Code é válido."** e o botão **"Tentar novamente"**. Sem o parâmetro `enterprise`, a mensagem é "ID da empresa não encontrado na URL. Verifique o QR Code.".

---

## UC-05 — Canais de coleta da empresa (QR Code, link e NFC)

Rota: `/user/edit/feedback-general` (menu **Configuração da coleta › Avaliação da empresa**) · **Autenticado**. A tela tem, nesta ordem, as **Perguntas**, o **Campo de comentário** e os **Canais de coleta**.

### CT-UC05-01 — Tela Avaliação da empresa carrega com o QR Code

- **Objetivo:** confirmar que a tela Avaliação da empresa (antes "Feedback geral") exibe, na seção **Canais de coleta**, o QR Code da empresa (ou o controle de ativação).
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/feedback-general`.
  2. Aguarde o carregamento assíncrono (até ~15s).
- **Resultado esperado:** a URL corresponde a `/user/edit/feedback-general` e, em **"Por onde seus clientes respondem"**, aparece o cartão **"Coleta de respostas"** com o estado **"Recebendo respostas"** e o botão **"Pausar coleta"** (coleta ativa, com a imagem do QR Code no cartão **QR Code**) **ou** o estado **"Pausado"** e o botão **"Ativar coleta"** (com "Ative a coleta para mostrar o QR Code.").

### CT-UC05-02 — Ativar e pausar a coleta

- **Objetivo:** confirmar que o interruptor da coleta liga e desliga todos os canais. Cobre também o CT-UC05-07 (coleta pausada).
- **Pré-condições:** logado.
- **Passos:**
  1. Em `/user/edit/feedback-general`, se a coleta estiver pausada, clique em **"Ativar coleta"**.
  2. Clique em **"Pausar coleta"** e abra o link da empresa (CT-UC05-04) numa janela anônima.
  3. Clique em **"Ativar coleta"** de novo.
- **Resultado esperado:** passo 1 → aviso **"Coleta ativada!"** ("Agora os clientes podem enviar feedback"), estado **"Recebendo respostas"** e a imagem do QR Code no cartão **QR Code**; passo 2 → aviso **"Coleta desativada!"** ("Coleta de feedback pausada"), estado **"Pausado"**, e o link abre o aviso "QR Code indisponível" em vez do formulário (o mesmo vale para o QR Code e a etiqueta NFC); passo 3 → a coleta volta a **"Recebendo respostas"** e o **mesmo** QR Code continua valendo.

### CT-UC05-04 — Copiar o link e o endereço da etiqueta NFC

- **Objetivo:** confirmar que os canais levam ao mesmo formulário, cada um com a sua marca.
- **Pré-condições:** logado; coleta ativa (CT-UC05-02).
- **Passos:**
  1. Em `/user/edit/feedback-general`, no cartão **Link**, clique em **"Copiar link"**.
  2. No cartão **Etiqueta NFC**, no computador, clique em **"Copiar endereço da etiqueta"** (no Chrome de um celular Android, no lugar dele aparece **"Gravar etiqueta"**, que grava direto numa etiqueta encostada).
  3. Abra os dois endereços copiados numa janela anônima.
- **Resultado esperado:** passo 1 → o botão vira **"Link copiado!"**; passo 2 → **"Endereço copiado!"**; passo 3 → os dois abrem o formulário público da empresa, o do link com `canal=link` e o da etiqueta com `canal=nfc` na URL (o QR Code baixado leva `canal=qr`).

### CT-UC05-08 — Campo de comentário do escopo

- **Objetivo:** confirmar que o campo de comentário configurado na tela é o que o cliente vê no formulário.
- **Pré-condições:** logado; coleta ativa (CT-UC05-02).
- **Passos:**
  1. Em `/user/edit/feedback-general`, no cartão **"Campo de comentário"**, escolha **"Pergunta própria"**.
  2. Escreva `O que faltou para ser nota 5?` (ou toque na sugestão de mesmo texto) e clique em **"Salvar campo de comentário"**.
  3. Abra o link da empresa (CT-UC05-04) numa janela anônima.
  4. Volte, escolha **"Ocultar o campo"**, salve e recarregue o formulário anônimo.
  5. Volte para **"Convite padrão"** e salve.
- **Resultado esperado:** passo 2 → aviso **"Campo de comentário salvo!"** e a prévia "Como o cliente vê: "O que faltou para ser nota 5?" (opcional)"; passo 3 → o formulário mostra a pergunta própria acima do campo; passo 4 → a tela avisa que, sem comentários, a "Análise dos comentários" fica vazia, o aviso diz "O formulário não pede mais comentário." e o formulário fica só com as estrelas e as perguntas; passo 5 → o formulário volta a mostrar "Conte-nos mais sobre sua experiência". Uma pergunta própria com menos de 10 caracteres deixa o botão de salvar desabilitado.

---

## UC-06 — Ativação de tipos de feedback

Rota: `/user/edit/types-feedback` · **Autenticado**.

### CT-UC06-01 — Página de tipos de feedback carrega com as opções

- **Objetivo:** confirmar que as opções de tipos de feedback aparecem.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/types-feedback`.
  2. Aguarde o conteúdo principal carregar.
- **Resultado esperado:** a URL corresponde a `/user/edit/types-feedback`, aparece **"O que você quer acompanhar?"** e são exibidos os rótulos **"Produtos"**, **"Serviços"** e **"Departamentos"**.

---

## UC-07 — Configuração do catálogo

Rota: `/user/edit/feedback-products` · **Autenticado**.

### CT-UC07-01 — Página de catálogo de produtos carrega corretamente

- **Objetivo:** garantir que a rota de catálogo responde com a lista de produtos.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/feedback-products`.
  2. Aguarde o carregamento (até ~15s).
- **Resultado esperado:** aparece o cartão **"Produtos"** com o botão **"Cadastrar produto"** e **ou** a lista dos produtos (cada um com o selo "Coleta ativa"/"Coleta inativa" e o botão **"Configurar"**) **ou** o estado vazio **"Nenhum produto cadastrado"**. A lista não é mais bloqueada quando o tipo está desligado em `/user/edit/types-feedback`.

### CT-UC07-05 — Coleta por item: perguntas, comentário e canais

- **Objetivo:** confirmar que cada item do catálogo tem a sua tela, com campo de comentário e canais próprios.
- **Pré-condições:** logado; ao menos um produto cadastrado (use **"Cadastrar produto"** no CT-UC07-01, se preciso).
- **Passos:**
  1. Em `/user/edit/feedback-products`, clique em **"Configurar"** num produto.
  2. Aguarde a tela `/user/edit/feedback/<tipo>/<id do item>` carregar.
  3. Em **Canais de coleta**, ative a coleta do item e copie o link.
  4. Em **Campo de comentário**, escolha **"Pergunta própria"**, escreva `O que você mudaria aqui?` e salve.
  5. Abra o link copiado numa janela anônima.
- **Resultado esperado:** passo 2 → a tela mostra os dados do item (**"Salvar dados do item"**), as perguntas, o **"Campo de comentário"** e os **Canais de coleta**, com o breadcrumb "Configuração da coleta › Catálogo › <item>"; passo 3 → aviso **"Coleta ativada!"** ("Item disponível para coleta de feedback."); passo 5 → o formulário do item mostra a pergunta própria do item, sem afetar a da empresa (CT-UC05-08). Um id inexistente na URL mostra "Item não encontrado".

---

## UC-08 — Configuração de coleta e contexto de IA

Rota: `/user/profile` · **Autenticado**. O contexto da empresa para a IA fica no cartão **"Contexto e LLM da empresa"** do Perfil e é editado na janela aberta por **"Editar contexto e LLM"** (a mesma do onboarding), em quatro passos: **1. Seu negócio** (resumo do negócio), **2. Sua meta** (objetivo da empresa), **3. O que descobrir** (objetivo da análise) e **4. Modelo LLM**. A rota antiga `/user/edit/collecting-data-enterprise` redireciona para `/user/profile#contexto-da-ia`.

### CT-UC08-01 — Página de configuração de coleta carrega com formulário visível

- **Objetivo:** confirmar que a tela de configuração/contexto carrega.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/profile`.
  2. Aguarde o conteúdo principal carregar.
- **Resultado esperado:** a URL corresponde a `/user/profile` e aparece o cartão **"Contexto e LLM da empresa"**, com o selo **"Configurado"** ou **"Incompleto"**, os blocos **"1. Seu negócio"**, **"2. Sua meta"**, **"3. O que descobrir"** e **"4. Modelo LLM"** (campo vazio aparece como "Não preenchido"; sem IA, "Chave e modelo não configurados") e o botão **"Editar contexto e LLM"**.

### CT-UC08-02 — Salvar objetivo da empresa persiste e exibe confirmação

- **Objetivo:** editar e salvar o objetivo da empresa.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/profile` e clique em **"Editar contexto e LLM"**.
  2. Avance com **"Próximo Passo"** até **"Sua meta"** ("O que você mais quer melhorar nos próximos meses?").
  3. Preencha com `Melhorar a satisfação dos clientes em 20%` (os outros dois campos do contexto precisam estar preenchidos para salvar).
  4. Avance até **"4. Modelo LLM"** e clique em **"Salvar sem configurar IA"** (ou **"Salvar e concluir"**, se a IA já estiver configurada).
- **Resultado esperado:** aparece o aviso **"Contexto salvo!"**, a janela fecha e o bloco **"2. Sua meta"** do cartão mostra o texto novo. Com algum dos três campos vazio, o salvamento é barrado com "Complete os campos obrigatórios".

### CT-UC08-04 — Resumo do negócio pode ser preenchido e salvo

- **Objetivo:** editar e salvar o resumo/descrição do negócio.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/profile` e clique em **"Editar contexto e LLM"**.
  2. No passo **"Seu negócio"** ("O que seu negócio faz e para quem?"), preencha com `Empresa de varejo com foco em atendimento ao cliente.`
  3. Avance com **"Próximo Passo"** até **"4. Modelo LLM"** e clique em **"Salvar sem configurar IA"** (ou **"Salvar e concluir"**).
- **Resultado esperado:** aparece o aviso **"Contexto salvo!"** e o bloco **"1. Seu negócio"** do cartão mostra o texto novo.

### CT-UC08-07 — Geração automática das perguntas e avisos

- **Objetivo:** confirmar que, com a IA configurada e o contexto completo, a IA gera as 3 perguntas do formulário geral e a tela avisa o andamento e a falha.
- **Pré-condições:** logado numa conta **nova** (as perguntas ainda são as padrão), com uma chave OpenRouter de teste. Consome a cota da IA. Se a conta já editou as perguntas, a IA não interfere e o cenário **não se aplica**.
- **Passos:**
  1. Na primeira entrada, preencha o contexto na janela do onboarding e configure a IA no passo **"4. Modelo LLM"** (ou use **"Conectar com OpenRouter"**); clique em **"Configurar IA e salvar"**.
  2. Acompanhe a tela **"Preparando sua conta"**.
  3. Abra `/user/edit/feedback-general`.
  4. Para ver a falha, repita com um modelo que costuma falhar ou sem saldo, e recarregue a área logada depois da falha.
- **Resultado esperado:** passo 2 → a tela espera a geração; depois de 40 s mostra **"A IA está demorando"**, com a troca de modelo; ao concluir, mostra **"Sua conta está pronta"** e leva ao Dashboard. Na falha, mostra o motivo com **"Tentar de novo"**, a troca de modelo (ou **"Revisar chave"**, se o erro é da conta) e **"Continuar com as perguntas padrão"**. Passo 3 → durante a geração, a seção Perguntas mostra "A IA está criando suas perguntas personalizadas. Elas aparecem aqui assim que ficarem prontas."; depois, as 3 perguntas novas. Passo 4 → o aviso **"As perguntas personalizadas não foram criadas"** fica no topo da área logada (sobrevive a recarregar) com **"Tentar de novo"**, **"Trocar modelo"** (ou **"Revisar chave"**) e **"Manter perguntas padrão"**, que dispensa o aviso.

---

## UC-09 — Dashboard

Rota: `/user/dashboard` · **Autenticado**. A barra abaixo do cabeçalho escolhe o **escopo** (empresa ou um item) e o **período**; todas as seções seguem essa escolha.

> **Conta sem nenhum feedback:** no lugar das seções de métricas, o Dashboard mostra as boas-vindas e a prévia "Aguardando os primeiros feedbacks". Os **"Primeiros passos"** (ativar a coleta e, se quiser, testar o formulário) aparecem no topo quando a coleta da empresa está pausada ao abrir o Dashboard, como na conta nova (CT-UC09-13). Os CT-UC09-02 a 04, 09 e 10 pedem uma conta com feedbacks.

### CT-UC09-01 — Dashboard carrega e exibe saudação personalizada

- **Objetivo:** confirmar carregamento do dashboard com saudação.
- **Passos:**
  1. Navegue para `/user/dashboard` e aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/dashboard` e a saudação **"Olá,"** está visível.

### CT-UC09-02 — Dashboard exibe a Avaliação por estrelas

- **Passos:**
  1. No dashboard, localize a seção **"Avaliação por estrelas"**.
- **Resultado esperado:** aparece o card **"Média"** com a nota /5, o rótulo (Ótima, Boa, Mediana, Ruim ou Péssima) e o número de avaliações, **ou** "Ainda sem avaliações" no escopo. A etiqueta de escopo aparece no canto da seção (ex.: "Avaliação geral da empresa"). Com um período escolhido, os cards mostram também a comparação com o período anterior.

### CT-UC09-03 — Dashboard exibe avaliações positivas e críticas

- **Passos:**
  1. Na seção **"Avaliação por estrelas"**, localize os cards de positivas e críticas.
- **Resultado esperado:** aparecem **"Positivas (4–5★)"** e **"Críticas (1–2★)"**, cada um com contagem e %. O link **"Ver todas as métricas de estrelas"** leva a `/user/ratings`. Com pelo menos dois itens do mesmo tipo no catálogo, aparece também **"Comparar dois itens"**, que leva a `/user/compare`.

### CT-UC09-04 — Dashboard exibe a Análise dos comentários

- **Passos:**
  1. No dashboard, localize a seção **"Análise dos comentários ✨ IA"**.
- **Resultado esperado:** aparecem o bloco **"Tom dos comentários"** (ou "Ainda sem comentários analisados pela IA") e o card **"Resumo dos comentários e recomendações"** (ou "Ainda não há resumo dos comentários para este escopo"). O link **"Ver a análise completa dos comentários"** leva a `/user/insights/overview`.

### CT-UC09-05 — Clique em "Ver feedbacks" navega para a listagem completa

- **Passos:**
  1. No dashboard, clique no link **"Ver feedbacks"**.
- **Resultado esperado:** a URL muda para `/user/feedbacks/all`.

### CT-UC09-09 — "Por onde chegaram" separa os canais de coleta

- **Objetivo:** confirmar que o Dashboard mostra por qual canal chegaram as avaliações.
- **Pré-condições:** logado; feedbacks recebidos por pelo menos um canal marcado (ex.: o do CT-UC04-01, pelo QR, e um pelo link do CT-UC05-04, de outro navegador).
- **Passos:**
  1. No dashboard, localize a seção **"Por onde chegaram"** (abaixo de "Avaliação por estrelas").
- **Resultado esperado:** com um canal só, aparece "Todas as avaliações marcadas ... vieram pelo **QR Code**" (ou **Link compartilhado** / **Etiqueta NFC**); com mais de um, uma linha por canal com contagem, % e média. Avaliações sem a marca de canal (anteriores a ela ou de QR Codes impressos antes dela) aparecem numa linha à parte, com a orientação de baixar o QR Code de novo. Sem nenhuma avaliação no escopo, a seção não aparece. Os envios do "Testar o formulário" não entram.

### CT-UC09-10 — Diagnóstico do escopo e histórico

- **Objetivo:** gerar o diagnóstico da IA no Dashboard e encontrá-lo no histórico.
- **Pré-condições:** logado; IA configurada, contexto da empresa completo e **pelo menos 10 avaliações** no escopo e no período escolhidos. Consome a cota da IA.
- **Passos:**
  1. No dashboard, localize a seção **"Diagnóstico do escopo ✨ IA"** (no topo, com 10 ou mais avaliações no período; no fim da página, com menos).
  2. Clique em **"Gerar diagnóstico"**.
  3. Aguarde o resultado.
  4. Clique em **"Ver o histórico de diagnósticos"** (ou use o menu **"Diagnósticos ✨"**).
- **Resultado esperado:** passo 2 → aparece "A IA está lendo os números e os comentários. Leva alguns segundos." (ou "Aguardando a vez na cota da IA…"); passo 3 → o diagnóstico mostra o período, o número de avaliações e as seções **"O que fazer, em ordem"**, **"O que vai bem"**, **"O que preocupa"** e **"O que mudou"**; o botão passa a **"Gerar de novo"** (ou **"Atualizar diagnóstico"**, quando chegam avaliações novas, ou **"Gerar para o período selecionado"**, se o período mudar); passo 4 → `/user/diagnosis` lista os diagnósticos do escopo, o mais recente aberto. Sem IA, a seção mostra "Configure a IA para receber o diagnóstico." com o link **"Configurar a IA"**; sem o contexto, "A IA precisa conhecer a empresa para recomendar."; com menos de 10 avaliações, "São precisas pelo menos 10 avaliações ..." e o botão desabilitado. Sem diagnóstico no escopo, `/user/diagnosis` mostra "Ainda não há diagnóstico ..." com o link **"Gerar o primeiro no Dashboard"**.

### CT-UC09-11 — Todas as métricas de estrelas

- **Objetivo:** confirmar a página com as métricas completas das notas.
- **Pré-condições:** logado; conta com feedbacks.
- **Passos:**
  1. No dashboard, clique em **"Ver todas as métricas de estrelas"**.
- **Resultado esperado:** a URL muda para `/user/ratings`, com **"Avaliação por estrelas"** (agora com **"Neutras (3★)"**), **"Distribuição das avaliações"**, **"Movimento das avaliações"**, **"Dias e horários de pico"** e **"Clientes que voltam"** (cada uma com "Ainda sem avaliações ..." quando o escopo não tem dados).

### CT-UC09-12 — Comparar dois itens

- **Objetivo:** confirmar a comparação lado a lado de dois itens do mesmo tipo.
- **Pré-condições:** logado.
- **Passos:**
  1. Abra o menu **"Comparar itens"** (`/user/compare`).
  2. Com dois ou mais itens do mesmo tipo, escolha o tipo, os dois itens e o período.
- **Resultado esperado:** sem dois itens do mesmo tipo, a página mostra o passo a passo para chegar lá ("Cadastre os itens no Catálogo", "Ative a coleta de cada item", "Volte aqui e escolha os dois"). Com eles, aparece **"Leitura lado a lado"**, uma tabela com **Nº de avaliações**, **Média**, **Positivas (4–5★)**, **Críticas (1–2★)**, **Tom dos comentários**, **Escreveram comentário** e **Precisão da média**, e a coluna **"Quem está melhor"** (com "Diferença incerta" quando as margens se sobrepõem).

### CT-UC09-13 — Primeiros passos e "Testar o formulário"

- **Objetivo:** confirmar que o gestor ativa a coleta e testa o formulário sem sair do Dashboard, e que o teste fica fora das métricas.
- **Pré-condições:** logado; a coleta da empresa pausada (conta nova, ou **"Pausar coleta"** no CT-UC05-02). O aparelho não pode ter respondido ao formulário geral da empresa no mesmo dia (o CT-UC04-01 no mesmo navegador conta).
- **Passos:**
  1. Navegue para `/user/dashboard`.
  2. No cartão **"Primeiros passos"**, clique em **"Ativar QR Code"**.
  3. Clique em **"Testar o formulário"**, responda na janela e clique em **Enviar Feedback**.
  4. Abra `/user/feedbacks/all`.
- **Resultado esperado:** passo 1 → o cartão mostra **"Ativar a coleta da empresa"** e **"Testar o formulário (opcional)"**, este desabilitado com "Ative o QR Code para poder testar."; passo 2 → o primeiro passo vira **"Coleta ativada"** ("Os clientes já conseguem responder pelo QR Code, pelo link e pela etiqueta NFC."); passo 3 → a janela "Testar o formulário" abre o mesmo formulário do cliente e, depois do envio, mostra **"Pronto! Seu teste chegou."**, fecha sozinha e o cartão passa a **"Tudo pronto ✓"**; passo 4 → o feedback aparece com a marca **"Teste"** e o canal "Teste do formulário", e não entra em "Por onde chegaram" (CT-UC09-09) nem nas métricas. Se o aparelho já respondeu no dia, a janela mostra "Você já respondeu por este aparelho.". **"Pular"** conclui o passo sem testar.

---

## UC-10 — Listagem de feedbacks

Rota: `/user/feedbacks/all` · **Autenticado**.

### CT-UC10-01 — Listagem carrega feedbacks ou exibe estado vazio

- **Objetivo:** garantir que a listagem renderiza cards de feedback ou o estado vazio, e **nunca** fica presa em estado de erro.
- **Pré-condições:** logado. Em ambiente serverless (Vercel), pode haver "cold start" transitório.
- **Passos:**
  1. Navegue para `/user/feedbacks/all`.
  2. Aguarde um estado terminal (até ~15s).
  3. Se aparecer **"Erro ao carregar feedbacks"**, aguarde ~2s e **recarregue a página** (repita até 2 tentativas para absorver cold start).
- **Resultado esperado:** é exibido **ou** ao menos um **card de feedback** **ou** o **estado vazio** ("Nenhum feedback encontrado"). Os feedbacks do "Testar o formulário" aparecem com a marca **"Teste"**. Se o erro **persistir** após as tentativas, é uma **falha real** (o endpoint `GET /api/protected/user/feedbacks` provavelmente está falhando — verificar o deploy).

---

## UC-11 — Análise dos comentários com IA

Rotas: `/user/insights/overview` (Visão geral) e `/user/insights/comments` (Comentários) · **Autenticado**. Os endereços antigos (`/user/insights`, `/user/insights/reports`, `emotional`, `statistics` e `/user/feedbacks/analytics/*`) redirecionam para elas (ver CT-UC12-16).

### CT-UC11-01 — Visão geral carrega com a análise ou o estado vazio

- **Passos:**
  1. Navegue para `/user/insights/overview` e aguarde o conteúdo principal.
  2. Aguarde o carregamento assíncrono (até ~15s).
- **Resultado esperado:** aparecem **"Tom dos comentários"** e **"Resumo dos comentários e recomendações ✨ IA"**, com dados **ou** com os estados vazios ("Ainda sem comentários analisados pela IA" / "Ainda não há resumo dos comentários para este escopo").

### CT-UC11-02 — Visão geral exibe o tom e os assuntos

- **Passos:**
  1. Navegue para `/user/insights/overview` e aguarde o carregamento.
- **Resultado esperado:** com comentários analisados, o tom mostra a barra com **positivos**, **neutros** e **negativos**, o saldo em palavras (**"Positivo"**, **"Neutro"** ou **"Atenção"**) e a seção **"Assuntos que mais impactam"** (ou as categorias como reserva). Sem comentários analisados, aparece o estado vazio. Palavras-chave **não** aparecem mais.

### CT-UC11-05 — Gerar o resumo de novo solicita nova análise

- **Objetivo:** disparar a geração de nova análise.
- **Pré-condições:** logado; o botão "Apenas gerar o resumo" deve estar **habilitado** — ele fica **desabilitado** quando o escopo ainda não tem comentários analisados, quando falta o contexto da empresa, quando o escopo é um tipo sem item escolhido ou enquanto outra análise está em andamento (comportamento intencional). Com o resumo em dia, ele segue habilitado e gera de novo. Se estiver desabilitado, o cenário **não se aplica**.
- **Observação:** no teste automatizado, a chamada `POST /api/protected/ia-analyze/**` era interceptada (mock) para não consumir créditos de IA. **No teste manual, o clique dispara a análise real** — execute com consciência do consumo.
- **Passos:**
  1. Navegue para `/user/insights/overview`.
  2. Clique em **"Analisar comentários com IA"**, na barra abaixo do cabeçalho.
  3. Na janela, localize **"Apenas gerar o resumo"** e, se estiver habilitado, clique nele.
- **Resultado esperado:** aparece indicação de progresso — **"Processando IA..."** / "Escrevendo o resumo (N de M)..." / "Escrevendo o resumo dos comentários em segundo plano" — ou a confirmação **"Análise atualizada!"**.

---

## UC-12 — Gestão de perfil

Rotas: `/user/profile`, `/user/qrcode/enterprise`, `/user/edit/types-feedback`, `/user/dashboard` · **Autenticado** (exceto CT-UC12-07).

### CT-UC12-01 — Página de perfil carrega com dados da empresa

- **Passos:**
  1. Navegue para `/user/profile` e aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/profile` e aparecem as seções **"Dados pessoais e acesso"** (com **"Nome completo"** e **"Email"**), **"Dados e configurações da empresa"**, o cartão **"Contexto e LLM da empresa"** e, no fim, **"Excluir minha conta"**.

### CT-UC12-02 — E-mail do usuário autenticado é exibido no perfil

- **Passos:**
  1. Navegue para `/user/profile` e aguarde o conteúdo principal.
- **Resultado esperado:** o **e-mail da conta logada** aparece na tela.

### CT-UC12-03 — Endereço antigo do QR Code da empresa leva aos Canais de coleta

- **Objetivo:** o perfil não tem mais link de QR Code; o QR Code fica em **Configuração da coleta › Avaliação da empresa**, e o endereço antigo continua funcionando.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue diretamente para `/user/qrcode/enterprise`.
- **Resultado esperado:** a URL muda para `/user/edit/feedback-general` e a seção **Canais de coleta** aparece (como no CT-UC05-01).

### CT-UC12-04 — Configuração do catálogo é acessível

- **Objetivo:** validar que a tela de catálogo/tipos responde na rota (o catálogo é acessado pelo menu Configuração da coleta → Catálogo, não mais pelo perfil).
- **Passos:**
  1. Navegue para `/user/edit/types-feedback`.
  2. Aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/edit/types-feedback` e o conteúdo principal fica visível.

### CT-UC12-06 — Logout redireciona para a página de login

- **Passos:**
  1. Navegue para `/user/dashboard` e aguarde o conteúdo principal.
  2. Clique no **menu de conta** (nome da empresa no canto do cabeçalho; o menu tem **"Minha conta"**, **"Guia do Sistema"** e **"Sair"**).
  3. No menu aberto, clique em **"Sair"**.
- **Resultado esperado:** a URL muda para `/login`.

### CT-UC12-07 — Usuário não autenticado é redirecionado ao acessar rota protegida

- **Objetivo:** garantir proteção de rota.
- **Pré-condições:** sessão **deslogada** (use janela anônima ou faça logout antes).
- **Passos:**
  1. Sem estar autenticado, navegue diretamente para `/user/dashboard`.
- **Resultado esperado:** você é redirecionado para `/login`.

### CT-UC12-09 — Troca de e-mail

- **Objetivo:** confirmar que a troca de e-mail só vale depois da confirmação pelo endereço novo.
- **Pré-condições:** logado numa conta **descartável** e com acesso à caixa de um e-mail novo (no ambiente local, o Mailpit). A troca muda o e-mail de login da conta.
- **Passos:**
  1. Navegue para `/user/profile`, na seção **"Dados pessoais e acesso"**.
  2. No campo **Email** (dica "Após alterar, confirme pelo link enviado ao novo e-mail"), clique em **"Editar"**, digite um e-mail novo e clique em **"Salvar"**.
  3. Recarregue a página.
  4. Na caixa do e-mail novo, abra **"Confirme seu novo e-mail"** e clique em **"Confirmar meu novo e-mail"**.
  5. Volte a `/user/profile`.
- **Resultado esperado:** passo 2 → toast **"Confirme no novo e-mail!"**, e você continua no Perfil; passo 3 → o Perfil ainda mostra o e-mail **antigo**; passo 4 → o link abre `/auth/success`; passo 5 → o Perfil mostra o e-mail **novo**. Se o e-mail novo já for de outra conta, a tela mostra o mesmo toast, mas nenhum e-mail sai e a troca não acontece.

### CT-UC12-10 — Troca de telefone

- **Objetivo:** confirmar que o telefone é salvo num passo só, sem código por SMS.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/profile` e clique no campo **Telefone**.
  2. Digite um número no formato `+55` seguido do DDD e do número e clique em **"Salvar"**.
- **Resultado esperado:** toast **"Telefone atualizado!"**, o campo volta ao modo de visualização e mostra o número novo. Não há passo de código: o sistema não tem provedor de SMS.

### CT-UC12-15 — Excluir minha conta

- **Objetivo:** confirmar que a exclusão pede confirmação, recusa senha errada e apaga a conta.
- **Pré-condições:** logado numa conta **descartável** com senha (ex.: uma criada só para este teste). **Nunca** use a conta de teste do time: a exclusão apaga a conta, a empresa e todos os feedbacks, sem volta.
- **Passos:**
  1. Navegue para `/user/profile` e, no fim, clique em **"Excluir minha conta"**.
  2. Na janela, digite uma senha errada em **"Sua senha"** e `EXCLUIR` no campo de confirmação; clique em **"Excluir para sempre"**.
  3. Corrija a senha e clique em **"Excluir para sempre"** de novo.
  4. Clique em **"Ir para o início"** e tente entrar com a conta excluída em `/login`.
- **Resultado esperado:** passo 1 → a janela "Excluir minha conta" lista o que será apagado, e **"Excluir para sempre"** só habilita com a senha e a palavra `EXCLUIR`; passo 2 → "Senha incorreta. Confira e tente de novo." e nada é apagado; passo 3 → **"Sua conta foi excluída."** ("Apagamos a conta, a empresa e todos os dados dela."), sem fechar a janela; passo 4 → a página recarrega em `/` e o login responde "E-mail ou senha incorretos.". Numa conta que só entra pelo Google, a janela não pede senha, e com a entrada feita há mais de 24 h aparece "Por segurança, saia, entre de novo e volte aqui para excluir a conta.".

### CT-UC12-16 — Rotas antigas redirecionam

- **Objetivo:** confirmar que links salvos das telas antigas continuam funcionando.
- **Pré-condições:** logado.
- **Passos:** navegue diretamente para cada endereço da tabela.
- **Resultado esperado:** cada um termina no destino indicado.

| Endereço antigo | Destino |
|---|---|
| `/user/insights`, `/user/insights/reports`, `/user/insights/emotional`, `/user/insights/statistics` | `/user/insights/overview` |
| `/user/feedbacks/analytics/all` | `/user/insights/comments` |
| `/user/feedbacks/analytics/positive` | `/user/insights/comments?filtro=positivos` |
| `/user/feedbacks/analytics/negative` | `/user/insights/comments?filtro=negativos` |
| `/user/insights/questions` | `/user/dashboard` |
| `/user/edit/feedback-settings` | `/user/edit/types-feedback` |
| `/user/qrcode/enterprise` | `/user/edit/feedback-general` |
| `/user/edit/collecting-data-enterprise` | `/user/profile#contexto-da-ia` |

---

### Observações finais

- **Sessão:** faça login uma vez (ver "Como fazer login") antes de executar as UCs 05–12; reutilize a mesma aba/sessão. Para UC-01, UC-02, UC-04 e CT-UC12-07, use uma janela **anônima/deslogada**.
- **Latência:** telas com carregamento assíncrono podem levar até ~15s; aguarde o estado final antes de concluir que houve falha.
- **UC-04 é a mais sensível a dados:** exige empresa válida, coleta ativa (ponto de coleta ativo, o mesmo para QR Code, link e NFC) e dispositivo sem envio prévio no mesmo ponto e no mesmo dia — prepare esses dados antes de testar.
- **Casos com IA** (CT-UC08-07, CT-UC09-10, CT-UC11-05) consomem a cota da chave OpenRouter da empresa. **Casos destrutivos** (CT-UC12-15) só em conta descartável.
- **Ordem que evita retrabalho:** CT-UC05-02 (ativar a coleta) antes de UC-04 e CT-UC05-08; UC-04 antes de CT-UC09-09; CT-UC12-09 por último na sessão logada, porque troca o e-mail de login da conta.
- **IDs dos casos:** seguem os documentos de cada caso de uso (`concepcao/casos-de-uso/uc-xx-*.md`). Os casos que entraram depois da suíte Playwright usam o ID do cenário correspondente nesses documentos (ex.: CT-UC04-02, CT-UC12-09) ou um número novo no fim da lista (ex.: CT-UC01-08, CT-UC09-09).
