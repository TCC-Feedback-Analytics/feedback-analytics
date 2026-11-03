# Guia de Instalação

> Suba o ambiente local completo do Feedback Analytics. Como o projeto é **multi-repo**, você clona e configura cada serviço separadamente. Cada repositório traz um `.env.example` e um `README` com as instruções **autoritativas** do próprio serviço — este guia dá a visão de conjunto.

## Antes de Começar

Certifique-se de ter instalado:

| Ferramenta | Versão Mínima | Como verificar |
|---|---|---|
| **Node.js** | 20.x | `node -v` |
| **npm** | 10.x | `npm -v` |
| **Git** | — | `git --version` |
| **Docker Desktop** | — | `docker --version` — sobe o banco local do API Gateway (Postgres na porta **5433**) e o **Mailpit** (SMTP local, captura os e-mails de auth) pelo `docker-compose.yml` do Gateway |
| **Chave OpenRouter** | — | só para rodar as análises de IA — [openrouter.ai](https://openrouter.ai). Não vai em `.env`: cada empresa a configura em **Configuração de IA**, no app |

---

## Passo 1 — Clone os Repositórios

O código está dividido em três serviços deployáveis (o pacote de contratos é consumido como dependência, não precisa ser clonado para rodar):

```bash
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-web.git
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway.git
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze.git
```

> Os serviços consomem o pacote público [`@feedback/lib-shared`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts) por **tag git** declarada no `package.json` de cada repo — hoje `v1.8.0` no Gateway e na Web e `v1.7.0` no IA Analyze. O `npm install` já o baixa e compila; não há token envolvido.

---

## Passo 2 — Instale as Dependências

Em **cada** repositório clonado:

```bash
cd feedback-analytics-web        && npm install && cd ..
cd feedback-analytics-api-gateway && npm install && cd ..
cd feedback-analytics-ia-analyze  && npm install && cd ..
```

---

## Passo 3 — Configure as Variáveis de Ambiente

Cada serviço tem seu próprio `.env.example` — **copie-o para `.env` e preencha** (`cp .env.example .env`). A lista completa, comentada e com o ambiente em que cada variável vale (Local, Preview, Produção), está no `.env.example` de cada repositório; abaixo fica só o que você precisa mexer para rodar local.

### `feedback-analytics-web/.env`

O `.env.example` já vem com o valor local:

```env
VITE_API_BASE_URL=http://localhost:3000
```

> O frontend fala **apenas com o API Gateway** — não acessa o banco diretamente. Se você deixar `VITE_API_BASE_URL` vazia, a Web chama `/api` no próprio endereço e o proxy do `vite.config.ts` repassa para `http://localhost:3000`.

Em produção a configuração é outra: o `vercel.json` da Web repassa `/api/*` ao Gateway, para o cookie de sessão ficar no domínio do próprio site. Por isso, no projeto `feedback-analytics-web` da Vercel, `VITE_API_BASE_URL` fica **vazia** e `VITE_PUBLIC_API_BASE_URL` recebe a URL pública do Gateway (usada nas rotas públicas que contam por IP: formulário do cliente e reenvio da confirmação). `VITE_GOOGLE_AUTH_ENABLED=true` mostra o "Continuar com Google". Como variáveis `VITE_*` são incorporadas ao bundle durante o build, qualquer alteração exige um novo deploy do web. Detalhes no [README da Web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web#readme).

### `feedback-analytics-api-gateway/.env`

Partindo do `.env.example`, ajuste para o ambiente local:

```env
# Banco local do docker-compose (Passo 4)
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5433/feedback

# Autenticação — Better Auth
BETTER_AUTH_SECRET=segredo_aleatorio_aqui   # gere com: openssl rand -base64 32 (SEM ele o app NÃO sobe)
BETTER_AUTH_URL=http://localhost:3000
PUBLIC_SITE_URL=http://localhost:5173

# Integração com o IA Analyze
IA_ANALYZE_REMOTE_URL=http://localhost:4100
IA_ANALYZE_REMOTE_TOKEN=um_token_secreto_compartilhado

# OpenRouter por empresa (BYO-key) — obrigatória
IA_CONFIG_ENCRYPTION_KEY=chave_mestra_aleatoria   # gere com: openssl rand -base64 32

# Usuário de teste criado pelo db:reset (Passo 4)
E2E_TEST_EMAIL=<e-mail do usuário de teste>
E2E_TEST_PASSWORD=<senha do usuário de teste>
E2E_TEST_ENTERPRISE_ID=aaaaaaaa-0000-0000-0000-000000000001
```

O SMTP já vem apontado para o Mailpit (`SMTP_HOST=127.0.0.1`, `SMTP_PORT=1025`, `SMTP_SECURE=false`, sem usuário e senha), e o CORS já aceita `http://localhost:5173` sem configuração. As demais variáveis (worker da fila, limites da IA, Google, reenvio de e-mail) podem ficar como estão no `.env.example`. Detalhes do banco local no [`db/local/README.md`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/db/local/README.md) do Gateway.

!!! warning "`BETTER_AUTH_SECRET` é obrigatório"
    Sem `BETTER_AUTH_SECRET` o api-gateway **não sobe**. Gere um valor aleatório com `openssl rand -base64 32` e mantenha-o secreto.

!!! warning "Preencha `IA_ANALYZE_REMOTE_URL` no local"
    O `.env.example` traz `IA_ANALYZE_REMOTE_PREVIEW_ALIAS_URL` preenchida, e o Gateway usa essa URL quando `IA_ANALYZE_REMOTE_URL` está vazia. Para o Gateway local chamar o IA Analyze local, defina `IA_ANALYZE_REMOTE_URL=http://localhost:4100` (ou esvazie a variável de preview).

!!! note "Autenticação saiu do Supabase Auth → Better Auth"
    O login/cadastro/sessão usam **Better Auth**, montado no Gateway, com a sessão em cookie httpOnly. O Supabase ficou só como **provedor do Postgres** em produção. As tabelas do Better Auth (`user`, `session`, `account`, `verification`) ficam no mesmo Postgres e são criadas pelas migrations. Não use mais `SUPABASE_URL`, `SUPABASE_ANON_KEY` nem `AUTH_PROVIDER`.

!!! tip "Produção (Vercel)"
    As variáveis de runtime ficam nas Settings do projeto Vercel de cada serviço. No Gateway de produção: `BETTER_AUTH_URL` é a URL da **Web** (que repassa `/api/*`), `COOKIE_CROSS_SITE=false`, `IA_ANALYZE_REMOTE_URL` com a URL do IA Analyze, `WORKER_TICK_TOKEN` preenchido e `CORS_ALLOWED_ORIGINS` com `https://feedback-analytics-web.vercel.app`. O e-mail sai pela **Brevo**: `SMTP_HOST=smtp-relay.brevo.com`, `SMTP_PORT=587`, `SMTP_SECURE=false`, `SMTP_USER=<login SMTP da Brevo>`, `SMTP_PASS=<chave SMTP da Brevo, não a API key>` e `MAIL_FROM=<remetente verificado na Brevo>`.

### `feedback-analytics-ia-analyze/.env`

```env
IA_ANALYZE_INTERNAL_TOKEN=um_token_secreto_compartilhado
IA_LLM_CONCURRENCY=3
PORT=4100
```

O provedor, o modelo e a chave OpenRouter não ficam no `.env` do IA Analyze. Cada empresa configura sua chave no app; o Gateway a armazena cifrada e envia pelos headers internos `x-llm-*`.

!!! warning "Token compartilhado (nomes diferentes nos dois lados)"
    No API Gateway o token interno se chama `IA_ANALYZE_REMOTE_TOKEN`; no IA Analyze, `IA_ANALYZE_INTERNAL_TOKEN`. Ambos devem ter o **mesmo valor** — o Gateway o envia no header `x-ia-analyze-token` e o serviço valida. Use uma string longa e aleatória (mínimo 32 caracteres). No local, com `IA_ANALYZE_INTERNAL_TOKEN` vazio, `analyze` e `synthesize-insights` ficam abertos; na Vercel, sem ele, `diagnose-scope` e `generate-company-questions` respondem `503`.

!!! note "`DATABASE_URL` em produção — use o Transaction Pooler"
    Na Vercel, o Gateway usa a conexão **Transaction Pooler** do Supabase (`...pooler.supabase.com:6543`, com `prepare: false`), não a conexão direta (`db.[ref].supabase.co`), e entra com o papel `feedback_app`, que só lê e escreve dados. O secret `DATABASE_URL` do GitHub, que aplica as migrations no deploy, usa o `postgres`. Ver [CI/CD — Workflows e Deploys](workflows.md).

---

## Passo 4 — Configure o Banco de Dados

O banco local roda em Docker e é montado pelo API Gateway. A **fonte única do schema** são as migrations Drizzle do Gateway (`drizzle/schema.ts` + `drizzle/*.sql`); a mesma sequência é aplicada em produção pelo workflow de deploy da API. No repositório do Gateway:

```bash
npm run db:local:up     # sobe Postgres (host :5433) + Mailpit (UI :8025, SMTP :1025)
npm run db:reset        # recria o schema pelas migrations + seed determinístico + usuário de teste
```

O `db:reset` roda, nesta ordem:

1. `node scripts/db-local.mjs` — apaga e recria os schemas, aplica as migrations (`drizzle-kit migrate`) e o seed `db/local/seed.sql`: duas empresas (A `aaaaaaaa-0000-0000-0000-000000000001` e B `bbbbbbbb-0000-0000-0000-000000000001`), com pontos de coleta, perguntas, feedbacks, análises e um relatório de insights cada.
2. `npm run db:seed:e2e` — cria o usuário de teste do Better Auth (e-mail verificado e senha) com `E2E_TEST_EMAIL` e `E2E_TEST_PASSWORD` e o vincula à empresa de `E2E_TEST_ENTERPRISE_ID` (a empresa A serve). Exige também `DATABASE_URL` e `BETTER_AUTH_SECRET`; sem essas variáveis o `db:reset` falha neste passo, com o schema e o seed SQL já aplicados. Pode ser rodado sozinho e é idempotente.

Depois, entre no app com o e-mail e a senha do usuário de teste.

!!! danger "Nunca aponte o `db:reset` para produção"
    O script faz `DROP SCHEMA` e por isso recusa rodar se a `DATABASE_URL` não for local (`127.0.0.1`/`localhost`) ou se parecer um host remoto (Supabase, pooler, Neon etc.).

Para derrubar os containers ao terminar: `npm run db:local:down` (os dados ficam no volume do Docker).

As principais tabelas são:

| Tabela | Para quê |
|---|---|
| `public.enterprise` | Dados da empresa |
| `public.collecting_data_enterprise` | Configurações de coleta e contexto da IA |
| `public.catalog_items` | Produtos, serviços e departamentos |
| `public.collection_points` | Pontos de coleta (empresa e itens do catálogo) |
| `public.feedback` | Feedbacks coletados |
| `public.feedback_analysis` | Análises geradas pela IA |
| `public.feedback_insights_report` | Relatórios de insights consolidados |
| `public.enterprise_ia_config` | Chave OpenRouter (cifrada) e modelo de cada empresa |
| `public.ia_analysis_job` | Fila dos trabalhos de IA |
| `public.tracked_devices` | Controle anti-spam por dispositivo |

> **Tabelas de autenticação (Better Auth):** `user`, `session`, `account` e `verification`, no mesmo Postgres, também criadas pelas migrations. A lista das migrations e o papel de cada uma estão em [`docs/migrations-drizzle.md`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/migrations-drizzle.md), no Gateway.

!!! note "E o `database/sql/` deste repositório?"
    É um dump SQL organizado por tipo de objeto, anterior às migrations Drizzle. Serve de consulta (`database/sql/DESCRICOES.md` descreve os objetos), mas não é ele que cria o banco e pode estar defasado em relação às migrations.

---

## Passo 5 — Inicie os Serviços

Cada serviço roda a partir do seu próprio repositório (abra um terminal por serviço). O Mailpit já subiu com o `npm run db:local:up` do Passo 4: os e-mails de confirmação de cadastro e de recuperação de senha aparecem em http://localhost:8025, sem ser enviados de verdade.

```bash
# feedback-analytics-api-gateway
npm run dev        # API Gateway em http://localhost:3000

# feedback-analytics-ia-analyze
npm run dev        # IA Analyze em http://localhost:4100

# feedback-analytics-web
npm run dev        # Frontend em http://localhost:5173
```

> Fora da Vercel, o Gateway inicia sozinho o worker que processa a fila de IA — não é preciso agendar nada no local.

---

## Passo 6 — Verifique a Instalação

```bash
curl http://localhost:3000/api/health
# → { "ok": true }

curl http://localhost:4100/internal/health
# → { "ok": true, "service": "ia-analyze" }
```

Se ambos retornarem `ok: true`, o ambiente está funcionando. Abra http://localhost:5173 e entre com o usuário de teste.

---

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `400 ia_config_required` | Empresa sem chave OpenRouter | Configure a chave e o modelo em **Configuração de IA** |
| `401 unauthorized_internal_request` | Tokens internos diferentes | Iguale `IA_ANALYZE_REMOTE_TOKEN` (gateway) e `IA_ANALYZE_INTERNAL_TOKEN` (ia-analyze) |
| `422 collecting_data_required_for_analysis` | Empresa sem contexto para a IA | Preencha o objetivo da empresa, o objetivo analítico e o resumo do negócio |
| `422 insufficient_feedbacks_for_analysis` | Menos de 10 feedbacks no escopo | Colete mais feedbacks antes de analisar |
| `ECONNREFUSED :4100` | IA Analyze não está rodando | Suba o serviço `feedback-analytics-ia-analyze` |
| `ECONNREFUSED 127.0.0.1:5433` | Banco local fora do ar | Abra o Docker Desktop e rode `npm run db:local:up` no Gateway |
| `db:reset` falha no `db:seed:e2e` | Faltam variáveis do usuário de teste | Preencha `E2E_TEST_EMAIL`, `E2E_TEST_PASSWORD`, `E2E_TEST_ENTERPRISE_ID` e `BETTER_AUTH_SECRET` e rode `npm run db:seed:e2e` |
| `ENOTFOUND db.[ref].supabase.co` | `DATABASE_URL` de produção usando conexão direta | Troque pela conexão **Transaction Pooler** (`...pooler.supabase.com:6543`) |

---

## Executar os Testes

Cada repositório roda seus próprios testes (veja [Testes](testes/visao-geral.md) para a estratégia geral):

```bash
# feedback-analytics-api-gateway e feedback-analytics-ia-analyze
npm test               # Vitest, execução única

# feedback-analytics-web
npm run test -- run    # Vitest, execução única (o `npm test` da Web fica em modo watch)

# em todos
npm run lint
```
