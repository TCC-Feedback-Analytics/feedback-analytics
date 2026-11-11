# Política de Privacidade

> **Última atualização:** 10 de Novembro de 2026

Esta política explica de forma clara quais dados o Feedback Analytics trata, para quais finalidades, com quais fornecedores compartilha e como você pode exercer seus direitos, em estrita conformidade com a Lei Geral de Proteção de Dados Pessoais (Lei nº 13.709/2018 — LGPD).

---

## 1. Quem trata os dados (Papéis perante a LGPD)

O papel do Feedback Analytics varia de acordo com a origem do dado:

* **Dados da conta do negócio (quem se cadastra na plataforma):** o **Feedback Analytics é o Controlador**. Nós definimos os dados cadastrais mínimos necessários para criar e manter a conta, permitir o acesso e garantir a segurança do serviço.
* **Feedbacks dos clientes finais:** o **negócio (empresa cliente) é o Controlador**. O negócio é quem decide coletar a opinião dos seus clientes, define os pontos de atendimento e personaliza perguntas. O **Feedback Analytics atua como Operador**, tratando esses dados em nome do negócio exclusivamente para registrá-los, consolidar métricas e processar diagnósticos solicitados pela própria empresa.

---

## 2. Quais dados coletamos

### Da conta do negócio (gestor)
* **Cadastro básico:** nome do gestor ou do negócio, endereço de e-mail e telefone de contato;
* **Credenciais de acesso:** senha de login, armazenada exclusivamente sob a forma de **hash criptográfico com salt** (bcrypt), nunca em texto plano;
* **Login social (ao entrar com o Google):** nome, endereço de e-mail e foto de perfil informados pelo Google, mediante autorização do usuário;
* **Contexto e catálogo do negócio:** descrição das atividades da empresa, objetivos e catálogo de produtos/serviços cadastrados para parametrizar o formulário;
* **Configuração de Inteligência Artificial:** chave de API da empresa (BYO-Key do OpenRouter), mantida **criptografada em repouso** (AES-256-GCM), e o modelo de IA selecionado;
* **Dados técnicos de sessão:** endereço IP e identificador do navegador utilizados para autenticação e auditoria de segurança.

### Dos clientes que enviam feedback (formulário público)
* **Avaliação do atendimento:** nota de 1 a 5 estrelas, respostas às perguntas do questionário e comentário em texto livre (opcional);
* **Identificação facultativa:** nome, e-mail e gênero, **estritamente se a pessoa optar por se identificar** (todos os campos de identificação são opcionais);
* **Metadados de integridade e anti-spam:** endereço IP, identificação do navegador (*user agent*) e um identificador técnico do aparelho (*fingerprint*), utilizados unicamente para prevenir envios repetidos ou automações maliciosas (limitando a uma avaliação por aparelho e ponto de coleta a cada ciclo).

> **Minimização de dados por design:** a plataforma **não solicita nem armazena CPF, CNPJ ou documentos de identificação**. Também não coletamos nem armazenamos gravações de áudio, voz ou arquivos de mídia, mantendo a entrada de dados estritamente estruturada em texto.

---

## 3. Para que usamos os dados

Os dados tratados destinam-se exclusivamente às seguintes finalidades:

1. **Gestão da conta e acesso:** criar e autenticar a conta, gerenciar a sessão do gestor e enviar e-mails transacionais indispensáveis (confirmação de cadastro, troca de e-mail e redefinição de senha);
2. **Prestação do serviço:** receber as avaliações dos clientes, calcular métricas de satisfação (médias, distribuição por canal e produto) e gerar resumos e diagnósticos com IA no painel do gestor;
3. **Segurança e proteção contra abuso:** barrar acessos não autorizados, mitigar ataques de força bruta, frear spam e assegurar o isolamento estrito entre empresas (*multi-tenant*).

Não comercializamos dados pessoais sob qualquer hipótese e não os utilizamos para direcionamento de anúncios publicitários ou perfilamento comercial com terceiros.

---

## 4. Bases legais (LGPD)

Todo o tratamento realizado fundamenta-se nas seguintes bases legais do art. 7º da LGPD:

| Finalidade do tratamento | Base legal |
|---|---|
| Criação da conta, autenticação, suporte e e-mails do sistema | **Execução de contrato** (art. 7º, V) |
| Coleta e processamento de feedbacks para o painel da empresa | **Execução de contrato** a pedido do controlador (art. 7º, V) |
| Prevenção a spam, rate limit e segurança da infraestrutura | **Legítimo interesse** (art. 7º, IX) |
| Nome, e-mail e gênero informados voluntariamente no feedback | **Consentimento** do titular (art. 7º, I) |

---

## 5. Com quem compartilhamos os dados

O compartilhamento ocorre exclusivamente com fornecedores de infraestrutura indispensáveis para a operação segura da plataforma:

* **Vercel:** hospedagem da interface web, do gateway de API e do serviço de processamento;
* **Supabase:** hospedagem do banco de dados relacional PostgreSQL;
* **Brevo:** serviço de SMTP para envio dos e-mails transacionais da conta;
* **Google:** provedor de autenticação federada (quando o gestor opta por "Entrar com Google");
* **OpenRouter e Provedor do Modelo de IA:** processamento das análises dos comentários, diagnóstico de escopo e sugestões de perguntas. O envio inclui apenas o texto do comentário, a nota e o contexto do negócio, utilizando a chave de API cadastrada pela própria empresa. **Nome, e-mail e endereço IP do cliente final nunca são repassados ao provedor de IA**.

**Transferência internacional de dados:** os servidores dos provedores acima estão localizados fora do Brasil (notadamente Estados Unidos e União Europeia). A transferência internacional observa o art. 33 da LGPD, respaldada por cláusulas contratuais de proteção e acordos de tratamento de dados (DPAs) firmados com cada serviço.

---

## 6. Cookies e armazenamento no navegador

* **Cookie essencial de autenticação:** emitido pelo Better Auth com os parâmetros `httpOnly`, `Secure` (em produção) e política `SameSite`. Não pode ser lido por scripts do navegador (proteção contra XSS) e contém apenas um identificador opaco de sessão;
* **Armazenamento local (localStorage):** utilizado unicamente para salvar preferências visuais da interface (modo claro/escuro) e o progresso do guia inicial (*onboarding*);
* **Ausência de rastreadores:** a plataforma não utiliza cookies de publicidade, ferramentas de telemetria comportamental invasiva ou pixels de redes sociais.

---

## 7. Retenção e exclusão dos dados

* **Dados cadastrais e feedbacks:** permanecem armazenados enquanto a conta do negócio estiver ativa na plataforma;
* **Direito de exclusão autônomo:** o gestor pode apagar sua conta e todos os dados associados a qualquer momento, sem necessidade de intermediários, diretamente no painel em **Perfil > Excluir minha conta**. A solicitação dispara uma exclusão transacional em cascata que elimina permanentemente a empresa, todos os feedbacks, respostas, cadastros de clientes e configurações de IA;
* **Registros de sessão:** sessões expiradas tornam-se inoperantes de forma imediata na aplicação e são eliminadas definitivamente no descarte da conta.

---

## 8. Seus direitos (Art. 18 da LGPD)

Na condição de titular de dados pessoais, você pode solicitar a qualquer momento:

1. A confirmação da existência de tratamento e o acesso aos seus dados;
2. A correção de dados incompletos, inexatos ou desatualizados;
3. A anonimização, o bloqueio ou a eliminação de dados desnecessários, excessivos ou tratados em desacordo com a lei;
4. A portabilidade dos dados para outro fornecedor de serviço;
5. A eliminação dos dados tratados com base no seu consentimento;
6. Informações sobre as entidades públicas e privadas com as quais compartilhamos dados;
7. A revogação do consentimento concedido.

### Canal de atendimento
Para exercer quaisquer desses direitos sobre dados cadastrais da sua conta, entre em contato pelo nosso canal formal:

**E-mail de contato:** `feedbackanalytics2026@gmail.com`

*Nota aos clientes finais que responderam a um formulário:* como os feedbacks pertencem à empresa avaliada (controladora), você pode direcionar seu pedido de acesso ou exclusão diretamente ao estabelecimento comercial correspondente ou entrar em contato conosco pelo e-mail acima para auxiliarmos no encaminhamento.

Você também tem o direito de peticionar perante a **Autoridade Nacional de Proteção de Dados (ANPD)** caso entenda que seus dados foram tratados de forma irregular.

---

## 9. Segurança da informação

Adotamos salvaguardas técnicas e organizacionais compatíveis com as melhores práticas de mercado:
* Criptografia em trânsito via HTTPS (TLS) em todas as comunicações;
* Senhas armazenadas exclusivamente sob funções de hash seguras e com salt;
* Chaves de API de terceiros cifradas em repouso com algoritmo AES-256-GCM;
* Banco de dados operando com perfil de menor privilégio (`feedback_app`) e políticas de isolamento multi-tenant aplicadas pelo gateway;
* Plano de resposta e contenção rápida a incidentes de segurança, garantindo comunicação à ANPD e aos titulares no prazo legal de **3 dias úteis** em caso de risco ou dano relevante.

---

## 10. Atualizações desta política

Esta Política de Privacidade pode ser revisada periodicamente para refletir melhorias do sistema, novas funcionalidades ou adequações regulatórias. Quando houver alterações, a data da última revisão no topo deste documento será atualizada. Alterações materiais serão informadas previamente através do painel ou por e-mail aos gestores cadastrados.
