# Padrões de Projeto

> Convenções que todos os contribuidores devem seguir para manter consistência no codebase.

## Commits

O projeto usa **Conventional Commits** em Português do Brasil. Formato:

```
<tipo>: <descrição curta no imperativo>
```

| Tipo | Quando usar | Exemplo |
|---|---|---|
| `feat` | Nova funcionalidade | `feat: adicionar seletor de escopo no painel de insights` |
| `fix` | Correção de bug | `fix: corrigir validação de fingerprint duplicado` |
| `refatorar` | Refatoração sem mudança de comportamento | `refatorar: separar formFeedbackSettings em dois componentes` |
| `test` / `teste` | Adição ou correção de testes | `test: cobrir actionFeedbackSettings com cenário de erro` |
| `docs` | Documentação | `docs: adicionar guia de instalação` |
| `chore` | Manutenção | `chore: atualizar dependências do frontend` |

---

## Nomenclatura de Arquivos

| Camada | Convenção | Exemplo |
|---|---|---|
| Componentes React | `PascalCase.tsx` | `InsightsHeaderControls.tsx` |
| Páginas | `camelCase.tsx` | `feedbackInsightsReport.tsx` |
| Actions (React Router) | `action + PascalCase.ts` | `actionFeedbackSettings.ts` |
| Loaders (React Router) | `loader + PascalCase.ts` | `loaderFeedbacksInsightsReport.ts` |
| Serviços frontend | `service + PascalCase.ts` | `serviceFeedbacks.ts` |
| Rotas Express | `camelCase.routes.ts` | `iaAnalyze.routes.ts` |
| Controllers Express | `camelCase.controller.ts` | `iaAnalyze.controller.ts` |
| Serviços backend | `camelCase.service.ts` | `iaAnalyze.service.ts` |
| Contratos compartilhados | `camelCase.contract.ts` | `remote.contract.ts` |
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
Route → Controller → Service → Repository → Supabase
```

- **Controller**: valida autorização, extrai body, retorna HTTP response — sem lógica de negócio
- **Service**: orquestra a lógica, chama repositories e providers externos
- **Repository**: queries Supabase puras, sem `if`s de negócio
- **Libs** (`libs/iaAnalyze/`): helpers puros e reutilizáveis do domínio

---

## Contratos Compartilhados

:::note Regra de Ouro
Nunca duplique tipos entre serviços. Todo tipo que transita entre `api-gateway` e `ia-analyze` deve viver em `shared/interfaces/contracts/ia-analyze/`.
:::

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

O controller captura e retorna:
```json
{ "error": "collecting_data_required_for_analysis", "message": "..." }
```

### Frontend (Actions)

```typescript
return { ok: false, error: 'update_failed', message: 'Mensagem para o usuário' }
```

---

## Variáveis de Ambiente

| Variável | Serviço | Obrigatória |
|---|---|---|
| `VITE_SUPABASE_URL` | Frontend | Sim |
| `VITE_SUPABASE_ANON_KEY` | Frontend | Sim |
| `VITE_API_BASE_URL` | Frontend | Sim |
| `VITE_SUPABASE_URL` | API Gateway | Sim |
| `VITE_SUPABASE_ANON_KEY` | API Gateway | Sim |
| `IA_ANALYZE_REMOTE_TOKEN` | API Gateway | Não |
| `IA_ANALYZE_INTERNAL_TOKEN` | IA Analyze | Não |
| `IA_ANALYZE_REMOTE_URL` | API Gateway | Sim |
| `IA_CONFIG_ENCRYPTION_KEY` | API Gateway | Sim |
| `REQUIRE_USER_IA_KEY` | API Gateway | Sim (`true`) |
| `IA_LLM_CONCURRENCY` | IA Analyze | Não |
| `PORT` | Gateway (3000) / IA (4100) | Não |
