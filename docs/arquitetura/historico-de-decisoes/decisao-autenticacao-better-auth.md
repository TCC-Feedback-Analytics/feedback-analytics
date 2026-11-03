# Autenticação: de Supabase Auth para Better Auth

!!! note "Status (jul/2026)"
    A autenticação do sistema **saiu do Supabase Auth** e passou para o **Better Auth**. O **banco continua sendo o mesmo Postgres** (hospedado no Supabase, acessado direto por `DATABASE_URL` + Drizzle). "Sair do Supabase" aqui significou sair do **Auth + SDK**, não do banco.

!!! info "Situação em nov/2026"
    A decisão segue valendo. Depois dela, entraram a **entrada com o Google** (pelo handler nativo do Better Auth, em `/api/auth/*`) e a **exclusão da conta**; os e-mails de produção passaram do SendGrid para a **Brevo**; e o app passou a entrar no banco com o papel **`feedback_app`**, de menor privilégio, com a RLS ligada em todas as tabelas (migration `0013`).

## Em uma frase

Login, cadastro, sessão e e-mails de autenticação passaram a ser responsabilidade do **api-gateway** (via **Better Auth**), em vez do Supabase Auth. O banco de dados não mudou.

## O que mudou

| Antes (Supabase Auth) | Agora (Better Auth) |
|---|---|
| Login/cadastro/sessão pelo **Supabase Auth** (SDK do Supabase) | Login/cadastro/sessão pelo **Better Auth**, exposto pelo **api-gateway** |
| Usuários na tabela `auth.users` (schema `auth` gerenciado pelo Supabase) | Tabelas do Better Auth (`user`, `session`, `account`, `verification`) **no mesmo Postgres** |
| Sessão validada por `supabase.auth.getUser()` / `auth.uid()` no banco | Sessão validada **na aplicação** (Gateway) a partir do **cookie httpOnly** |
| E-mails (confirmação, recuperação) enviados pelo Supabase | E-mails enviados pelo Gateway via **SMTP** (Brevo em produção, Mailpit no local) |

O **app web não mudou o jeito de chamar auth**: ele já chamava os endpoints do Gateway (`/api/public/auth/login|register|logout|forgot-password|resend-confirmation`), que agora usam Better Auth por baixo. O Gateway devolve o cookie de sessão; o web só envia as requisições com credencial (`credentials: 'include'`).

## O que NÃO mudou

- **O banco é o mesmo Postgres** do Supabase, acessado direto por connection string (`DATABASE_URL`, pooler) com **Drizzle ORM**.
- O **isolamento por empresa (tenant)** é feito na aplicação (filtro explícito por `enterprise_id`). O app entra com o papel `feedback_app`, que a policy da RLS deixa ver todas as linhas; a RLS fica ligada para barrar os outros papéis. Ver [ORM × RLS: nossa decisão](../orm-rls-decisao.md).
- O fluxo público anônimo (QR Code) também passa pelo Gateway e pelo Drizzle, com o mesmo filtro por empresa.

## Variáveis de ambiente (api-gateway)

**Removidas (não usar mais):** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `AUTH_PROVIDER`.

**Novas / obrigatórias:**

| Variável | Para quê |
|---|---|
| `DATABASE_URL` | Conexão do Postgres (o mesmo do Supabase, pooler); em produção, com o papel `feedback_app` |
| `BETTER_AUTH_SECRET` | Segredo aleatório (`openssl rand -base64 32`). **Sem ele o app não sobe.** |
| `BETTER_AUTH_URL` | URL pública do Gateway (local: `http://localhost:3000`) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Entrada com o Google (opcional; a Web só mostra o botão com `VITE_GOOGLE_AUTH_ENABLED=true`). |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` / `SMTP_USER` / `SMTP_PASS` / `MAIL_FROM` | Envio de e-mail. Prod: Brevo (`smtp-relay.brevo.com:587`, `SMTP_SECURE=false`, login e chave SMTP da Brevo). Local: Mailpit (`127.0.0.1:1025`). |
| `IA_CONFIG_ENCRYPTION_KEY` | Chave mestra (`openssl rand -base64 32`) usada para cifrar chaves de IA (BYO-key) com AES-256-GCM em repouso no Postgres. |
| `REQUIRE_USER_IA_KEY` | Flag booleana (`true`/`false`) que define se o uso de chave própria de IA pela empresa é mandatório ou se há fallback global. |

Ver o passo a passo em [Guia de Instalação](../../guias/guia-instalacao.md).

## Rollback

Não há mais a flag `AUTH_PROVIDER`. **Rollback = redeploy do commit anterior.**
