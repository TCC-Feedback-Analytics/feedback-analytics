# Testes Manuais — API Gateway

!!! note "Por que este runbook existe"
    As suítes automatizadas de **integração** (`src/tests/integration/*.itest.ts`) e o **e2e de cutover** (`src/tests/e2e/authCutover.e2e.ts`) — que rodavam contra um Postgres local (docker `:5433`) com seed determinístico — foram **removidas**. A cobertura passou a ser **manual**, reproduzível por este roteiro (via a UI do app e/ou `curl` aos endpoints). Os testes **unitários** (mockados, `src/tests/*.test.ts`) continuam automatizados no CI.

## Pré-requisitos

Estes cenários substituem a suíte automatizada que rodava contra o Postgres local (docker `:5433`) com seed determinístico. O ambiente comum abaixo vale para **todas** as seções.

### Subir a infraestrutura

1. Suba o banco local e o Mailpit (captura de e-mails): `npm run db:local:up` (executa `docker compose up -d`). Isso expõe:
   - Postgres em `127.0.0.1:5433` (container `feedback-api-db`), usuário `postgres`, senha `postgres`, database `feedback`.
   - Mailpit em `http://localhost:8025` (UI web) e SMTP em `127.0.0.1:1025` — é onde caem os e-mails de confirmação/recuperação.
2. Garanta o `.env` local. Valores mínimos (ver `.env.example`):
   - `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5433/feedback`
   - `BETTER_AUTH_SECRET=<qualquer segredo>` e `BETTER_AUTH_URL=http://localhost:3000`
   - `IA_ANALYZE_EXECUTION_MODE=local` (para os fluxos de IA)
   - `IA_CONFIG_ENCRYPTION_KEY=<gere com: openssl rand -base64 32>` (cifra a chave OpenRouter; sem ela, salvar a chave responde 500)
   - `E2E_TEST_EMAIL`, `E2E_TEST_PASSWORD`, `E2E_TEST_ENTERPRISE_ID` (obrigatórios — sem eles o `db:reset` falha).
   - Opcionais: `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` (só para a seção do login com Google; sem elas o Google fica desligado).

### Resetar e semear (estado pristino)

3. Rode `npm run db:reset`. Isso faz `DROP SCHEMA` → `drizzle-kit migrate` → aplica `db/local/seed.sql` → provisiona a fixture E2E (`scripts/seed-e2e-user.ts`). Recria o dataset determinístico das empresas A e B. A fixture cria o usuário de teste com o nome `Gestor E2E`, marca o e-mail como verificado e **vincula a ele** a empresa de `E2E_TEST_ENTERPRISE_ID` (troca o `auth_user_id` dela).
4. **Regra de ouro:** rode `npm run db:reset` **antes de cada seção** que verifica contagens (listas, estatísticas, análises). Os testes originais zeravam o estado a cada arquivo; aqui o reset cumpre o mesmo papel e garante os números exatos.

### Subir a API

5. `npm run dev` (executa `tsx watch index.ts`). A API sobe em `http://localhost:3000`. Todas as rotas ficam sob `http://localhost:3000/api/...`. Para conferir: `curl http://localhost:3000/api/health` → `{"ok":true}`.

### Identidades de teste

- **Gestor A** — `user_id 11111111-1111-1111-1111-111111111111`, empresa A `aaaaaaaa-0000-0000-0000-000000000001` (`TRIAL`). E-mail no seed: `gestor.a@teste.local`.
- **Gestor B** — `user_id 22222222-2222-2222-2222-222222222222`, empresa B `bbbbbbbb-0000-0000-0000-000000000001` (`TRIAL`). E-mail no seed: `gestor.b@teste.local`.
- O CPF/CNPJ não existe mais (migration `0009`): o seed e a API não têm documento da empresa.
- Os gestores A/B do `seed.sql` **não têm senha** (o seed não cria conta de credencial no Better Auth). Para exercitar os endpoints **protegidos** com os dados do seed, use a **fixture E2E** do `.env` apontando `E2E_TEST_ENTERPRISE_ID` para a empresa A — assim o login expõe exatamente o dataset de A. Alternativamente, para os fluxos de escrita/QR/auth, **registre um gestor novo** (começa com a empresa e as 3 perguntas padrão, sem feedbacks).
- Para entrar como **B** com o dataset do seed, provisione um segundo usuário de teste vinculado a B, sem mudar o `.env` (o `dotenv` não sobrescreve variável já definida no shell): `E2E_TEST_EMAIL=<outro e-mail> E2E_TEST_ENTERPRISE_ID=bbbbbbbb-0000-0000-0000-000000000001 npm run db:seed:e2e`. Ele usa a mesma `E2E_TEST_PASSWORD`; salve o cookie dele em `cookies-b.txt`.
- Com a fixture vinculada, o nome público da empresa (view `enterprise_public`, que lê o nome do dono) passa a ser `Gestor E2E`, e não mais `Gestor A`/`Gestor B`.
- As seções **públicas** (`/api/public/...`) não exigem login e usam os IDs de A/B diretamente — reproduzem os testes sem nenhuma ponte.

### Convenções para os comandos `curl`

Defina no shell (Git Bash) para encurtar os exemplos:

```bash
BASE=http://localhost:3000/api
ENT_A=aaaaaaaa-0000-0000-0000-000000000001
ENT_B=bbbbbbbb-0000-0000-0000-000000000001
QR_A=cccccccc-0000-0000-0000-0000000000aa      # ponto QR "Geral A"
QR_B=cccccccc-0000-0000-0000-0000000000bb      # ponto QR "Geral B"
Q_A1=dddddddd-0000-0000-0000-0000000000a1      # pergunta COMPANY A, ordem 1
Q_A2=dddddddd-0000-0000-0000-0000000000a2      # pergunta COMPANY A, ordem 2
```

Autenticação (gera o cookie de sessão httpOnly do Better Auth e o salva em `cookies-a.txt`):

```bash
curl -i -c cookies-a.txt -X POST "$BASE/public/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"<E2E_TEST_EMAIL>","password":"<E2E_TEST_PASSWORD>"}'
```

Nas chamadas protegidas, reenvie o cookie com `-b cookies-a.txt`. Sufixo ` | jq` é opcional (formata o JSON).

As rotas nativas do Better Auth (`/api/auth/...`, como a exclusão de conta) conferem a origem quando a requisição leva cookie: sem o header `Origin` de uma origem confiável, respondem **403**. No `curl`, acrescente `-H 'Origin: http://localhost:5173'`.

Os erros da API vêm como JSON com o código em `error` (muitas vezes acompanhado de `message`). Onde o roteiro diz "**400** `invalid_payload`", confira o `error` do corpo.

Verificação opcional por SQL (**somente leitura** — nunca escreva):

```bash
docker exec -it feedback-api-db psql -U postgres -d feedback -c "SELECT ..."
```

### Dataset determinístico do seed (resumo)

- **Empresa A**: 5 feedbacks com notas 5, 4, 2, 3, 5 (soma 19 → média 3,8); 3 deles com análise de IA (2 `positive`, 1 `negative`); 2 perguntas COMPANY ativas; 1 ponto QR "Geral A" ativo; 1 relatório de insights COMPANY cujo resumo cita "atendimento".
- **Empresa B**: 2 feedbacks com notas 5 e 1 (média 3); nenhuma análise de IA; nenhuma pergunta; 1 ponto QR "Geral B" ativo; 1 relatório de insights COMPANY cujo resumo cita "corte".
- Nas duas: nenhum feedback com canal (`channel` nulo), nenhuma configuração de IA (sem chave OpenRouter), nenhum campo de comentário configurado (vale o convite padrão) e nenhum diagnóstico. A empresa A tem os três campos de contexto preenchidos e perguntas COMPANY próprias (não as padrão).
- Invariante central de **todas** as seções: **isolamento por `enterprise_id`** — nenhum tenant enxerga dados do outro.

---

## Autenticação e acesso protegido (`authCutover.e2e`)

Cobre o corte para Better Auth: sessão por cookie, leitura da própria empresa, isolamento e os endpoints públicos de auth. Aqui a UI equivalente é a tela de login/registro do frontend; os passos abaixo usam HTTP direto.

### Preparação: registrar dois gestores (A e B)

**Objetivo:** ter dois gestores autenticáveis e isolados.
**Pré-condições:** API no ar; Mailpit acessível.
**Passos:**
1. `curl` `POST $BASE/public/auth/register` com corpo (`fullName` é o nome do negócio; telefone no formato `+55DDXXXXXXXXX`; a senha precisa de pelo menos 10 caracteres e nota 4 no zxcvbn — uma frase curta passa, e ela não pode conter o nome, o e-mail nem o telefone):
   ```json
   {"fullName":"Gestor A","email":"a@x.local","phone":"+5511900000001","password":"sol azul de manha","confirmPassword":"sol azul de manha","terms":true}
   ```
2. Repita para o gestor B (`b@x.local`, phone `+5511900000002`).
3. Confirme o e-mail: abra `http://localhost:8025`, clique no link de confirmação de cada conta (via UI). O teste original atalhava isso marcando `email_verified=true` direto no banco.
4. Faça login de cada um (`POST /public/auth/login`) salvando os cookies em `cookies-a.txt` e `cookies-b.txt`.

**Resultado esperado:** cada registro retorna 200 `{"ok":true,"message":"confirmation_required"}`; após confirmar e logar, cada login retorna 200 com `Set-Cookie` de sessão. O cadastro já cria a empresa (`TRIAL`) e as 3 perguntas COMPANY padrão. Senha fraca → **400** `password_too_weak`.

### Bloqueio sem sessão

**Objetivo:** rota protegida exige sessão.
**Passos:** `curl -i "$BASE/protected/user/enterprise"` (sem cookie).
**Resultado esperado:** **401**, corpo `{"error":"unauthorized"}`.

### Gestor lê a própria empresa

**Objetivo:** sessão → `enterpriseId` → dados corretos.
**Passos:** `curl -b cookies-a.txt "$BASE/protected/user/enterprise"`.
**Resultado esperado:** **200**; `enterprise.id` = empresa de A (anote); `enterprise.subscription_status` = `"TRIAL"`; `user.id` = id do gestor A; `user.email` = `a@x.local`.

### Isolamento entre gestores

**Objetivo:** cada gestor vê apenas a sua empresa.
**Passos:** `curl -b cookies-b.txt "$BASE/protected/user/enterprise"`.
**Resultado esperado:** **200**; `user.id` = id de B; `enterprise.id` = empresa de B e **diferente** da de A.

### collecting_data: escrita + leitura + isolamento

**Objetivo:** provar sessão → `enterpriseId` → Drizzle (transação), sem vazamento.
**Passos:**
1. `GET $BASE/protected/user/collecting_data` (cookie A) numa empresa recém-criada.
2. `PATCH $BASE/protected/user/collecting_data` (cookie A) com `{"company_objective":"Objetivo E2E A"}`.
3. `GET` de novo (cookie A).
4. `GET` com cookie B.
5. `GET $BASE/protected/user/collection-points/qr/status` (cookie A).

**Resultado esperado:** passo 1 → 200 `{"collecting":null}`; passo 2 → 200; passo 3 → `collecting.company_objective` = `"Objetivo E2E A"`; passo 4 → `{"collecting":null}` (B não vê A); passo 5 → 200 `{"active":false,"id":null}` (o cadastro não cria ponto de coleta).

### QR ponta-a-ponta, isolado

**Objetivo:** habilitar o QR reflete no status e não vaza para o outro tenant.
**Passos:**
1. `POST $BASE/protected/user/collection-points/qr/enable` (cookie A, corpo `{}`).
2. `GET .../qr/status` (cookie A).
3. `GET .../qr/status` (cookie B).

**Resultado esperado:** passo 1 → 200 `{"active":true,"id":<uuid>}`; passo 2 → `active:true` e `id` igual ao retornado; passo 3 → `active:false` (a escrita de A não vazou).

### Endpoints públicos de auth via HTTP

Todos sob `$BASE/public/auth`. Valores de erro são os que o teste verifica.

| Cenário | Requisição | Resultado esperado |
|---|---|---|
| Login válido | `POST /login` `{email,password}` válidos | **200**, `{"ok":true,"user":{"id":...,"email":...}}`, header `Set-Cookie` presente |
| Senha errada | `POST /login` senha inválida | **401**, `error` = `invalid_credentials` |
| E-mail não verificado (RNE-014) | registre um usuário e **não** confirme; `POST /login` | **401**, `error` = `invalid_credentials`; o corpo **não** pode conter `confirm` nem `verificad` (anti-enumeração) |
| Payload inválido no login | `POST /login` `{"email":"nao-eh-email","password":"123"}` | **400**, `error` = `invalid_payload` |
| Register com e-mail já usado | `POST /register` com e-mail existente (e um telefone livre) | **200**, `{"ok":true,"message":"confirmation_required"}` (anti-enumeração) |
| Register com telefone já usado | `POST /register` com `phone` já existente | **409**, `error` = `phone_taken`. O telefone é conferido **antes** do e-mail |
| Register com senha fraca | `POST /register` com senha de 10+ caracteres e nota abaixo de 4 no zxcvbn (ex.: uma palavra comum repetida) | **400**, `error` = `password_too_weak` |
| Register payload inválido | `POST /register` `{"email":"x"}` | **400**, `error` = `invalid_payload` |
| Forgot-password (sempre 200) | `POST /forgot-password` `{email}` | **200**, `{"ok":true,"message":"Se este e-mail estiver cadastrado, você receberá as instruções em breve."}` |
| Forgot-password e-mail inválido | `POST /forgot-password` `{"email":"nao-eh-email"}` | **400**, `error` = `invalid_payload` |
| Resend-confirmation (sempre 200) | `POST /resend-confirmation` `{email}` com um e-mail que ainda não pediu reenvio | **200**, `{"ok":true,"message":"Se existir uma conta pendente...","retryAfterSeconds":60}`, com ou sem conta pendente |
| Resend-confirmation repetido | repita a mesma chamada logo em seguida | **429**, `error` = `rate_limited`, `retryAfterSeconds` no corpo e header `Retry-After` com o mesmo valor (use `curl -i`) |
| Resend-confirmation e-mail inválido | `POST /resend-confirmation` `{"email":"nao-eh-email"}` | **400**, `error` = `invalid_payload` |
| Logout | `POST /logout` com cookie de sessão | **204** (sem corpo) |

> O intervalo de 60 s do reenvio vem de `RESEND_EMAIL_COOLDOWN_SECONDS`; há também limite por e-mail (5 por hora) e por IP (20 a cada 15 min). Os contadores ficam no banco (`auth_rate_limit`): um `db:reset` zera tudo.

### Troca de e-mail

**Objetivo:** a troca de e-mail só vale depois da confirmação pelo endereço novo.
**Passos:**
1. `curl -i -b cookies-a.txt -X PATCH "$BASE/protected/user/email" -H 'Content-Type: application/json' -d '{"email":"novo-a@x.local"}'`.
2. `GET $BASE/protected/user/auth_user` com o cookie A.
3. No Mailpit, abra **"Confirme seu novo e-mail"** (enviado para `novo-a@x.local`) e clique no link.
4. Repita o passo 2.

**Resultado esperado:** passo 1 → **200** com `{"user":{"id":…,"email":"a@x.local"},"pending_email":"novo-a@x.local"}`; passo 2 → ainda `a@x.local`; passo 3 → o link passa por `/api/auth/verify-email` e volta para `<web>/auth/success`; passo 4 → `novo-a@x.local`. Com `{"email":"nao-eh-email"}` → **400** `invalid_payload`. Com um e-mail que já é de outra conta → **200**, mas nenhum e-mail sai e a conta não muda (o Better Auth não revela que o endereço existe).

### Guia do sistema (onboarding)

**Objetivo:** o fim do guia é gravado por usuário, e `completed` prevalece sobre `skipped`.
**Passos** (cookie A, conta recém-registrada):
1. `GET $BASE/protected/user/onboarding/system-guide`.
2. `PUT` na mesma rota com `{"version":1,"status":"skipped"}`.
3. `PUT` com `{"version":1,"status":"completed"}`.
4. `PUT` com `{"version":1,"status":"skipped"}` de novo.
5. `PUT` com `{"version":2,"status":"completed"}` e, depois, com `{"version":1,"status":"completed","extra":true}`.

**Resultado esperado:** passo 1 → 200 `{"tourKey":"system-guide","version":1,"status":"pending","finishedAt":null}`; passo 2 → `status` = `"skipped"` com `finishedAt` preenchido; passo 3 → `"completed"` com `finishedAt` novo; passo 4 → continua `"completed"` (não volta atrás); passo 5 → **400** `invalid_payload` nos dois. O cookie B continua vendo `"pending"` (o guia é do usuário).

### Entrar com o Google e completar o cadastro

**Objetivo:** a primeira entrada pelo Google cria a conta e a empresa; `complete-signup` grava telefone, nome do negócio e termos.
**Pré-condições:** `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` no `.env` (sem elas, o Google fica desligado e o cenário **não se aplica**) e a Web local apontando para esta API. O vaivém com o Google exige navegador.
**Passos:**
1. Na Web, em `/login`, use **"Continuar com Google"** com uma conta Google que ainda não existe no sistema. Por baixo, a Web chama `POST /api/auth/sign-in/social` com `provider: "google"` e a volta passa por `/api/auth/callback/google`.
2. Copie o cookie de sessão pelo DevTools do navegador (Application › Cookies) para `cookies-g.txt`, ou siga só pela Web.
3. `GET $BASE/protected/user/auth_user` → `phone` = `null`.
4. `POST $BASE/protected/user/complete-signup` com `{"fullName":"Negócio Google","phone":"+5511900000003","terms":true}`.
5. Repita o passo 4 com o telefone de outra conta (ex.: `+5511900000001`) e, à parte, com um campo extra (`"extra":1`).

**Resultado esperado:** passo 1 → a conta nova volta para `/auth/complete-signup`; passo 4 → **200** `{"ok":true}` e o `auth_user` passa a ter o telefone; passo 5 → **409** `phone_taken` e **400** `invalid_payload`. O mesmo e-mail com senha e com Google é a **mesma** conta.

### Excluir a conta (`POST /api/auth/delete-user`)

**Objetivo:** "Excluir minha conta" apaga o usuário, a empresa e tudo dela, sem volta.
**Pré-condições:** uma conta descartável — registre e confirme uma terceira (ex.: `c@x.local`, phone `+5511900000004`) e salve o cookie em `cookies-c.txt`. Não use a fixture E2E nem as contas A/B das outras seções.
**Passos:**
1. `curl -i -b cookies-c.txt -X POST "http://localhost:3000/api/auth/delete-user" -H 'Origin: http://localhost:5173' -H 'Content-Type: application/json' -d '{"password":"senha-errada-123"}'`.
2. A mesma chamada com a senha certa.
3. `GET $BASE/protected/user/enterprise` com `cookies-c.txt`.
4. `POST $BASE/public/auth/login` com `c@x.local` e a senha antiga.

**Resultado esperado:** passo 1 → **400** com `code` = `INVALID_PASSWORD` (nada é apagado); passo 2 → **200** `{"success":true,"message":"User deleted"}` e o cookie de sessão é limpo; passo 3 → **401** `unauthorized`; passo 4 → **401** `invalid_credentials`. Sem o header `Origin`, o passo 1 já responde **403**.

**Verificação opcional (SQL, leitura):**
```sql
SELECT count(*) FROM public."user" WHERE email = 'c@x.local';            -- 0
SELECT count(*) FROM public.enterprise e
  LEFT JOIN public."user" u ON u.id = e.auth_user_id WHERE u.id IS NULL;  -- 0 (nenhuma empresa órfã)
```

---

## Empresa / perfil do gestor (`enterprise.itest`)

Cobre `resolveEnterpriseIdByUser` — resolução tenant-safe do gestor para a sua empresa.

### Usuário resolve para a própria empresa

**Objetivo:** cada gestor resolve exatamente a sua empresa; usuário sem empresa não resolve nada.
**Pré-condições:** autenticado como gestor de A e como gestor de B (cookies distintos).
**Passos:**
1. `GET $BASE/protected/user/enterprise` com cookie A.
2. `GET $BASE/protected/user/enterprise` com cookie B.

**Resultado esperado:** A retorna a empresa A; B retorna a empresa B (nunca a de A). Um usuário sem empresa vinculada não passa pelo isolamento — a rota responde **404 enterprise_not_found** (equivalente ao `null` do teste).

**Verificação opcional (SQL, leitura):**
```sql
-- a fixture E2E é a dona da empresa A depois do db:reset
SELECT e.id FROM public.enterprise e
  JOIN public."user" u ON u.id = e.auth_user_id
 WHERE u.email = '<E2E_TEST_EMAIL>';
-- deve retornar aaaaaaaa-0000-0000-0000-000000000001 e nunca a de B
```

---

## Dados de coleta / `collecting_data` (`collectingData.itest`)

Cobre perfil (get/patch por usuário) e o upsert/patch transacional de `collecting_data` + catálogo + perguntas COMPANY. Use um **gestor recém-registrado** (empresa vazia) para não corromper o seed; ou rode `db:reset` ao final.

### Perfil em snake_case

**Objetivo:** `GET` devolve o perfil da empresa em snake_case.
**Passos:** `GET $BASE/protected/user/enterprise` (autenticado).
**Resultado esperado:** 200; `enterprise` com `id`, `terms_version`, `terms_accepted_at`, `created_at`, `trial_ends_at` e `subscription_status` (`TRIAL`); `user` com `id`, `email` e `phone`. Não há mais `document` nem `account_type`.

### PATCH aplica só as chaves presentes

**Objetivo:** atualizar apenas os campos enviados, preservando o resto.
**Passos:** `PATCH $BASE/protected/user/enterprise` com `{"terms_version":"v2"}`.
**Resultado esperado:** 200; `enterprise.terms_version` = `"v2"`; `enterprise.terms_accepted_at` **inalterado**. (Campos aceitos: `terms_version`, de 1 a 32 caracteres, e `terms_accepted_at`, data ISO 8601. Corpo vazio ou só com campos desconhecidos, como o antigo `account_type`, → **400** `invalid_payload`.)

### Upsert cria collecting + catálogo + 3 perguntas COMPANY

**Objetivo:** `PUT` cria a linha de coleta, o catálogo e sincroniza as 3 perguntas COMPANY.
**Passos:** `PUT $BASE/protected/user/collecting_data` com:
```json
{"company_objective":"Objetivo C","uses_company_products":true,
 "catalog_products":[{"name":"Prod A"}],
 "company_feedback_questions":[
   {"question_order":1,"question_text":"Como você avalia o atendimento recebido hoje aqui?","is_active":true,"subquestions":[]},
   {"question_order":2,"question_text":"Como você avalia a qualidade geral dos produtos?","is_active":true,"subquestions":[]},
   {"question_order":3,"question_text":"A relação entre preço e qualidade foi satisfatória?","is_active":true,"subquestions":[]}]}
```
**Resultado esperado:** 200; `collecting.company_objective` = `"Objetivo C"`, `collecting.uses_company_products` = `true`; `catalog_products` com 1 item de `name` `"Prod A"` e `catalog_services` vazio; `company_feedback_questions` com 3 itens de `question_order` `[1,2,3]`.

### Catálogo: update do existente, insert do novo, soft-delete do ausente

**Objetivo:** ao reenviar o catálogo, item existente é atualizado, novo é inserido e omitido vira `INACTIVE` (não some do banco).
**Pré-condições:** ter 2 produtos (`P1`, `P2`) — crie via `PUT`/`PATCH` como acima.
**Passos:** `PATCH $BASE/protected/user/collecting_data` com `uses_company_products:true` e `catalog_products` contendo `P1` renomeado (mesmo `id`) e um novo `P3`, **omitindo** `P2`.
**Resultado esperado:** 200; o snapshot retornado (`catalog_products`, só ativos) contém apenas `["P1 renomeado","P3"]`. `P2` continua no banco como `INACTIVE`.

**Verificação opcional (SQL):**
```sql
SELECT status FROM public.catalog_items WHERE name = 'P2'; -- INACTIVE
```

### Subpergunta ausente vira INACTIVE (soft-delete)

**Objetivo:** remover uma subpergunta no PATCH a **desativa** (preserva a linha), não apaga.
**Passos:** crie Q1 com 1 subpergunta ativa; depois `PATCH` reenviando Q1 **sem** a subpergunta.
**Resultado esperado:** no snapshot, a subpergunta continua existindo porém com `is_active=false`.

### Atomicidade: rollback quando a pergunta é inválida

**Objetivo:** falha na sincronização de perguntas desfaz também o update do `collecting` (tudo numa transação).
**Passos:**
1. `PUT`/`PATCH` deixando `company_objective` = `"ANTES"`.
2. `PATCH $BASE/protected/user/collecting_data` com `company_objective:"DEPOIS"` **e** uma pergunta de texto curto demais (ex.: `"curto"` — viola o mínimo de 20 caracteres).
3. `GET $BASE/protected/user/collecting_data`.

**Resultado esperado:** passo 2 → **400** (`upsert_failed`); passo 3 → `collecting.company_objective` permanece `"ANTES"` (o update foi revertido junto com o sync). No teste original a violação era o `CHECK` (20–150 chars) no banco; via HTTP a validação barra antes, mas o invariante observável é o mesmo: 400 e nenhuma mutação.

---

## Pontos de coleta QR (`collectionPointsQr.itest`)

Cobre o QR "geral" (COMPANY) e o QR por item de catálogo: ativar/reusar/desativar/reativar (sempre o **mesmo** ponto), o upsert transacional de perguntas do item e o isolamento por tenant. Autenticado como gestor. O nome "QR" ficou nas rotas e no tipo `QR_CODE`, mas o ponto é o mesmo para os três canais: QR Code, link e etiqueta NFC.

### QR geral (COMPANY): criar, reusar, desativar, reativar

**Objetivo:** um único ponto COMPANY por empresa, reaproveitado.
**Passos:**
1. `GET .../collection-points/qr/status` → deve estar inativo.
2. `POST .../collection-points/qr/enable` (corpo `{}`) — anote o `id`.
3. `POST .../collection-points/qr/enable` de novo.
4. `POST .../collection-points/qr/disable`.
5. `POST .../collection-points/qr/enable` mais uma vez.

**Resultado esperado:** passo 1 → `{"active":false,"id":null}`; passo 2 → `{"id":<uuid>,"active":true}`; passo 3 → **mesmo `id`** (reusa o ativo, não cria outro); passo 4 → `{"active":false}` e status inativo; passo 5 → **mesmo `id`** do passo 2 (reativa o mesmo ponto).

### QR por item de catálogo: listar, ativar/reusar/desativar

**Objetivo:** ponto QR vinculado a um item de catálogo, com reuso do mesmo ponto.
**Pré-condições:** ter um item `PRODUCT` ativo — crie via `PUT/PATCH /collecting_data` com `catalog_products:[{"name":"Produto D"}]` e `uses_company_products:true`. Pegue o `catalog_item_id` no `GET .../qr/catalog?kind=PRODUCT`.
**Passos:**
1. `GET .../collection-points/qr/catalog?kind=PRODUCT` → o item aparece na lista.
2. `POST .../collection-points/qr/catalog/enable` com `{"catalog_item_id":"<id>"}` — anote `collection_point_id`.
3. Repita o passo 2.
4. `POST .../collection-points/qr/catalog/disable` com o mesmo `catalog_item_id`.
5. `POST .../collection-points/qr/catalog/enable` de novo.

**Resultado esperado:** passo 1 lista o item (`active:false`, `collection_point_id:null`); passo 2 → `{"collection_point_id":<uuid>,"active":true}`; passo 3 → **mesmo `collection_point_id`** (reusa); passo 4 → `{"active":false}` e no catálogo o item fica `active:false` (ponto `INACTIVE`); passo 5 → **mesmo `collection_point_id`** e existe **apenas um** ponto para o item.

### saveCatalogQuestions — transacional, contagem variável

**Objetivo:** salvar 1–3 perguntas por item; slot sem texto vira soft-delete; snapshot só mostra ativas.
**Endpoint:** `POST .../collection-points/qr/catalog/questions/upsert` — corpo exige `catalog_item_id` e exatamente **3 slots** em `questions` (texto entre 20 e 150 chars quando presente).
**Passos e resultados:**

1. **Criar 1 pergunta + 1 subpergunta:** enviar `questions` com slot 1 preenchido (com 1 subpergunta) e slots 2 e 3 vazios.
   → Resposta: `questions` do item com **1** pergunta (`question_order` 1) e **1** subpergunta.
2. **Re-save (atualiza/insere/desativa):** reenviar com o slot 1 com texto atualizado (sem subpergunta), slot 2 novo, slot 3 vazio.
   → Resposta: perguntas com `question_order` `[1,2]`; a de ordem 1 com o texto novo e **sem** subperguntas (a subpergunta removida foi desativada).
3. **Esvaziar todos os slots:** reenviar os 3 slots vazios.
   → Resposta: snapshot com **0** perguntas ativas. As linhas continuam no banco como `INACTIVE` (histórico preservado).

**Verificação opcional (SQL):**
```sql
SELECT count(*) FROM public.questions_of_feedbacks WHERE is_active = false; -- >= 2 após o passo 3
```

### Isolamento por tenant no item de catálogo

**Objetivo:** um gestor não acessa item de catálogo de outra empresa.
**Passos:** autenticado como gestor de A, `POST .../collection-points/qr/catalog/enable` com um `catalog_item_id` que pertence a **outra** empresa.
**Resultado esperado:** **404** (`getCatalogItemForEnterprise` retorna nada para o tenant errado) — o item não vaza entre empresas.

---

## Empresa pública (`publicEnterprise.itest`)

Endpoint **público** (sem login): `GET $BASE/public/enterprise/:id` com query opcional `collection_point` e `catalog_item`. Cobre a resolução da empresa via view pública e do ponto QR tenant-scoped.

### Empresa A resolve id + nome + ponto geral

**Passos:** `curl "$BASE/public/enterprise/$ENT_A"`.
**Resultado esperado:** 200; `id` = `$ENT_A`; `name` = nome do dono via view pública (`"Gestor E2E"` com a fixture vinculada a A; `"Gestor A"` só com o seed puro); `collection_point_id` = `$QR_A` (ponto "Geral A", escopo empresa); `catalog_item_id` = `null`; `questions` = as 2 perguntas COMPANY ativas; `comment` = `{"mode":"DEFAULT","prompt":null}` (sem campo de comentário configurado).

### Empresa inexistente → 404

**Passos:** `curl -i "$BASE/public/enterprise/dddddddd-0000-0000-0000-0000000000ff"`.
**Resultado esperado:** **404** (`enterprise_not_found`).

### Resolver por id do próprio ponto

**Passos:** `curl "$BASE/public/enterprise/$ENT_A?collection_point=$QR_A"`.
**Resultado esperado:** 200; `collection_point_id` = `$QR_A`.

### Isolamento: A pedindo o ponto de B

**Passos:** `curl "$BASE/public/enterprise/$ENT_A?collection_point=$QR_B"`.
**Resultado esperado:** 200, porém `collection_point_id` = `null` — o ponto de B **não** resolve sob a empresa A (escopo por tenant). No teste de repositório isso é `resolveQrCollectionPoint(...) => null`.

### Empresa B resolve o próprio ponto geral

**Passos:** `curl "$BASE/public/enterprise/$ENT_B"`.
**Resultado esperado:** 200; `collection_point_id` = `$QR_B`; `name` = `"Gestor B"` (ou `"Gestor E2E"`, se uma fixture foi vinculada a B). Nunca o ponto de A.

---

## Perguntas públicas por escopo (`publicQuestions.itest`)

Cobre `fetchActiveQuestionsForScope`, exposto no campo `questions` do endpoint público de empresa. Sem fallback entre escopos.

### A / COMPANY: 2 perguntas ativas ordenadas

**Passos:** `curl "$BASE/public/enterprise/$ENT_A"` (escopo empresa por padrão).
**Resultado esperado:** `questions` com 2 itens; o primeiro com `question_order` = 1, `scope_type` = `"COMPANY"`, `catalog_item_id` = `null`, e `subquestions` como array.

### Isolamento: B (sem perguntas) → lista vazia

**Passos:** `curl "$BASE/public/enterprise/$ENT_B"`.
**Resultado esperado:** `questions` = `[]` (B não vê as perguntas de A).

### Escopo PRODUCT sem perguntas → lista vazia (sem fallback)

**Objetivo:** um escopo sem perguntas configuradas retorna `[]` — **não** cai de volta para as perguntas COMPANY.
**Passos:** configure um item `PRODUCT` com QR ativo **e sem perguntas** (seção de QR por catálogo, passo "esvaziar slots"); depois `curl "$BASE/public/enterprise/$ENT_A?catalog_item=<produtoId>"`.
**Resultado esperado:** `item_kind` = `"PRODUCT"` e `questions` = `[]`.

---

## Envio de feedback pelo formulário público (`qrFeedback.itest`)

Endpoint **público**: `POST $BASE/public/qrcode/feedback`. Escrita atômica (dispositivo + feedback + respostas), deduplicação diária, isolamento e anti-adulteração. O corpo exige `enterprise_id`, `rating` e `answers` (que devem **casar exatamente** com as perguntas ativas do escopo) e aceita, opcionalmente, `channel`, `message` (comentário, até 5000 caracteres), `subanswers`, `collection_point_id`/`catalog_item_id` e dados do cliente.

> `channel` é o canal de coleta: `QR`, `LINK`, `NFC` ou `TEST` (o "Testar o formulário" do Dashboard). Valor ausente, desconhecido ou o antigo `QRCODE` não recusa o envio: o feedback é gravado com `channel` nulo ("sem a marca de canal").

> O "dispositivo" é um fingerprint `md5(user-agent | ip | dia)`. Via `curl` do mesmo host/dia, o fingerprint se repete; troque o header `User-Agent` para simular outro dispositivo.

### Feedback anônimo com respostas (empresa A)

**Objetivo:** criar dispositivo + feedback + respostas numa transação.
**Pré-condições:** `db:reset` recente; empresa A tem 2 perguntas COMPANY ativas (`Q_A1`, `Q_A2`).
**Passos:**
```bash
curl -X POST "$BASE/public/qrcode/feedback" -H 'Content-Type: application/json' \
 -d "{\"channel\":\"QR\",\"enterprise_id\":\"$ENT_A\",\"collection_point_id\":\"$QR_A\",
      \"rating\":5,\"message\":\"itest com respostas\",
      \"answers\":[{\"question_id\":\"$Q_A1\",\"answer_value\":\"OTIMA\"},
                   {\"question_id\":\"$Q_A2\",\"answer_value\":\"BOA\"}]}"
```
**Resultado esperado:** 200 `{"ok":true}`. O feedback foi persistido com 2 respostas. Verificável autenticado como gestor de A: `GET $BASE/protected/user/feedbacks` passa a listar 6 feedbacks (5 do seed + 1), e o novo vem com `channel` = `"QR"`.

### Feedback sem perguntas (empresa B — 0 respostas)

**Objetivo:** happy path com `answers` vazio quando o escopo não tem perguntas ativas.
**Passos:**
```bash
curl -X POST "$BASE/public/qrcode/feedback" -H 'Content-Type: application/json' \
 -d "{\"channel\":\"QR\",\"enterprise_id\":\"$ENT_B\",\"collection_point_id\":\"$QR_B\",
      \"rating\":5,\"message\":\"itest sem perguntas\",\"answers\":[]}"
```
**Resultado esperado:** 200 `{"ok":true}` — B não tem perguntas, então `answers` deve ser `[]` (o número de respostas precisa bater com o de perguntas ativas).

### Deduplicação diária (mesmo dispositivo + mesmo ponto)

**Objetivo:** o mesmo dispositivo não envia duas vezes no mesmo dia para o mesmo ponto.
**Passos:** repita **exatamente** a mesma chamada da empresa B acima (mesmo `User-Agent`, mesmo dia).
**Resultado esperado:** a 2ª chamada retorna **409**, `error` = `DEVICE_ALREADY_SUBMITTED`. Enviar para **outro ponto** (ex.: um QR de produto) com o mesmo dispositivo **é permitido** (a dedup é por ponto + dia).

### Anti-adulteração / atomicidade (rollback)

**Objetivo:** resposta com `question_id` que não pertence ao conjunto ativo não persiste nada.
**Passos:** `POST` para `$ENT_A` com uma `answers` referenciando `99999999-9999-9999-9999-999999999999` (pergunta inexistente).
**Resultado esperado:** **400** (`invalid_payload`); **nenhum** feedback ou dispositivo é criado (A continua com 5 feedbacks). No teste de repositório isso dispara `QrFeedbackWriteError` com rollback; via HTTP a validação barra antes, com o mesmo invariante: sem feedback órfão.

### Isolamento de dispositivo e de cliente entre empresas

**Objetivo:** dispositivo/dedup e cliente por e-mail são escopados por empresa.
**Passos:** envie um feedback para A e outro para B com o **mesmo** `User-Agent` (mesmo dia), um que ainda não foi usado hoje (ex.: `-H 'User-Agent: itest-iso'`; com o do `curl` padrão, os envios anteriores já dariam 409), e com `"customer_email":"itest-cust-iso@x.local"` nos dois.
**Resultado esperado:** ambos retornam 200 — o dispositivo de A e o de B são registros independentes (a dedup de A não bloqueia B).

**Verificação opcional (SQL, leitura):**
```sql
-- mesmo fingerprint aparece separado por empresa:
SELECT enterprise_id, feedback_count FROM public.tracked_devices ORDER BY enterprise_id;
-- cliente por e-mail não vaza entre empresas:
SELECT enterprise_id FROM public.customer WHERE email = 'itest-cust-iso@x.local';
```

### Canal de coleta gravado no feedback

**Objetivo:** a marca de canal do envio chega ao feedback e às métricas por canal; valor desconhecido vira "sem canal".
**Pré-condições:** `db:reset` recente. Use um `User-Agent` novo em cada envio, para a dedup não barrar (ex.: `-H 'User-Agent: itest-link'`, `itest-nfc`, `itest-antigo`).
**Passos:** envie para A (ponto `$QR_A`, respostas de `Q_A1` e `Q_A2`) três feedbacks: um com `"channel":"LINK"`, um com `"channel":"nfc"` e um com `"channel":"QRCODE"`. Depois, como gestor de A, `GET $BASE/protected/user/feedbacks` e `GET $BASE/protected/user/feedbacks/stats`.
**Resultado esperado:** os três envios → 200. Na lista, os novos vêm com `channel` = `"LINK"`, `"NFC"` (o valor é normalizado para maiúsculas) e `null`. Em `stats.channelBreakdown`, aparecem `LINK` (1), `NFC` (1) e `null` (6: os 5 do seed e o `QRCODE`), na ordem QR, link, NFC e sem marca. Um envio com `"channel":"TEST"` aparece na lista, mas não entra em `stats` nem nas outras métricas.

---

## Lista de feedbacks (`feedbackList.itest`)

Endpoint protegido: `GET $BASE/protected/user/feedbacks` (autenticado como gestor de A). Cobre contagem, filtros, paginação, shape aninhado e isolamento. Faça `db:reset` antes.

### Contagem isolada A=5 / B=2

**Passos:** `GET $BASE/protected/user/feedbacks` como A; depois como B.
**Resultado esperado:** A → `pagination.totalItems` = 5; B → 2.

### Filtro por nota

**Passos:** `GET .../feedbacks?rating=5` e `?rating=1` (como A).
**Resultado esperado:** `rating=5` → `totalItems` = 2; `rating=1` → 0.

### Busca por texto (ilike na mensagem)

**Passos:** `GET .../feedbacks?search=excelente` (como A).
**Resultado esperado:** `totalItems` = 1 (só o feedback "Atendimento excelente...").

### Shape aninhado e ordenação

**Passos:** `GET .../feedbacks` (como A).
**Resultado esperado:** 5 feedbacks; cada `feedbacks[i].collection_points.id` = `$QR_A` e `catalog_item_id` = `null`; ordenados por `created_at` desc; todos do ponto de A.

### Isolamento entre páginas

**Passos:** compare `GET .../feedbacks?limit=100` de A e de B.
**Resultado esperado:** A tem 5 e B tem 2; **nenhuma** mensagem de B aparece na lista de A (e vice-versa).

### Paginação (limit/page recorta corretamente)

**Passos:** `GET .../feedbacks?limit=2&page=1` e `?limit=2&page=2` (como A).
**Resultado esperado:** cada página com 2 itens; os `id` da página 2 são **disjuntos** dos da página 1.

### Filtro por categoria (escopo)

**Passos:** `GET .../feedbacks?category=COMPANY` e `?category=PRODUCT` (como A).
**Resultado esperado:** `COMPANY` → 5 (todos do ponto geral de A); `PRODUCT` → `totalItems` = 0 e `feedbacks: []` (sem catálogo no seed).

---

## Estatísticas (`feedbackStats.itest`)

Endpoint protegido: `GET $BASE/protected/user/feedbacks/stats`. Cobre agregados de nota/análise e isolamento. `db:reset` antes.

### Agregados da empresa A

**Passos:** `GET .../feedbacks/stats` (como A).
**Resultado esperado:** `totalFeedbacks` = 5; `averageRating` = 3.8; `ratingDistribution` = `{"1":0,"2":1,"3":1,"4":1,"5":2}`; `totalAnalyzed` = 3; `pendingCount` = 2; `aiSentiment` = `{positive:2, neutral:0, negative:1, ...}`.

### Agregados da empresa B

**Passos:** `GET .../feedbacks/stats` (como B).
**Resultado esperado:** `totalFeedbacks` = 2; `averageRating` = 3; `ratingDistribution` = `{"1":1,"2":0,"3":0,"4":0,"5":1}`; sem bloco `aiSentiment` (0 analisados).

### Isolamento e empresa inexistente

**Objetivo:** A e B nunca somam dados um do outro; total geral do seed é 7 (5 + 2).
**Resultado esperado:** `A.totalFeedbacks` (5) + `B.totalFeedbacks` (2) = 7. Uma empresa inexistente retorna zero — via HTTP, um gestor sem empresa resolvível recebe **404 enterprise_not_found** (o `assertEnterpriseId` do repositório é o fail-fast equivalente, que barra qualquer query sem `enterprise_id`).

**Verificação opcional (SQL):**
```sql
SELECT enterprise_id, count(*), sum(rating) FROM public.feedback GROUP BY enterprise_id;
-- A: 5 / 19 ; B: 2 / 6
```

---

## Análise de sentimento (`feedbackAnalysis.itest`)

Endpoint protegido: `GET $BASE/protected/user/feedbacks/analysis`. Cobre o subconjunto analisado, o filtro por sentimento e o isolamento. `db:reset` antes.

### A: 3 analisados, shape correto

**Passos:** `GET .../feedbacks/analysis` (como A).
**Resultado esperado:** `summary.totalAnalyzed` = 3; cada item tem `sentiment` (string), `categories` (array) e `sentiment_score` (número).

### Filtro por sentimento

**Passos:** `GET .../feedbacks/analysis?sentiment=positive`, `?sentiment=negative`, `?sentiment=neutral` (como A).
**Resultado esperado:** `positive` → `summary.totalAnalyzed` = 2; `negative` → 1; `neutral` → resultado vazio (`items: []`, `totalAnalyzed` = 0).

### Isolamento: B não tem análises

**Passos:** `GET .../feedbacks/analysis` (como B), inclusive com `?sentiment=positive`.
**Resultado esperado:** resultado vazio (`items: []`, `summary.totalAnalyzed` = 0) — B não enxerga as análises de A.

---

## Relatório de insights (`feedbackInsights.itest`)

Endpoint protegido: `GET $BASE/protected/user/feedbacks/insights/report`. Escopo padrão `COMPANY`. `db:reset` antes.

### A / COMPANY

**Passos:** `GET .../feedbacks/insights/report` (como A).
**Resultado esperado:** `summary` contém `"atendimento"`; `recommendations` = `["Reduzir o tempo de espera","Manter a qualidade do atendimento"]`; `scopeType` = `"COMPANY"`.

### B / COMPANY (nunca o de A)

**Passos:** `GET .../feedbacks/insights/report` (como B).
**Resultado esperado:** `summary` contém `"corte"`; `recommendations` = `["Revisar o acabamento final"]`; o resumo **não** contém `"atendimento"`.

### Escopo sem relatório → vazio

**Passos:** `GET .../feedbacks/insights/report?scope_type=PRODUCT` (como A).
**Resultado esperado:** `summary` = `null`, `recommendations` = `[]`, `updatedAt` = `null`, `scopeType` = `"PRODUCT"` (equivale ao `null` do teste). O mesmo vale para uma empresa inexistente (não vaza nada).

---

## Métricas por pergunta (`feedbackQuestions.itest`)

Cobre `fetchQuestionDefsScoped` / `fetchSubquestionDefsScoped` (config de perguntas por tenant), que classifica as métricas em `GET $BASE/protected/user/feedbacks/questions`. `db:reset` antes.

### A resolve as próprias perguntas

**Passos:** `GET .../feedbacks/questions` (como A).
**Resultado esperado:** `questions` com 1 entrada — a pergunta `Q_A1` ("Como você avalia o atendimento recebido hoje?"), pois só ela tem respostas no seed (`count` = 2: uma OTIMA e uma RUIM), `status` = `"current"` (ativa e texto igual ao configurado), `subquestions` = `[]`.

### Isolamento: B não enxerga perguntas de A

**Passos:** `GET .../feedbacks/questions` (como B).
**Resultado esperado:** `questions` = `[]`. Mesmo que se conheçam os ids das perguntas de A, o tenant B não as resolve (o repositório força `enterprise_id`; ids de outra empresa ou lista vazia retornam `[]`).

**Verificação opcional (SQL):**
```sql
SELECT id, is_active FROM public.questions_of_feedbacks
 WHERE enterprise_id = 'bbbbbbbb-0000-0000-0000-000000000001'; -- vazio
```

---

## Escopo de coleta (`scope.itest`)

Cobre `resolveScopeCollectionPointIds`, exposto pelos parâmetros `scope_type` e `catalog_item_id` nos endpoints de estatísticas/análise/perguntas. Verifique via `GET .../feedbacks/stats` (como A). `db:reset` antes.

### Sem escopo → empresa inteira

**Passos:** `GET .../feedbacks/stats` (sem `scope_type`).
**Resultado esperado:** `totalFeedbacks` = 5 (todos os pontos da empresa; o repositório resolve `ids: null`).

### COMPANY → apenas o ponto geral da própria empresa

**Passos:** `GET .../feedbacks/stats?scope_type=COMPANY` (como A) e (como B).
**Resultado esperado:** A → 5 (só o ponto `$QR_A`); B → 2 (só o `$QR_B`). A nunca resolve o ponto de B.

### PRODUCT sem catálogo → nenhum ponto

**Passos:** `GET .../feedbacks/stats?scope_type=PRODUCT` (como A).
**Resultado esperado:** `totalFeedbacks` = 0 (o escopo resolve `ids: []`). O mesmo para um `catalog_item_id` inexistente ou de outra empresa: `GET .../feedbacks/stats?scope_type=PRODUCT&catalog_item_id=11111111-2222-3333-4444-555555555555` → 0 (não vaza).

---

## Análise de IA — leituras de escopo (`iaAnalyze.itest`)

Cobre as leituras do `iaAnalyze.repository` (feedbacks para análise, já-analisados, contexto e relatórios), que alimentam `POST $BASE/protected/ia-analyze/analyze-raw` e `POST .../regenerate-insights`. As contagens são observáveis pelos endpoints determinísticos abaixo. Os endpoints de escrita `analyze-raw`/`regenerate-insights` **sempre enfileiram** e respondem **202** `{"jobId":...,"status":"queued"}`; o resultado sai no job (`GET $BASE/protected/ia-analyze/jobs/<jobId>`), que só chega a `completed` com a chave OpenRouter da empresa configurada e o `ia-analyze` no ar (rode com `IA_ANALYZE_EXECUTION_MODE=local`). Com o seed (sem chave e com só 5 feedbacks em A), o job termina `failed`, com o motivo em `errorCode`. `db:reset` antes.

### Feedbacks para análise e já-analisados (A=5 / A=3)

**Objetivo:** A tem 5 feedbacks elegíveis e 3 já analisados (2 pendentes); B tem 2 e 0.
**Passos:** `GET .../feedbacks/stats` (como A) e (como B).
**Resultado esperado:** A → `totalFeedbacks` = 5, `totalAnalyzed` = 3, `pendingCount` = 2; B → `totalFeedbacks` = 2, `totalAnalyzed` = 0. (No repositório: `fetchFeedbacksForAnalysis` A=5/B=2; `fetchAlreadyAnalyzedFeedbacks` A=3/B=0.)

### Restrição de escopo PRODUCT → vazio

**Passos:** `GET .../feedbacks/stats?scope_type=PRODUCT` (como A).
**Resultado esperado:** `totalFeedbacks` = 0 e `totalAnalyzed` = 0 (sem catálogo no seed).

### Relatórios de insights por escopo

**Passos:** `GET .../feedbacks/insights/report` (como A, escopo COMPANY) e `?scope_type=PRODUCT` (como B).
**Resultado esperado:** A/COMPANY → 1 relatório com `summary` citando `"atendimento"`; B/PRODUCT → vazio (`summary: null`).

### Contexto do tenant e distinção de analisados (verificação por SQL)

O teste também verifica o **contexto** para a IA (`fetchEnterpriseContextForAnalysis`: dados de coleta + nome do gestor via view pública) e a distinção fino-granular entre feedbacks analisados e não-analisados (`a1`/`a2` analisados, `a4` não). Isso não tem endpoint de leitura dedicado; confirme por SQL (leitura):

```sql
-- contexto: coleta presente + nome do gestor
SELECT c.company_objective, ep.name
  FROM public.collecting_data_enterprise c
  JOIN public.enterprise_public ep ON ep.id = c.enterprise_id
 WHERE c.enterprise_id = 'aaaaaaaa-0000-0000-0000-000000000001';

-- a1/a2 têm análise; a4 não:
SELECT feedback_id FROM public.feedback_analysis
 WHERE feedback_id IN ('f0000000-0000-0000-0000-0000000000a1',
                       'f0000000-0000-0000-0000-0000000000a2',
                       'f0000000-0000-0000-0000-0000000000a4');
-- retorna a1 e a2, nunca a4
```

**Resultado esperado:** `company_objective` não vazio e `name` = nome do dono da empresa A (`"Gestor E2E"` com a fixture vinculada; `"Gestor A"` só com o seed puro); a consulta de análises retorna `a1` e `a2`, mas não `a4`.

---

## Campo de comentário por escopo (`comment-field`)

Endpoints protegidos `GET` e `PUT $BASE/protected/user/collection-points/comment-field`: o que o formulário mostra no lugar do comentário, por empresa ou por item do catálogo. Autenticado como gestor de A; `db:reset` antes.

### Padrão, pergunta própria e validação

**Passos:**
1. `GET .../comment-field?scope_type=COMPANY`.
2. `PUT .../comment-field` com `{"scope_type":"COMPANY","mode":"CUSTOM","prompt":"O que faltou no atendimento?"}`; depois `curl "$BASE/public/enterprise/$ENT_A"`.
3. `PUT` com `{"scope_type":"COMPANY","mode":"CUSTOM","prompt":"curto"}`.
4. `PUT` com `{"scope_type":"COMPANY","catalog_item_id":"11111111-2222-3333-4444-555555555555","mode":"DEFAULT"}`.
5. `PUT` com `{"scope_type":"PRODUCT","catalog_item_id":"11111111-2222-3333-4444-555555555555","mode":"DEFAULT"}`.

**Resultado esperado:** passo 1 → 200 `{"mode":"DEFAULT","prompt":null}` (sem configuração, vale o convite padrão); passo 2 → 200 `{"mode":"CUSTOM","prompt":"O que faltou no atendimento?"}` e o endpoint público traz o mesmo em `comment`; passo 3 → **400** `invalid_payload` (a pergunta própria tem de 10 a 150 caracteres); passo 4 → **400** `invalid_payload` (`catalog_item_id` é proibido em `COMPANY`); passo 5 → **404** `catalog_item_not_found` (item inexistente ou de outra empresa).

### Campo oculto descarta o comentário

**Passos:**
1. `PUT .../comment-field` com `{"scope_type":"COMPANY","mode":"HIDDEN"}`.
2. Envie um feedback para A (`POST $BASE/public/qrcode/feedback`, ponto `$QR_A`, respostas de `Q_A1` e `Q_A2`, `User-Agent` novo) com `"message":"texto que deve sumir"`.
3. `GET $BASE/protected/user/feedbacks` e `GET $BASE/protected/user/feedbacks/stats?scope_type=COMPANY`.
4. Volte ao padrão: `PUT` com `{"scope_type":"COMPANY","mode":"DEFAULT"}`.

**Resultado esperado:** passo 1 → 200 `{"mode":"HIDDEN","prompt":null}` e o público passa a trazer `comment.mode` = `"HIDDEN"`; passo 2 → 200 `{"ok":true}` (o texto não é recusado, é descartado); passo 3 → o feedback novo aparece **sem** o texto e não conta como "aguardando análise"; em `stats`, `commentField.hidden` = `"all"`; passo 4 → 200 `{"mode":"DEFAULT","prompt":null}`.

---

## Diagnóstico do escopo (`scope-diagnosis`)

Endpoints protegidos sob `$BASE/protected/ia-analyze/scope-diagnosis`. Os passos sem IA são determinísticos; os com IA consomem a chave OpenRouter da empresa. `db:reset` antes.

### Validação e leituras sem diagnóstico (sem IA)

**Pré-condições:** autenticado como gestor de A (o seed não tem chave de IA).
**Passos:**
1. `POST .../scope-diagnosis` com `{"scope_type":"COMPANY"}`.
2. `POST` com `{"scope_type":"COMPANY","start_date":"2026-10-01T03:00:00Z","end_date":"2026-09-01T03:00:00Z"}`.
3. `POST` com `{"scope_type":"COMPANY","tz":"Fuso/Invalido"}` e, depois, com `{"scope_type":"COMPANY","catalog_item_id":"11111111-2222-3333-4444-555555555555"}`.
4. `GET .../scope-diagnosis/latest?scope_type=COMPANY`, `GET .../scope-diagnosis?scope_type=COMPANY` e `GET .../scope-diagnosis/11111111-2222-3333-4444-555555555555`.

**Resultado esperado:** passo 1 → **409** `ia_config_required` (sem chave e modelo, nada é calculado); passo 2 → **400** `invalid_period`; passo 3 → **400** `invalid_timeline` e **400** `invalid_payload` (item não combina com `COMPANY`); passo 4 → 200 `{"diagnosis":null,"job":null}`, 200 `{"items":[]}` e **404** `scope_diagnosis_not_found`.

### Gerar, reaproveitar e listar (com IA)

**Pré-condições:** chave OpenRouter da empresa salva (seção de configuração de IA abaixo), os três campos de contexto preenchidos e **pelo menos 10 avaliações** no período — o seed tem 5 em A; complete pelo formulário público com `User-Agent` diferentes. Este cenário consome a cota da IA.
**Passos:**
1. Com menos de 10 avaliações, `POST .../scope-diagnosis` com `{"scope_type":"COMPANY"}`.
2. Com 10 ou mais, repita o `POST`; acompanhe `GET $BASE/protected/ia-analyze/jobs/<jobId>` até `completed`.
3. Repita o mesmo `POST`, sem avaliação nova no meio.
4. `GET .../scope-diagnosis/latest?scope_type=COMPANY` e `GET .../scope-diagnosis?scope_type=COMPANY`.

**Resultado esperado:** passo 1 → **422** `insufficient_feedbacks_for_analysis`; passo 2 → **202** `{"jobId":...,"status":...,"deduped":false,"cached":false,"diagnosisId":null}`, e o job concluído traz `diagnosisId`; repetir o `POST` com o job ainda ativo devolve o mesmo job com `deduped: true`; passo 3 → **200** com `cached: true`, `jobId: null` e o mesmo `diagnosisId` (não paga IA de novo; com `"force":true` volta a enfileirar); passo 4 → `diagnosis` com `result` (`summary`, `going_well`, `concerns`, `changes`, `recommendations`, `limitations`) e o histórico com 1 item.

---

## Perguntas automáticas da empresa (`company-questions`)

Endpoints protegidos sob `$BASE/protected/ia-analyze/jobs/company-questions`: a geração das 3 perguntas COMPANY pela IA na configuração inicial. Só sai pedido quando a empresa tem os três campos de contexto, a IA configurada e as perguntas ainda são as padrão.

### Estado sem pedido (sem IA)

**Passos:**
1. Como gestor de A: `GET .../company-questions/latest`, `POST .../company-questions/retry` (sem corpo) e `POST .../company-questions/dismiss` (sem corpo).
2. Como um gestor recém-registrado (perguntas padrão, contexto incompleto): `POST .../company-questions/retry`.

**Resultado esperado:** passo 1 → 200 `{"job":null,"stillDefault":null}`; 200 `{"questionsGeneration":{"status":"customized"}}` (A já tem perguntas próprias, a IA não interfere); 200 `{"dismissed":false}` (não há pedido falho para dispensar). Passo 2 → 200 `{"questionsGeneration":{"status":"unavailable","code":"company_context_required"}}`. O `retry` responde sempre **200**; o motivo vem em `questionsGeneration`.

### Geração na configuração inicial (com IA)

**Pré-condições:** um gestor recém-registrado e uma chave OpenRouter de teste (não versionada). Consome a cota da IA.
**Passos:**
1. Salve a chave (`PUT $BASE/protected/user/ia-config`, seção abaixo).
2. `PATCH $BASE/protected/user/collecting_data` com `company_objective`, `analytics_goal` e `business_summary` preenchidos.
3. Acompanhe `GET .../company-questions/latest` (e o `GET $BASE/protected/ia-analyze/jobs/<job.id>`) até o fim.
4. `POST .../company-questions/retry`.

**Resultado esperado:** passo 2 → 200 (o pedido não volta nesta resposta); passo 3 → o `job` passa de `queued`/`running` a `completed`, com `applied: true` e `stillDefault: false`, e `GET $BASE/protected/user/collecting_data` traz as 3 perguntas novas; passo 4 → `{"questionsGeneration":{"status":"completed"}}`. Se o job terminar `failed`, `stillDefault` segue `true` e `dismissed` `false` (é o que acende o aviso na Web); `POST .../dismiss` passa a responder `{"dismissed":true}`. Depois de uma falha, um `retry` dentro de 60 s do pedido anterior (ou além de 5 pedidos no dia) volta como `rate_limited`, com `retryAfterSeconds`.

---

## Configuração de IA: chave, modelos e "Conectar com OpenRouter"

Endpoints protegidos sob `$BASE/protected/user/ia-config` e `$BASE/protected/user/ia-models`. As respostas usam `Cache-Control: private, no-store` e **nunca** trazem a chave. Os passos que falam com o OpenRouter precisam de internet.

### Sem chave salva

**Passos** (gestor de A):
1. `GET .../ia-config`.
2. `GET .../ia-models`.
3. `PATCH .../ia-config/model` com `{"model":"openrouter/auto"}` e, depois, com `{"model":"openrouter/auto","apiKey":"x"}`.
4. `PUT .../ia-config` com `{}` e, depois, com `{"apiKey":"sk-or-chave-invalida"}`.
5. `POST .../ia-config/openrouter/connect` com `{"code":"x","codeVerifier":"curto"}` e, depois, com `{"code":"codigo-falso","codeVerifier":"<43 caracteres de [A-Za-z0-9._~-]>"}`.

**Resultado esperado:** passo 1 → 200 `{"hasKey":false,"provider":null,"model":null,"keyHint":null}`; passo 2 → 200 com `source` = `"public"`, `currentModel` e `currentModelAvailable` = `null` e a lista em `models` (pode vir vazia; sem acesso ao OpenRouter e sem cache → **503** `ia_models_unavailable`); passo 3 → **409** `ia_config_required` e **400** `invalid_payload` (o `PATCH` só aceita `model`); passo 4 → **400** `invalid_payload` e **400** `ia_config_invalid_key`; passo 5 → **400** `invalid_payload` e **400** `openrouter_connect_failed` (código vencido, usado ou falso).

### Com chave salva (opcional, chave real de teste)

**Passos:**
1. `PUT .../ia-config` com `{"apiKey":"<chave de teste>","model":"<um id que veio em ia-models>"}`.
2. `GET .../ia-models`.
3. `PATCH .../ia-config/model` com outro id da lista.
4. `DELETE .../ia-config`.

**Resultado esperado:** passo 1 → 200 `{"hasKey":true,"provider":"openrouter","model":...,"keyHint":"<4 últimos caracteres>"}`; passo 2 → `source` = `"user"` e `currentModelAvailable` = `true`; passo 3 → 200 com o modelo novo e `questionsGeneration` (os mesmos status do `retry`); passo 4 → 200 `{"hasKey":false,"provider":null,"model":null,"keyHint":null}`. O "Conectar com OpenRouter" de ponta a ponta (`openrouter.ai/auth` → `/user/openrouter/callback` → `connect`) precisa do navegador: faça pela Web, em Configuração de IA.

---

### Observações finais

- Os arquivos originais (`src/tests/integration/*.itest.ts`, `globalSetup.ts`, `src/tests/e2e/authCutover.e2e.ts`) chamavam **funções de repositório** e a **camada HTTP** diretamente. Este runbook mapeia cada asserção para o endpoint real do API Gateway que exercita o mesmo repositório (rotas em `src/routes/**`), sem inventar rotas. As seções de troca de e-mail, guia do sistema, Google, exclusão de conta, canal, campo de comentário, diagnóstico, perguntas automáticas e configuração de IA não vieram dos testes antigos: cobrem rotas que entraram depois. A referência completa de cada rota é o `docs/endpoints.md` do repositório `feedback-analytics-api-gateway`.
- Onde o teste verifica um invariante puramente de banco (soft-delete `INACTIVE`, isolamento de `tracked_devices`/`customer`, contexto de IA), incluí uma verificação opcional por SQL **somente leitura** — nunca execute `INSERT/UPDATE/DELETE` fora do fluxo da aplicação.
- Para números determinísticos, rode `npm run db:reset` antes de cada seção que conta feedbacks/análises; os cenários de escrita (envio de feedback, collecting_data, pontos de coleta, campo de comentário, exclusão de conta) alteram o estado.
- Nunca versione a chave OpenRouter, o cookie de sessão nem os valores reais do `.env` usados nestes passos.
