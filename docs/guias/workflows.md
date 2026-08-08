# CI/CD — Workflows e Deploys

> Estratégia de integração contínua e deploy da plataforma, baseada em GitHub Actions com hospedagem na Vercel.

!!! info "Onde os workflows vivem"
    Com a separação em **multi-repo**, cada serviço carrega seus próprios workflows em `.github/workflows/` do seu repositório. Este documento descreve a **estratégia compartilhada** (as decisões e o porquê); os arquivos concretos e atuais estão em cada repo de código:
    [web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/tree/main/.github/workflows) ·
    [api-gateway](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/.github/workflows) ·
    [ia-analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/tree/main/.github/workflows).
    A publicação **desta documentação** é o único workflow deste repositório (`deploy-docs.yml`).

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

O CI automático (lint, typecheck, testes de **unidade** e build) roda em push e Pull Requests nas branches protegidas de cada repo (`main` e `developer`), bloqueando merges quando falha. Os testes que exigem **banco de dados ou ambiente deployado** — integração do API Gateway e e2e (Playwright) do web — **não são mais automatizados**: foram convertidos em **testes manuais** (ver [runbook do API Gateway](testes/manuais-api-gateway.md) e [runbook do Web](testes/manuais-web.md)).

| Serviço (repo) | CI | Deploy | Alvo |
|---|---|---|---|
| `feedback-analytics-web` | lint + typecheck + testes unitários + build | `deploy-web.yml` (manual, só `main`) | Site estático (CDN) |
| `feedback-analytics-api-gateway` | lint + typecheck + testes unitários + bundle · smoke de migrations | `deploy-api.yml` (manual, só `main`) | Serverless Function |
| `feedback-analytics-ia-analyze` | lint + typecheck + testes unitários | `deploy-ia-analyze.yml` (manual, só `main`) | Serverless Function |
| `feedback-analytics` (docs) | build MkDocs `--strict` | `deploy-docs.yml` (push a `main`) | GitHub Pages |

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

O meio e o topo da pirâmide — **integração** (API Gateway, contra Postgres local) e **e2e** (web, Playwright, contra ambiente deployado) — exigiam um banco semeado ou um ambiente homolog no ar, com o respectivo conjunto de credenciais. Esse custo de infraestrutura e de manutenção de secrets passou a superar o retorno para o tamanho do time, então essas suítes foram **removidas do código e do CI** e viraram **roteiros de teste manual**:

- [Testes manuais — API Gateway](testes/manuais-api-gateway.md) — reproduz os cenários de integração/e2e via a UI e/ou `curl` aos endpoints, contra o banco local semeado.
- [Testes manuais — Web (UCs)](testes/manuais-web.md) — reproduz os casos de uso UC-01…UC-12 clicando na aplicação.

### Vantagens e limites

- **CI nunca pode ser bypassado** — lint, typecheck, testes unitários e build são obrigatórios em qualquer PR.
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

- **CI (`ci.yml`)** — roda em push/PR nas branches protegidas (`main` e `developer`): instala dependências (incluindo o pacote `@feedback/lib-shared`), roda lint + typecheck (`tsc --noEmit` com `tsconfig.ci.json`, que exclui testes) + testes de unidade; no web, também `build`.
- **Smoke de migrations (`schema-migrations.yml`, no api-gateway)** — em push/PR que tocam `db/`, `drizzle/` ou os scripts de banco: sobe um Postgres efêmero via docker-compose, aplica as migrations + seed e roda `drizzle-kit check` para garantir que `schema.ts` ↔ migrations batem. Não usa credenciais externas.
- **Deploy (`deploy-*.yml`)** — `workflow_dispatch` manual com confirmação `ok`, aceito **apenas na branch `main`**; usa a Vercel CLI com `--local-config vercel.json` do repo, fazendo `vercel deploy --prod`. O `feedback-analytics-api-gateway` roda uma etapa de `esbuild` antes, empacotando o entrypoint no `_bundle.cjs` apontado pelo `vercel.json`.
- **Deploy da documentação (`deploy-docs.yml`, este repo)** — publica o site MkDocs no GitHub Pages no push a `main`.

Para os detalhes de cada workflow, veja o `.github/workflows/` do respectivo repositório (links no topo desta página).

---

## Secrets Necessários

Os secrets são configurados em cada repositório GitHub em **Settings → Secrets and variables → Actions**. Com o deploy `main`-only e sem ambiente homolog, o CI é hermético (sem secrets) e o que resta é o necessário para o deploy na Vercel:

| Secret | Usado em | Descrição |
|---|---|---|
| `VERCEL_TOKEN` / `VERCEL_ORG_ID` | Deploys | Autenticação e organização na Vercel |
| `VERCEL_PROJECT_ID_WEB` / `_API_GATEWAY` / `_IA_ANALYZE` | Deploy do respectivo serviço | ID do projeto na Vercel |

> Os secrets antes usados pelo e2e/homolog (`SUPABASE_*`, `E2E_TEST_*`, `E2E_DATABASE_URL_DEVELOPER`, `BETTER_AUTH_SECRET_DEVELOPER`) **não são mais necessários** no CI. As variáveis de ambiente de runtime de cada serviço continuam sendo configuradas no painel da Vercel do respectivo projeto.

---

## Fluxo Completo

| Etapa | Branch | O que acontece |
|---|---|---|
| 1 | `feature/*` | Desenvolvimento local |
| 2 | PR → `developer` | CI roda automaticamente: lint + typecheck + testes unitários + build. Merge bloqueado se falhar. |
| 3 | `developer` (integração) | Código integrado. Antes de promover, o time roda os [runbooks manuais](testes/manuais-web.md) conforme necessário. |
| 4 | PR → `main` | CI roda novamente (lint + typecheck + unit + build). Merge bloqueado se falhar. |
| 5 | `main` (produção) | Deploy manual via `workflow_dispatch` com confirmação `ok` → deploy `--prod` na Vercel do serviço alterado |

> **Cada serviço é deployado independentemente** — deploya-se somente o frontend sem tocar o API Gateway ou o serviço de IA.
