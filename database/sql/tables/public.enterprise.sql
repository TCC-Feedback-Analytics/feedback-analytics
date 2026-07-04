-- Descrição: Cadastro da empresa vinculada ao usuário autenticado.
-- Uso: Entidade raiz de autorização para dados de negócio (RLS por auth_user_id).

-- public.enterprise
CREATE SCHEMA IF NOT EXISTS "public";

CREATE TABLE IF NOT EXISTS "public"."enterprise" (
  "document" text NOT NULL,
  "auth_user_id" uuid NOT NULL,
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now(),
  "account_type" text,
  "terms_version" text,
  "terms_accepted_at" timestamp with time zone,
  PRIMARY KEY ("id")
);

ALTER TABLE "public"."enterprise" ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Usuários autenticados podem criar sua empresa" ON "public"."enterprise";
CREATE POLICY "Usuários autenticados podem criar sua empresa" ON "public"."enterprise"
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK ((auth.uid() = auth_user_id));

DROP POLICY IF EXISTS "Usuários autenticados veem apenas sua empresa" ON "public"."enterprise";
CREATE POLICY "Usuários autenticados veem apenas sua empresa" ON "public"."enterprise"
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING ((auth.uid() = auth_user_id));

DROP POLICY IF EXISTS "Usuários podem atualizar sua própria empresa" ON "public"."enterprise";
CREATE POLICY "Usuários podem atualizar sua própria empresa" ON "public"."enterprise"
  AS PERMISSIVE
  FOR UPDATE
  TO public
  USING ((auth.uid() = auth_user_id))
  WITH CHECK ((auth.uid() = auth_user_id));

-- Trial / Subscription
ALTER TABLE "public"."enterprise"
  ADD COLUMN IF NOT EXISTS "trial_ends_at" timestamp with time zone,
  ADD COLUMN IF NOT EXISTS "subscription_status" text DEFAULT 'TRIAL';

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enterprise_subscription_status_check'
      AND conrelid = 'public.enterprise'::regclass
  ) THEN
    ALTER TABLE "public"."enterprise"
      ADD CONSTRAINT enterprise_subscription_status_check
        CHECK (subscription_status IN ('TRIAL', 'ACTIVE', 'EXPIRED', 'CANCELED'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enterprise_account_type_check'
      AND conrelid = 'public.enterprise'::regclass
  ) THEN
    ALTER TABLE "public"."enterprise"
      ADD CONSTRAINT enterprise_account_type_check
        CHECK (account_type IS NULL OR account_type IN ('CPF', 'CNPJ'));
  END IF;
END $$;

-- Unicidade
-- Barreira REAL (atômica, à prova de corrida) contra cadastros duplicados, e
-- pré-requisito do `ON CONFLICT (auth_user_id)` usado pela trigger
-- create_enterprise_on_signup. Idempotente: só cria se ainda não existir.
--
-- ATENÇÃO: se já houver duplicatas no banco, o ADD CONSTRAINT FALHA. Rode antes
-- e limpe o que retornar:
--   SELECT document, count(*)     FROM public.enterprise GROUP BY document     HAVING count(*) > 1;
--   SELECT auth_user_id, count(*) FROM public.enterprise GROUP BY auth_user_id HAVING count(*) > 1;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enterprise_document_key'
      AND conrelid = 'public.enterprise'::regclass
  ) THEN
    ALTER TABLE "public"."enterprise"
      ADD CONSTRAINT enterprise_document_key UNIQUE (document);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'enterprise_auth_user_id_key'
      AND conrelid = 'public.enterprise'::regclass
  ) THEN
    ALTER TABLE "public"."enterprise"
      ADD CONSTRAINT enterprise_auth_user_id_key UNIQUE (auth_user_id);
  END IF;
END $$;

-- Triggers
DROP TRIGGER IF EXISTS "set_updated_at" ON "public"."enterprise";
CREATE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."enterprise"
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();


