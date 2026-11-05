# CI/CD — Workflows e Deploys

> Estratégia de integração contínua e deploy da plataforma, baseada em GitHub Actions com hospedagem na Vercel.

!!! info "Onde os workflows vivem"
    Com a separação em **multi-repo**, cada serviço carrega seus próprios workflows em `.github/workflows/` do seu repositório. Este documento descreve a **estratégia compartilhada** (as decisões e o porquê); os arquivos concretos e atuais estão em cada repo de código:
    [web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/tree/main/.github/workflows) ·
    [api-gateway](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/.github/workflows) ·
    [ia-analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/tree/main/.github/workflows).
    A publicação **desta documentação** é o único workflow deste repositório (`deploy-docs.yml`). O repositório de contratos (`feedback-analytics-contracts`) não tem workflows.

---

## Sumário

1. [Visão Geral](#visão-geral)
2. [Por que foi construído assim](#por-que-foi-construído-assim)
3. [Estratégia de Branches](#estratégia-de-branches)
4. [Workflows por repositório](#workflows-por-repositório)
5. [Secrets Necessários](#secrets-necessários)
6. [Fluxo Completo](#fluxo-completo)

---

## Visão Geral

O projeto utiliza GitHub Actions com **deploy totalmente manual e confirmado** na Vercel. **Só a branch `main` é deployada para produção** — os workflows de deploy exigem disparo manual via `workflow_dispatch`, aceitam apenas `main` e pedem confirmação explícita digitando `ok`.

O CI automático (lint, typecheck e testes de **unidade**; na Web, também o build) roda em push e Pull Requests nas branches protegidas de cada repo (`main` e `developer`), bloqueando merges quando falha. Os testes que exigem **banco de dados ou ambiente deployado** — integração do API Gateway e e2e (Playwright) do web — **não são mais automatizados**: foram convertidos em **testes manuais** (ver [runbook do API Gateway](testes/manuais-api-gateway.md) e [runbook do Web](testes/manuais-web.md)).

| Serviço (repo) | CI | Deploy | Alvo |
|---|---|---|---|
| `feedback-analytics-web` | lint + typecheck + build + testes unitários (Node 24) | `deploy-web.yml` (manual, só `main`, Node 20) | Site estático (CDN) |
| `feedback-analytics-api-gateway` | lint + typecheck + testes unitários · smoke de migrations (Node 20) | `deploy-api.yml` (manual, só `main`, aplica as migrations antes) | Serverless Function |
| `feedback-analytics-ia-analyze` | lint + typecheck + testes unitários (Node 20) | `deploy-ia-analyze.yml` (manual, só `main`) | Serverless Function |
| `feedback-analytics` (docs) | `deploy-docs.yml` em pull request (só o build MkDocs `--strict`) | `deploy-docs.yml` (push a `main` que mexe na doc, ou manual) | GitHub Pages |

Além deles, o API Gateway tem o `ia-worker.yml`, que chama o worker da fila de IA em produção a cada 5 minutos.

---

## Por que foi construído assim

### O contexto: três serviços deployáveis independentes

A plataforma tem três peças deployáveis — frontend, API Gateway e serviço de IA —, hoje em **repositórios separados**. Cada uma tem seu próprio projeto na Vercel e seu próprio ciclo de vida. Isso separa naturalmente CI de CD:

- **CI é automático e universal** — roda para tudo, em toda branch protegida, sem exceção. É o portão de qualidade.
- **CD é manual e granular** — cada serviço é deployado individualmente, apenas quando necessário, por decisão humana explícita.

> A separação em multi-repo reforçou esse modelo: antes (monorepo) um push podia acionar validação dos quatro pacotes; agora cada repo valida e deploya só a si mesmo. Veja [a decisão de arquitetura](../arquitetura/historico-de-decisoes/decisao-monorepo-vs-monolito.md).

### Por que o deploy é manual e só em `main`

Num projeto com equipe pequena, **controle supera velocidade**. Deploy automático em `main` significa que qualquer merge — mesmo um ajuste de texto — dispara um ciclo de deploy. Além do custo desnecessário, isso retira do time a decisão de *quando* uma mudança chega ao usuário.

O `workflow_dispatch` com confirmação `ok` resolve isso: o merge acontece, o CI valida, mas a exposição para produção é uma decisão deliberada. Manter **apenas `main` em produção** simplifica a operação: não há um ambiente de homologação paralelo (`developer`) a manter, nem um segundo conjunto de credenciais/secrets a configurar e sincronizar — o que estava tomando tempo desproporcional ao valor. A branch `developer` continua existindo como **branch de integração** (recebe CI), mas **não é deployada**.

### Por que a confirmação `ok` existe

Evitar cliques acidentais no botão "Run workflow" da interface do GitHub. Sem a confirmação, é fácil disparar um deploy de produção por engano ao testar o painel de Actions. O custo de digitar `ok` é baixo; o de um deploy acidental num momento errado pode ser alto.

### Pirâmide de testes: o que é automático e o que é manual

O CI executa a base da pirâmide — **testes de unidade (Vitest)** — em **toda** PR, em jobs paralelos. São testes herméticos (100% mockados, sem rede nem secrets), rápidos e determinísticos: o lugar certo para bloquear cedo. No API Gateway há ainda um **smoke de migrations** (`schema-migrations.yml`) que sobe um Postgres efêmero no próprio runner (sem credenciais externas) e verifica que as migrations Drizzle aplicam limpo e batem com o `schema.ts`.

O meio e o topo da pirâmide — **integração** (API Gateway, contra Postgres local) e **e2e** (web, Playwright, contra ambiente deployado) — exigiam um banco semeado ou um ambiente homolog no ar, com o respectivo conjunto de credenciais. Esse custo de infraestrutura e de manutenção de secrets passou a superar o retorno para o tamanho do time, então essas suítes foram **removidas do código e do CI** e viraram **roteiros de teste manual** (no Gateway sobrou um único teste contra Postgres real, `onboarding.database.test.ts`, que só roda com `ONBOARDING_TEST_DATABASE_URL` definida e fica pulado no CI):

- [Testes manuais — API Gateway](testes/manuais-api-gateway.md) — reproduz os cenários de integração/e2e via a UI e/ou `curl` aos endpoints, contra o banco local semeado.
- [Testes manuais — Web (UCs)](testes/manuais-web.md) — reproduz os casos de uso UC-01…UC-12 clicando na aplicação.

### Vantagens e limites

- **CI nunca pode ser bypassado** — lint, typecheck e testes unitários (e o build, na Web) são obrigatórios em qualquer PR.
- **Serviços independentes** — deploya-se só o frontend sem tocar a API ou o serviço de IA, e vice-versa. Janela de risco menor a cada deploy.
- **Deploy consciente** — nada vai para produção sem ação intencional, e só a partir de `main`.
- **Menos superfície de configuração** — sem ambiente homolog paralelo, some um conjunto inteiro de secrets e um passo de deploy por serviço.
- **Produção não é atualizada automaticamente após merge** — se o dev esquece de disparar o deploy, a `main` fica com código mais novo que o ambiente silenciosamente.
- **A cobertura de integração/e2e depende de disciplina manual** — sem o gate automatizado, rodar os runbooks antes de promover para produção passa a ser responsabilidade do time (não há mais bloqueio de CI para isso).

---

## Estratégia de Branches

Cada repositório de serviço segue um fluxo linear de promoção de código:

```
feature → developer → main
```

| Branch | Ambiente | Papel |
|---|---|---|
| `feature/*` | Local | Desenvolvimento. Nunca deployada diretamente. |
| `developer` | — (sem deploy) | Branch de **integração**. Recebe merges de features e roda **CI** (lint/typecheck/unit/build). **Não é deployada.** |
| `main` | Vercel Production | Recebe merges vindos de `developer`. Única branch **deployada** (manual, com confirmação). |

> **Nota:** não há mais ambiente de homologação (`homolog`/alias `-developer`) nem provisionamento de credenciais E2E por deploy. `developer` é só uma branch de integração com CI.

---

## Workflows por repositório

Os passos concretos (steps, `npm ci`, config Vercel) vivem em cada repo, junto do código que validam. Em linhas gerais:

- **CI (`ci.yml`)** — roda em push/PR nas branches protegidas (`main` e `developer`), em dois jobs paralelos. Os dois reescrevem `ssh→https` no git (para o `npm ci` baixar o `@feedback/lib-shared`, repositório público, sem token) e instalam as dependências. O job de qualidade roda lint + typecheck (`tsc -p tsconfig.ci.json --noEmit`, que exclui os testes) e, na Web, também `npm run build`; o job `unit-tests` roda o Vitest (`npm test` no Gateway e no IA Analyze, `npm run test -- run` na Web). Node 20 no Gateway e no IA Analyze, Node 24 na Web.
- **Smoke de migrations (`schema-migrations.yml`, no api-gateway)** — em push/PR para `main` e `developer` que tocam `db/**`, `drizzle/**`, `scripts/db-local.mjs`, `docker-compose.yml`, `package.json`, `package-lock.json` ou o próprio workflow: sobe o Postgres do docker-compose no runner, roda `node scripts/db-local.mjs` (migrations + seed) e `npm run db:check` (`drizzle-kit check`) para garantir que `schema.ts` ↔ migrations batem. Não usa credenciais externas.
- **Deploy (`deploy-*.yml`)** — `workflow_dispatch` manual com o campo `confirm_deploy` = `ok`, aceito **apenas na branch `main`**; roda `npm ci` e publica com a Vercel CLI (`npx vercel deploy --yes --prod --local-config vercel.json`), em Node 20. Por serviço:
    - **API Gateway (`deploy-api.yml`)** — gera o bundle com `esbuild` (`index.ts → _bundle.cjs`) e executa `npm run db:migrate` com o secret `DATABASE_URL` antes de publicar; secret ausente ou migration com erro interrompem o deploy. Execuções na mesma branch ficam em fila, sem cancelar a que está em andamento.
    - **Web (`deploy-web.yml`)** — o workflow não builda: envia o código e a Vercel faz o build, por isso as variáveis `VITE_*` ficam no projeto da Vercel. Um deploy novo cancela o anterior.
    - **IA Analyze (`deploy-ia-analyze.yml`)** — sem bundle: o `@vercel/node` roda `src/index.ts` direto. Um deploy novo cancela o anterior.
- **Worker da fila de IA (`ia-worker.yml`, no api-gateway)** — roda automaticamente a cada cinco minutos (cron `2-59/5 * * * *`, evitando o minuto zero) e também aceita disparo manual. Envia `POST <API_GATEWAY_URL>/api/internal/worker/tick` com o header `x-worker-token`, onde `API_GATEWAY_URL` é a variável do repositório (sem ela, `https://feedback-analytics-api-gateway.vercel.app`); o secret `WORKER_TICK_TOKEN` do GitHub deve ter exatamente o mesmo valor da variável homônima no API Gateway publicado na Vercel. Uma execução por vez, com limite de 6 minutos.
- **Deploy da documentação (`deploy-docs.yml`, este repo)** — no push a `main` que mexe em `docs/**`, `mkdocs.yml`, `requirements-docs.txt` ou no próprio workflow (ou por disparo manual): instala o MkDocs Material com Python 3.12, roda `mkdocs build --strict` e publica no GitHub Pages. Em pull request com os mesmos caminhos, roda só o build estrito, sem publicar: o link ou a âncora quebrada aparece antes do merge.

Para os detalhes de cada workflow, veja o `.github/workflows/` do respectivo repositório (links no topo desta página).

---

## Secrets Necessários

Os secrets são configurados em cada repositório GitHub em **Settings → Secrets and variables → Actions**. Com o deploy `main`-only e sem ambiente homolog, o CI é hermético (sem secrets) e o que resta é o necessário para o deploy na Vercel:

| Secret | Usado em | Descrição |
|---|---|---|
| `VERCEL_TOKEN` / `VERCEL_ORG_ID` | Deploys | Autenticação e organização na Vercel |
| `VERCEL_PROJECT_ID_WEB` / `_API_GATEWAY` / `_IA_ANALYZE` | Deploy do respectivo serviço | ID do projeto na Vercel |
| `DATABASE_URL` | Deploy do API Gateway | Conexão de produção usada por `drizzle-kit migrate` antes do deploy, com o `postgres` (dono das tabelas), não com o `feedback_app` que o app usa na Vercel |
| `WORKER_TICK_TOKEN` | `ia-worker.yml` do API Gateway | Autentica o agendador no endpoint interno; deve coincidir com a variável da Vercel |
| `API_GATEWAY_URL` (variável, opcional) | `ia-worker.yml` do API Gateway | Endereço do gateway que o agendador chama; sem ela, `https://feedback-analytics-api-gateway.vercel.app` |

> Os secrets antes usados pelo e2e/homolog (`SUPABASE_*`, `E2E_TEST_*`, `E2E_DATABASE_URL_DEVELOPER`, `BETTER_AUTH_SECRET_DEVELOPER`) **não são mais necessários** no CI. `DATABASE_URL` permanece necessária no GitHub exclusivamente para aplicar migrations no deploy do Gateway, e `WORKER_TICK_TOKEN` para chamar o worker. As variáveis de runtime continuam configuradas no projeto correspondente da Vercel. O `deploy-docs.yml` deste repositório não usa secrets: publica no GitHub Pages com as permissões `pages: write` e `id-token: write` do próprio workflow.

---

## Fluxo Completo

| Etapa | Branch | O que acontece |
|---|---|---|
| 1 | `feature/*` | Desenvolvimento local |
| 2 | PR → `developer` | CI roda automaticamente: lint + typecheck + testes unitários (+ build na Web; + smoke de migrations no Gateway, quando a PR mexe no banco). Merge bloqueado se falhar. |
| 3 | `developer` (integração) | Código integrado. Antes de promover, o time roda os [runbooks manuais](testes/manuais-web.md) conforme necessário. |
| 4 | PR → `main` | CI roda novamente (lint + typecheck + unit, + build na Web). Merge bloqueado se falhar. |
| 5 | `main` (produção) | Deploy manual via `workflow_dispatch` com confirmação `ok` → deploy `--prod` na Vercel do serviço alterado (no Gateway, depois de aplicar as migrations pendentes) |

> **Cada serviço é deployado independentemente** — deploya-se somente o frontend sem tocar o API Gateway ou o serviço de IA.
