# Requisitos e Funcionalidades

> Documento que descreve as funcionalidades do produto, regras de negócio, requisitos funcionais (RF), requisitos não funcionais (RNF), critérios de aceitação, rastreabilidade e detalhamento de prioridades/status.

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

- Cadastro de conta corporativa (CPF/CNPJ).
- Login seguro.
- Logout.
- Callback/Sucesso de autenticação por e-mail (validação do link, troca de código por sessão, redirecionamento).
- **Recuperação de senha (Esqueci minha senha)** com envio de e-mail e link seguro.
- **Reenvio de e-mail de confirmação** caso o usuário não tenha recebido.
- Proteção de rotas privadas por autenticação.

### Área do Usuário Gestor (Dashboard)

- **Apresentação do Produto (Landing Page Pública):** Página inicial destacando as funcionalidades da plataforma e versão do sistema gerada por CI/CD.
- **Dashboard Principal:**
  - Estatísticas gerais consolidadas de feedbacks.
  - Listagem rápida dos últimos feedbacks.
- **Perfil do Usuário:**
  - Atualiza nome e metadados.
  - Atualiza e-mail (com fluxo de confirmação e validação).
- **Gestão Institucional da Empresa:**
  - Visualizar dados corporativos cadastrados.
  - Atualizar dados corporativos.
- **Coleta de Dados de Contexto (Motor de Negócio IA):**
  - Consultar dados de coleta e contexto de negócio.
  - Atualizar parcialmente (PATCH).
  - Inserir/atualizar de forma completa (PUT/upsert).
- **Gerenciamento de QR Code de Coleta:**
  - Alternar status do QR (Ativo/Inativo) com bloqueio instantâneo.
  - Gerar QR code mestre da empresa e específicos (produtos, serviços, departamentos).
  - Configurar perguntas e subperguntas dinâmicas por item.
  - **Exportação e Compartilhamento Nativo:** Download do QR Code em imagem (`.png`) e integração com API nativa de compartilhamento (`navigator.share`) do dispositivo para distribuição instantânea do link.

### Gestão e Análise de Feedbacks

- Listagem paginada do histórico completo.
- Filtros avançados (por nota, por busca textual).
- Visualização detalhada (modal/página) de cada feedback.
- Estatísticas quantitativas (média, distribuição percentual de notas).
- Analytics de feedbacks (separação entre positivos e negativos, visão geral).
- **Insights Avançados com IA (IA Studio):**
  - Botão para disparar processamento com Inteligência Artificial.
  - Relatório global automatizado (resumo situacional + recomendações).
  - Análise de carga emocional/sentimento do texto.
  - Estatísticas da Análise (total analisado, distribuição de emoções, *Top Categories* e *Top Keywords* extraídas).
  - **Filtro Semântico Anti-Poluição:** O motor de IA remove automaticamente as palavras presentes nas perguntas originais para evitar que elas "sujem" as categorias identificadas.

### Interface de Coleta (Público Final)

- Validação sistêmica da empresa pelo ID do QR antes de liberar o formulário.
- Envio de respostas a perguntas e subperguntas dinâmicas (notas de 1-5).
- Atribuição de nota global da experiência (1-5).
- Campo de mensagem de texto livre.
- Captura de dados do cliente de forma opcional (nome, e-mail, gênero).
- **Proteção anti-duplicidade (anti-spam)** por dispositivo/dia usando *fingerprint*.

---

## Regras de Negócio (RNE)

| ID | Descrição | Requisitos Relacionados | Detalhamento |
|---|---|---|---|
| **RNE-001** | Isolamento de Dados por Empresa (Multi-tenancy) | RF08, RF09, RNF02 | Uma conta empresarial só pode acessar dados (Feedbacks, Dashboards, QR Codes) atrelados ao seu próprio `enterprise_id`. O banco de dados aplica RLS (Row Level Security) para garantir esse bloqueio intransponível. |
| **RNE-002** | Obrigatoriedade de Validação da Empresa para Coleta | RF06, RNF08 | O formulário público não pode ser renderizado nem aceitar envios caso o QR Code acesse um identificador de empresa desativado ou inexistente. |
| **RNE-003** | Classificação de Sentimento via IA | RF12, RF13, RNF05, RNF10 | Todo feedback submetido para análise deve obrigatoriamente ser categorizado como 'Positivo', 'Neutro' ou 'Negativo' pelo motor de Inteligência Artificial. |
| **RNE-004** | Janela de Resfriamento de Submissões (Anti-Spam) | RF07, RNF03 | Um cliente final (mesmo dispositivo/IP) só pode submeter 1 feedback por dia **por ponto de coleta** (`collection_point_id`). Isso previne spam, mas permite que o cliente avalie áreas distintas da empresa (ex: Recepção e Pós-Venda) no mesmo dia. |
| **RNE-005** | Fallback de Análise (Resiliência Operacional) | RF20, RNF12 | Caso o provedor externo de IA falhe ou as regras de higienização invalidem 100% dos termos devolvidos pela IA, o sistema deve acionar mecanismos locais de extração (fallback) para não corromper o painel de análise com dados vazios ou alucinados. |
| **RNE-006** | Fidelidade Analítica de Dados | RF08, RNF08 | Os dados consolidados exibidos no Dashboard (Totalizadores, Médias, Distribuição) devem obrigatoriamente espelhar o estado transacional exato do banco de dados relacional no momento da requisição, não sendo permitido o uso de *cache* desatualizado que mascare a realidade operacional. |
| **RNE-007** | Validação Estrita de Documentos | RF01, RNF01 | O cadastro e a atualização do CNPJ/CPF não aceitam apenas a máscara (regex). O sistema implementa o cálculo matemático do Módulo 11 para impedir a inserção de documentos de teste ou inválidos na base de produção. |
| **RNE-008** | Validação Geográfica de Telefones | RF02, RNF01 | O sistema só aceita dados de contato estruturados no padrão brasileiro (+55), validando ativamente códigos de área (DDD) e regras de nono dígito (ex: proibindo sequências repetidas e exigindo prefixo válido). |
| **RNE-009** | Restrição Lógica de Hierarquia do Catálogo | RF05, RF06 | Um formulário de feedback atrelado a um serviço/produto específico só fica online se o QR Code **e** o produto do catálogo estiverem `ACTIVE`. Se a empresa desativar o produto no catálogo, o QR Code bloqueia envios automaticamente. |
| **RNE-010** | Preenchimento Automático do Catálogo (Onboarding) | RF04, RNF06 | Imediatamente após o cadastro (via *Trigger* no banco de dados), o sistema cria automaticamente 3 perguntas institucionais base (Atendimento, Qualidade e Custo-Benefício) para evitar que o cliente fique diante de um dashboard vazio. |
| **RNE-011** | Higienização de Metadados de Autenticação | RF01, RNF01, RNF02 | O banco de dados intercepta a criação de contas e *apaga* proativamente os dados sensíveis (Documento, Telefone, Termos) do payload JSON do provedor de Auth, transferindo-os unicamente para a tabela `enterprise` com RLS, prevenindo vazamentos de dados (LGPD) no token JWT. |
| **RNE-012** | Proteção contra Mutação Destrutiva (Storage) | RNF08, RNF09 | Para garantir rastreabilidade histórica, os arquivos de logotipo e mídias salvos em Storage não podem ser deletados (apenas substituídos ou mantidos). Um gatilho (*Trigger*) de `protect_delete` bloqueia a exclusão de *buckets* inteiros. |
| **RNE-013** | Inicialização do Trial no Cadastro | RF01, RF21 | O trigger `on_auth_user_created` deve inicializar `trial_ends_at = NOW() + 4 meses` e `subscription_status = 'TRIAL'` automaticamente ao criar a empresa, garantindo que toda nova conta inicie com período de teste completo sem intervenção manual. |
| **RNE-014** | Proteção contra Enumeração de Usuários (Higienização de Respostas) | RF01, RF16, RNF01 | Nos fluxos de login, cadastro e recuperação de senha, as respostas relativas ao **e-mail** devem ser genéricas e indistinguíveis. O login responde a e-mail inexistente, senha incorreta e conta não confirmada com a **mesma** mensagem (`invalid_credentials`); o cadastro com e-mail já existente segue para a tela de sucesso (`confirmation_required`) sem revelar duplicidade; a recuperação sempre exibe a mesma mensagem genérica. Impede que atacantes descubram, por varredura automatizada, quais e-mails possuem cadastro ativo. |

---

## Requisitos Funcionais (RF)

| Código | Requisito | Descrição |
|---|---|---|
| **RF01** | Autenticação de Usuário | O sistema deve permitir cadastro (CPF/CNPJ), login e logout, com sessões seguras e validação via callback. |
| **RF02** | Gestão de Perfil | O usuário gestor deve poder atualizar nome/metadados e e‑mail/telefone (com confirmação). |
| **RF03** | Gestão de Empresa | O sistema deve permitir visualizar e atualizar os dados cadastrais da empresa. |
| **RF04** | Coleta de Dados de Contexto | Consultar, atualizar (PATCH) e inserir (PUT) dados de contexto utilizados pela IA. |
| **RF05** | Gestão de QR Codes | Gerar códigos para empresa, produtos/serviços e customizar perguntas dinâmicas por item, além de habilitar/desabilitar pontos de coleta. |
| **RF06** | Submissão de Feedback | Formulário público acessível via QR Code (nota + mensagem) com validação prévia de existência da empresa. |
| **RF07** | Proteção Anti-Spam | Impedir mais de 1 envio por dispositivo por dia (*fingerprint*), retornando HTTP 409 em duplicidade. |
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
| **RF20** | Filtro Semântico Anti-Poluição (IA) | O motor de IA deve isolar e remover do texto analisado as palavras contidas nas perguntas originais, evitando que os próprios enunciados do formulário poluam a nuvem de palavras-chave. |
| **RF21** | Exibição do Status de Assinatura | O dashboard deve exibir um badge dinâmico refletindo o `subscription_status` da empresa: âmbar com dias restantes (TRIAL), verde (ACTIVE), vermelho (EXPIRED) ou cinza (CANCELED). |

---

## Requisitos Não Funcionais (RNF)

| Código | Categoria | Requisito |
|---|---|---|
| **RNF01** | Segurança | API autenticada via JWT; validação rigorosa de entradas de dados (schemas Zod) no backend. |
| **RNF02** | Segurança Multi-Tenant | Banco com isolamento lógico via *Row Level Security* (RLS) baseado em `enterprise_id`; tenant validado por requisição. |
| **RNF03** | Integridade / Anti-Spam | Rastreio de *devices* (fingerprint) garantindo máximo de 1 envio diário, barrando ataques em massa. |
| **RNF04** | Performance | Tempos de resposta: Dashboard \< 2,5s; APIs críticas \< 400ms; registro de feedback público \< 5s. |
| **RNF05** | Performance de IA | O processamento assíncrono do motor de IA deve salvar resultados em até 10s após disparo pelo gestor. |
| **RNF06** | Usabilidade (UX) | Interface *mobile-first* responsiva, focando em simplicidade extrema no formulário de coleta (público). |
| **RNF07** | Escalabilidade | Arquitetura Cloud/Serverless (BFF Node.js + Supabase) com provisionamento automático sob demanda. |
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
| Trial e Status de Assinatura | RF21 | RNF08 | RNE-013 |
| Recuperação e Reenvio de E-mail | RF16, RF17 | RNF01 | RNE-014 |
| Gestão de Perfil | RF02 | RNF01, RNF08 | - |
| Gestão de Empresa | RF03 | RNF01, RNF08 | - |
| Coleta de Dados de Contexto | RF04 | RNF01 | - |
| QR Code (Geração e Exportação) | RF05, RF19 | RNF07 | RNE-002 |
| Submissão de Feedback Público | RF06 | RNF04, RNF06 | RNE-002 |
| Proteção Anti-Spam (Duplicidade) | RF07 | RNF03 | RNE-004 |
| Dashboard Principal | RF08 | RNF04, RNF08 | RNE-001, RNE-006 |
| Listagem, Filtros e Detalhamento | RF09 | RNF04 | RNE-001 |
| Estatísticas Globais | RF10 | RNF04, RNF08 | RNE-006 |
| Analytics Base | RF11 | RNF04 | - |
| Motor de IA e Regras Anti-Poluição | RF12, RF20 | RNF05, RNF10, RNF12 | RNE-003, RNE-005 |
| Estatísticas de Classificação da IA | RF13 | RNF05, RNF10 | RNE-003 |
| Histórico de Clientes | RF14 | RNF01, RNF02 | RNE-001 |
| Rotas Protegidas e API Gateway | RF15 | RNF01, RNF02, RNF09 | RNE-001 |
| Apresentação (Landing Page) | RF18 | RNF06, RNF13 | - |
| Monitoramento Sistêmico | - | RNF11 | - |

---

## Critérios de Aceitação (Principais)

- **Acesso:** Rotas administrativas (Dashboard, Perfil) redirecionam automaticamente para login caso a sessão JWT seja inexistente ou inválida (RF15).
- **Autenticação:** E-mail de confirmação ou recuperação de senha deve ser enviado pelo provedor em até 30 segundos (RF01, RF16, RF17).
- **Gestão do QR Code e Compartilhamento:**
  - Desabilitar o QR Code corporativo deve tornar o formulário inacessível imediatamente, exibindo mensagem (RF05).
  - O sistema deve gerar um Blob de imagem (`.png`) baixável com o nome da empresa e invocar a `Share API` do sistema operacional quando disponível (RF19).
- **Integridade da Coleta:**
  - Caso o usuário tente acessar um formulário alterando o ID do QR Code para uma empresa inexistente, exibir tela de erro fatal, impedindo acesso (RF06).
  - O feedback preenchido e válido deve persistir no Supabase e gerar resposta HTTP 201 Created em menos de 5 segundos (RF06, RNF04).
- **Segurança (Spam):** Ao enviar o 2º feedback pelo mesmo navegador/dispositivo no mesmo dia, a API Gateway deve abortar com HTTP 409 Conflict (RF07).
- **Inteligência Artificial de Alta Precisão:**
  - O motor assíncrono `ia-analyze` deve obrigatoriamente remover do payload as palavras que compõem a "pergunta base" para garantir nuvem de palavras reais do cliente (RF20).
  - Em caso de queda da API do provedor LLM externo ou falha na formatação JSON, o algoritmo de *Fallback Local* deve garantir que o feedback seja processado e que keywords essenciais sejam extraídas com base em *stopwords* (RNF12).
- **Integração Contínua:** A versão da interface exibida no rodapé (Landing Page) deve refletir de forma automatizada a tag de *release* real extraída do histórico Git no momento do *build* (RNF13).

---

## Detalhamento dos Requisitos Funcionais (por ID)

| ID | Descrição | Status | Prioridade |
|---|---|---|---|
| **RF-001** | Autenticação de Usuário: cadastro, login, logout, callback de e-mail e gestão de sessões via Supabase. | Implementado | Alta |
| **RF-002** | Gestão de Perfil: atualizar nome/metadados e e‑mail (exigindo nova validação do provedor). | Implementado | Alta |
| **RF-003** | Gestão de Empresa: CRUD de dados da organização para apresentação ao cliente. | Implementado | Alta |
| **RF-004** | Coleta de Dados de Contexto: injeção de regras de negócio da empresa para refino dos prompts da IA. | Implementado | Alta |
| **RF-005** | Geração e Gestão de QR Codes: criação rastreável por departamento/serviço e customização de subperguntas. | Implementado | Alta |
| **RF-006** | Submissão de Feedback: formulário web móvel público com conferência da saúde do Tenant (empresa). | Implementado | Alta |
| **RF-007** | Proteção Anti-Spam: fingerprint baseado em sessão local + bloqueio em API para coibir automação robótica. | Implementado | Alta |
| **RF-008** | Dashboard: tela de entrada com métricas absolutas e extrato dos feedbacks recentes. | Implementado | Alta |
| **RF-009** | Listagem e Filtros: listagem densa, paginada com parâmetros de busca livres (Query Strings). | Implementado | Média |
| **RF-010** | Estatísticas de Feedbacks: consolidação matemática de médias, volume e análise humana. | Implementado | Média |
| **RF-011** | Analytics de Feedbacks: desmembramento das métricas entre espectros emocionais (Positivo/Negativo). | Implementado | Média |
| **RF-012** | Insights/IA sob demanda: orquestração de chamadas ao provedor LLM externo configurável para extração profunda de inteligência. | Implementado | Média |
| **RF-013** | Estatísticas da IA: espelhamento em tela do resultado de categorizações criadas proceduralmente pela IA. | Implementado | Média |
| **RF-014** | Gestão de Clientes: base estruturada do comportamento e frequência de um mesmo comprador. | A implementar | Média |
| **RF-015** | Proteção de Rotas: blindagem sistêmica com middlewares e RLS garantindo soberania do acesso. | Implementado | Alta |
| **RF-016** | Recuperação de Acesso: Fluxo completo de "Esqueci minha senha" com token criptografado para redefinição segura. | Implementado | Alta |
| **RF-017** | Reenvio de Confirmação: Endpoint para reenviar o e-mail de ativação caso o original tenha expirado/falhado. | Implementado | Média |
| **RF-018** | Apresentação do Produto: Interface pública institucional (Landing Page) para atração de novos usuários. | Implementado | Baixa |
| **RF-019** | Exportação e Compartilhamento: Extração do QR Code em imagem local e integração com APIs de compartilhamento mobile-first. | Implementado | Média |
| **RF-020** | Filtro Semântico Anti-Poluição (IA): Lógica de exclusão de termos (perguntas matrizes) para preservação da integridade da análise de sentimento livre. | Implementado | Alta |
| **RF-021** | Exibição do Status de Assinatura: Badge dinâmico no dashboard refletindo o ciclo de vida da conta (`subscription_status` + dias restantes de trial calculados no cliente). | Implementado | Média |

---

## Detalhamento dos Requisitos Não Funcionais (por ID)

| ID | Descrição | Status | Prioridade |
|---|---|---|---|
| **RNF-001** | Segurança: API autenticada via JWT, com validação de dados em runtime utilizando Zod para impedir payloads maliciosos. | Implementado | Alta |
| **RNF-002** | Segurança Multi-Tenant: Isolamento arquitetural de registros entre empresas utilizando a camada de proteção RLS do PostgreSQL. | Implementado | Alta |
| **RNF-003** | Integridade / Anti-Spam: Geração de *fingerprints* diários bloqueando varreduras de robôs ou envio abusivo de clientes (HTTP 409). | Implementado | Alta |
| **RNF-004** | Performance: Respostas da API em menos de 400ms, gravação de feedback \< 5s, e interface visualizando o Dashboard em no máximo 2,5s. | Implementado | Alta |
| **RNF-005** | Performance de IA: O processamento textual pela IA não deve atrasar a interface do cliente final. Toda a extração ocorre assincronamente em até 10s. | Implementado | Alta |
| **RNF-006** | Usabilidade (UX): Responsividade garantida (*mobile-first*) no fluxo público para melhorar conversões de feedback do usuário na ponta. | Implementado | Alta |
| **RNF-007** | Escalabilidade: Topologia em Nuvem usando infraestrutura Serverless (Vercel) integrando Node.js e banco dinâmico da Supabase. | Implementado | Alta |
| **RNF-008** | Confiabilidade: Restrições de chaves estrangeiras, `ON DELETE RESTRICT` e uso de sub-consultas validadas impedem exclusões acidentais que quebrem os dados e dashboards. | Implementado | Alta |
| **RNF-009** | Manutenibilidade: serviços em repositórios independentes com um pacote de contratos versionado (`@feedback/lib-shared`) para reuso de interfaces/tipagens globais entre Backend e Frontend usando TypeScript rigoroso. | Implementado | Alta |
| **RNF-010** | Acurácia de IA: A precisão das categorias semânticas geradas (positivas/negativas) e a correlação cruzada de dados deve manter-se em 80% frente ao julgamento humano. | Em testes (Refinamento) | Alta |
| **RNF-011** | Monitoramento da API: Provisionamento de rota leve de *Health Check* sem acesso ao banco para varreduras de UpTime por sistemas de monitoramento (DataDog, UptimeRobot, etc). | Implementado | Média |
| **RNF-012** | Resiliência de IA (Fallback): Contingência lógica dentro da camada de inteligência com uso de filtros de *stopwords* base garantindo keywords em cenários de timeout/alucinações da API remota. | Implementado | Alta |
| **RNF-013** | Rastreabilidade de Versão (CI/CD): Leitura em tempo de *Build* da tag Git local que amarra visualmente a interface da web com o snapshot técnico do código-fonte implantado no momento. | Implementado | Média |
