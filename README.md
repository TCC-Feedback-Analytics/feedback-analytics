# Feedback Analytics — Documentação

Repositório **central de documentação** do Feedback Analytics (Projeto Integrador). Aqui vive a **descoberta e a decisão** do produto — concepção, requisitos, arquitetura, decisões e o schema do banco. O **código** de cada serviço mora em repositórios próprios (veja abaixo).

📖 **Site da documentação:** <https://tcc-feedback-analytics.github.io/feedback-analytics/>

O projeto adota metodologias ágeis, engenharia de software rigorosa e uma arquitetura moderna orientada a serviços independentes.

### Diferenciais Técnicos
* **Arquitetura distribuída (multi-repo serverless):** cada serviço (frontend, API Gateway, IA) é um repositório e um deploy independente, com tipos compartilhados por um pacote versionado. Evoluiu de um monorepo — veja [a decisão](https://tcc-feedback-analytics.github.io/feedback-analytics/arquitetura/historico-de-decisoes/decisao-monorepo-vs-monolito/).
* **Inteligência Semântica:** integração com Large Language Models (LLMs) para análise de sentimentos e injeção automatizada de metadados.
* **Qualidade de Software:** portões de qualidade estruturados via CI/CD, validação estrita de tipos, linters e testes automatizados (unitários, integração e e2e).

---

### Repositórios do projeto

| Repositório | Visibilidade | Papel |
|---|---|---|
| **[feedback-analytics](https://github.com/TCC-Feedback-Analytics/feedback-analytics)** (este) | Público | Documentação central (site MkDocs) + `database/` + roadmap |
| **[feedback-analytics-web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web)** | Privado | Frontend React — área pública (QR Code) e painel da empresa |
| **[feedback-analytics-api-gateway](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway)** | Público | API Gateway / BFF — ponto único de entrada do backend |
| **[feedback-analytics-ia-analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze)** | Público | Serviço isolado de análise por IA (provedor LLM externo) |
| **[feedback-analytics-contracts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts)** | Público | Pacote `@feedback/lib-shared` — tipos e contratos compartilhados |

A **referência técnica** de cada serviço (arquitetura interna, endpoints, testes) vive no `docs/` do respectivo repositório de código. Este repositório concentra concepção, decisões arquiteturais, requisitos e o schema do banco.

---

### Stack Tecnológica Geral

* **Frontend:** React 19 (TypeScript) + Vite + Tailwind CSS 4.x
* **Backend:** Node.js (TypeScript) + Express
* **Banco de Dados:** PostgreSQL (Supabase)
* **IA/Analytics:** provedor LLM externo — atualmente Google Gemini API
* **CI/CD & Infra:** GitHub Actions, Vercel Serverless Functions, Supabase

---

### Rodar a documentação localmente

O site é gerado com [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

```bash
pip install -r requirements-docs.txt
mkdocs serve          # http://127.0.0.1:8000
mkdocs build --strict # valida links quebrados (mesmo gate do CI)
```

O deploy para o GitHub Pages é automático no push a `main` (workflow `deploy-docs.yml`).
