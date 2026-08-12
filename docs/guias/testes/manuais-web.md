# Testes Manuais — Web (Casos de Uso)

!!! note "Por que este runbook existe"
    A suíte **Playwright (e2e)** do `feedback-analytics-web` — que rodava contra o ambiente **homolog** deployado + Supabase, além do gate `e2e-main.yml` — foi **removida**. A cobertura dos casos de uso (UC-01…UC-12) passou a ser **manual**, reproduzível por este roteiro clicando na aplicação. Os testes **unitários** (Vitest/jsdom) continuam automatizados no CI.

Cada seção corresponde a um caso de uso (UC) e a um ou mais casos de teste (CT). Execute os passos clicando na aplicação e confira os resultados esperados.

## Pré-requisitos

### Ambiente

- **Produção (recomendado):** use a URL do ambiente deployado (Vercel). A URL base é o domínio de produção do web.
- **Local (alternativa):** frontend em `http://localhost:5173` (valor padrão da base) e API em `http://localhost:3000` (`VITE_API_BASE_URL`, com a API rodando).
- Todas as rotas citadas abaixo são **relativas à URL base** do ambiente escolhido (ex.: `/login` → `https://<base>/login`).
- Navegador recomendado: Chrome/Chromium (desktop). Para cenários de usuário deslogado, use uma janela anônima.

### Conta de teste

- **E-mail:** uma conta de teste da empresa (ex.: `gestor@empresateste.com`).
- **Senha:** a senha do fixture de teste do time — não versionada nesta doc (em dev local, os fixtures usam um default de desenvolvimento).
- **ID da empresa de teste (apenas UC-04):** o `enterprise_id` da conta de teste (não versionado aqui).
- **Dados fixos de apoio (cadastro/validação):**
  - CPF válido já vinculado à conta de teste: `529.982.247-25`
  - CNPJ válido: `11.222.333/0001-81`
  - Senha forte de exemplo para cadastro (valor descartável que você inventa): `Teste@Exemplo123`

> A conta de teste precisa existir previamente com o CPF `529.982.247-25`, pois os cenários de UC-01 dependem desse cadastro pré-existente.

### Acesso administrativo ao banco (somente para preparar UC-04)

Os cenários originais usavam acesso admin ao Supabase para: (1) apagar o "device fingerprint" da empresa antes de reenviar feedback e (2) descobrir um ponto de coleta QR ativo. Para o teste manual, veja as pré-condições da UC-04.

### Como fazer login

1. Navegue para `/login`.
2. Preencha **E-mail** com o e-mail de teste.
3. Preencha **Senha** com a senha de teste.
4. Clique no botão **Entrar** (submit).
5. Aguarde o redirecionamento para `/user/dashboard`.

Este login autenticado é **pré-condição para as UCs 05 a 12** (exceto o CT-UC12-07, que exige sessão deslogada). As UCs **01, 02 e 04** são executadas **sem autenticação** (janela anônima ou deslogado).

---

## UC-01 — Cadastro de conta

Rota: `/register` · Executar **deslogado**. Campos do formulário: `Nome completo`, `E-mail`, `Documento (CPF)`, `Telefone`, `Senha`, `Confirmar senha`, checkbox `Aceitar termos`.

### CT-UC01-02 — E-mail já existente segue para tela de sucesso (prevenção de enumeração)

- **Objetivo:** garantir que, ao cadastrar com e-mail já usado, o sistema **não revela** que o e-mail existe e mostra tela de sucesso.
- **Pré-condições:** deslogado; o e-mail da conta de teste já está cadastrado.
- **Passos:**
  1. Navegue para `/register`.
  2. Preencha **Nome completo** com `Usuário Duplicado`.
  3. Preencha **E-mail** com o e-mail da conta de teste (já existente).
  4. Preencha **Documento** com um **CPF válido novo** (gere um CPF válido diferente do da conta de teste).
  5. Preencha **Telefone** com um número válido qualquer (ex.: `11987654321`).
  6. Preencha **Senha** e **Confirmar senha** com `Teste@Exemplo123`.
  7. Marque o checkbox de **termos**.
  8. Clique em **Cadastrar** (submit).
- **Resultado esperado:** aparece a mensagem **"Cadastro realizado com sucesso"** (nenhum erro de "e-mail já existe" é exibido).

### CT-UC01-03 — Documento (CPF) já existente exibe erro

- **Objetivo:** validar que CPF já cadastrado é rejeitado com mensagem de erro.
- **Pré-condições:** deslogado; o CPF `529.982.247-25` já está vinculado à conta de teste.
- **Passos:**
  1. Navegue para `/register`.
  2. Preencha **Nome completo** com `Usuário CPF Dup`.
  3. Preencha **E-mail** com um endereço **novo/único** (ex.: `dup-doc+<timestamp>@teste.com`).
  4. Preencha **Documento** com `529.982.247-25` (CPF já existente).
  5. Preencha **Telefone** com `11999990002`.
  6. Preencha **Senha** e **Confirmar senha** com `Teste@Exemplo123`.
  7. Marque o checkbox de **termos**.
  8. Clique em **Cadastrar** (submit).
- **Resultado esperado:** aparece mensagem de erro contendo **"documento"**, **"CPF"** ou **"já cadastrado"**.

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
- **Resultado esperado:** a URL muda para `/user/dashboard` e a saudação **"Olá,"** fica visível.

### CT-UC02-02 — Senha incorreta exibe mensagem de erro

- **Objetivo:** validar tratamento de credenciais inválidas.
- **Pré-condições:** deslogado.
- **Passos:**
  1. Navegue para `/login`.
  2. Preencha **E-mail** com o e-mail de teste.
  3. Preencha **Senha** com `senha-errada-123`.
  4. Clique em **Entrar**.
- **Resultado esperado:** aparece mensagem **"E-mail ou senha incorretos"** (ou "Credenciais inválidas") e a URL **permanece em** `/login`.

---

## UC-04 — Envio de feedback via QR Code

Área pública de coleta · Executar **deslogado**. Rota: `/feedback/qrcode?enterprise=<ID>&collection_point=<CP_ID>&item=<ITEM_ID>`. O submit envia `POST /api/public/qrcode/feedback`.

### CT-UC04-01 — Envio válido exibe confirmação de feedback recebido

- **Objetivo:** enviar um feedback completo via QR e ver a confirmação.
- **Pré-condições:**
  - `enterprise_id` da conta de teste disponível (ID de empresa válido).
  - A empresa precisa ter um **ponto de coleta QR ativo** (`type=QR_CODE`, `status=ACTIVE`). Prefira o ponto de escopo empresa (sem item de catálogo). Sem um ponto ativo, o submit retorna 404.
  - O **fingerprint do dispositivo** para essa empresa deve estar limpo (a tabela `tracked_devices` bloqueia reenvio pelo mesmo dispositivo). Para reexecutar: limpe o registro do dispositivo no banco **ou** use um dispositivo/navegador que ainda não enviou feedback para essa empresa.
- **Passos:**
  1. Monte a URL com o `enterprise` e o `collection_point` (e `item`, se o ponto for específico de um item) e navegue até ela.
  2. Aguarde a página de coleta carregar (conteúdo principal visível).
  3. No topo, clique na **5ª estrela** (nota máxima), se as estrelas estiverem presentes.
  4. Para **cada** pergunta/subpergunta com escala, clique na opção **"Ótima"**.
  5. Preencha o campo de **comentário** (textarea) com um texto, ex.: `Ótimo atendimento, equipe muito prestativa e produto excelente.`
  6. Clique no botão **Enviar** (submit).
- **Resultado esperado:** a requisição `POST /api/public/qrcode/feedback` retorna **HTTP 200** e aparece a confirmação **"Feedback enviado"** (ou "Obrigado" / "Recebemos").

### CT-UC04-03 — Enterprise ID inválido exibe "empresa não encontrada"

- **Objetivo:** validar tratamento de QR com empresa inexistente.
- **Pré-condições:** deslogado.
- **Passos:**
  1. Navegue para `/feedback/qrcode?enterprise=id-invalido-que-nao-existe`.
- **Resultado esperado:** aparece mensagem **"Empresa não encontrada"** (ou "QR Code inválido" / "não encontrado" / "404").

---

## UC-05 — Geração de QR Code da empresa

Rota: `/user/edit/feedback-general` · **Autenticado**.

### CT-UC05-01 — Tela de Feedback geral carrega com o QR Code

- **Objetivo:** confirmar que a tela de feedback geral exibe o QR Code da empresa (ou o controle de ativação).
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/feedback-general`.
  2. Aguarde o carregamento assíncrono (até ~15s).
- **Resultado esperado:** a URL corresponde a `/user/edit/feedback-general` e é exibido **ou** o QR Code (imagem/canvas/SVG) **ou** o botão de **habilitar/desabilitar/ativar QR Code** (ou "ativar coleta").

---

## UC-06 — Ativação de tipos de feedback

Rota: `/user/edit/types-feedback` · **Autenticado**.

### CT-UC06-01 — Página de tipos de feedback carrega com as opções

- **Objetivo:** confirmar que as opções de tipos de feedback aparecem.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/types-feedback`.
  2. Aguarde o conteúdo principal carregar.
- **Resultado esperado:** a URL corresponde a `/user/edit/types-feedback` e é exibido pelo menos um dos rótulos: **"Produtos"**, **"Serviços"** ou **"Departamentos"**.

---

## UC-07 — Configuração do catálogo

Rota: `/user/edit/feedback-products` · **Autenticado**.

### CT-UC07-01 — Página de catálogo de produtos carrega corretamente

- **Objetivo:** garantir que a rota de catálogo responde, seja com acesso liberado ou com bloqueio por tipo não ativado.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/edit/feedback-products`.
  2. Aguarde o carregamento (até ~15s).
- **Resultado esperado:** é exibido **ou** o conteúdo principal da página (acesso liberado) **ou** a mensagem de bloqueio do tipo (ex.: **"tipo ... não ativado"** / **"ative ... produtos"**).

---

## UC-08 — Configuração de coleta e contexto de IA

Rota: `/user/profile` · **Autenticado**.

### CT-UC08-01 — Página de configuração de coleta carrega com formulário visível

- **Objetivo:** confirmar que a tela de configuração/contexto carrega.
- **Pré-condições:** logado.
- **Passos:**
  1. Navegue para `/user/profile`.
  2. Aguarde o conteúdo principal carregar.
- **Resultado esperado:** a URL corresponde a `/user/profile` e aparece texto relacionado ao contexto da empresa, como **"O que ... empresa"**, **"Empresa"**, **"Objetivo"** ou **"Analytics"**.

### CT-UC08-02 — Salvar objetivo da empresa persiste e exibe confirmação

- **Objetivo:** editar e salvar o objetivo da empresa.
- **Pré-condições:** logado; o campo de objetivo deve estar presente na tela (se não existir neste estado da aplicação, o cenário **não se aplica**).
- **Passos:**
  1. Navegue para `/user/profile`.
  2. Localize o campo de **objetivo da empresa** (campo de texto/textarea de objetivo).
  3. Preencha com `Melhorar a satisfação dos clientes em 20%`.
  4. Clique no botão **Salvar** (ou **Confirmar**).
- **Resultado esperado:** aparece confirmação **"Salvo"** (ou "Configurações salvas" / "Atualizado").

### CT-UC08-04 — Resumo do negócio pode ser preenchido e salvo

- **Objetivo:** editar e salvar o resumo/descrição do negócio.
- **Pré-condições:** logado; o campo de resumo do negócio deve estar presente (senão, não se aplica).
- **Passos:**
  1. Navegue para `/user/profile`.
  2. Localize o campo de **resumo do negócio** (textarea).
  3. Preencha com `Empresa de varejo com foco em atendimento ao cliente.`
  4. Clique no botão **Salvar** (ou **Confirmar**).
- **Resultado esperado:** aparece confirmação **"Salvo"** (ou "Configurações salvas" / "Atualizado").

---

## UC-09 — Dashboard

Rota: `/user/dashboard` · **Autenticado**.

### CT-UC09-01 — Dashboard carrega e exibe saudação personalizada

- **Objetivo:** confirmar carregamento do dashboard com saudação.
- **Passos:**
  1. Navegue para `/user/dashboard` e aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/dashboard` e a saudação **"Olá,"** está visível.

### CT-UC09-02 — Dashboard exibe métrica de total de feedbacks

- **Passos:**
  1. No dashboard, localize a área de métricas.
- **Resultado esperado:** aparece a métrica de **"Total"** (ou "Feedbacks recebidos" / "Feedbacks").

### CT-UC09-03 — Dashboard exibe distribuição de sentimentos

- **Passos:**
  1. No dashboard, localize a seção de sentimentos.
- **Resultado esperado:** aparece pelo menos um dos rótulos: **"Positivo"**, **"Neutro"** ou **"Negativo"**.

### CT-UC09-04 — Dashboard exibe seção de relatório de insights

- **Passos:**
  1. No dashboard, localize a seção de insights.
- **Resultado esperado:** aparece a seção **"Relatório de Insights"**.

### CT-UC09-05 — Clique em "Ver feedbacks" navega para a listagem completa

- **Passos:**
  1. No dashboard, clique no link **"Ver feedbacks"**.
- **Resultado esperado:** a URL muda para `/user/feedbacks/all`.

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
- **Resultado esperado:** é exibido **ou** ao menos um **card de feedback** **ou** o **estado vazio** ("Nenhum feedback" / "Sem feedbacks" / "Vazio"). Se o erro **persistir** após as tentativas, é uma **falha real** (o endpoint `GET /api/protected/user/feedbacks` provavelmente está falhando — verificar o deploy).

---

## UC-11 — Insights de IA

Rota: `/user/insights/reports` · **Autenticado**.

### CT-UC11-01 — Relatório de insights carrega com sumário ou estado vazio

- **Passos:**
  1. Navegue para `/user/insights/reports` e aguarde o conteúdo principal.
  2. Aguarde o carregamento assíncrono (até ~15s).
- **Resultado esperado:** aparece **ou** o sumário/insights (**"Sumário"** / "Resumo" / "Insights") **ou** um estado vazio (**"Nenhum insight"** / "Sem dados" / "Gerar insights" / "Sem feedbacks").

### CT-UC11-02 — Insights exibem análise de sentimentos e keywords

- **Passos:**
  1. Navegue para `/user/insights/reports` e aguarde o carregamento.
- **Resultado esperado:** aparece **ou** a análise (**"Positivo"** / "Negativo" / "Neutro" / **"Palavra-chave"** / "Keywords") **ou** um estado vazio ("Nenhum insight" / "Sem dados" / "Gerar insights" / "Ainda não há relatório").

### CT-UC11-05 — Botão de regenerar insights solicita nova análise

- **Objetivo:** disparar a geração de nova análise.
- **Pré-condições:** logado; o botão de regenerar deve estar **habilitado** — ele fica **desabilitado** quando não há análise nova a gerar (comportamento intencional). Se estiver desabilitado, o cenário **não se aplica**.
- **Observação:** no teste automatizado, a chamada `POST /api/protected/ia-analyze/**` era interceptada (mock) para não consumir créditos de IA. **No teste manual, o clique dispara a análise real** — execute com consciência do consumo.
- **Passos:**
  1. Navegue para `/user/insights/reports`.
  2. Localize o botão **"Regenerar"** (ou "Gerar insights" / "Atualizar insights").
  3. Se estiver habilitado, clique nele.
- **Resultado esperado:** aparece indicação de progresso — **"Processando"** / "Gerando" / "Analisando" / "Aguarde" — ou a confirmação **"Insights atualizados"**.

---

## UC-12 — Gestão de perfil

Rotas: `/user/profile`, `/user/qrcode/enterprise`, `/user/edit/types-feedback`, `/user/dashboard` · **Autenticado** (exceto CT-UC12-07).

### CT-UC12-01 — Página de perfil carrega com dados da empresa

- **Passos:**
  1. Navegue para `/user/profile` e aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/profile` e aparece pelo menos um dos textos: **"Perfil"**, **"Empresa"**, **"Nome"** ou **"E-mail"**.

### CT-UC12-02 — E-mail do usuário autenticado é exibido no perfil

- **Passos:**
  1. Navegue para `/user/profile` e aguarde o conteúdo principal.
- **Resultado esperado:** o **e-mail da conta logada** aparece na tela.

### CT-UC12-03 — Link para QR Code da empresa está presente no perfil

- **Pré-condições:** logado; o link de QR Code deve existir no perfil (senão, não se aplica).
- **Passos:**
  1. Navegue para `/user/profile` e aguarde o conteúdo.
  2. Clique no link **"QR Code"** (ou "Acessar QR Code").
- **Resultado esperado:** a URL muda para `/user/qrcode/enterprise`.

### CT-UC12-04 — Configuração do catálogo é acessível

- **Objetivo:** validar que a tela de catálogo/tipos responde na rota (o catálogo é acessado pelo menu Configuração da coleta → Catálogo, não mais pelo perfil).
- **Passos:**
  1. Navegue para `/user/edit/types-feedback`.
  2. Aguarde o conteúdo principal.
- **Resultado esperado:** a URL corresponde a `/user/edit/types-feedback` e o conteúdo principal fica visível.

### CT-UC12-06 — Logout redireciona para a página de login

- **Passos:**
  1. Navegue para `/user/dashboard` e aguarde o conteúdo principal.
  2. Clique no **menu de conta** (avatar/botão no canto que abre o menu).
  3. No menu aberto, clique em **"Sair"** (ou "Logout").
- **Resultado esperado:** a URL muda para `/login`.

### CT-UC12-07 — Usuário não autenticado é redirecionado ao acessar rota protegida

- **Objetivo:** garantir proteção de rota.
- **Pré-condições:** sessão **deslogada** (use janela anônima ou faça logout antes).
- **Passos:**
  1. Sem estar autenticado, navegue diretamente para `/user/dashboard`.
- **Resultado esperado:** você é redirecionado para `/login`.

---

### Observações finais

- **Sessão:** faça login uma vez (ver "Como fazer login") antes de executar as UCs 05–12; reutilize a mesma aba/sessão. Para UC-01, UC-02, UC-04 e CT-UC12-07, use uma janela **anônima/deslogada**.
- **Latência:** telas com carregamento assíncrono podem levar até ~15s; aguarde o estado final antes de concluir que houve falha.
- **UC-04 é a mais sensível a dados:** exige empresa válida, ponto de coleta QR ativo e dispositivo sem envio prévio — prepare esses dados antes de testar.
