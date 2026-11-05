# Padrões de Projeto

> Convenções que todos os contribuidores devem seguir para manter consistência no codebase.

## Commits

O projeto usa **Conventional Commits** em Português do Brasil. Formato (o escopo entre parênteses é opcional e diz a área tocada):

```
<tipo>(<escopo>): <descrição curta no imperativo>
```

| Tipo | Quando usar | Exemplo |
|---|---|---|
| `feat` | Nova funcionalidade | `feat: adicionar seletor de escopo no painel de insights` |
| `fix` | Correção de bug | `fix: corrigir validação de fingerprint duplicado` |
| `refactor` / `refatorar` | Refatoração sem mudança de comportamento | `refactor(ia): separar a montagem dos lotes do worker` |
| `test` / `teste` | Adição ou correção de testes | `test: cobrir actionFeedbackSettings com cenário de erro` |
| `docs` | Documentação | `docs: adicionar guia de instalação` |
| `chore` | Manutenção | `chore: atualizar dependências do frontend` |
| `ci` | Workflows do GitHub Actions | `ci: rodar o smoke das migrations no pull request` |

---

## Nomenclatura de Arquivos

| Camada | Convenção | Exemplo |
|---|---|---|
| Componentes React | `PascalCase.tsx` | `InsightsControlsBar.tsx` |
| Páginas | `camelCase.tsx` | `editFeedbackSettings.tsx` |
| Actions (React Router) | `action + PascalCase.ts` | `actionFeedbackSettings.ts` |
| Loaders (React Router) | `loader + PascalCase.ts` | `loaderFeedbackGeneral.ts` |
| Serviços frontend | `service + PascalCase.ts` | `serviceFeedbacks.ts` |
| Rotas Express | `camelCase.routes.ts` | `iaAnalyze.routes.ts` |
| Controllers Express | `camelCase.controller.ts` | `iaAnalyze.controller.ts` |
| Serviços backend | `camelCase.service.ts` | `iaAnalyze.service.ts` |
| Repositórios backend | `camelCase.repository.ts` | `iaJob.repository.ts` |
| Contratos compartilhados | `kebab-case.contract.ts` | `scope-diagnosis.contract.ts` |
| Tipos de UI | `ui.types.ts` | Um por diretório de página |
| Documentação | `kebab-case.md` | `arquitetura-estrutura.md` |

---

## Padrão de Rotas (React Router v7)

```tsx
<Route
  path="edit/types-feedback"
  element={<EditTypeFeedbacks />}
  action={ActionTypesFeedback}   // mutations via POST
  loader={LoaderXxx}             // data fetching via GET
/>
```

**Regras:**
- **Actions** sempre retornam `{ ok: boolean, error?: string, message?: string }`
- **Loaders** sempre retornam dados tipados da página
- Use `useRouteLoaderData('user')` para acessar dados do loader pai

---

## Padrão de Serviços Backend

```
Route → Controller → Service → Repository → Postgres (Drizzle)
```

- **Controller**: valida autorização, extrai body, retorna HTTP response — sem lógica de negócio
- **Service**: orquestra a lógica, chama repositories e providers externos
- **Repository**: queries Drizzle puras, sem `if`s de negócio, sempre filtradas por `enterprise_id` (helpers de `src/db/tenantScope.ts`)
- **Libs** (`libs/`): lógica de domínio reutilizável — a maior parte pura (estatística, período, montagem dos lotes da IA)

Fluxos sem regra de negócio própria podem ir direto do Controller ao Repository (ex.: pontos de coleta e formulário público).

---

## Contratos Compartilhados

!!! note "Regra de Ouro"
    Nunca duplique tipos entre serviços. Todo tipo que transita entre `api-gateway` e `ia-analyze` deve viver no pacote [`@feedback/lib-shared`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts), em `interfaces/contracts/ia-analyze/`. Cada serviço fixa a versão do pacote por tag do Git (hoje, `v1.8.0` no Gateway e na Web e `v1.7.0` no IA-Analyze).

---

## Intents (Actions Multi-Form)

Quando uma página tem múltiplas ações via `<Form>`, use o padrão de **intent**:

**1. Declare a constante:**
```typescript
// src/lib/constants/routes/intents.ts
export const INTENT_FEEDBACK_SETTINGS_SAVE_PRODUCTS_CATALOG = 'save_products_catalog'
```

**2. Inclua no formulário:**
```html
<input type="hidden" name="intent" value="save_products_catalog" />
```

**3. Despache na action:**
```typescript
const intent = formData.get('intent');
switch (intent) {
  case INTENT_FEEDBACK_SETTINGS_SAVE_PRODUCTS_CATALOG:
    // ...
}
```

---

## Padrão de Erros

### Backend

```typescript
throw new IaAnalyzeServiceError(
  'collecting_data_required_for_analysis',  // message
  422,                                       // HTTP status
  'collecting_data_required_for_analysis',  // code legível pela UI
);
```

O controller captura e responde com o status do erro e o código, via `sendTypedError` (`src/utils/sendTypedError.ts`):
```json
{ "error": "collecting_data_required_for_analysis" }
```

### Frontend (Actions)

```typescript
return { ok: false, error: 'update_failed', message: 'Mensagem para o usuário' }
```

---

## Variáveis de Ambiente

| Variável | Serviço | Obrigatória |
|---|---|---|
| `VITE_API_BASE_URL` | Frontend | Vazia no local (o proxy do Vite repassa `/api`) e em produção; `http://localhost:3000` só para chamar o gateway direto |
| `VITE_PUBLIC_API_BASE_URL` | Frontend | Em produção (URL pública do Gateway); vazia no local |
| `VITE_GOOGLE_AUTH_ENABLED` | Frontend | Não (`true` mostra o "Continuar com Google") |
| `DATABASE_URL` | API Gateway | Sim |
| `BETTER_AUTH_SECRET` / `BETTER_AUTH_URL` | API Gateway | Sim |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | API Gateway | Só com a entrada pelo Google ligada |
| `PUBLIC_SITE_URL` / `CORS_ALLOWED_ORIGINS` | API Gateway | Sim |
| `CORS_ALLOW_VERCEL_PROJECT_PAIR` | API Gateway | Sim (`false` em produção sem previews pareados) |
| `CORS_VERCEL_WEB_PROJECT_SLUG` / `CORS_VERCEL_API_PROJECT_SLUG` | API Gateway | Somente com pareamento de previews habilitado |
| `WORKER_TICK_TOKEN` | API Gateway e GitHub Actions | Sim em produção; mesmo valor nos dois lados |
| `IA_ANALYZE_REMOTE_TOKEN` | API Gateway | Sim no modo remoto |
| `IA_ANALYZE_INTERNAL_TOKEN` | IA Analyze | Sim; mesmo valor de `IA_ANALYZE_REMOTE_TOKEN` |
| `IA_ANALYZE_REMOTE_URL` | API Gateway | Sim |
| `IA_CONFIG_ENCRYPTION_KEY` | API Gateway | Sim |
| `REQUIRE_USER_IA_KEY` | API Gateway | Sim (`true`) |
| `SMTP_HOST` / `SMTP_PORT` / `MAIL_FROM` | API Gateway | Sim |
| `IA_LLM_CONCURRENCY` | IA Analyze | Não |
| `PORT` | Gateway (3000) / IA (4100) | Não |

O endereço do Gateway no frontend vem só dessas duas variáveis; não mantenha slugs ou URLs da Vercel fixos no código. Em produção, a `VITE_API_BASE_URL` fica vazia: a Web chama `/api/*` no próprio domínio e o `vercel.json` repassa ao Gateway, para o cookie de sessão ser do site. As rotas públicas que contam por IP (formulário do cliente e reenvio da confirmação) vão direto ao Gateway pela `VITE_PUBLIC_API_BASE_URL`. Faça novo deploy do web depois de alterar qualquer uma delas.
