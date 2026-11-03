# SQL Dump Organizado

> **Legado — não é mais a fonte do schema.** Estes dumps são do banco da época do Supabase Auth, antes das migrations Drizzle. A fonte única do schema é o repositório do gateway: [`drizzle/schema/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle/schema) e as migrations em [`drizzle/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle) (ADR-0001). Mudança de schema nasce como migration lá, nunca aqui.
>
> O que mudou desde estes dumps: a autenticação saiu do `auth.users` para as tabelas do Better Auth (`public.user`, `session`, `account`, `verification`); as policies `auth.uid()`/`anon`, os triggers de `auth.users` e as funções `create_enterprise_on_signup`, `clean_user_metadata_before_change`, `jwt_custom_claims`, `phone_exists`, `document_exists`, `enterprise_public_documents_fn` e `enterprise_public_ids_fn` foram removidos; a coluna `enterprise.document` (CPF/CNPJ) saiu; e entraram tabelas que não aparecem aqui (`ia_analysis_job`, `ia_rate_budget`, `enterprise_ia_config`, `user_onboarding`, `auth_rate_limit`, `scope_diagnosis`, `feedback_comment_field`), as colunas `feedback.comment_prompt` e `feedback.channel`, e a RLS com a policy única `feedback_app_all` para o papel do app. A descrição atual está em [Banco de Dados — Visão Geral](../../docs/referencia/banco-de-dados/visao-geral.md).
>
> Os arquivos ficam como referência histórica.

Gerado a partir dos arquivos em database/tables e database/functions.

## Estrutura
- tables/: 1 arquivo SQL por tabela, com CREATE TABLE + RLS + policies + triggers
- views/: 1 arquivo SQL por view (objetos relacionais derivados)
- policies/all_policies.sql: políticas consolidadas
- triggers/all_triggers.sql: triggers consolidados
- functions/: funções SQL por schema
- DESCRICOES.md: descrição breve de cada tabela, função, trigger e policy
