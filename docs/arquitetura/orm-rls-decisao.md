# ORM × RLS: nossa decisão (Drizzle)

> **Em uma frase:** adotamos o **Drizzle** (ORM SQL-first) nos caminhos **autenticados/internos** do backend, com **filtro explícito por `enterprise_id` na aplicação**, mantendo a **RLS do Postgres ligada como defesa em profundidade** — e deixando o fluxo público anônimo (QR Code) inteiramente sob a RLS, sem Drizzle.

Este documento responde, de frente, à crítica da banca *"usar Supabase não exercita conhecimento de banco; migrem para um ORM"* e registra o trade-off central — segurança no nível do banco (RLS) versus ORM — para a defesa do TCC.

Artefatos relacionados:

- Schema Drizzle **canônico** (introspectado do banco real via `db:pull`): [`backends/api-gateway/drizzle/schema.ts`](../../backends/api-gateway/drizzle/schema.ts) · tipos inferidos estáveis em [`src/db/types.ts`](../../backends/api-gateway/src/db/types.ts)
- Cliente Drizzle (lazy, pooler): [`backends/api-gateway/src/db/client.ts`](../../backends/api-gateway/src/db/client.ts)
- Config do drizzle-kit: [`backends/api-gateway/drizzle.config.ts`](../../backends/api-gateway/drizzle.config.ts)
- Convenção de migrations: [Migrations com Drizzle](migrations-drizzle.md)
- Caminho migrado (stats via Drizzle, tenant-scoped): [`src/db/tenantScope.ts`](../../backends/api-gateway/src/db/tenantScope.ts) + [`src/repositories/feedbackStats.repository.ts`](../../backends/api-gateway/src/repositories/feedbackStats.repository.ts)
- Modelagem existente: [Modelo Conceitual (MER)](modelo-conceitual-mer.md) · [Diagrama de Entidade e Relacionamento (DER)](modelagem-de-dados.md) · [Visão Geral do Banco](../referencia/banco-de-dados/visao-geral.md)

---

## 1. A crítica e a resposta honesta

A crítica parte de um **equívoco parcial**: o Supabase é apenas uma **hospedagem do PostgreSQL** — quem modela e programa o banco continua sendo a equipe. E o banco do projeto **já usa recursos avançados, escritos à mão**, que vão além do que um ORM geraria automaticamente:

- **RLS multi-tenant** em todas as tabelas (isolamento por empresa via `auth.uid()`).
- **Funções PL/pgSQL** com `SECURITY DEFINER`, `SQLSTATE` customizado e `pg_advisory_xact_lock`.
- **Índices avançados**: parciais com `WHERE` (`uq_questions_company_order`), compostos, e `UNIQUE ... NULLS NOT DISTINCT` (`uq_feedback_insights_context`).
- **Triggers de validação de coerência** e uma **view cruzando schemas** (`enterprise_public`).

Ironicamente, ORMs "mágicos" como o **Prisma escondem o SQL** — demonstrariam *menos* domínio de banco, não mais. Por isso a escolha recai no **Drizzle (SQL-first)**: ele não esconde o SQL, e agrega o que vale num TCC — **tipagem ponta-a-ponta** e **migrations versionadas**.

## 2. O trade-off central: ORM × RLS

Hoje, num acesso autenticado, **o próprio banco** confere "esta linha é da empresa do usuário?" usando `auth.uid()` dentro das policies (ex.: `enterprise_id IN (SELECT id FROM enterprise WHERE auth_user_id = auth.uid())`).

Um ORM, porém, conecta ao Postgres por uma **connection string com uma role administrativa que IGNORA a RLS** (é o modo normal de operar com performance via pool). Propagar o JWT/claims do usuário para cada conexão e fazer a RLS valer também no Drizzle é **possível, mas frágil e lento** num pool compartilhado.

**Consequência:** ao usar o Drizzle, a checagem de "cada empresa só vê o seu" **migra para a aplicação** nesses caminhos. Um filtro de `enterprise_id` esquecido vira vazamento entre empresas. Reconhecer e tratar isso bem é, por si só, um bom ponto de discussão acadêmica.

## 3. A decisão

1. **Drizzle nos caminhos AUTENTICADOS/INTERNOS** (onde o backend já sabe de qual empresa é a requisição), **sempre com filtro explícito por `enterprise_id`**.
2. **O fluxo público anônimo (QR Code) NÃO usa Drizzle** — continua via cliente Supabase + RLS, que é a fronteira de segurança correta para um papel `anon` não confiável.
3. **A RLS permanece LIGADA em todas as tabelas**, como **defesa em profundidade**: mesmo que um filtro de aplicação falhe, a policy do banco é a segunda barreira.
4. **Adoção incremental, não migração total**: começamos por um caminho de leitura (as agregações de stats — fundação da [Etapa 02](../../proximos-passos/02-metricas-por-periodo-e-comparacao.md)); o resto migra sob demanda, declarado como trabalho futuro.

## 4. Mitigações (como evitamos o vazamento entre empresas)

- **Helper único de query tenant-scoped:** todo acesso via Drizzle passa por um helper que **sempre injeta `enterprise_id`** — em vez de cada consulta lembrar de filtrar. (A introduzir junto da migração do stats — Etapa 01-3.)
- **Teste de isolamento multi-tenant:** teste automatizado garantindo que uma requisição da empresa A **nunca** retorna linha da empresa B pelo caminho via Drizzle.
- **RLS como rede de segurança:** mantida ligada; um esquecimento de filtro é contido pela policy do banco.
- **Code review** focado em qualquer query Drizzle sem `enterprise_id`.

## 5. O que NÃO faremos (e por quê)

- **NÃO Prisma** — esconde o SQL e a modelagem real; demonstraria menos domínio de banco, o oposto do que a banca pediu.
- **NÃO migração total** para o ORM de uma vez — o fluxo anônimo é mais seguro sob RLS; migrá-lo traria risco sem ganho.
- **NÃO trocar Express por NestJS** — é framework de aplicação, não de banco; não melhora a demonstração de modelagem de dados.

## 6. Conexão e introspecção (operacional)

- **Runtime (app):** `src/db/client.ts` conecta lazy, com `prepare: false` (obrigatório no pooler do Supabase em modo transação, porta 6543) e pool pequeno (`max: 3`).
- **drizzle-kit:** `drizzle.config.ts` com **`schemaFilter: ['public']`** — introspecção e migrations atuam **apenas no schema `public`**, nunca no `auth` (gerenciado pelo Supabase).
- O schema canônico é a **introspecção do banco real** (`npm run db:pull` → `drizzle/schema.ts`). FKs cruzadas para `auth.users` usam o helper `authUsers` de `drizzle-orm/supabase`, re-exportado como `usersInAuth` (reaplicar após cada `db:pull`).

> **Achado da introspecção (importante):** o banco de produção tem **mais constraints do que os dumps em `database/sql/`** — FKs ausentes nos dumps (`feedback → collection_points`, `feedback → tracked_devices`, `enterprise.auth_user_id → auth.users`, `tracked_devices.blocked_by → auth.users`), CHECKs (`rating 1..5`, `sentiment`, `gender`, `collection_points.type/status`), uniques 1:1 (`feedback_analysis.feedback_id`, `collecting_data_enterprise.enterprise_id`) e índices extras. Conclusão: os dumps `database/sql/` estão **defasados**; a partir de agora a **fonte da verdade do schema é a introspecção do Drizzle**, e os dumps devem ser regenerados ou tratados como legado.

## 7. O que isso demonstra no TCC

- **Modelagem de dados relacional** e **uso consciente de um ORM SQL-first** e seus limites.
- **Isolamento multi-tenant** e a discussão (rara em TCCs) do **trade-off entre ORM e segurança no nível do banco** — defesa em profundidade na prática.
- **Migrations e versionamento de esquema** com histórico (Etapa 01-4).
