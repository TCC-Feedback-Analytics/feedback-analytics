# Migrations com Drizzle (convenção)

> **Em uma frase:** o schema em [`drizzle/schema.ts`](../../backends/api-gateway/drizzle/schema.ts) é a fonte da verdade; mudanças nascem como **migrations versionadas** geradas por `drizzle-kit generate` e aplicadas por `drizzle-kit migrate`. Os dumps em `database/sql/` viram **legado**.

Relacionado: [ORM × RLS: nossa decisão](orm-rls-decisao.md).

## Estrutura da pasta `backends/api-gateway/drizzle/`

| Arquivo | Papel |
|---|---|
| `schema.ts` | **Fonte da verdade** do schema (introspectado do banco real via `db:pull`, depois mantido à mão). |
| `relations.ts` | Relações para a query API do Drizzle (gerado; opcional). |
| `0000_*.sql` | **Baseline** — representa o estado ATUAL do banco. **Não é aplicado** (o banco já existe). |
| `0001_*.sql` | Primeira migration incremental de exemplo: cria o índice `idx_feedback_enterprise_created_at` (fundação da Etapa 02). |
| `meta/_journal.json` + `meta/*_snapshot.json` | Histórico e snapshots usados pelo `generate` para fazer o diff. |

## Scripts (em `backends/api-gateway`)

| Comando | O que faz | Precisa do banco? |
|---|---|---|
| `npm run db:pull` | Introspecta o banco → regenera `schema.ts` | sim (leitura) |
| `npm run db:generate` | Faz o **diff** schema × último snapshot → nova migration SQL | **não** (offline) |
| `npm run db:migrate` | Aplica as migrations pendentes no banco | sim |
| `npm run db:check` | Valida consistência das migrations | não |
| `npm run db:studio` | Abre o Drizzle Studio | sim |

## Fluxo de uma mudança de schema (daqui pra frente)

1. Edite `drizzle/schema.ts` (ex.: adicione uma coluna, índice, tabela).
2. `npm run db:generate` → cria `drizzle/000N_*.sql` (revise o SQL!).
3. `npm run db:migrate` → aplica no banco.
4. Commit do `schema.ts` + da migration + do snapshot juntos.

> O `db:generate` é **offline** e seguro de rodar a qualquer momento. **Sempre revise** o SQL gerado antes de aplicar.

## ⚠️ Baseline: o banco já existe

Como o Drizzle foi adotado sobre um banco **já populado** (Supabase), o `0000` descreve o que **já está lá** e **não deve ser aplicado** (rodar os `CREATE TABLE` falharia — as tabelas existem). É preciso dizer ao Drizzle "o 0000 já está aplicado" **uma única vez**, antes do primeiro `db:migrate`:

```sql
-- BASELINE (rodar UMA vez no SQL Editor do Supabase): marca o 0000 como aplicado
-- sem executá-lo. Depois disso, `npm run db:migrate` aplica só o 0001 em diante.
CREATE SCHEMA IF NOT EXISTS drizzle;
CREATE TABLE IF NOT EXISTS drizzle."__drizzle_migrations" (
  id SERIAL PRIMARY KEY,
  hash text NOT NULL,
  created_at bigint
);
INSERT INTO drizzle."__drizzle_migrations" (hash, created_at)
VALUES ('44d4e84d8f77652c511524a620d4ee97f43b2e049c379e532ff9e53b11e5d81f', 1782652609488);
```

(`hash` = sha256 do arquivo `0000_bumpy_the_order.sql`; `created_at` = o `when` dele no `_journal.json`. Se o `0000` for regenerado, recalcule.)

Depois do baseline:

```bash
npm --prefix backends/api-gateway run db:migrate   # aplica o 0001 (o índice)
```

**Atalho para a demo:** o `0001` é uma linha só; dá para aplicar direto no SQL Editor sem baseline:

```sql
CREATE INDEX "idx_feedback_enterprise_created_at"
  ON "feedback" USING btree ("enterprise_id","created_at" DESC NULLS LAST);
```

## Decisões e ressalvas (honestas)

- **`auth.users` no baseline:** o `0000` inclui um `CREATE TABLE "auth"."users"` mínimo. É só representação para resolver as FKs cruzadas (`enterprise.auth_user_id`, `tracked_devices.blocked_by`); como o `0000` **nunca é aplicado** e o `schemaFilter` é `['public']`, as migrations **nunca tocam** o schema `auth` (gerenciado pelo Supabase).
- **Baseline foi resetado:** o `db:pull` com `schemaFilter:['public']` gerou um baseline inconsistente (registrava a FK para `auth.users` sem a tabela), o que fazia o `generate` querer **criar `auth.users`** numa migration. Resetamos o baseline (`0000`) para que schema e snapshot concordem; assim o `0001` sai limpo (só o índice).
- **Imperfeições da introspecção:** o baseline carrega pequenas imperfeições do `db:pull` (CHECKs com `NOT VALID`, e o `uq_feedback_insights_context` sem `NULLS NOT DISTINCT`). Como o `0000` não é aplicado, **não afetam o banco atual**; só seriam relevantes num rebuild do zero — reconciliar nesse caso.
- **`database/sql/` é legado:** os dumps SQL antigos param de ser a fonte da verdade do schema. Mantenha-os como referência/histórico ou regenere a partir do banco; mudanças novas nascem como migration Drizzle.

## O que isso demonstra no TCC

- **Migrations versionadas** com histórico e diff automático (declarativo), em vez de SQL escrito à mão.
- **Adoção de ORM sobre banco existente** — o problema real de *baseline*, resolvido de forma consciente.
- **Fronteira clara com o Supabase** — o que o Drizzle gerencia (`public`) e o que fica fora (`auth`).
