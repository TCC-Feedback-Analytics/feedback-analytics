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
   - `E2E_TEST_EMAIL`, `E2E_TEST_PASSWORD`, `E2E_TEST_ENTERPRISE_ID` (obrigatórios — sem eles o `db:reset` falha).

### Resetar e semear (estado pristino)

3. Rode `npm run db:reset`. Isso faz `DROP SCHEMA` → `drizzle-kit migrate` → aplica `db/local/seed.sql` → provisiona a fixture E2E (`scripts/seed-e2e-user.ts`). Recria o dataset determinístico das empresas A e B.
4. **Regra de ouro:** rode `npm run db:reset` **antes de cada seção** que verifica contagens (listas, estatísticas, análises). Os testes originais zeravam o estado a cada arquivo; aqui o reset cumpre o mesmo papel e garante os números exatos.

### Subir a API

5. `npm run dev` (executa `tsx watch index.ts`). A API sobe em `http://localhost:3000`. Todas as rotas ficam sob `http://localhost:3000/api/...`.

### Identidades de teste

- **Gestor A** — `user_id 11111111-1111-1111-1111-111111111111`, empresa A `aaaaaaaa-0000-0000-0000-000000000001` (documento `12.345.678/0001-99`, `CNPJ`, `TRIAL`). E-mail no seed: `gestor.a@teste.local`.
- **Gestor B** — `user_id 22222222-2222-2222-2222-222222222222`, empresa B `bbbbbbbb-0000-0000-0000-000000000001` (documento `98.765.432/0001-11`).
- Os gestores A/B do `seed.sql` **não têm senha** (o seed não cria conta de credencial no Better Auth). Para exercitar os endpoints **protegidos** com os dados do seed, use a **fixture E2E** do `.env` apontando `E2E_TEST_ENTERPRISE_ID` para a empresa A — assim o login expõe exatamente o dataset de A. Alternativamente, para os fluxos de escrita/QR/auth, **registre um gestor novo** (começa com empresa vazia).
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

Verificação opcional por SQL (**somente leitura** — nunca escreva):

```bash
docker exec -it feedback-api-db psql -U postgres -d feedback -c "SELECT ..."
```

### Dataset determinístico do seed (resumo)

- **Empresa A**: 5 feedbacks com notas 5, 4, 2, 3, 5 (soma 19 → média 3,8); 3 deles com análise de IA (2 `positive`, 1 `negative`); 2 perguntas COMPANY ativas; 1 ponto QR "Geral A" ativo; 1 relatório de insights COMPANY cujo resumo cita "atendimento".
- **Empresa B**: 2 feedbacks com notas 5 e 1 (média 3); nenhuma análise de IA; nenhuma pergunta; 1 ponto QR "Geral B" ativo; 1 relatório de insights COMPANY cujo resumo cita "corte".
- Invariante central de **todas** as seções: **isolamento por `enterprise_id`** — nenhum tenant enxerga dados do outro.

---

## Autenticação e acesso protegido (`authCutover.e2e`)

Cobre o corte para Better Auth: sessão por cookie, leitura da própria empresa, isolamento e os endpoints públicos de auth. Aqui a UI equivalente é a tela de login/registro do frontend; os passos abaixo usam HTTP direto.

### Preparação: registrar dois gestores (A e B)

**Objetivo:** ter dois gestores autenticáveis e isolados.
**Pré-condições:** API no ar; Mailpit acessível.
**Passos:**
1. `curl` `POST $BASE/public/auth/register` com corpo (documento CNPJ precisa ser 14 dígitos):
   ```json
   {"email":"a@x.local","password":"SenhaForte123","confirmPassword":"SenhaForte123","terms":true,"accountType":"CNPJ","fullName":"Gestor A","phone":"+5511900000001","document":"11222333000181"}
   ```
2. Repita para o gestor B (`b@x.local`, phone `+5511900000002`, outro documento).
3. Confirme o e-mail: abra `http://localhost:8025`, clique no link de confirmação de cada conta (via UI). O teste original atalhava isso marcando `email_verified=true` direto no banco.
4. Faça login de cada um (`POST /public/auth/login`) salvando os cookies em `cookies-a.txt` e `cookies-b.txt`.

**Resultado esperado:** cada registro retorna 200; após confirmar e logar, cada login retorna 200 com `Set-Cookie` de sessão.

### Bloqueio sem sessão

**Objetivo:** rota protegida exige sessão.
**Passos:** `curl -i "$BASE/protected/user/enterprise"` (sem cookie).
**Resultado esperado:** **401**, corpo `{"error":"unauthorized"}`.

### Gestor lê a própria empresa

**Objetivo:** sessão → `enterpriseId` → dados corretos.
**Passos:** `curl -b cookies-a.txt "$BASE/protected/user/enterprise"`.
**Resultado esperado:** **200**; `enterprise.document` = documento de A; `user.id` = id do gestor A.

### Isolamento entre gestores

**Objetivo:** cada gestor vê apenas a sua empresa.
**Passos:** `curl -b cookies-b.txt "$BASE/protected/user/enterprise"`.
**Resultado esperado:** **200**; `user.id` = id de B; `enterprise.document` = documento de B e **diferente** do de A.

### collecting_data: escrita + leitura + isolamento

**Objetivo:** provar sessão → `enterpriseId` → Drizzle (transação), sem vazamento.
**Passos:**
1. `GET $BASE/protected/user/collecting_data` (cookie A) numa empresa recém-criada.
2. `PATCH $BASE/protected/user/collecting_data` (cookie A) com `{"company_objective":"Objetivo E2E A"}`.
3. `GET` de novo (cookie A).
4. `GET` com cookie B.
5. `GET $BASE/protected/user/collection-points/qr/status` (cookie A).

**Resultado esperado:** passo 1 → 200 `{"collecting":null}`; passo 2 → 200; passo 3 → `collecting.company_objective` = `"Objetivo E2E A"`; passo 4 → `{"collecting":null}` (B não vê A); passo 5 → 200 `{"active":false, ...}`.

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
| Login válido | `POST /login` `{email,password}` válidos | **200**, `{"ok":true,"user":{"id":...}}`, header `Set-Cookie` presente |
| Senha errada | `POST /login` senha inválida | **401**, `{"error":"invalid_credentials"}` |
| E-mail não verificado (RNE-014) | registre um usuário e **não** confirme; `POST /login` | **401**, `{"error":"invalid_credentials"}`; o corpo **não** pode conter `confirm` nem `verificad` (anti-enumeração) |
| Payload inválido no login | `POST /login` `{"email":"nao-eh-email","password":"123"}` | **400**, `{"error":"invalid_payload"}` |
| Register com e-mail já usado | `POST /register` com e-mail existente | **200**, `{"message":"confirmation_required"}` (anti-enumeração) |
| Register com telefone já usado | `POST /register` com `phone` já existente | **409**, `{"error":"phone_taken"}` |
| Register payload inválido | `POST /register` `{"email":"x"}` | **400**, `{"error":"invalid_payload"}` |
| Forgot-password (sempre 200) | `POST /forgot-password` `{email}` | **200**, `{"ok":true}` |
| Forgot-password e-mail inválido | `POST /forgot-password` `{"email":"nao-eh-email"}` | **400**, `{"error":"invalid_payload"}` |
| Resend-confirmation e-mail inválido | `POST /resend-confirmation` `{"email":"nao-eh-email"}` | **400**, `{"error":"invalid_payload"}` |
| Logout | `POST /logout` com cookie de sessão | **204** (sem corpo) |

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
SELECT id FROM public.enterprise WHERE auth_user_id = '11111111-1111-1111-1111-111111111111';
-- deve retornar aaaaaaaa-0000-0000-0000-000000000001 e nunca a de B
```

---

## Dados de coleta / `collecting_data` (`collectingData.itest`)

Cobre perfil (get/patch por usuário) e o upsert/patch transacional de `collecting_data` + catálogo + perguntas COMPANY. Use um **gestor recém-registrado** (empresa vazia) para não corromper o seed; ou rode `db:reset` ao final.

### Perfil em snake_case

**Objetivo:** `GET` devolve o perfil da empresa em snake_case.
**Passos:** `GET $BASE/protected/user/enterprise` (autenticado).
**Resultado esperado:** 200; `enterprise` com `id`, `document`, `account_type` (`CNPJ`), `subscription_status` (`TRIAL`).

### PATCH aplica só as chaves presentes

**Objetivo:** atualizar apenas os campos enviados, preservando o resto.
**Passos:** `PATCH $BASE/protected/user/enterprise` com `{"account_type":"CPF"}`.
**Resultado esperado:** 200; `enterprise.account_type` = `"CPF"`; `enterprise.document` **inalterado**. (Campos aceitos: `document`, `account_type` ∈ {CPF,CNPJ}, `terms_version`, `terms_accepted_at`; corpo vazio → 400.)

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

Cobre o QR "geral" (COMPANY) e o QR por item de catálogo: ativar/reusar/desativar/reativar (sempre o **mesmo** ponto), o upsert transacional de perguntas do item e o isolamento por tenant. Autenticado como gestor.

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
**Resultado esperado:** 200; `id` = `$ENT_A`; `name` = `"Gestor A"` (nome do gestor via view pública); `collection_point_id` = `$QR_A` (ponto "Geral A", escopo empresa); `catalog_item_id` = `null`; `questions` = as 2 perguntas COMPANY ativas.

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
**Resultado esperado:** 200; `collection_point_id` = `$QR_B`; `name` = `"Gestor B"`. Nunca o ponto de A.

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

## Envio de feedback via QR (`qrFeedback.itest`)

Endpoint **público**: `POST $BASE/public/qrcode/feedback`. Escrita atômica (dispositivo + feedback + respostas), deduplicação diária, isolamento e anti-adulteração. O corpo exige `channel:"QRCODE"`, `enterprise_id`, `rating`, `message`, `answers` (que devem **casar exatamente** com as perguntas ativas do escopo) e, opcionalmente, `collection_point_id`/`catalog_item_id`/dados do cliente.

> O "dispositivo" é um fingerprint `md5(user-agent | ip | dia)`. Via `curl` do mesmo host/dia, o fingerprint se repete; troque o header `User-Agent` para simular outro dispositivo.

### Feedback anônimo com respostas (empresa A)

**Objetivo:** criar dispositivo + feedback + respostas numa transação.
**Pré-condições:** `db:reset` recente; empresa A tem 2 perguntas COMPANY ativas (`Q_A1`, `Q_A2`).
**Passos:**
```bash
curl -X POST "$BASE/public/qrcode/feedback" -H 'Content-Type: application/json' \
 -d "{\"channel\":\"QRCODE\",\"enterprise_id\":\"$ENT_A\",\"collection_point_id\":\"$QR_A\",
      \"rating\":5,\"message\":\"itest com respostas\",
      \"answers\":[{\"question_id\":\"$Q_A1\",\"answer_value\":\"OTIMA\"},
                   {\"question_id\":\"$Q_A2\",\"answer_value\":\"BOA\"}]}"
```
**Resultado esperado:** 200 `{"ok":true}`. O feedback foi persistido com 2 respostas. Verificável autenticado como gestor de A: `GET $BASE/protected/user/feedbacks` passa a listar 6 feedbacks (5 do seed + 1).

### Feedback sem perguntas (empresa B — 0 respostas)

**Objetivo:** happy path com `answers` vazio quando o escopo não tem perguntas ativas.
**Passos:**
```bash
curl -X POST "$BASE/public/qrcode/feedback" -H 'Content-Type: application/json' \
 -d "{\"channel\":\"QRCODE\",\"enterprise_id\":\"$ENT_B\",\"collection_point_id\":\"$QR_B\",
      \"rating\":5,\"message\":\"itest sem perguntas\",\"answers\":[]}"
```
**Resultado esperado:** 200 `{"ok":true}` — B não tem perguntas, então `answers` deve ser `[]` (o número de respostas precisa bater com o de perguntas ativas).

### Deduplicação diária (mesmo dispositivo + mesmo ponto)

**Objetivo:** o mesmo dispositivo não envia duas vezes no mesmo dia para o mesmo ponto.
**Passos:** repita **exatamente** a mesma chamada da empresa B acima (mesmo `User-Agent`, mesmo dia).
**Resultado esperado:** a 2ª chamada retorna **409** (`device_already_submitted`). Enviar para **outro ponto** (ex.: um QR de produto) com o mesmo dispositivo **é permitido** (a dedup é por ponto + dia).

### Anti-adulteração / atomicidade (rollback)

**Objetivo:** resposta com `question_id` que não pertence ao conjunto ativo não persiste nada.
**Passos:** `POST` para `$ENT_A` com uma `answers` referenciando `99999999-9999-9999-9999-999999999999` (pergunta inexistente).
**Resultado esperado:** **400** (`invalid_payload`); **nenhum** feedback ou dispositivo é criado (A continua com 5 feedbacks). No teste de repositório isso dispara `QrFeedbackWriteError` com rollback; via HTTP a validação barra antes, com o mesmo invariante: sem feedback órfão.

### Isolamento de dispositivo e de cliente entre empresas

**Objetivo:** dispositivo/dedup e cliente por e-mail são escopados por empresa.
**Passos:** envie um feedback para A e outro para B com o **mesmo** `User-Agent` (mesmo dia).
**Resultado esperado:** ambos retornam 200 — o dispositivo de A e o de B são registros independentes (a dedup de A não bloqueia B).

**Verificação opcional (SQL, leitura):**
```sql
-- mesmo fingerprint aparece separado por empresa:
SELECT enterprise_id, feedback_count FROM public.tracked_devices ORDER BY enterprise_id;
-- cliente por e-mail não vaza entre empresas:
SELECT enterprise_id FROM public.customer WHERE email = 'itest-cust-iso@x.local';
```

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

Cobre as leituras do `iaAnalyze.repository` (feedbacks para análise, já-analisados, contexto e relatórios), que alimentam `POST $BASE/protected/ia-analyze/analyze-raw` e `POST .../regenerate-insights`. As contagens são observáveis pelos endpoints determinísticos abaixo; os endpoints de escrita `analyze-raw`/`regenerate-insights` acionam o serviço de IA (rode com `IA_ANALYZE_EXECUTION_MODE=local`). `db:reset` antes.

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

**Resultado esperado:** `company_objective` não vazio e `name` = `"Gestor A"`; a consulta de análises retorna `a1` e `a2`, mas não `a4`.

---

### Observações finais

- Os arquivos originais (`src/tests/integration/*.itest.ts`, `globalSetup.ts`, `src/tests/e2e/authCutover.e2e.ts`) chamavam **funções de repositório** e a **camada HTTP** diretamente. Este runbook mapeia cada asserção para o endpoint real do API Gateway que exercita o mesmo repositório (rotas em `src/routes/**`), sem inventar rotas.
- Onde o teste verifica um invariante puramente de banco (soft-delete `INACTIVE`, isolamento de `tracked_devices`/`customer`, contexto de IA), incluí uma verificação opcional por SQL **somente leitura** — nunca execute `INSERT/UPDATE/DELETE` fora do fluxo da aplicação.
- Para números determinísticos, rode `npm run db:reset` antes de cada seção que conta feedbacks/análises; os cenários de escrita (feedback via QR, collecting_data, QR) alteram o estado.
