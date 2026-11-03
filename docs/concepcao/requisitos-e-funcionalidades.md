# Requisitos e Funcionalidades

> Documento que descreve as funcionalidades do produto, regras de negócio, requisitos funcionais (RF), requisitos não funcionais (RNF), critérios de aceitação, rastreabilidade e detalhamento de prioridades/status.

!!! note "Situação conferida contra o código (03/11/2026)"
    Os requisitos nasceram na concepção (junho e julho de 2026). Nesta revisão, cada um foi conferido no código dos repositórios `feedback-analytics-web`, `feedback-analytics-api-gateway` e `feedback-analytics-ia-analyze`. A coluna **Status** dos detalhamentos diz o que foi implementado, o que mudou e o que não foi feito. Os requisitos **RF22 a RF28** entraram agora: são funcionalidades que já existiam no código e faltavam nesta lista.

---

## Sumário

1. [Funcionalidades do Produto](#funcionalidades-do-produto)
2. [Regras de Negócio (RNE)](#regras-de-negócio-rne)
3. [Requisitos Funcionais (RF)](#requisitos-funcionais-rf)
4. [Requisitos Não Funcionais (RNF)](#requisitos-não-funcionais-rnf)
5. [Tabela de Rastreabilidade](#tabela-de-rastreabilidade)
6. [Critérios de Aceitação](#critérios-de-aceitação-principais)
7. [Detalhamento dos Requisitos Funcionais (por ID)](#detalhamento-dos-requisitos-funcionais-por-id)
8. [Detalhamento dos Requisitos Não Funcionais (por ID)](#detalhamento-dos-requisitos-não-funcionais-por-id)

---

## Funcionalidades do Produto

### Autenticação e Gestão de Acesso

- Cadastro da conta com nome do negócio, e-mail, celular e senha. O CPF/CNPJ deixou de ser pedido (migration `0009` do gateway).
- **Login com e-mail e senha ou com o Google.** Na primeira entrada com o Google, a tela "Complete seu cadastro" pede o nome do negócio, o celular e o aceite dos termos.
- Logout.
- Confirmação do e-mail pelo link do Better Auth (`/api/auth/verify-email`), que redireciona para a Web.
- **Recuperação de senha (Esqueci minha senha)** com envio de e-mail e link seguro.
- **Reenvio de e-mail de confirmação** caso o usuário não tenha recebido, com limite por e-mail e por IP.
- Proteção de rotas privadas por autenticação.
- **Exclusão da conta** pelo Perfil ("Excluir minha conta"), que apaga a empresa e todos os dados dela.

### Área do Usuário Gestor (Dashboard)

- **Apresentação do Produto (Landing Page Pública):** Página inicial destacando as funcionalidades da plataforma e versão do sistema gerada por CI/CD.
- **Dashboard Principal:**
  - Métricas do escopo (empresa ou um item do catálogo) e do período escolhidos: estrelas, canais de chegada (QR Code, link e NFC), movimento das avaliações, perguntas do formulário, análise dos comentários e diagnóstico do escopo.
  - A listagem dos feedbacks fica na tela Feedbacks; o Dashboard não lista mais os últimos feedbacks.
  - Telas de apoio: todas as métricas de estrelas (dias e horários de pico, clientes que voltam) e a comparação de dois itens do catálogo.
- **Perfil do Usuário:**
  - Atualiza o nome.
  - Mostra o campo de e-mail, mas a troca ainda não acontece: o `changeEmail` do Better Auth está desligado, e o gateway responde `400 update_failed`.
  - Atualiza o telefone, salvo direto, sem verificação por SMS.
- **Gestão Institucional da Empresa:**
  - Visualizar o cadastro da empresa (data de criação e status da conta), no Perfil.
  - O `PATCH /api/protected/user/enterprise` atualiza só a versão e o aceite dos termos.
- **Coleta de Dados de Contexto (Motor de Negócio IA):**
  - Consultar dados de coleta e contexto de negócio.
  - Atualizar parcialmente (PATCH).
  - Inserir/atualizar de forma completa (PUT/upsert).
  - Com o contexto preenchido e a IA configurada, as 3 perguntas da empresa são geradas automaticamente.
- **Configuração da IA por empresa:**
  - Chave do OpenRouter da própria empresa, colada ou obtida por "Conectar com OpenRouter", guardada cifrada no banco.
  - Escolha do modelo.
- **Gerenciamento de QR Code de Coleta:**
  - Alternar status do QR (Ativo/Inativo) com bloqueio instantâneo.
  - Gerar QR code mestre da empresa e específicos (produtos, serviços, departamentos).
  - Configurar perguntas e subperguntas dinâmicas por item.
  - **Canais de coleta:** além do QR Code, o mesmo formulário sai por link e por etiqueta NFC; cada canal leva a sua marca na URL.
  - **Campo de comentário por escopo:** convite padrão, pergunta própria ou campo oculto.
  - **Exportação e Compartilhamento Nativo:** Download do QR Code em imagem (`.png`) e integração com API nativa de compartilhamento (`navigator.share`) do dispositivo para distribuição instantânea do link. Sem a API nativa, o link é copiado.

### Gestão e Análise de Feedbacks

- Listagem paginada do histórico completo, com o canal de chegada e a marca "Teste".
- Filtros (por nota, busca textual, item do catálogo e tipo de escopo).
- Visualização detalhada (modal/página) de cada feedback.
- Estatísticas quantitativas (média, distribuição percentual de notas).
- **Análise dos comentários:** filtros por tom (positivos, neutros e negativos) e pela divergência entre a nota e o texto.
- **Insights Avançados com IA:**
  - Botão "Analisar comentários com IA", que põe o pedido numa fila; a tela acompanha o andamento.
  - Relatório global automatizado (resumo situacional + recomendações).
  - Análise do sentimento do texto, com intensidade, confiança e sentimento por aspecto.
  - Estatísticas da Análise (total analisado, distribuição de sentimentos, *Top Categories* e *Top Keywords* extraídas).
  - **Filtro Semântico Anti-Poluição:** o motor de IA descarta as palavras-chave e categorias iguais às opções de resposta, aos rótulos da escala ou ao texto das perguntas, e só aceita termos presentes no comentário do cliente.
- **Diagnóstico do escopo com IA:** interpreta os números do período (e do período anterior) e uma amostra de comentários; o histórico fica na tela Diagnósticos.

### Interface de Coleta (Público Final)

- Validação da empresa e de um ponto de coleta ativo antes de liberar o formulário.
- O mesmo formulário atende QR Code, link e NFC; o "Testar o formulário" do painel fica fora das métricas.
- Envio de respostas a perguntas e subperguntas dinâmicas (notas de 1-5).
- Atribuição de nota global da experiência (1-5).
- Campo de comentário opcional, conforme a configuração do escopo (convite padrão, pergunta própria ou oculto).
- Captura de dados do cliente de forma opcional (nome, e-mail, gênero).
- **Proteção anti-duplicidade (anti-spam)** por dispositivo, ponto de coleta e dia, usando *fingerprint*.

---

## Regras de Negócio (RNE)

| ID | Descrição | Requisitos Relacionados | Detalhamento |
|---|---|---|---|
| **RNE-001** | Isolamento de Dados por Empresa (Multi-tenancy) | RF08, RF09, RNF02 | Uma conta empresarial só pode acessar dados (Feedbacks, Dashboards, QR Codes) atrelados ao seu próprio `enterprise_id`. O gateway tira a empresa da sessão e filtra toda consulta por ela (`src/db/tenantScope.ts`). A RLS está ligada nas 24 tabelas (migration `0013`), mas a policy deixa o papel do app (`feedback_app`) ver todas as linhas: entre empresas, quem barra é a aplicação; a RLS barra os demais papéis do banco. |
| **RNE-002** | Obrigatoriedade de Validação da Empresa para Coleta | RF06, RNF08 | O formulário público não pode ser renderizado nem aceitar envios se a empresa não existir (`404 enterprise_not_found`) ou se não houver ponto de coleta QR ativo para o escopo (a Web mostra "QR Code indisponível" e o envio responde `404 collection_point_not_found`). Não existe status de empresa desativada: o bloqueio é pelo ponto de coleta. |
| **RNE-003** | Classificação de Sentimento via IA | RF12, RF13, RNF05, RNF10 | Todo feedback submetido para análise deve obrigatoriamente ser categorizado como 'Positivo', 'Neutro' ou 'Negativo' pelo motor de Inteligência Artificial. Uma resposta da IA com outro valor invalida o lote inteiro (`invalid_ai_response_schema`). |
| **RNE-004** | Janela de Resfriamento de Submissões (Anti-Spam) | RF07, RNF03 | Um cliente final (mesmo dispositivo/IP) só pode submeter 1 feedback por dia **por ponto de coleta** (`collection_point_id`). Isso previne spam, mas permite que o cliente avalie áreas distintas da empresa (ex: Recepção e Pós-Venda) no mesmo dia. O dia é o do relógio do servidor (UTC em produção). |
| **RNE-005** | Fallback de Análise (Resiliência Operacional) | RF20, RNF12 | **Mudou.** Se o provedor de IA falhar, a análise falha com um código tipado (ex.: `ia_provider_unavailable`) e não grava resultado parcial; não há extração local no lugar da IA. O fallback que ficou é por feedback: quando nenhuma palavra-chave sugerida pela IA passa na higienização, o `ia-analyze` usa palavras da própria mensagem (sem *stopwords*), e as categorias caem nas duas primeiras palavras-chave. |
| **RNE-006** | Fidelidade Analítica de Dados | RF08, RNF08 | Os dados consolidados exibidos no Dashboard (Totalizadores, Médias, Distribuição) devem obrigatoriamente espelhar o estado transacional exato do banco de dados relacional no momento da requisição, não sendo permitido o uso de *cache* desatualizado que mascare a realidade operacional. |
| **RNE-007** | Validação Estrita de Documentos | RF01, RNF01 | **Substituída (migration `0009`).** O CPF/CNPJ deixou de ser pedido e guardado, porque nada no sistema o usava (LGPD, necessidade). Não há mais validação de documento. |
| **RNE-008** | Validação Geográfica de Telefones | RF02, RNF01 | O sistema só aceita dados de contato estruturados no padrão brasileiro (+55), com DDD de 11 a 99, sem sequência de dígitos repetidos, celular de 9 dígitos começando por 9 e fixo começando por 2 a 5 (`registerSchema` do `@feedback/lib-shared`). |
| **RNE-009** | Restrição Lógica de Hierarquia do Catálogo | RF05, RF06 | **Em parte.** Ativar o QR Code de um item exige o item `ACTIVE`, e o envio exige o ponto de coleta QR `ACTIVE`. Desativar o item no catálogo, porém, não desativa o QR dele, e o envio público não confere o status do item: um QR que já estava ativo continua aceitando respostas. |
| **RNE-010** | Preenchimento Automático do Catálogo (Onboarding) | RF04, RF25, RNF06 | Logo após o cadastro (com senha ou na primeira entrada com o Google), o gateway cria a empresa e 3 perguntas institucionais base (Atendimento, Qualidade e Custo-Benefício) numa transação (`src/auth/enterpriseOnSignup.ts`), no lugar do antigo *trigger* do banco, para evitar que o cliente fique diante de um formulário vazio. Com o contexto da empresa e a IA configurados, a IA troca essas perguntas padrão por 3 perguntas feitas para o negócio. |
| **RNE-011** | Higienização de Metadados de Autenticação | RF01, RNF01, RNF02 | **Substituída.** Com o Better Auth, não há payload de metadados do Supabase Auth nem JWT: a sessão é um cookie httpOnly com um token guardado na tabela `session`. O telefone fica em `user.phone`, o aceite dos termos na `enterprise`, e o CPF/CNPJ não é mais pedido. |
| **RNE-012** | Proteção contra Mutação Destrutiva (Storage) | RNF08, RNF09 | **Substituída.** O sistema não usa o Storage do Supabase (o Supabase só hospeda o Postgres) e não guarda logotipo nem mídia; o gatilho `protect_delete` não existe nas migrations atuais. |
| **RNE-013** | Inicialização do Trial no Cadastro | RF01, RF21 | Ao criar a empresa, o gateway grava `trial_ends_at = NOW() + 4 meses` e `subscription_status = 'TRIAL'` (`src/auth/enterpriseOnSignup.ts`, no lugar do antigo trigger `on_auth_user_created`), garantindo que toda nova conta inicie com período de teste completo sem intervenção manual. Nada no código muda o status depois: não há passagem automática para `EXPIRED` nem bloqueio ao fim do trial. |
| **RNE-014** | Proteção contra Enumeração de Usuários (Higienização de Respostas) | RF01, RF16, RNF01 | Nos fluxos de login, cadastro e recuperação de senha, as respostas relativas ao **e-mail** devem ser genéricas e indistinguíveis. O login responde a e-mail inexistente, senha incorreta e conta não confirmada com a **mesma** mensagem (`invalid_credentials`); o cadastro com e-mail já existente segue para a tela de sucesso (`confirmation_required`) sem revelar duplicidade; a recuperação sempre exibe a mesma mensagem genérica. Impede que atacantes descubram, por varredura automatizada, quais e-mails possuem cadastro ativo. |

---

## Requisitos Funcionais (RF)

| Código | Requisito | Descrição |
|---|---|---|
| **RF01** | Autenticação de Usuário | O sistema deve permitir cadastro (nome do negócio, e-mail, celular e senha), login e logout, com sessões seguras e confirmação do e-mail. O CPF/CNPJ previsto na concepção saiu na migration `0009`. |
| **RF02** | Gestão de Perfil | O usuário gestor deve poder atualizar nome/metadados e e‑mail/telefone (com confirmação). |
| **RF03** | Gestão de Empresa | O sistema deve permitir visualizar e atualizar os dados cadastrais da empresa. |
| **RF04** | Coleta de Dados de Contexto | Consultar, atualizar (PATCH) e inserir (PUT) dados de contexto utilizados pela IA. |
| **RF05** | Gestão de QR Codes | Gerar códigos para empresa, produtos/serviços e customizar perguntas dinâmicas por item, além de habilitar/desabilitar pontos de coleta. |
| **RF06** | Submissão de Feedback | Formulário público acessível via QR Code (nota + mensagem) com validação prévia de existência da empresa. |
| **RF07** | Proteção Anti-Spam | Impedir mais de 1 envio por dispositivo, ponto de coleta e dia (*fingerprint*), retornando HTTP 409 em duplicidade. |
| **RF08** | Dashboard | Apresentar estatísticas gerais e a listagem dos últimos feedbacks para a empresa logada. |
| **RF09** | Filtros e Listagem | Listar feedbacks com paginação, filtros por nota, busca textual e visualização detalhada. |
| **RF10** | Estatísticas Base | Exibir nota média e distribuição percentual de avaliações. |
| **RF11** | Analytics Visual | Visão analítica segmentando os feedbacks de forma visual (positivos vs. negativos). |
| **RF12** | Insights e IA | Disparo sob demanda para geração de relatórios, insights acionáveis e análise de sentimento via IA. |
| **RF13** | Dados Analíticos de IA | Exibir métricas da IA (total processado, distribuição, *top categories* e *keywords*). |
| **RF14** | Gestão de Clientes | Listar clientes que se identificaram e seu histórico de submissões de feedback. |
| **RF15** | Controle de Acesso | Restringir rotas administrativas apenas a usuários devidamente autenticados no sistema. |
| **RF16** | Recuperação de Acesso | Disponibilizar fluxo completo de "Esqueci minha senha" com envio de token via e-mail e redefinição segura. |
| **RF17** | Reenvio de Confirmação | Permitir que o usuário solicite o reenvio do e-mail de ativação/confirmação de conta. |
| **RF18** | Apresentação do Produto | Possuir uma Landing Page pública (*Home*) detalhando as funcionalidades e benefícios da plataforma. |
| **RF19** | Exportação e Compartilhamento | O sistema deve permitir o download do QR Code (imagem PNG) e utilizar a API nativa do dispositivo para compartilhamento rápido do link de coleta. |
| **RF20** | Filtro Semântico Anti-Poluição (IA) | O motor de IA deve impedir que as opções de resposta e os enunciados do formulário virem palavras-chave ou categorias, evitando que o próprio formulário polua a nuvem de palavras-chave. |
| **RF21** | Exibição do Status de Assinatura | O dashboard deve exibir um badge dinâmico refletindo o `subscription_status` da empresa: âmbar com dias restantes (TRIAL), verde (ACTIVE), vermelho (EXPIRED) ou cinza (CANCELED). |
| **RF22** | Canais de Coleta (QR Code, link e NFC) | O mesmo formulário público deve ser distribuído por QR Code, link e etiqueta NFC, registrando o canal de chegada de cada feedback; o "Testar o formulário" fica fora das métricas e da IA. |
| **RF23** | Campo de Comentário por Escopo | A empresa deve escolher, para o feedback geral e para cada item do catálogo, se o campo de comentário mostra o convite padrão, uma pergunta própria ou fica oculto. |
| **RF24** | Diagnóstico do Escopo com IA | Gerar, sob demanda, um diagnóstico do escopo que interpreta os números do período (e do anterior) e uma amostra de comentários, com histórico dos diagnósticos gerados. |
| **RF25** | Geração Automática das Perguntas | Com o contexto da empresa e a IA configurados, gerar com a IA as 3 perguntas do feedback geral no lugar das perguntas padrão. |
| **RF26** | Login com Google | Permitir cadastro e login com a conta Google, completando na primeira entrada o nome do negócio, o celular e o aceite dos termos. |
| **RF27** | Exclusão de Conta | Permitir que o gestor exclua a própria conta pelo Perfil, apagando a empresa e todos os dados dela. |
| **RF28** | Configuração da IA por Empresa (OpenRouter) | Cada empresa deve usar a própria chave do OpenRouter, guardada cifrada, e escolher o modelo das análises. |

---

## Requisitos Não Funcionais (RNF)

| Código | Categoria | Requisito |
|---|---|---|
| **RNF01** | Segurança | API autenticada pela sessão do Better Auth (cookie httpOnly); validação rigorosa de entradas de dados (schemas Zod) no backend. |
| **RNF02** | Segurança Multi-Tenant | Isolamento por `enterprise_id` em todas as consultas da aplicação, com a empresa tirada da sessão; RLS ligada em todas as tabelas, acessíveis só pelo papel do app. |
| **RNF03** | Integridade / Anti-Spam | Rastreio de *devices* (fingerprint) garantindo máximo de 1 envio diário, barrando ataques em massa. |
| **RNF04** | Performance | Tempos de resposta: Dashboard \< 2,5s; APIs críticas \< 400ms; registro de feedback público \< 5s. |
| **RNF05** | Performance de IA | O processamento assíncrono do motor de IA deve salvar resultados em até 10s após disparo pelo gestor. |
| **RNF06** | Usabilidade (UX) | Interface *mobile-first* responsiva, focando em simplicidade extrema no formulário de coleta (público). |
| **RNF07** | Escalabilidade | Arquitetura Cloud/Serverless (BFF Node.js na Vercel + Postgres hospedado no Supabase) com provisionamento automático sob demanda. |
| **RNF08** | Confiabilidade | Garantia de integridade referencial no banco de dados (chaves estrangeiras), refletindo no dashboard o estado consistente dos dados. |
| **RNF09** | Manutenibilidade | Serviços em repositórios independentes com deploys separados e tipos compartilhados por um pacote versionado (`@feedback/lib-shared`), com tipagem global forte em TypeScript. |
| **RNF10** | Acurácia de IA | A Inteligência Artificial deve atingir >= 80% de precisão semântica nos testes de sentimento e "sanitização" contra alucinações. |
| **RNF11** | Monitoramento da API | O sistema deve expor um *Endpoint* de *Health Check* ultraleve para monitoramento de disponibilidade da infraestrutura. |
| **RNF12** | Resiliência de IA (Fallback Local) | O sistema deve possuir um mecanismo de contingência que utilize algoritmos de extração locais (baseados em *stopwords*) caso a API externa do provedor de IA falhe ou gere "alucinações" inaceitáveis. |
| **RNF13** | Rastreabilidade de Versão (CI/CD) | O processo de *build* do frontend deve extrair e injetar dinamicamente a versão exata da *release* do Git no código compilado (Vite config), para fins de auditoria visual no ambiente de produção. |

---

## Tabela de Rastreabilidade

| Funcionalidade | Requisitos Funcionais | Requisitos Não Funcionais | Regras de Negócio |
|---|---|---|---|
| Autenticação Completa (Login, Logout, Callback) | RF01 | RNF01 | RNE-014 |
| Login com Google | RF26 | RNF01 | RNE-013 |
| Exclusão de Conta | RF27 | RNF01, RNF02 | - |
| Trial e Status de Assinatura | RF21 | RNF08 | RNE-013 |
| Recuperação e Reenvio de E-mail | RF16, RF17 | RNF01 | RNE-014 |
| Gestão de Perfil | RF02 | RNF01, RNF08 | RNE-008 |
| Gestão de Empresa | RF03 | RNF01, RNF08 | - |
| Coleta de Dados de Contexto | RF04 | RNF01 | - |
| Configuração da IA por Empresa | RF28 | RNF01 | - |
| Geração Automática das Perguntas | RF25 | RNF05 | RNE-010 |
| QR Code (Geração e Exportação) | RF05, RF19 | RNF07 | RNE-002, RNE-009 |
| Canais de Coleta (QR Code, link e NFC) | RF22 | RNF06 | RNE-002 |
| Campo de Comentário por Escopo | RF23 | RNF06 | - |
| Submissão de Feedback Público | RF06 | RNF04, RNF06 | RNE-002 |
| Proteção Anti-Spam (Duplicidade) | RF07 | RNF03 | RNE-004 |
| Dashboard Principal | RF08 | RNF04, RNF08 | RNE-001, RNE-006 |
| Listagem, Filtros e Detalhamento | RF09 | RNF04 | RNE-001 |
| Estatísticas Globais | RF10 | RNF04, RNF08 | RNE-006 |
| Analytics Base | RF11 | RNF04 | - |
| Motor de IA e Regras Anti-Poluição | RF12, RF20 | RNF05, RNF10, RNF12 | RNE-003, RNE-005 |
| Estatísticas de Classificação da IA | RF13 | RNF05, RNF10 | RNE-003 |
| Diagnóstico do Escopo com IA | RF24 | RNF05 | RNE-006 |
| Histórico de Clientes | RF14 | RNF01, RNF02 | RNE-001 |
| Rotas Protegidas e API Gateway | RF15 | RNF01, RNF02, RNF09 | RNE-001 |
| Apresentação (Landing Page) | RF18 | RNF06, RNF13 | - |
| Monitoramento Sistêmico | - | RNF11 | - |

---

## Critérios de Aceitação (Principais)

- **Acesso:** Rotas administrativas (Dashboard, Perfil) redirecionam automaticamente para login caso a sessão seja inexistente ou inválida (RF15).
- **Autenticação:** E-mail de confirmação ou recuperação de senha deve ser enviado pelo provedor em até 30 segundos (RF01, RF16, RF17).
- **Gestão do QR Code e Compartilhamento:**
  - Desabilitar o QR Code corporativo deve tornar o formulário inacessível imediatamente, exibindo mensagem (RF05).
  - O sistema deve gerar um Blob de imagem (`.png`) baixável com o nome da empresa e invocar a `Share API` do sistema operacional quando disponível (RF19).
- **Integridade da Coleta:**
  - Caso o usuário tente acessar um formulário alterando o ID do QR Code para uma empresa inexistente, exibir tela de erro fatal, impedindo acesso (RF06).
  - O feedback preenchido e válido deve persistir no banco e gerar resposta HTTP 200 (`{ "ok": true }`) em menos de 5 segundos (RF06, RNF04).
- **Segurança (Spam):** Ao enviar o 2º feedback pelo mesmo navegador/dispositivo, para o mesmo ponto de coleta e no mesmo dia, a API Gateway deve abortar com HTTP 409 Conflict (RF07).
- **Inteligência Artificial de Alta Precisão:**
  - O motor assíncrono `ia-analyze` deve descartar as palavras-chave e categorias iguais às opções de resposta, aos rótulos da escala ou ao texto das perguntas, e só aceitar termos presentes no comentário, para garantir nuvem de palavras reais do cliente (RF20).
  - Quando nenhuma palavra-chave da IA passa nessa validação, o *Fallback Local* extrai as palavras-chave da própria mensagem com base em *stopwords*. Em caso de queda do provedor LLM ou de JSON inválido, a análise falha com código tipado e não grava resultado parcial (RNF12).
- **Integração Contínua:** A versão da interface exibida no rodapé (Landing Page) deve refletir de forma automatizada a tag de *release* real extraída do histórico Git no momento do *build* (RNF13).

---

## Detalhamento dos Requisitos Funcionais (por ID)

Status: **Implementado** (como pedido), **Implementado (mudou)** (existe, de outro jeito), **Parcial** (só uma parte existe) e **Não implementado**. A prioridade dos requisitos RF-022 a RF-028 não foi definida na concepção.

| ID | Descrição | Status | Prioridade |
|---|---|---|---|
| **RF-001** | Autenticação de Usuário: cadastro, login, logout e confirmação de e-mail pelo **Better Auth** no gateway (não pelo Supabase), com sessão em cookie httpOnly. O cadastro pede nome do negócio, e-mail, celular e senha, sem CPF/CNPJ. | Implementado (mudou) | Alta |
| **RF-002** | Gestão de Perfil: o nome é atualizado. A troca de e-mail não acontece (`changeEmail` desligado no Better Auth, `400 update_failed`), e o telefone é salvo direto, sem verificação por SMS (`/phone/verify` não faz nada). | Parcial | Alta |
| **RF-003** | Gestão de Empresa: o Perfil mostra o cadastro da empresa (data de criação e status da conta) e edita o contexto para a IA; o `PATCH /enterprise` só atualiza a versão e o aceite dos termos. | Parcial | Alta |
| **RF-004** | Coleta de Dados de Contexto: injeção de regras de negócio da empresa para refino dos prompts da IA. Salvar o contexto também dispara a geração automática das perguntas (RF-025). | Implementado | Alta |
| **RF-005** | Geração e Gestão de QR Codes: QR da empresa e de cada item do catálogo, com até 3 perguntas por escopo e até 3 subperguntas cada, e ativação/desativação de cada ponto de coleta. | Implementado | Alta |
| **RF-006** | Submissão de Feedback: formulário web móvel público que confere a empresa e o ponto de coleta ativo antes de abrir. | Implementado | Alta |
| **RF-007** | Proteção Anti-Spam: fingerprint calculado no backend (hash MD5 do navegador, do IP e do dia) e bloqueio na API (`409`) do segundo envio do mesmo aparelho, para o mesmo ponto de coleta, no mesmo dia. | Implementado | Alta |
| **RF-008** | Dashboard: métricas do escopo e do período escolhidos (estrelas, canais, movimento, perguntas, análise dos comentários e diagnóstico). O extrato dos feedbacks recentes saiu do Dashboard e ficou na tela Feedbacks. | Implementado (mudou) | Alta |
| **RF-009** | Listagem e Filtros: listagem paginada com filtros por nota, busca no comentário, item e tipo de escopo (Query Strings), canal de chegada, marca "Teste" e detalhe em janela. | Implementado | Média |
| **RF-010** | Estatísticas de Feedbacks: consolidação matemática de médias, volume e distribuição de 1 a 5, com movimento no tempo, dias e horários de pico e clientes que voltam. | Implementado | Média |
| **RF-011** | Analytics de Feedbacks: a tela Análise dos comentários separa os comentários por tom (positivos, neutros e negativos) e pela divergência entre a nota e o texto. | Implementado (mudou) | Média |
| **RF-012** | Insights/IA sob demanda: o pedido entra numa fila (`202` com o id do job), um worker chama o `ia-analyze` com a chave OpenRouter da própria empresa, e a Web acompanha o job. | Implementado (mudou) | Média |
| **RF-013** | Estatísticas da IA: total analisado, distribuição de sentimentos, *top categories* e *keywords* com intervalos de confiança, sentimento líquido e sentimento por aspecto. | Implementado | Média |
| **RF-014** | Gestão de Clientes: a tela Clientes mostra "Em breve". Existem só a métrica "clientes que voltam" (contada por aparelho, sem dado pessoal) e o nome e o e-mail do cliente no detalhe do feedback. | Não implementado | Média |
| **RF-015** | Proteção de Rotas: o middleware `requireAuth` valida a sessão em toda rota protegida do gateway, e a Web redireciona para o login sem sessão. O isolamento entre empresas fica na aplicação (RNE-001). | Implementado | Alta |
| **RF-016** | Recuperação de Acesso: Fluxo completo de "Esqueci minha senha"; o token do link vai para um cookie httpOnly que vale 1 hora e só é enviado à rota de nova senha. | Implementado | Alta |
| **RF-017** | Reenvio de Confirmação: endpoint para reenviar o e-mail de ativação, com resposta sempre igual e limite por e-mail e por IP. | Implementado | Média |
| **RF-018** | Apresentação do Produto: Interface pública institucional (Landing Page) para atração de novos usuários. | Implementado | Baixa |
| **RF-019** | Exportação e Compartilhamento: download do QR Code em PNG (a imagem é gerada pelo serviço externo `api.qrserver.com`) e compartilhamento pela API nativa; sem ela, o link é copiado. | Implementado | Média |
| **RF-020** | Filtro Semântico Anti-Poluição (IA): o `ia-analyze` descarta palavras-chave e categorias iguais às opções de resposta, aos rótulos da escala (péssimo a ótima) ou ao texto inteiro das perguntas, e exige que o termo apareça no comentário. Não remove palavras soltas das perguntas. | Implementado (mudou) | Alta |
| **RF-021** | Exibição do Status de Assinatura: badge no menu da conta e no Perfil (não no Dashboard), com `subscription_status` e dias restantes do trial calculados no cliente. O status só é gravado no cadastro; nada o muda depois. | Implementado (mudou) | Média |
| **RF-022** | Canais de Coleta: o formulário recebe a marca `canal` na URL (`qr`, `link`, `nfc` ou `teste`) e grava o canal no feedback; o Dashboard mostra "Por onde chegaram", e os feedbacks de teste ficam fora das métricas e da IA. | Implementado | — |
| **RF-023** | Campo de Comentário por Escopo: modos padrão, pergunta própria (10 a 150 caracteres) e oculto; com pergunta própria, ela é guardada com o comentário e vai para a IA; com o campo oculto, o texto enviado é descartado. | Implementado | — |
| **RF-024** | Diagnóstico do Escopo com IA: pedido pela fila, usa os números do escopo calculados no gateway e até 60 comentários; o histórico fica em Diagnósticos. Exige o contexto da empresa e a IA configurada. | Implementado | — |
| **RF-025** | Geração Automática das Perguntas: quando a empresa tem os três campos de contexto, a IA configurada e ainda as perguntas padrão, um job gera 3 perguntas; se falhar, a Web avisa e oferece tentar de novo. | Implementado | — |
| **RF-026** | Login com Google: entrada pelo Better Auth; na primeira entrada a empresa é criada e a tela "Complete seu cadastro" pede nome do negócio, celular e aceite dos termos. O mesmo e-mail com senha e com Google é a mesma conta. Só funciona com as credenciais do Google configuradas. | Implementado | — |
| **RF-027** | Exclusão de Conta: "Excluir minha conta" no Perfil (`POST /api/auth/delete-user`), com a senha ou, para quem só entra pelo Google, uma sessão aberta nas últimas 24 horas. Apaga a empresa e tudo dela numa transação, e depois o usuário. Publicada em 02/11/2026. | Implementado | — |
| **RF-028** | Configuração da IA por Empresa: chave do OpenRouter colada ou obtida por "Conectar com OpenRouter", guardada cifrada (AES-256-GCM), com o painel mostrando só o final; escolha do modelo. Sem chave, as análises falham com `ia_config_required`. | Implementado | — |

---

## Detalhamento dos Requisitos Não Funcionais (por ID)

| ID | Descrição | Status | Prioridade |
|---|---|---|---|
| **RNF-001** | Segurança: sessão do Better Auth em cookie httpOnly (não há JWT nem `Authorization: Bearer`), com validação de dados em runtime utilizando Zod para impedir payloads maliciosos. | Implementado (mudou) | Alta |
| **RNF-002** | Segurança Multi-Tenant: a aplicação filtra toda consulta pela empresa da sessão (`src/db/tenantScope.ts`). A RLS está ligada nas 24 tabelas (migration `0013`), com policy só para o papel `feedback_app`, com que o app entra no banco em produção: ele lê e escreve dados, mas não altera a estrutura nem desliga a RLS. | Implementado (mudou) | Alta |
| **RNF-003** | Integridade / Anti-Spam: Geração de *fingerprints* diários bloqueando varreduras de robôs ou envio abusivo de clientes (HTTP 409). | Implementado | Alta |
| **RNF-004** | Performance: Respostas da API em menos de 400ms, gravação de feedback \< 5s, e interface visualizando o Dashboard em no máximo 2,5s. Não há teste nem registro de medição desses tempos nos repositórios. | Meta sem medição | Alta |
| **RNF-005** | Performance de IA: o processamento não atrasa a interface: o pedido responde `202` na hora e a Web acompanha o job. O worker avança a cada ação do usuário e por um cron de reserva; o tempo até o resultado depende do número de lotes e do provedor, e a meta de 10s não é medida. | Implementado (mudou) | Alta |
| **RNF-006** | Usabilidade (UX): Responsividade garantida (*mobile-first*) no fluxo público para melhorar conversões de feedback do usuário na ponta. | Implementado | Alta |
| **RNF-007** | Escalabilidade: Topologia em Nuvem usando infraestrutura Serverless (Vercel) com Node.js e o Postgres hospedado no Supabase. | Implementado | Alta |
| **RNF-008** | Confiabilidade: 26 chaves estrangeiras, 25 com `ON DELETE CASCADE` e uma com `SET NULL` (não há `RESTRICT`). O histórico é preservado porque itens do catálogo e perguntas são desativados, não apagados, e cada resposta guarda o texto da pergunta. A exclusão da conta apaga tudo em cascata de propósito. | Implementado (mudou) | Alta |
| **RNF-009** | Manutenibilidade: serviços em repositórios independentes com um pacote de contratos versionado (`@feedback/lib-shared`) para reuso de interfaces/tipagens globais entre Backend e Frontend usando TypeScript rigoroso. | Implementado | Alta |
| **RNF-010** | Acurácia de IA: A precisão das categorias semânticas geradas (positivas/negativas) e a correlação cruzada de dados deve manter-se em 80% frente ao julgamento humano. As funções de medição (acurácia, kappa de Cohen e F1) estão em `src/libs/eval` do gateway. | Em testes (Refinamento) | Alta |
| **RNF-011** | Monitoramento da API: Provisionamento de rota leve de *Health Check* sem acesso ao banco para varreduras de UpTime por sistemas de monitoramento (DataDog, UptimeRobot, etc). | Implementado | Média |
| **RNF-012** | Resiliência de IA (Fallback): o fallback por *stopwords* existe só por feedback, quando nenhuma palavra-chave da IA passa na validação. Se o provedor falhar ou devolver JSON inválido, a análise falha com código tipado, sem resultado parcial e sem extração local no lugar da IA. | Parcial | Alta |
| **RNF-013** | Rastreabilidade de Versão (CI/CD): Leitura em tempo de *Build* da tag Git local que amarra visualmente a interface da web com o snapshot técnico do código-fonte implantado no momento. | Implementado | Média |
