# Banco de Dados — Visão Geral e Arquitetura

> Documentação técnica do schema PostgreSQL hospedado no Supabase. Cobre todas as tabelas, relacionamentos, políticas de segurança (RLS), funções, triggers e índices do sistema.
>
> **Fonte da verdade:** o schema vive no repositório do gateway, em [`drizzle/schema/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle/schema), e muda só por migration ([`drizzle/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle), hoje de `0000` a `0013`). Esta página foi conferida contra essas migrations em 03/11/2026; na dúvida, vale o código. Os dumps SQL de `database/sql/` deste repositório são **legado**.

---

## Sumário

1. [Visão Geral](#visão-geral)
2. [Tecnologia e Infraestrutura](#tecnologia-e-infraestrutura)
3. [Diagrama de Entidades (ERD)](#diagrama-de-entidades-erd)
4. [Domínios e Grupos de Tabelas](#domínios-e-grupos-de-tabelas)
5. [Referência de Tabelas](#referência-de-tabelas)
6. [Funções e Stored Procedures](#funções-e-stored-procedures)
7. [Triggers](#triggers)
8. [Segurança e RLS](#segurança-e-rls)
9. [Índices e Performance](#índices-e-performance)
10. [Regras de Integridade e Constraints](#regras-de-integridade-e-constraints)
11. [Storage](#storage)

---

## Visão Geral

O banco de dados é a camada de persistência central da plataforma. Ele garante a integridade (constraints, FKs em cascata e triggers de coerência) e o menor privilégio (o app entra com um papel que só lê e escreve dados). O **isolamento entre empresas** fica na **camada de aplicação** (API Gateway), que filtra toda query por `enterprise_id`. O controle **anti-spam** de feedback também é aplicado no Gateway: o banco guarda a estrutura de apoio (tabela `tracked_devices`), mas o cálculo do fingerprint e o limite diário são verificados lá.

**Princípios arquiteturais:**

- **Multi-tenancy na aplicação:** cada linha de dados de negócio está vinculada a um `enterprise_id`, e o Gateway sempre filtra por ele (`src/db/tenantScope.ts`). A RLS não filtra por empresa — ver [Segurança e RLS](#segurança-e-rls).
- **Menor privilégio:** o app usa o papel `feedback_app`, que não cria, altera nem apaga estrutura. A RLS ligada em todas as tabelas barra qualquer outro papel, como o `anon` e o `authenticated` do Supabase.
- **Integridade por cascata:** deleções propagam-se via `ON DELETE CASCADE` onde há FK; o que não tem FK em cascata o Gateway apaga ao excluir a conta.
- **Onboarding pela aplicação:** ao criar a conta, o Gateway (gancho do Better Auth) cria a empresa e semeia as 3 perguntas institucionais padrão. Não há trigger de cadastro no banco.

---

## Tecnologia e Infraestrutura

| Item | Detalhe |
|---|---|
| **Banco** | PostgreSQL (hospedado no Supabase, acessado direto via `DATABASE_URL` + Drizzle; não usamos o Supabase Auth nem a Data API) |
| **Conexão do app** | Pooler do Supabase em modo transação (porta 6543), com `prepare: false` e pool `max: 3`, como o papel `feedback_app` |
| **Migrations** | `drizzle-kit migrate`, rodado pelo workflow de deploy do gateway com o papel `postgres` |
| **Autenticação** | **Better Auth** (tabelas `user`/`session`/`account`/`verification` no próprio Postgres) — sessão em cookie httpOnly, validada no api-gateway |
| **Segurança** | Row Level Security (RLS) habilitado em todas as 24 tabelas, com a policy `feedback_app_all` |
| **Schema do projeto** | `public` (o drizzle-kit atua só nele: `schemaFilter: ['public']`) |
| **Recursos do Postgres usados** | `gen_random_uuid()`, `pg_advisory_xact_lock()`, `md5()`, índices parciais e por expressão, `FOR UPDATE SKIP LOCKED` |

---

## Diagrama de Entidades (ERD)

O diagrama de entidades (crow's-foot, com as relações que têm FK e as que são só lógicas) fica na [Modelagem de Dados (DER)](../../arquitetura/modelagem-de-dados.md); a visão conceitual, no [Modelo Conceitual (MER)](../../arquitetura/modelo-conceitual-mer.md).

> Os dados de negócio carregam `enterprise_id`. Chegam à empresa pela tabela pai: `feedback_question_subquestions`, `feedback_question_answers`, `feedback_subquestion_answers` e `feedback_analysis`. São por usuário ou por chave: `user`, `session`, `account`, `verification`, `user_onboarding`, `auth_rate_limit` e `ia_rate_budget`.

---

## Domínios e Grupos de Tabelas

| Domínio | Tabelas | Responsabilidade |
|---|---|---|
| **Identidade** | `user`, `session`, `account`, `verification`, `enterprise`, `user_onboarding`, `auth_rate_limit` | Autenticação (Better Auth), sessões, raiz de autorização multi-tenant, guia do sistema e limite de reenvio de e-mail |
| **Contexto Analítico** | `collecting_data_enterprise` | Dados estratégicos injetados nos prompts de IA |
| **Catálogo** | `catalog_items`, `collection_points` | Produtos/Serviços/Departamentos e pontos de coleta (QR Code, link e NFC) |
| **Formulário** | `questions_of_feedbacks`, `feedback_question_subquestions`, `feedback_comment_field` | Perguntas dinâmicas e campo de comentário do formulário público |
| **Coleta** | `feedback`, `feedback_question_answers`, `feedback_subquestion_answers` | Dados brutos dos clientes finais |
| **Anti-spam** | `tracked_devices`, `customer` | Rastreio de dispositivos e identificação opcional de clientes |
| **Inteligência Artificial** | `feedback_analysis`, `feedback_insights_report`, `scope_diagnosis` | Resultados, relatórios e diagnósticos do motor de IA |
| **Fila e configuração de IA** | `ia_analysis_job`, `ia_rate_budget`, `enterprise_ia_config` | Fila assíncrona, controle de ritmo e chave de IA por empresa |

---

## Referência de Tabelas

> A coluna **Impacto no Projeto** indica qual parte do sistema consome cada campo e o que é afetado se ele for alterado ou removido.

### `public.user` (Better Auth)

> Tabela central de usuários do Better Auth no schema `public`.

| Coluna | Tipo | Descrição | Impacto no Projeto |
|---|---|---|---|
| `id` | uuid PK | Identificador único do usuário | **Crítico** — raiz de autenticação; referenciado como FK por `enterprise.auth_user_id`, `session`, `account` e `user_onboarding` |
| `name` | text | Nome do gestor / empresa | **Crítico** — exibido no painel e na view `enterprise_public`, que dá o nome da empresa no formulário de feedback |
| `email` | text (unique) | E-mail de login do gestor | **Crítico** — credencial de acesso e canal de envio de e-mails transacionais |
| `email_verified` | boolean | E-mail confirmado | **Alto** — `true` após validação do link de confirmação enviado no cadastro |
| `phone` | text (unique) | Telefone de contato | **Alto** — contato exibido e gerenciado no perfil |
| `image` | text | Imagem/Avatar do perfil | **Baixo** — opcional |
| `created_at` | timestamptz | Data de criação | **Baixo** — auditoria |
| `updated_at` | timestamptz | Última atualização | **Baixo** — auditoria |

> **Tabelas auxiliares do Better Auth:**
> - `public.session`: Gerencia sessões ativas (`user_id`, `token` único, `expires_at`, `ip_address`, `user_agent`).
> - `public.account`: Guarda os provedores de entrada (senha, Google), os tokens do provedor e o hash da senha (`user_id`, `account_id`, `provider_id`, `password`).
> - `public.verification`: Armazena tokens temporários de verificação e recuperação de senha (`identifier`, `value`, `expires_at`).
>
> `session` e `account` têm FK para `user` com `ON DELETE CASCADE`; `verification` não tem FK.

---

### `public.user_onboarding`

> Estado do guia do sistema (tour da Web) por usuário. Chave primária composta `(user_id, tour_key, version)`.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `user_id` | uuid FK | Sim | → `user.id` ON DELETE CASCADE | **Alto** — o tour é por pessoa, não por empresa |
| `tour_key` | text | Sim | Qual tour (hoje, `system-guide`) | **Médio** — permite mais de um tour no futuro |
| `version` | integer | Sim | Versão do tour (CHECK `> 0`) | **Médio** — subir a versão faz o tour aparecer de novo para todos |
| `status` | text | Sim | `completed` \| `skipped` (CHECK) | **Médio** — define se a Web mostra o tour ao entrar |
| `finished_at` | timestamptz | Sim (default `now()`) | Quando terminou ou pulou | **Baixo** — auditoria |

---

### `public.auth_rate_limit`

> Contador durável do limite de reenvio do e-mail de confirmação (`src/libs/resendRateLimit.ts`), compartilhado entre as instâncias serverless.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `key` | text PK | Sim | `ip:`, `email:` ou `cooldown:` seguido do HMAC do IP ou do e-mail | **Alto** — nunca guarda o IP ou o e-mail em claro |
| `used` | integer | Sim | Tentativas na janela | **Alto** — passou do limite, o reenvio é recusado |
| `expires_at` | timestamptz | Sim | Fim da janela | **Médio** — janela vencida recomeça a contagem; índice `auth_rate_limit_expiry_idx` |

---

### `enterprise_public` (objeto público)

> **VIEW** criada no baseline (`drizzle/0000_great_talisman.sql`) que expõe apenas `id` e `name` da empresa. É o caminho que resolve o **nome** da empresa exibido no formulário público (`publicEnterprise.repository.ts`) e no contexto da empresa enviado à IA (`iaAnalyze.repository.ts`).

| Coluna | Tipo | Descrição | Impacto no Projeto |
|---|---|---|---|
| `id` | uuid | Identificador da empresa (= `enterprise.id`) | **Crítico** — usado pelo formulário público para validar a empresa e carregar perguntas |
| `name` | text | Nome público da empresa | **Crítico** — exibido no formulário de coleta; **derivado de `public.user.name`** via JOIN com `enterprise.auth_user_id` |

> **Definição** (`drizzle/schema/views.ts`):
> ```sql
> CREATE VIEW "public"."enterprise_public" AS
> SELECT e.id, pu.name AS name
> FROM enterprise e
> LEFT JOIN "user" pu ON pu.id = e.auth_user_id;
> ```
> O Gateway a lê com o papel `feedback_app` (que tem `SELECT` em todas as tabelas e views do schema `public`).

---

### `public.enterprise`

> Cadastro da empresa vinculada ao usuário autenticado. **Entidade raiz de todo o isolamento multi-tenant.**
>
> **Atenção:** esta tabela **não tem coluna `name`**. O "nome" da empresa exibido publicamente (ex.: no formulário de coleta) **não** vem diretamente desta tabela — vem da coluna `name` da tabela `public.user` (cadastrada no Better Auth), exposto publicamente via a relação [`enterprise_public`](#enterprise_public-objeto-público).

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | Identificador único | **Crítico** — referenciado como `enterprise_id` nas tabelas de negócio; âncora do isolamento multi-tenant na aplicação |
| `auth_user_id` | uuid | Sim | FK para `public.user.id` (único, `ON DELETE CASCADE`) | **Crítico** — vincula a empresa ao usuário autenticado no Better Auth; o `requireAuth` resolve a empresa da sessão por ele |
| `terms_version` | text | Não | Versão dos termos aceitos | **Médio** — registra qual versão dos termos foi aceita; usado para auditoria legal e conformidade |
| `terms_accepted_at` | timestamptz | Não | Data de aceite dos termos | **Médio** — auditoria legal; exibido na tela de perfil |
| `trial_ends_at` | timestamptz | Não | Data de expiração do período de teste | **Alto** — inicializada no signup com `NOW() + 4 months`; usada no frontend para exibir dias restantes do trial e status da conta |
| `subscription_status` | text | Não (default `TRIAL`) | Status da assinatura: `TRIAL` \| `ACTIVE` \| `EXPIRED` \| `CANCELED` | **Alto** — controla o badge de status exibido na UI; gerado no signup como `TRIAL`; futuramente atualizado pelo sistema de cobrança |
| `created_at` | timestamptz | Auto | — | **Baixo** — auditoria interna |
| `updated_at` | timestamptz | Auto | Atualizado por trigger | **Baixo** — auditoria interna |

**Restrições:** `auth_user_id` único (`enterprise_auth_user_id_key`); `subscription_status` restrito ao enum `{TRIAL, ACTIVE, EXPIRED, CANCELED}`.

> **Sem CPF/CNPJ:** as colunas `document` e `account_type` (e as funções `document_exists`, `enterprise_public_documents_fn` e `enterprise_public_ids_fn`, que as liam) saíram na migration `0009`. O sistema não usa esse dado e não o guarda (LGPD).

---

### `public.collecting_data_enterprise`

> Dados estratégicos da empresa usados para contextualizar os prompts enviados à IA. No máximo um registro por empresa, criado quando ela preenche o contexto.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna do registro |
| `enterprise_id` | uuid | Sim | Empresa dona (único; **sem FK** nas migrations) | **Crítico** — isolamento multi-tenant na aplicação; o Gateway apaga a linha ao excluir a conta |
| `company_objective` | text | Não | Objetivo macro do negócio | **Alto** — injetado diretamente no prompt da IA; sem preenchimento, a análise fica genérica e sem contexto |
| `analytics_goal` | text | Não | Meta de análise de feedbacks | **Alto** — idem; orienta o que a IA deve destacar na análise |
| `business_summary` | text | Não | Resumo livre do negócio | **Alto** — idem; contextualiza o tipo de empresa para a IA |
| `main_products_or_services` | text[] | Não | Lista dos principais produtos/serviços | **Alto** — compõe o contexto enviado à IA junto com os dados do catálogo |
| `uses_company_products` | boolean | Sim | Habilita uso de produtos no formulário | **Crítico** — controla se o tipo `PRODUCT` aparece no catálogo e no formulário público |
| `uses_company_services` | boolean | Sim | Habilita uso de serviços no formulário | **Crítico** — controla se o tipo `SERVICE` aparece no catálogo e no formulário público |
| `uses_company_departments` | boolean | Sim | Habilita uso de departamentos no formulário | **Crítico** — controla se o tipo `DEPARTMENT` aparece no catálogo e no formulário público |

> Os três campos de contexto (objetivo, meta e resumo) mais a IA configurada disparam a geração automática das perguntas da empresa (job `generate_company_questions`).

---

### `public.catalog_items`

> Catálogo de itens da empresa (produtos, serviços, departamentos) — base para segmentação de QR Codes e feedback.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — referenciado por `collection_points`, `questions_of_feedbacks`, `feedback_comment_field`, `feedback_insights_report`, `scope_diagnosis` e `ia_analysis_job` |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — isolamento multi-tenant |
| `kind` | text | Sim | `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Crítico** — determina em qual aba/seção o item aparece no frontend; filtrado pelos flags `uses_company_*` de `collecting_data_enterprise` |
| `name` | text | Sim | Nome exibido no formulário e dashboard | **Alto** — exibido no formulário público, na tela de catálogo e nos relatórios de insights |
| `description` | text | Não | Descrição opcional | **Baixo** — informativo; não impacta fluxos funcionais |
| `status` | text | Sim | `ACTIVE` (default) \| `INACTIVE` | **Médio** — estado do item no catálogo; o formulário público confere o status do ponto de coleta do item, não o do item |
| `sort_order` | integer | Sim | Ordenação exibição (default 0) | **Médio** — controla a ordem de listagem no frontend; sem ele os itens aparecem em ordem indefinida |

**Índices:** `(enterprise_id, kind)`, `(status)`

---

### `public.collection_points`

> Pontos de coleta de feedback. O mesmo ponto atende o QR Code, o link compartilhado e a etiqueta NFC; o canal de cada resposta fica em `feedback.channel`.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — compõe a URL do formulário público e é gravado em `feedback.collection_point_id` |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `catalog_item_id` | uuid FK | Não | → `catalog_items.id` ON DELETE SET NULL — `null` = ponto corporativo | **Alto** — determina o escopo do formulário e quais perguntas dinâmicas são exibidas |
| `name` | text | Sim | Nome do ponto de coleta | **Médio** — exibido na tela de gerenciamento de QR Codes do dashboard |
| `type` | text | Sim | `QR_CODE` (único tipo gravado; sem CHECK no banco) | **Crítico** — o Gateway só aceita envio por ponto `QR_CODE` |
| `identifier` | text | Não | Identificador opcional | **Baixo** — lido na listagem de feedbacks e no contexto enviado à IA |
| `status` | text | Sim | `ACTIVE` (default) \| `INACTIVE` (sem CHECK no banco) | **Crítico** — sem ponto `ACTIVE` para o escopo, o envio responde `collection_point_not_found` |

**Regra de negócio:** o formulário público só aceita resposta se existe um ponto `QR_CODE` `ACTIVE` para o escopo (verificado no Gateway, em `resolveQrCollectionPoint`).

---

### `public.questions_of_feedbacks`

> Perguntas dinâmicas exibidas no formulário público. Cada empresa tem até 3 perguntas por escopo (empresa ou item de catálogo).

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — referenciado por `feedback_question_answers` e `feedback_question_subquestions` |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `scope_type` | text | Sim | `COMPANY` \| `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Crítico** — determina em qual contexto a pergunta é exibida; o formulário filtra por este campo + `catalog_item_id` para montar as perguntas corretas |
| `catalog_item_id` | uuid FK | Condicional | → `catalog_items.id` ON DELETE CASCADE — obrigatório quando `scope_type ≠ COMPANY` | **Crítico** — junto com `scope_type`, forma a chave de lookup das perguntas de um item específico |
| `question_order` | integer | Sim | Posição da pergunta: `1`, `2` ou `3` | **Alto** — define a sequência de exibição das perguntas no formulário |
| `question_text` | text | Sim | Texto da pergunta (20–150 caracteres) | **Crítico** — exibido no formulário público; capturado como snapshot em `question_text_snapshot` no momento do envio |
| `is_active` | boolean | Sim | Controla exibição no formulário (default `true`) | **Alto** — `false` oculta a pergunta do formulário sem deletá-la nem perder o histórico de respostas |

**Perguntas padrão** (semeadas pelo Gateway no signup, `src/config/`): três perguntas do escopo `COMPANY`. Com o contexto e a IA configurados, o job `generate_company_questions` as substitui por perguntas geradas pela IA, desde que a empresa ainda não as tenha editado.

**Constraints:** unicidade por `(enterprise_id, question_order)` para escopo `COMPANY`; por `(enterprise_id, scope_type, catalog_item_id, question_order)` para itens; o trigger `validate_questions_of_feedbacks_context` confere a coerência entre `scope_type` e `catalog_item_id`.

---

### `public.feedback_question_subquestions`

> Subperguntas opcionais vinculadas a cada pergunta principal — ativadas individualmente pelo gestor.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — referenciado por `feedback_subquestion_answers` |
| `question_id` | uuid FK | Sim | → `questions_of_feedbacks.id` ON DELETE CASCADE | **Crítico** — vincula a subpergunta à pergunta pai; cascade garante remoção automática |
| `subquestion_order` | integer | Sim | Posição: `1`, `2` ou `3` | **Médio** — define a ordem de exibição das subperguntas no formulário |
| `subquestion_text` | text | Sim | Texto da subpergunta (20–150 caracteres) | **Crítico** — exibido no formulário; capturado como snapshot em `subquestion_text_snapshot` no envio |
| `is_active` | boolean | Sim | `false` por padrão — ativação explícita pelo gestor | **Alto** — `false` oculta a subpergunta sem deletá-la; controle granular de quais subperguntas aparecem |

**Constraint:** `(question_id, subquestion_order)` único.

---

### `public.feedback_comment_field`

> Como o campo de comentário aparece no formulário de cada escopo (migration `0010`). Sem linha para o escopo = convite padrão.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `scope_type` | text | Sim | `COMPANY` \| `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Alto** — escopo da configuração |
| `catalog_item_id` | uuid FK | Condicional | → `catalog_items.id` ON DELETE CASCADE — nulo no escopo `COMPANY` | **Alto** — configuração própria de um item |
| `mode` | text | Sim | `DEFAULT` (default) \| `CUSTOM` \| `HIDDEN` | **Crítico** — `HIDDEN` esconde o campo e o Gateway descarta o texto; `CUSTOM` troca o convite pela pergunta própria |
| `prompt` | text | Condicional | A pergunta própria — obrigatória, com 10 a 150 caracteres, no modo `CUSTOM` | **Alto** — exibida no formulário e gravada em `feedback.comment_prompt` junto com o comentário |
| `created_at` / `updated_at` | timestamptz | Sim | — | **Baixo** — auditoria |

**Índices únicos:** `uq_comment_field_company` (uma linha `COMPANY` por empresa) e `uq_comment_field_item` (uma linha por item).

---

### `public.customer`

> Cadastro opcional do cliente final que se identificou ao enviar feedback.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Alto** — gravado em `tracked_devices.customer_id` para associar dispositivo ao cliente identificado |
| `enterprise_id` | uuid | Sim | Empresa dona (**sem FK** nas migrations) | **Crítico** — isolamento multi-tenant na aplicação; o Gateway apaga os clientes ao excluir a conta |
| `name` | text | Não | Nome informado pelo cliente | **Baixo** — exibido no painel de feedbacks do dashboard quando disponível; totalmente opcional |
| `email` | text | Não | E-mail informado | **Baixo** — exibido no painel de feedbacks; o Gateway deduplica o cliente por ele |
| `gender` | text | Não | Gênero informado | **Baixo** — informativo; não impacta nenhum fluxo do sistema |

---

### `public.tracked_devices`

> Dispositivos rastreados por fingerprint para aplicar a regra anti-spam (1 feedback/dia por ponto de coleta).

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Alto** — gravado opcionalmente em `feedback.tracked_device_id` |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — isolamento multi-tenant |
| `customer_id` | uuid | Não | Cliente associado quando ele se identifica (sem FK) | **Baixo** — enriquece o registro do dispositivo com dados do cliente; não impacta o fluxo anti-spam |
| `device_fingerprint` | text | Não | Hash MD5 diário `(user_agent \| ip \| dia)`, calculado no Gateway | **Crítico** — chave de busca do dispositivo no envio; sem ele não há controle de spam |
| `user_agent` | text | Não | User-Agent do navegador | **Médio** — um dos três componentes do fingerprint; armazenado para auditoria e identificação do dispositivo |
| `ip_address` | inet | Não | IP do cliente | **Médio** — um dos três componentes do fingerprint; armazenado para auditoria |
| `is_blocked` | boolean | Não | Bloqueio manual pelo gestor (default `false`) | **Crítico** — conferido pelo Gateway no envio; `true` recusa o feedback com `DEVICE_BLOCKED` |
| `blocked_reason` | text | Não | Motivo do bloqueio | **Baixo** — informativo para o gestor; sem impacto funcional |
| `blocked_at` | timestamptz | Não | Data do bloqueio | **Baixo** — auditoria do bloqueio |
| `blocked_by` | uuid | Não | ID do gestor que bloqueou (sem FK) | **Baixo** — rastreabilidade de quem aplicou o bloqueio |
| `feedback_count` | integer | Não | Contador total de feedbacks (default 0) | **Alto** — o Gateway cria o registro com `0` e soma 1 a cada envio; usado para métricas de volume e como sinal de comportamento suspeito |
| `last_feedback_at` | timestamptz | Não | Data/hora do último envio | **Médio** — atualizado a cada envio; o limite diário é conferido em `feedback` (mesmo dispositivo, mesmo ponto, desde o início do dia) |

---

### `public.feedback`

> Feedback bruto recebido do cliente via formulário público.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — referenciado por `feedback_question_answers`, `feedback_subquestion_answers` e `feedback_analysis` |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `collection_point_id` | uuid | Sim | Ponto de coleta de origem (**sem FK** nas migrations) | **Crítico** — identifica de onde veio o feedback; base para filtros por escopo no dashboard |
| `tracked_device_id` | uuid | Não | Dispositivo emissor (**sem FK** nas migrations) | **Alto** — vincula o feedback ao dispositivo; usado no limite diário e no bloqueio |
| `message` | text | Sim | Texto livre do cliente (texto vazio quando não há comentário) | **Crítico** — principal entrada do motor de IA; sem comentário, o feedback não vai para a IA nem conta como "aguardando análise" |
| `comment_prompt` | text | Não | Pergunta própria que o cliente viu no campo de comentário (nulo = convite padrão) | **Alto** — vai à IA junto com o comentário, que é lido como resposta a ela |
| `channel` | text | Não | `QR` \| `LINK` \| `NFC` \| `TEST` (CHECK); nulo = sem a marca de canal | **Alto** — métricas por canal; `TEST` ("Testar o formulário") fica fora das métricas |
| `rating` | integer | Não | Nota global da experiência (1–5) | **Crítico** — exibido nos cards de métricas do dashboard (média, positivos, críticos) e na listagem de feedbacks |

**Índice:** `idx_feedback_enterprise_created_at` `(enterprise_id, created_at DESC)` — toda leitura de métricas filtra por empresa e recorta por período.

**Validação do envio** (no Gateway, `qrcode.controller.ts`): empresa existente, ponto `QR_CODE` ativo para o escopo, dispositivo não bloqueado e no máximo um envio por dia por ponto de coleta.

---

### `public.feedback_question_answers`

> Respostas às perguntas dinâmicas para cada feedback enviado. Inclui snapshot do texto da pergunta para preservar histórico.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna do registro |
| `feedback_id` | uuid FK | Sim | → `feedback.id` ON DELETE CASCADE | **Crítico** — associação com o feedback pai; cascade garante limpeza automática |
| `question_id` | uuid FK | Sim | → `questions_of_feedbacks.id` ON DELETE CASCADE | **Crítico** — associação com a pergunta respondida |
| `question_text_snapshot` | text | Sim | Texto da pergunta no momento do envio (imutável) | **Alto** — preserva o contexto histórico; enviado ao serviço de IA junto com o `message` e o `answer_value` |
| `answer_value` | text | Sim | `PESSIMO` \| `RUIM` \| `MEDIANA` \| `BOA` \| `OTIMA` | **Crítico** — valor categórico exibido na listagem de feedbacks e lido pela IA para análise de sentimento por pergunta |
| `answer_score` | integer | Sim | Valor numérico correspondente (1–5) | **Crítico** — usado para cálculo de médias por pergunta nos componentes analíticos do dashboard |

**Constraint:** `(feedback_id, question_id)` único — 1 resposta por pergunta por feedback.

---

### `public.feedback_subquestion_answers`

> Respostas às subperguntas para cada feedback. Mesma lógica de snapshot das respostas principais.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna do registro |
| `feedback_id` | uuid FK | Sim | → `feedback.id` ON DELETE CASCADE | **Crítico** — associação com o feedback pai; cascade garante limpeza automática |
| `subquestion_id` | uuid FK | Sim | → `feedback_question_subquestions.id` ON DELETE CASCADE | **Crítico** — associação com a subpergunta respondida |
| `subquestion_text_snapshot` | text | Sim | Texto da subpergunta no momento do envio | **Alto** — preserva contexto histórico; enviado ao serviço de IA junto com o `answer_value` |
| `answer_value` | text | Sim | `PESSIMO` \| `RUIM` \| `MEDIANA` \| `BOA` \| `OTIMA` | **Crítico** — valor categórico lido pela IA para análise de sentimento no nível de subpergunta |
| `answer_score` | integer | Sim | Valor numérico (1–5) | **Crítico** — usado para cálculo de médias nos componentes analíticos do dashboard |

**Constraint:** `(feedback_id, subquestion_id)` único.

---

### `public.feedback_analysis`

> Resultado da análise de sentimento e extração semântica gerada pelo motor de IA para cada feedback.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna do registro |
| `feedback_id` | uuid FK | Sim | → `feedback.id` ON DELETE CASCADE, **único** | **Crítico** — relação 1:1 com o feedback analisado; a unicidade permite `INSERT ... ON CONFLICT (feedback_id) DO NOTHING` na retomada dos jobs |
| `sentiment` | text | Não | `positive` \| `neutral` \| `negative` (minúsculo, em inglês — valores gravados pela IA; a tradução/capitalização para Positivo/Neutro/Negativo ocorre só na UI; sem CHECK no banco) | **Crítico** — exibido nos cards de sentimento do dashboard; base do filtro por sentimento na listagem de feedbacks |
| `categories` | text[] | Não | Categorias semânticas extraídas pela IA, canonicalizadas pela taxonomia do escopo | **Alto** — exibido no painel de insights; usado para agrupar e filtrar feedbacks por tema no dashboard |
| `keywords` | text[] | Não | Palavras-chave extraídas e saneadas contra o texto original | **Alto** — exibido no painel de insights; o saneamento é feito pelo serviço `ia-analyze` |
| `aspects` | jsonb | Não | Array de `{ aspect, sentiment, sentiment_score }` — sentimento por aspecto (ABSA, Tier 2) | **Alto** — base da lente de **Aspectos** ("Assuntos que mais impactam") na tela de estatísticas; preenchido pelo serviço de IA via `extractAspects` |
| `sentiment_score` | numeric | Não | Intensidade graduada do sentimento geral em `[-1, 1]` | **Médio** — refina o `sentiment` categórico com a magnitude do sentimento; preenchido pelo serviço de IA |
| `confidence` | numeric | Não | Confiança da classificação em `[0, 1]` | **Médio** — sinaliza o grau de certeza da análise; preenchido pelo serviço de IA |

---

### `public.feedback_insights_report`

> Relatório consolidado de insights por empresa e por escopo (empresa, produto, serviço ou departamento). O Gateway grava por upsert no contexto `(enterprise_id, scope_type, catalog_item_id)` e lê o mais recente.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna do registro |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `scope_type` | text | Sim | `COMPANY` \| `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Crítico** — determina o escopo do relatório; usado no seletor de escopo da tela de insights |
| `catalog_item_id` | uuid FK | Condicional | → `catalog_items.id` ON DELETE CASCADE — obrigatório quando `scope_type ≠ COMPANY` | **Crítico** — junto com `scope_type` e `enterprise_id`, forma a chave do relatório; distingue insights de diferentes itens do catálogo |
| `catalog_item_name` | text | Não | Nome do item no momento do relatório | **Médio** — snapshot do nome para exibição; garante que relatórios antigos mostrem o nome correto mesmo se o item for renomeado |
| `summary` | text | Não | Resumo situacional gerado pela IA | **Crítico** — conteúdo principal exibido no painel de insights da tela de Relatório IA |
| `recommendations` | text[] | Não | Lista de recomendações acionáveis | **Crítico** — lista de ações sugeridas pela IA exibida no painel de insights |

**Índice único:** `uq_feedback_insights_context` `(enterprise_id, scope_type, catalog_item_id)`. Nas migrations ele **não** tem `NULLS NOT DISTINCT` (o dump legado tinha); como o Postgres trata cada `NULL` como distinto, a unicidade no escopo `COMPANY` (`catalog_item_id` nulo) depende de como o banco foi criado.

---

### `public.scope_diagnosis`

> Diagnóstico do escopo gerado pela IA a partir dos números já calculados do período e do período anterior (migration `0008`). Guarda o histórico: um diagnóstico novo não sobrescreve o anterior.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant |
| `scope_type` | text | Sim | `COMPANY` (default) \| `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Alto** — escopo do diagnóstico |
| `catalog_item_id` | uuid FK | Condicional | → `catalog_items.id` ON DELETE CASCADE — nulo no escopo `COMPANY` | **Alto** — item do catálogo diagnosticado |
| `period_start` / `period_end` | timestamptz | Não | Período analisado | **Alto** — recorte exibido com o diagnóstico |
| `previous_start` / `previous_end` | timestamptz | Não | Período de comparação | **Médio** — base das variações |
| `feedback_count` | integer | Sim | Avaliações no período quando foi gerado | **Médio** — mostra sobre quantas respostas o diagnóstico fala |
| `data_hash` | text | Sim | sha256 do pacote enviado à IA | **Alto** — o mesmo recorte com os mesmos dados não paga IA de novo |
| `model` | text | Não | Modelo de IA usado | **Baixo** — auditoria |
| `result` | jsonb | Sim | O diagnóstico devolvido pela IA | **Crítico** — conteúdo da tela de diagnóstico |
| `created_at` | timestamptz | Sim | — | **Alto** — ordena o histórico |

**Índice:** `idx_scope_diagnosis_scope_created` `(enterprise_id, scope_type, catalog_item_id, created_at DESC)` — o último e o histórico por escopo.

---

### `public.enterprise_ia_config`

> Chave e modelo de IA da empresa (BYO-key, migration `0003`). Relação 1:1 com `enterprise`. A chave fica **cifrada** com AES-256-GCM e nunca volta para a Web.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE, **único** | **Crítico** — uma configuração por empresa |
| `provider` | text | Sim | `openrouter` (default) \| `gemini` (CHECK) | **Alto** — o Gateway grava `openrouter`; vai ao `ia-analyze` no header `x-llm-provider` |
| `model` | text | Não | Modelo escolhido | **Alto** — vai no header `x-llm-model` |
| `api_key_ciphertext` / `api_key_iv` / `api_key_auth_tag` | text | Não | Chave cifrada, vetor de inicialização e tag de autenticação | **Crítico** — decifrados só no Gateway, na hora de chamar a IA |
| `key_hint` | text | Não | Últimos 4 caracteres da chave | **Baixo** — a UI mostra qual chave está salva |
| `created_at` / `updated_at` | timestamptz | Não | — | **Baixo** — auditoria |

---

### `public.ia_analysis_job`

> Fila **e** status de progresso das operações de IA (migration `0002`). O worker pega jobs com `SELECT ... FOR UPDATE SKIP LOCKED`.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Crítico** — o `jobId` que a Web acompanha por polling |
| `enterprise_id` | uuid FK | Sim | → `enterprise.id` ON DELETE CASCADE | **Crítico** — multi-tenant; também é o escopo do orçamento de IA |
| `job_type` | text | Sim | `analyze_raw` \| `regenerate_insights` \| `generate_company_questions` \| `generate_scope_diagnosis` | **Crítico** — define o que o worker faz |
| `scope_type` | text | Sim | `COMPANY` (default) \| `PRODUCT` \| `SERVICE` \| `DEPARTMENT` | **Alto** — escopo do trabalho |
| `catalog_item_id` | uuid FK | Não | → `catalog_items.id` ON DELETE CASCADE | **Alto** — item do escopo |
| `status` | text | Sim | `queued` (default) \| `running` \| `waiting_budget` \| `completed` \| `failed` | **Crítico** — estado exibido na barra de progresso |
| `total` / `done` | integer | Sim | Itens a processar e já processados | **Alto** — progresso exibido na Web |
| `options` | jsonb | Não | Parâmetros do pedido e checkpoint do worker (`options.checkpoint`) | **Crítico** — permite retomar de onde parou |
| `attempts` | integer | Sim | Posses do job (sobe a cada vez que um worker o pega) | **Médio** — distingue um worker antigo de um novo |
| `next_run_at` | timestamptz | Sim | Quando o job fica elegível; enquanto `running`, é o fim do lease (10 min, renovado por heartbeat) | **Crítico** — base do claim e da retomada de job abandonado |
| `error_code` | text | Não | Código da falha | **Médio** — a Web traduz em mensagem |
| `requested_by` | uuid | Não | Usuário que pediu (sem FK) | **Baixo** — auditoria |
| `created_at` / `updated_at` | timestamptz | Não | `updated_at` mantido por trigger | **Baixo** — ordem e auditoria |

**Índices:** `idx_ia_analysis_job_claim` `(status, next_run_at)` para o claim; `uq_ia_analysis_job_active`, único por `(enterprise_id, job_type, scope_type, COALESCE(catalog_item_id, '00000000-…'))` só para jobs ativos (`queued`, `running`, `waiting_budget`) — impede o duplo clique.

---

### `public.ia_rate_budget`

> Token bucket durável que dita o ritmo das chamadas à IA (back-pressure), por janela de minuto e de dia.

| Coluna | Tipo | Obrigatório | Descrição | Impacto no Projeto |
|---|---|---|---|---|
| `id` | uuid PK | Sim | — | **Baixo** — identificação interna |
| `scope` | text | Sim | Dono do orçamento: o worker usa o id da empresa (em texto); default `global` | **Crítico** — isola a cota por empresa; sem FK, o Gateway apaga as linhas ao excluir a conta |
| `window_kind` | text | Sim | `minute` \| `day` (CHECK) | **Alto** — `IA_RPM_LIMIT` e `IA_RPD_LIMIT` |
| `window_start` | timestamptz | Sim | Início da janela | **Alto** — parte da chave da reserva |
| `used` | integer | Sim | Reservas usadas na janela | **Crítico** — passou do limite, o job vai para `waiting_budget` |
| `created_at` | timestamptz | Não | — | **Baixo** — auditoria |

**Constraint:** `uq_ia_rate_budget_window` `(scope, window_kind, window_start)` — permite a reserva atômica por upsert.

---

## Funções e Stored Procedures

Criadas na migration custom `0001_functions_triggers_rls.sql` (as três funções de CPF/CNPJ saíram na `0009`).

| Função | Schema | Tipo | Descrição |
|---|---|---|---|
| `generate_device_fingerprint(user_agent, ip)` | public | Utilitária | Retorna `md5(user_agent \| ip \| dia_epoch)` — fingerprint diário rotativo |
| `can_device_send_feedback(enterprise_id, fingerprint, collection_point_id?)` | public | Query | Retorna `boolean` — verifica se o dispositivo já enviou feedback no dia para o ponto informado |
| `register_device_feedback(enterprise_id, fingerprint, user_agent, ip, customer_id?, collection_point_id?)` | public | Mutação | Upsert em `tracked_devices` com `pg_advisory_xact_lock` para serializar acessos concorrentes; incrementa `feedback_count` |
| `update_updated_at_column()` | public | Trigger genérico | Atualiza `updated_at = now()` automaticamente em operações de UPDATE |
| `validate_questions_of_feedbacks_context()` | public | Trigger | Valida coerência entre `scope_type` e `catalog_item_id` em `questions_of_feedbacks` |
| `validate_feedback_insights_report_context()` | public | Trigger | Valida coerência entre `scope_type` e `catalog_item_id` em `feedback_insights_report` |

> **Funções de anti-spam:** `generate_device_fingerprint`, `can_device_send_feedback` e `register_device_feedback` continuam no banco, mas o Gateway não as chama: o fingerprint é calculado em `qrcode.controller.ts` e o limite diário e o contador ficam em `qrFeedback.repository.ts`.

---

## Triggers

| Trigger | Tabela | Evento | Função | Propósito |
|---|---|---|---|---|
| `validate_questions_of_feedbacks_context` | `questions_of_feedbacks` | BEFORE INSERT/UPDATE | `validate_questions_of_feedbacks_context()` | Integridade de escopo das perguntas |
| `validate_feedback_insights_report_context` | `feedback_insights_report` | BEFORE INSERT/UPDATE | `validate_feedback_insights_report_context()` | Integridade de escopo dos relatórios |
| `set_updated_at` | `catalog_items`, `collecting_data_enterprise`, `collection_points`, `customer`, `enterprise`, `feedback`, `feedback_analysis`, `feedback_insights_report`, `feedback_question_subquestions`, `questions_of_feedbacks`, `tracked_devices`, `ia_analysis_job` e `enterprise_ia_config` | BEFORE UPDATE | `update_updated_at_column()` | Auditoria automática de timestamps |

> Não há trigger de cadastro nem de higienização de metadados: os antigos `on_auth_user_created` e `on_auth_user_metadata_before_update`, do Supabase Auth, saíram no cutover para o Better Auth. A empresa e as perguntas padrão nascem no Gateway (`src/auth/enterpriseOnSignup.ts`). As tabelas do Better Auth atualizam o próprio `updated_at`, e `feedback_comment_field` tem a coluna sem trigger.

---

## Segurança e RLS

### Modelo de autorização

O sistema usa **duas camadas**:

1. **API Gateway (barreira principal):** o middleware `requireAuth` valida a sessão via **Better Auth** (cookie httpOnly) e injeta `req.user` e `req.enterpriseId` na requisição; o isolamento por empresa é aplicado na aplicação, com filtro explícito por `enterprise_id` em toda query (`src/db/tenantScope.ts`). O formulário público passa pelo mesmo Gateway e pelo mesmo filtro.
2. **Banco com o mínimo de privilégio (migration `0013`):** o app entra com o papel `feedback_app`, e a RLS ligada em todas as tabelas barra os outros papéis. A RLS **não filtra por empresa** — ver [ORM × RLS](../../arquitetura/orm-rls-decisao.md).

### Papéis e policy

| Papel | Quem usa | O que pode |
|---|---|---|
| `feedback_app` | O Gateway em runtime (a `DATABASE_URL` da Vercel; em produção, o app já entra com ele) | `SELECT`, `INSERT`, `UPDATE` e `DELETE` em todas as tabelas e `USAGE, SELECT` nas sequências do schema `public`, inclusive nas tabelas criadas depois (`ALTER DEFAULT PRIVILEGES`). Não cria, altera nem apaga estrutura, não desliga a RLS nem cria papéis |
| `postgres` | As migrations (secret `DATABASE_URL` do GitHub, no workflow de deploy do gateway) | Dono das tabelas; a RLS não vale para o dono |
| `anon` / `authenticated` (Supabase) | Ninguém do sistema — não usamos a Data API | Nada: sem policy para eles, a RLS devolve zero linhas |

Cada tabela tem a policy `feedback_app_all` (`FOR ALL TO feedback_app USING (true) WITH CHECK (true)`). Tabela nova precisa, na mesma migration, de `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` e dessa policy; sem ela, o app recebe zero linhas. Detalhes e passo a passo em [Banco com o mínimo de privilégio](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/banco-menor-privilegio.md).

> **Histórico:** antes do Better Auth, as policies eram por empresa e usavam `auth.uid()` do Supabase Auth, com policies próprias para o papel `anon` no formulário público e claims no JWT (`jwt_custom_claims`). Tudo isso saiu no cutover; os dumps legados em `database/sql/` ainda mostram essas policies.

---

## Índices e Performance

| Tabela | Índice | Colunas | Propósito |
|---|---|---|---|
| `catalog_items` | `idx_catalog_items_enterprise_kind` | `(enterprise_id, kind)` | Filtro por tipo de item da empresa |
| `catalog_items` | `idx_catalog_items_status` | `(status)` | Filtro rápido de itens ativos |
| `collection_points` | `idx_collection_points_catalog_item_id` | `(catalog_item_id)` | JOIN com catálogo |
| `questions_of_feedbacks` | `uq_questions_company_order` | `(enterprise_id, question_order)` WHERE COMPANY | Unicidade das perguntas corporativas |
| `questions_of_feedbacks` | `uq_questions_item_order` | `(enterprise_id, scope_type, catalog_item_id, question_order)` WHERE item | Unicidade das perguntas por item |
| `questions_of_feedbacks` | `idx_questions_context` | `(enterprise_id, scope_type, catalog_item_id, is_active)` | Busca do formulário público |
| `feedback_question_subquestions` | `idx_feedback_question_subquestions_active` | `(question_id, is_active, subquestion_order)` | Carregamento ordenado de subperguntas ativas |
| `feedback_question_subquestions` | `idx_feedback_question_subquestions_question_id` | `(question_id)` | JOIN com a pergunta |
| `feedback_comment_field` | `uq_comment_field_company` | `(enterprise_id)` WHERE COMPANY e sem item | Uma configuração corporativa por empresa |
| `feedback_comment_field` | `uq_comment_field_item` | `(enterprise_id, catalog_item_id)` WHERE com item | Uma configuração por item |
| `feedback` | `idx_feedback_enterprise_created_at` | `(enterprise_id, created_at DESC)` | Métricas por período |
| `feedback_question_answers` | `idx_feedback_question_answers_feedback_id` | `(feedback_id)` | JOIN no carregamento de respostas |
| `feedback_question_answers` | `idx_feedback_question_answers_question_id` | `(question_id)` | Análise por pergunta |
| `feedback_subquestion_answers` | `idx_feedback_subquestion_answers_feedback_id` | `(feedback_id)` | JOIN no carregamento |
| `feedback_subquestion_answers` | `idx_feedback_subquestion_answers_subquestion_id` | `(subquestion_id)` | Análise por subpergunta |
| `feedback_insights_report` | `uq_feedback_insights_context` | `(enterprise_id, scope_type, catalog_item_id)` | Upsert do relatório por contexto |
| `feedback_insights_report` | `idx_feedback_insights_report_enterprise_updated` | `(enterprise_id, updated_at DESC)` | Listagem dos relatórios mais recentes |
| `scope_diagnosis` | `idx_scope_diagnosis_scope_created` | `(enterprise_id, scope_type, catalog_item_id, created_at DESC)` | Último diagnóstico e histórico por escopo |
| `ia_analysis_job` | `idx_ia_analysis_job_claim` | `(status, next_run_at)` | Claim do worker |
| `ia_analysis_job` | `uq_ia_analysis_job_active` | `(enterprise_id, job_type, scope_type, COALESCE(catalog_item_id, …))` WHERE ativo | Deduplicação de jobs ativos |
| `auth_rate_limit` | `auth_rate_limit_expiry_idx` | `(expires_at)` | Janelas vencidas |

---

## Regras de Integridade e Constraints

| Tabela | Constraint | Regra |
|---|---|---|
| `user` | `user_email_key` / `user_phone_key` | `email` e `phone` únicos |
| `session` | `session_token_key` | `token` único |
| `enterprise` | `enterprise_auth_user_id_key` | Uma empresa por usuário |
| `enterprise` | `enterprise_subscription_status_check` | `subscription_status` ∈ `{TRIAL, ACTIVE, EXPIRED, CANCELED}` |
| `collecting_data_enterprise` | `collecting_data_enterprise_enterprise_unique` | Um registro por empresa |
| `catalog_items` | `catalog_items_kind_check` | `kind` ∈ `{PRODUCT, SERVICE, DEPARTMENT}` |
| `catalog_items` | `catalog_items_status_check` | `status` ∈ `{ACTIVE, INACTIVE}` |
| `questions_of_feedbacks` | `questions_of_feedbacks_scope_type_check` | `scope_type` ∈ `{COMPANY, PRODUCT, SERVICE, DEPARTMENT}` |
| `questions_of_feedbacks` | `questions_of_feedbacks_question_order_check` | `question_order` entre 1 e 3 |
| `questions_of_feedbacks` | `questions_of_feedbacks_question_text_length_check` | texto da pergunta entre 20 e 150 caracteres |
| `feedback_question_subquestions` | `feedback_question_subquestions_order_check` | `subquestion_order` entre 1 e 3 |
| `feedback_question_subquestions` | `feedback_question_subquestions_text_length_check` | texto da subpergunta entre 20 e 150 caracteres |
| `feedback_question_subquestions` | `feedback_question_subquestions_question_order_unique` | `(question_id, subquestion_order)` único |
| `feedback_comment_field` | `feedback_comment_field_scope_type_check` | `scope_type` ∈ `{COMPANY, PRODUCT, SERVICE, DEPARTMENT}` |
| `feedback_comment_field` | `feedback_comment_field_mode_check` | `mode` ∈ `{DEFAULT, CUSTOM, HIDDEN}` |
| `feedback_comment_field` | `feedback_comment_field_prompt_check` | No modo `CUSTOM`, `prompt` obrigatório com 10 a 150 caracteres |
| `feedback` | `feedback_channel_check` | `channel` nulo ou ∈ `{QR, LINK, NFC, TEST}` |
| `feedback_question_answers` | `feedback_question_answers_answer_value_check` | `answer_value` ∈ `{PESSIMO, RUIM, MEDIANA, BOA, OTIMA}` |
| `feedback_question_answers` | `feedback_question_answers_answer_score_check` | `answer_score` entre 1 e 5 |
| `feedback_question_answers` | `feedback_question_answers_feedback_question_unique` | `(feedback_id, question_id)` único |
| `feedback_subquestion_answers` | `feedback_subquestion_answers_answer_value_check` | Mesmo enum de valores |
| `feedback_subquestion_answers` | `feedback_subquestion_answers_answer_score_check` | `answer_score` entre 1 e 5 |
| `feedback_subquestion_answers` | `feedback_subquestion_answers_feedback_subquestion_unique` | `(feedback_id, subquestion_id)` único |
| `feedback_analysis` | `feedback_analysis_feedback_id_unique` | Uma análise por feedback |
| `feedback_insights_report` | `feedback_insights_report_scope_type_check` | `scope_type` ∈ `{COMPANY, PRODUCT, SERVICE, DEPARTMENT}` |
| `scope_diagnosis` | `scope_diagnosis_scope_type_check` | `scope_type` ∈ `{COMPANY, PRODUCT, SERVICE, DEPARTMENT}` |
| `user_onboarding` | `user_onboarding_status_check` / `user_onboarding_version_check` | `status` ∈ `{completed, skipped}`; `version > 0` |
| `enterprise_ia_config` | `enterprise_ia_config_enterprise_unique` / `enterprise_ia_config_provider_check` | Uma configuração por empresa; `provider` ∈ `{gemini, openrouter}` |
| `ia_analysis_job` | `ia_analysis_job_job_type_check` | `job_type` ∈ `{analyze_raw, regenerate_insights, generate_company_questions, generate_scope_diagnosis}` |
| `ia_analysis_job` | `ia_analysis_job_scope_type_check` | `scope_type` ∈ `{COMPANY, PRODUCT, SERVICE, DEPARTMENT}` |
| `ia_analysis_job` | `ia_analysis_job_status_check` | `status` ∈ `{queued, running, waiting_budget, completed, failed}` |
| `ia_rate_budget` | `ia_rate_budget_window_kind_check` | `window_kind` ∈ `{minute, day}` |

> **Unicidade do relatório de insights — constraint legada removida:** a unique antiga `feedback_insights_report_enterprise_id_key` (`UNIQUE (enterprise_id)`, **1 linha por empresa**) foi dropada antes das migrations Drizzle. Ela era incompatível com os relatórios segmentados por escopo — ao salvar um segundo relatório (ex.: de um item) quando já existia o da empresa, o INSERT batia nessa unique. A unicidade passou a ser o índice composto `uq_feedback_insights_context (enterprise_id, scope_type, catalog_item_id)`.

### Regras de cascata por deleção

| Tabela pai deletada | Tabelas afetadas | Comportamento |
|---|---|---|
| `user` | `enterprise`, `session`, `account`, `user_onboarding` | `CASCADE` |
| `enterprise` | `catalog_items`, `collection_points`, `questions_of_feedbacks`, `feedback_comment_field`, `tracked_devices`, `feedback`, `feedback_insights_report`, `scope_diagnosis`, `enterprise_ia_config`, `ia_analysis_job` | `CASCADE` — dados da empresa são removidos |
| `catalog_items` | `questions_of_feedbacks`, `feedback_comment_field`, `feedback_insights_report`, `scope_diagnosis`, `ia_analysis_job` | `CASCADE` |
| `catalog_items` → `collection_points` | `collection_points.catalog_item_id` | `SET NULL` — ponto vira corporativo ao perder o item |
| `feedback` | `feedback_question_answers`, `feedback_subquestion_answers`, `feedback_analysis` | `CASCADE` |
| `questions_of_feedbacks` | `feedback_question_answers`, `feedback_question_subquestions` | `CASCADE` |
| `feedback_question_subquestions` | `feedback_subquestion_answers` | `CASCADE` |

> **Sem FK em cascata:** `customer`, `collecting_data_enterprise` e `ia_rate_budget` não têm FK para `enterprise`, e `verification` não tem FK para `user`. Ao excluir a conta, o Gateway (`src/auth/enterpriseOnDelete.ts`) apaga essas linhas antes de apagar a empresa; o Better Auth apaga o usuário em seguida.

---

## Storage

O sistema não usa o Supabase Storage: nenhuma migration nem código do Gateway lê ou grava arquivos, e não há upload de logotipos. Os triggers do schema `storage` que os dumps antigos listavam (`protect_buckets_delete`, `protect_objects_delete`, `enforce_bucket_name_length_trigger`, `update_objects_updated_at`) pertencem ao próprio Supabase, fora do schema `public` que o projeto mantém.

---

## Veja Também

- [Arquitetura Geral do Sistema](../../arquitetura/visao-geral.md)
- [Modelagem de Dados (DER)](../../arquitetura/modelagem-de-dados.md)
- [ORM × RLS: nossa decisão](../../arquitetura/orm-rls-decisao.md)
- [Backend — Arquitetura Detalhada](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/arquitetura-estrutura.md)
- [Migrations com Drizzle](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/migrations-drizzle.md)
- [Funcionalidades — Visão Geral](../../concepcao/requisitos-e-funcionalidades.md)
- [Anti-spam e Fingerprint](../../produto/anti-spam-fingerprint.md)
- [Higienização JWT / LGPD](../../produto/higienizacao-jwt-lgpd.md) (histórico da época do Supabase Auth)
- [SQL legado das tabelas, funções e triggers](https://github.com/TCC-Feedback-Analytics/feedback-analytics/tree/main/database/sql/) (dumps de antes das migrations Drizzle)
