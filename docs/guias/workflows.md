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

O projeto utiliza GitHub Actions com **deploy totalmente manual e confirmado** na Vercel. Não há deploy automático em nenhuma branch de código — os workflows de deploy exigem disparo manual via `workflow_dispatch` e confirmação explícita digitando `ok`.

O CI automático (lint, typecheck, testes de unidade/integração e build) roda em push e Pull Requests nas branches protegidas de cada repo, bloqueando merges quando falha. O e2e roda como **gate da promoção para produção** (PR → `main`) contra o ambiente de homologação já deployado.

| Serviço (repo) | CI | Deploy | Alvo |
|---|---|---|---|
| `feedback-analytics-web` | lint + typecheck + testes + build | `deploy-web.yml` (manual) + e2e pós-deploy | Site estático (CDN) |
| `feedback-analytics-api-gateway` | lint + typecheck + testes + bundle | `deploy-api.yml` (manual) | Serverless Function |
| `feedback-analytics-ia-analyze` | lint + typecheck + testes | `deploy-ia-analyze.yml` (manual) | Serverless Function |
| `feedback-analytics` (docs) | build MkDocs `--strict` | `deploy-docs.yml` (push a `main`) | GitHub Pages |

---

## Por que foi construído assim

### O contexto: três serviços deployáveis independentes

A plataforma tem três peças deployáveis — frontend, API Gateway e serviço de IA —, hoje em **repositórios separados**. Cada uma tem seu próprio projeto na Vercel e seu próprio ciclo de vida. Isso separa naturalmente CI de CD:

- **CI é automático e universal** — roda para tudo, em toda branch protegida, sem exceção. É o portão de qualidade.
- **CD é manual e granular** — cada serviço é deployado individualmente, apenas quando necessário, por decisão humana explícita.

> A separação em multi-repo reforçou esse modelo: antes (monorepo) um push podia acionar validação dos quatro pacotes; agora cada repo valida e deploya só a si mesmo. Veja [a decisão de arquitetura](../arquitetura/historico-de-decisoes/decisao-monorepo-vs-monolito.md).

### Por que o deploy é manual

Num projeto com equipe pequena, **controle supera velocidade**. Deploy automático em `main` significa que qualquer merge — mesmo um ajuste de texto — dispara um ciclo de deploy. Além do custo desnecessário, isso retira do time a decisão de *quando* uma mudança chega ao usuário.

O `workflow_dispatch` com confirmação `ok` resolve isso: o merge acontece, o CI valida, mas a exposição para produção é uma decisão deliberada. Em projetos maiores, o caminho natural seria migrar os deploys de produção para automático após o CI passar — mas essa transição faz sentido quando o volume de deploys justifica.

### Por que a confirmação `ok` existe

Evitar cliques acidentais no botão "Run workflow" da interface do GitHub. Sem a confirmação, é fácil disparar um deploy de produção por engano ao testar o painel de Actions. O custo de digitar `ok` é baixo; o de um deploy acidental num momento errado pode ser alto.

### Pirâmide de testes e por que o e2e gateia a PR → `main`

O CI executa a base e o meio da pirâmide — **testes de unidade e integração (Vitest)** — em **toda** PR, em jobs paralelos. São testes herméticos (100% mockados, sem rede nem secrets), rápidos e determinísticos: o lugar certo para bloquear cedo.

O topo da pirâmide — **e2e (Playwright)**, no repo `feedback-analytics-web` — precisa de um ambiente real no ar e exercita o login por **cookie cross-domain**. Por isso não roda como teste hermético; roda como **gate da PR → `main`** contra o ambiente de **homologação já deployado** (`feedback-analytics-web-homolog.vercel.app`). Faz sentido porque toda PR para `main` vem obrigatoriamente da branch de homologação, um alias estável onde a derivação web→api e o cookie `SameSite=None; Secure` já funcionam.

Por que **não** bloquear o deploy de homologação com e2e? Porque o frontend tem uma proteção anti-cross-branch que faz uma URL de preview efêmera derivar uma API de hash inexistente e ignorar uma URL de API explícita de outra branch. Um preview efêmero não consegue autenticar contra a API homolog fixa. Testar contra o homolog já deployado contorna isso sem mexer no código do app.

### Vantagens e limites

- **CI nunca pode ser bypassado** — lint, typecheck, testes e build são obrigatórios em qualquer PR; o e2e é obrigatório na promoção para `main` (web).
- **Serviços independentes** — deploya-se só o frontend sem tocar a API ou o serviço de IA, e vice-versa. Janela de risco menor a cada deploy.
- **Deploy consciente** — nada vai para produção sem ação intencional.
- **Produção não é atualizada automaticamente após merge** — se o dev esquece de disparar o deploy, a `main` fica com código mais novo que o ambiente silenciosamente.
- **E2E depende do homolog estar atualizado** — o gate testa o ambiente deployado; se o homolog não foi redeployado com o código a promover, valida uma versão defasada.
- **E2E muta dados reais** — os specs usam `service_role` no Supabase compartilhado (seed/cleanup), então rodar o gate concorrentemente pode gerar flakiness.

---

## Estratégia de Branches

Cada repositório de serviço segue um fluxo linear de promoção de código:

```
feature → homologação → main
```

| Branch | Ambiente | Papel |
|---|---|---|
| `feature/*` | Local | Desenvolvimento. Nunca deployada diretamente. |
| Homologação (`homolog` / `developer` no web) | Vercel Preview (alias fixo) | Recebe merges de features. Deploy manual gera URL de preview para validação. |
| `main` | Vercel Production | Recebe apenas merges vindos da branch de homologação. |

> **Nota:** no `feedback-analytics-web` a branch de homologação foi renomeada de `homolog` para `developer` (apenas o nome; o subdomínio Vercel segue `-homolog`). Consulte cada repo para a convenção vigente.

---

## Workflows por repositório

Os passos concretos (steps, `npm ci`, matrizes de teste, config Vercel) vivem em cada repo, junto do código que validam. Em linhas gerais:

- **CI (`ci.yml`)** — roda em push/PR nas branches protegidas: instala dependências (incluindo o pacote `@feedback/lib-shared`), roda lint + typecheck (`tsc --noEmit` com `tsconfig.ci.json`, que exclui testes) + testes de unidade/integração; no web, também `build`.
- **Deploy (`deploy-*.yml`)** — `workflow_dispatch` manual com confirmação `ok`; usa a Vercel CLI com `--local-config vercel.json` do repo. O `feedback-analytics-api-gateway` roda uma etapa de `esbuild` antes, empacotando o entrypoint no `_bundle.cjs` apontado pelo `vercel.json`.
- **E2E gate (`e2e-main.yml`, no web)** — `pull_request` para `main`: roda a suíte Playwright contra o alias de homologação já deployado.
- **Deploy da documentação (`deploy-docs.yml`, este repo)** — publica o site MkDocs no GitHub Pages no push a `main`.

Para os detalhes de cada workflow, veja o `.github/workflows/` do respectivo repositório (links no topo desta página).

---

## Secrets Necessários

Os secrets são configurados em cada repositório GitHub em **Settings → Secrets and variables → Actions**. Os principais:

| Secret | Usado em | Descrição |
|---|---|---|
| `SUPABASE_URL` | CI (build web) · E2E | URL do projeto Supabase |
| `SUPABASE_ANON_KEY` | CI (build web) | Chave anon do Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | E2E (seed/cleanup) | Chave `service_role` para os testes e2e |
| `E2E_TEST_EMAIL` / `E2E_TEST_PASSWORD` / `E2E_TEST_ENTERPRISE_ID` | E2E | Conta e empresa de teste usadas no login dos specs |
| `VERCEL_TOKEN` / `VERCEL_ORG_ID` | Deploys | Autenticação e organização na Vercel |
| `VERCEL_PROJECT_ID_WEB` / `_API_GATEWAY` / `_IA_ANALYZE` | Deploy do respectivo serviço | ID do projeto na Vercel |

---

## Fluxo Completo

| Etapa | Branch | O que acontece |
|---|---|---|
| 1 | `feature/*` | Desenvolvimento local |
| 2 | PR → homologação | CI roda automaticamente: lint + typecheck + testes + build. Merge bloqueado se falhar. |
| 3 | homologação (validação) | Deploy manual via `workflow_dispatch` com confirmação `ok` → URL de preview na Vercel; e2e pós-deploy valida o ambiente |
| 4 | PR → `main` | CI roda novamente **e** o `e2e-main` (web) roda a suíte e2e contra o homolog — merge bloqueado se falhar |
| 5 | `main` (produção) | Deploy manual via `workflow_dispatch` com confirmação `ok` → deploy `--prod` na Vercel do serviço alterado |

> **Cada serviço é deployado independentemente** — deploya-se somente o frontend sem tocar o API Gateway ou o serviço de IA.
