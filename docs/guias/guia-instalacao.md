# Guia de Instalação

> Suba o ambiente local completo do Feedback Analytics. Como o projeto é **multi-repo**, você clona e configura cada serviço separadamente. Cada repositório traz um `.env.example` e um `README` com as instruções **autoritativas** do próprio serviço — este guia dá a visão de conjunto.

## Antes de Começar

Certifique-se de ter instalado:

| Ferramenta | Versão Mínima | Como verificar |
|---|---|---|
| **Node.js** | 20.x | `node -v` |
| **npm** | 10.x | `npm -v` |
| **Git** | — | `git --version` |
| **Conta Supabase** | — | [supabase.com](https://supabase.com) |
| **Chave API Gemini** | — | [Google AI Studio](https://aistudio.google.com) |

---

## Passo 1 — Clone os Repositórios

O código está dividido em três serviços deployáveis (o pacote de contratos é consumido como dependência, não precisa ser clonado para rodar):

```bash
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-web.git
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway.git
git clone https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze.git
```

> Os serviços consomem o pacote público [`@feedback/lib-shared`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts) via dependência git — o `npm install` de cada repo já o baixa.

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

Cada serviço tem seu próprio `.env.example` — **copie-o para `.env` e preencha**. A lista completa e atual de cada serviço está no seu repositório; as variáveis principais são:

### `feedback-analytics-web/.env`

```env
VITE_API_BASE_URL=http://localhost:3000   # em produção/preview na Vercel pode ficar vazio (derivação por hostname)
```

> O frontend fala **apenas com o API Gateway** — não acessa o Supabase diretamente.

### `feedback-analytics-api-gateway/.env`

```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua_anon_key_aqui
DATABASE_URL=postgresql://...@...pooler.supabase.com:6543/postgres   # Transaction Pooler (ver nota)
IA_ANALYZE_EXECUTION_MODE=local
IA_ANALYZE_REMOTE_TOKEN=um_token_secreto_compartilhado
IA_ANALYZE_REMOTE_URL=http://localhost:4100
PORT=3000
```

### `feedback-analytics-ia-analyze/.env`

```env
GEMINI_API_KEY=sua_chave_gemini_aqui
IA_ANALYZE_INTERNAL_TOKEN=um_token_secreto_compartilhado
PORT=4100
```

!!! warning "Token compartilhado (nomes diferentes nos dois lados)"
    No API Gateway o token interno se chama `IA_ANALYZE_REMOTE_TOKEN`; no IA Analyze, `IA_ANALYZE_INTERNAL_TOKEN`. Ambos devem ter o **mesmo valor** — o Gateway o envia no header `x-ia-analyze-token` e o serviço valida. Use uma string longa e aleatória (mínimo 32 caracteres).

!!! note "`DATABASE_URL` — use o Transaction Pooler"
    Em ambientes serverless (e para evitar problemas de resolução IPv6), o Gateway usa a conexão **Transaction Pooler** do Supabase (`...pooler.supabase.com:6543`, com `prepare: false`), não a conexão direta (`db.[ref].supabase.co`).

---

## Passo 4 — Configure o Banco de Dados

O schema do banco está versionado **neste repositório** (`feedback-analytics`), em `database/sql/`, como arquivos DDL organizados por tipo de objeto (`tables/`, `policies/`, `triggers/`, `functions/`). Aplique esses scripts no seu projeto Supabase (via SQL Editor ou Supabase CLI). Consulte `database/sql/README.md` para a estrutura e `database/sql/DESCRICOES.md` para a descrição de cada objeto.

As principais tabelas são:

| Tabela | Para quê |
|---|---|
| `public.enterprise` | Dados da empresa |
| `public.collecting_data_enterprise` | Configurações de coleta e catálogo |
| `public.catalog_items` | Produtos, serviços e departamentos |
| `public.feedback` | Feedbacks coletados |
| `public.feedback_analysis` | Análises geradas pela IA |
| `public.feedback_insights_report` | Relatórios de insights consolidados |
| `public.tracked_devices` | Controle anti-spam por dispositivo |

---

## Passo 5 — Inicie os Serviços

Cada serviço roda a partir do seu próprio repositório (abra um terminal por serviço):

```bash
# feedback-analytics-web
npm run dev        # Frontend em http://localhost:5173

# feedback-analytics-api-gateway
npm run dev        # API Gateway em http://localhost:3000

# feedback-analytics-ia-analyze
npm run dev        # IA Analyze em http://localhost:4100
```

> Consulte o `package.json`/`README` de cada repo para o nome exato do script de desenvolvimento.

---

## Passo 6 — Verifique a Instalação

```bash
curl http://localhost:3000/api/health
# → { "ok": true }

curl http://localhost:4100/internal/health
# → { "ok": true, "service": "ia-analyze" }
```

Se ambos retornarem `ok: true`, o ambiente está funcionando.

---

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `Missing Gemini API key` | `GEMINI_API_KEY` vazio | Verifique o `.env` do `ia-analyze` |
| `401 unauthorized_internal_request` | Tokens internos diferentes | Iguale `IA_ANALYZE_REMOTE_TOKEN` (gateway) e `IA_ANALYZE_INTERNAL_TOKEN` (ia-analyze) |
| `422 collecting_data_required` | Empresa sem dados de contexto | Preencha **Objetivo** e **Resumo** em Configurações |
| `422 insufficient_feedbacks` | Menos de 5 feedbacks disponíveis | Colete mais feedbacks antes de analisar |
| `ECONNREFUSED :4100` | IA Analyze não está rodando | Suba o serviço `feedback-analytics-ia-analyze` |
| `ENOTFOUND db.[ref].supabase.co` | `DATABASE_URL` usando conexão direta | Troque pela conexão **Transaction Pooler** (`...pooler.supabase.com:6543`) |

---

## Executar os Testes

Cada repositório roda seus próprios testes (veja [Testes](testes/visao-geral.md) para a estratégia geral):

```bash
# dentro de cada repo
npm test        # testes de unidade/integração (Vitest)
npm run lint    # lint do serviço
```
