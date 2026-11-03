# ORM × RLS: nossa decisão (Drizzle)

> **Em uma frase:** o backend acessa o banco **só pelo Drizzle** (ORM SQL-first), com **filtro explícito por `enterprise_id` na aplicação** em todos os caminhos — autenticados, internos e o formulário público —, e a **RLS do Postgres fica ligada em todas as tabelas** com uma única policy que deixa passar apenas o papel do app (`feedback_app`) e barra todos os outros papéis.

Este documento responde, de frente, à crítica da banca *"usar Supabase não exercita conhecimento de banco; migrem para um ORM"* e registra o trade-off central — segurança no nível do banco (RLS) versus ORM — para a defesa do TCC.

> **Nota (auth):** a **autenticação** deixou de usar o Supabase Auth e passou para o **Better Auth** — a sessão é validada na aplicação (Gateway) e não mais por `auth.uid()` do Postgres. O **banco continua sendo o mesmo Postgres** (hospedado no Supabase, acessado direto por `DATABASE_URL` + Drizzle; não usamos o Supabase Auth nem a Data API). "Sair do Supabase" aqui significou sair do **Auth + SDK**, não do banco. Ver [Autenticação com Better Auth](historico-de-decisoes/decisao-autenticacao-better-auth.md).

Artefatos relacionados:

- Schema Drizzle **canônico e modular** (Fase 2): barrel em [`drizzle/schema.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/drizzle/schema.ts) agrupando módulos em `drizzle/schema/*.ts` (`auth`, `authRateLimit`, `commentField`, `devices`, `enterprise`, `feedback`, `iaConfig`, `iaJobs`, `onboarding`, `questions`, `scopeDiagnosis`, `views`) – tipos inferidos estáveis em [`src/db/types.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/db/types.ts)
- Cliente Drizzle (lazy, pooler Supabase): [`src/db/client.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/db/client.ts)
- Config do drizzle-kit: [`drizzle.config.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/drizzle.config.ts)
- ADR-0001 (Decisão de Fonte Única): [`docs/adr/0001-fonte-unica-de-schema.md`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/adr/0001-fonte-unica-de-schema.md)
- Convenção de migrations: [Migrations com Drizzle](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/migrations-drizzle.md)
- Papel do app e RLS: [Banco com o mínimo de privilégio](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/banco-menor-privilegio.md) (migration `0013`)
- Camada de isolamento multi-tenant: [`src/db/tenantScope.ts`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/src/db/tenantScope.ts)
- Modelagem existente: [Modelo Conceitual (MER)](modelo-conceitual-mer.md) – [Diagrama de Entidade e Relacionamento (DER)](modelagem-de-dados.md) – [Visão Geral do Banco](../referencia/banco-de-dados/visao-geral.md)

---

## 1. A crítica e a resposta honesta

A crítica parte de um **equívoco parcial**: o Supabase é apenas uma **hospedagem do PostgreSQL** — quem modela e programa o banco continua sendo a equipe. E o banco do projeto **usa recursos escritos à mão**, que vão além do que um ORM geraria automaticamente:

- **RLS ligada em todas as tabelas**, com policy por papel (`feedback_app_all`) e um papel de aplicação com o mínimo de privilégio.
- **Funções PL/pgSQL** com `SECURITY DEFINER` e `pg_advisory_xact_lock`.
- **Índices avançados**: parciais com `WHERE` (`uq_questions_company_order`, `uq_comment_field_company`), compostos e um índice único por expressão com `COALESCE` (`uq_ia_analysis_job_active`, a deduplicação da fila).
- **Triggers de validação de coerência** e uma **view** (`enterprise_public`) que resolve o nome público da empresa.

Ironicamente, ORMs "mágicos" como o **Prisma escondem o SQL** — demonstrariam *menos* domínio de banco, não mais. Por isso a escolha recai no **Drizzle (SQL-first)**: ele não esconde o SQL, e agrega o que vale num TCC — **tipagem ponta-a-ponta** e **migrations versionadas**.

## 2. O trade-off central: ORM × RLS

As policies de RLS originais foram escritas para o modelo do Supabase Auth, em que **o próprio banco** conferia "esta linha é da empresa do usuário?" usando `auth.uid()` (ex.: `enterprise_id IN (SELECT id FROM enterprise WHERE auth_user_id = auth.uid())`). Com a migração da autenticação para o **Better Auth**, quem identifica o usuário e a empresa da requisição é **a aplicação** (o Gateway, a partir da sessão Better Auth) — não mais o `auth.uid()` do Postgres. As policies `auth.uid()` foram removidas no cutover.

Um ORM conecta ao Postgres por uma **connection string com um único papel**, compartilhado por todas as requisições num pool. Propagar o usuário de cada requisição para a conexão e fazer a RLS filtrar por empresa no Drizzle é **possível, mas frágil e lento** num pool compartilhado.

**Consequência:** a checagem de "cada empresa só vê o seu" **vive na aplicação**. Um filtro de `enterprise_id` esquecido vira vazamento entre empresas. Reconhecer e tratar isso bem é, por si só, um bom ponto de discussão acadêmica.

## 3. A decisão

1. **Drizzle como único caminho de dados** — rotas autenticadas, rotas internas, o Worker e também o formulário público (QR Code, link ou NFC) —, **sempre com filtro explícito por `enterprise_id`**.
2. **O app entra com o papel `feedback_app`** (migration `0013`): só `SELECT`, `INSERT`, `UPDATE` e `DELETE`; não cria, altera nem apaga estrutura, não desliga a RLS nem cria papéis. As migrations seguem rodando como `postgres`. Em produção, o app já entra como `feedback_app`.
3. **A RLS fica ligada em todas as tabelas** (as 24 criadas pelas migrations `0000` a `0013`), com a policy `feedback_app_all` (`FOR ALL TO feedback_app USING (true) WITH CHECK (true)`). Ela **não filtra por empresa**: deixa o `feedback_app` ver todas as linhas e barra qualquer outro papel, como o `anon` e o `authenticated` do Supabase. Tabela nova precisa, na mesma migration, de `ENABLE ROW LEVEL SECURITY` e dessa policy.
4. **Fonte única canônica (Fase 2 consolidada)**: o Drizzle assumiu a autoridade total do schema através de migrations versionadas (`0000_great_talisman.sql` a `0013_banco_menor_privilegio.sql`), substituindo definitivamente os dumps SQL manuais paralelos, que ficam como legado em `database/sql/` (ADR-0001).

## 4. Mitigações (como evitamos o vazamento entre empresas)

- **Helper único de query tenant-scoped:** `src/db/tenantScope.ts` monta as condições de leitura de feedback **sempre com `enterprise_id`** e falha alto se ele vier vazio (`assertEnterpriseId`).
- **Teste de isolamento multi-tenant:** `src/tests/tenantScope.test.ts` garante que a condição sempre filtra por empresa, que empresas diferentes geram filtros diferentes e que o recorte por escopo não remove o filtro de empresa.
- **Menor privilégio no banco:** se a senha do app vazar, o `feedback_app` não consegue apagar tabelas, desligar a RLS nem criar usuários; e os papéis do Supabase não leem nada.
- **Code review** focado em qualquer query Drizzle sem `enterprise_id`.

## 5. O que NÃO faremos (e por quê)

- **NÃO Prisma** — esconde o SQL e a modelagem real; demonstraria menos domínio de banco, o oposto do que a banca pediu.
- **NÃO RLS por empresa no pool** — exigiria propagar o usuário de cada requisição para a conexão (variáveis de sessão por transação), frágil e lento no pooler em modo transação; a policy por papel cobre o que a RLS faz bem aqui, que é barrar quem não é o app.
- **NÃO trocar Express por NestJS** — é framework de aplicação, não de banco; não melhora a demonstração de modelagem de dados.

## 6. Conexão e introspecção (operacional)

- **Runtime (app):** `src/db/client.ts` conecta lazy, com `prepare: false` (obrigatório no pooler do Supabase em modo transação, porta 6543) e pool pequeno (`max: 3`). A `DATABASE_URL` da Vercel usa o papel `feedback_app`.
- **Migrations:** o workflow de deploy do gateway roda `npm run db:migrate` com o secret `DATABASE_URL` do GitHub, que segue com o `postgres`.
- **drizzle-kit:** `drizzle.config.ts` com **`schemaFilter: ['public']`** — introspecção e migrations atuam **apenas no schema `public`**.
- O schema é **mantido à mão** em `drizzle/schema/*.ts`, e cada mudança nasce como migration (`npm run db:generate`). O `npm run db:pull` regera tudo num arquivo só; serve só para diff e auditoria. O schema **não depende mais de `auth.users`**: os usuários vivem em `public.user` (Better Auth).

> **Achado da introspecção (histórico, de quando o Drizzle entrou):** o banco de produção tinha **mais constraints do que os dumps em `database/sql/`** — FKs ausentes nos dumps (`feedback → collection_points`, `feedback → tracked_devices`, `enterprise.auth_user_id → auth.users`, `tracked_devices.blocked_by → auth.users`), CHECKs (`rating 1..5`, `sentiment`, `gender`, `collection_points.type/status`), uniques 1:1 (`feedback_analysis.feedback_id`, `collecting_data_enterprise.enterprise_id`) e índices extras. Foi isso que levou a tratar os dumps como legado. Hoje a referência é o schema das migrations do gateway; o baseline `0000` da Fase 2 não recria todas essas constraints (por exemplo, as FKs de `feedback` para `collection_points` e `tracked_devices` e os CHECKs de `rating`, `sentiment`, `gender` e `collection_points`).

## 7. O que isso demonstra no TCC

- **Modelagem de dados relacional** e **uso consciente de um ORM SQL-first** e seus limites.
- **Isolamento multi-tenant** e a discussão (rara em TCCs) do **trade-off entre ORM e segurança no nível do banco** — defesa em profundidade na prática, com papel de menor privilégio e RLS por papel.
- **Migrations e versionamento de esquema** com histórico (Etapa 01-4).
