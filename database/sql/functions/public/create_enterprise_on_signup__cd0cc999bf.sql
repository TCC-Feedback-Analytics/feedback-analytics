-- Descrição: Trigger function de pós-signup para criar empresa e validar dados.
-- Uso: Garante consistência de documento/telefone e saneia metadata.

CREATE OR REPLACE FUNCTION public.create_enterprise_on_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  meta jsonb := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_account_type       text        := NULLIF(meta->>'account_type', '');
  v_document           text        := NULLIF(meta->>'document', '');
  v_terms_version      text        := NULLIF(meta->>'terms_version', '');
  v_terms_accepted_at  timestamptz := NULLIF(meta->>'terms_accepted_at', '')::timestamptz;
  v_phone              text        := NULLIF(meta->>'phone', '');
  v_enterprise_id      uuid;
  v_exists int;
BEGIN
  -- documento obrigatório
  IF v_document IS NULL THEN
    RAISE EXCEPTION 'document is required' USING ERRCODE = '23514';
  END IF;

  -- valida duplicidade de documento antes de inserir
  SELECT 1 INTO v_exists
  FROM public.enterprise e
  WHERE e.document = v_document
  LIMIT 1;

  IF v_exists = 1 THEN
    RAISE EXCEPTION 'document_already_exists' USING ERRCODE = '23505';
  END IF;

  -- Insere a empresa. A barreira REAL contra documento duplicado é o
  -- UNIQUE(document); o SELECT acima é só otimização de mensagem amigável.
  -- Numa corrida (dois signups simultâneos passam pelo SELECT), o INSERT viola
  -- o UNIQUE e re-erguemos como 'document_already_exists' para manter o 409
  -- consistente. O conflito por auth_user_id segue idempotente no ON CONFLICT
  -- (re-disparo do trigger não duplica), então o único unique_violation que
  -- pode escapar do INSERT é o de documento.
  BEGIN
    INSERT INTO public.enterprise (document, account_type, terms_version, terms_accepted_at, auth_user_id, trial_ends_at, subscription_status)
    VALUES (v_document, v_account_type, v_terms_version, v_terms_accepted_at, NEW.id, NOW() + INTERVAL '4 months', 'TRIAL')
    ON CONFLICT (auth_user_id) DO NOTHING;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'document_already_exists' USING ERRCODE = '23505';
  END;

  -- Busca a enterprise atual para semear perguntas padrão no contexto COMPANY.
  SELECT e.id INTO v_enterprise_id
  FROM public.enterprise e
  WHERE e.auth_user_id = NEW.id
  LIMIT 1;

  IF v_enterprise_id IS NOT NULL AND to_regclass('public.questions_of_feedbacks') IS NOT NULL THEN
    INSERT INTO public.questions_of_feedbacks (
      enterprise_id,
      scope_type,
      catalog_item_id,
      question_order,
      question_text,
      is_active
    )
    SELECT
      v_enterprise_id,
      'COMPANY',
      NULL,
      q.question_order,
      q.question_text,
      true
    FROM (
      VALUES
        (1, 'Como foi sua experiência em relação ao atendimento?'),
        (2, 'O que você achou da qualidade do produto/serviço?'),
        (3, 'Como você avalia a relação entre o valor pago e a qualidade do produto/serviço?')
    ) AS q(question_order, question_text)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.questions_of_feedbacks existing
      WHERE existing.enterprise_id = v_enterprise_id
        AND existing.scope_type = 'COMPANY'
        AND existing.catalog_item_id IS NULL
        AND existing.question_order = q.question_order
    );
  END IF;

  -- valida duplicidade de telefone antes de atualizar auth.users
  IF v_phone IS NOT NULL THEN
    SELECT 1 INTO v_exists
    FROM auth.users u
    WHERE u.phone = v_phone AND u.id <> NEW.id
    LIMIT 1;

    IF v_exists = 1 THEN
      RAISE EXCEPTION 'phone_already_exists' USING ERRCODE = '23505';
    END IF;
  END IF;

  -- atualiza telefone de forma segura e higieniza metadados
  UPDATE auth.users
     SET phone = COALESCE(auth.users.phone, v_phone),
         raw_user_meta_data =
           COALESCE(raw_user_meta_data, '{}'::jsonb)
           - 'phone'
           - 'document'
           - 'company_name'
           - 'account_type'
           - 'terms_version'
           - 'terms_accepted_at'
           - 'email'
           - 'email_verified'
           - 'phone_verified'
   WHERE id = NEW.id;

  RETURN NEW;
END;
$function$


