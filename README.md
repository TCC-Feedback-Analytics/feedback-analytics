# Feedback Analytics — Documentação

Repositório **central de documentação** do Feedback Analytics (Projeto Integrador). Aqui vive a **descoberta e a decisão** do produto — concepção, requisitos, arquitetura, decisões e a referência do banco. O **código** de cada serviço mora em repositórios próprios (veja abaixo).

📖 **Site da documentação:** <https://tcc-feedback-analytics.github.io/feedback-analytics/>

O projeto adota metodologias ágeis, engenharia de software rigorosa e uma arquitetura moderna orientada a serviços independentes.

**O que o produto faz hoje:** coleta de feedback por QR Code, link ou etiqueta NFC, com campo de comentário configurável por escopo (empresa ou item do catálogo); métricas por escopo, período e canal de coleta; análise dos comentários e diagnóstico do escopo por IA; geração automática das perguntas do formulário; login por e-mail e senha ou Google; e exclusão da conta com todos os dados da empresa.

### Diferenciais Técnicos
* **Arquitetura distribuída (multi-repo serverless):** cada serviço (frontend, API Gateway, IA) é um repositório e um deploy independente, com tipos compartilhados por um pacote versionado. Evoluiu de um monorepo — veja [a decisão](https://tcc-feedback-analytics.github.io/feedback-analytics/arquitetura/historico-de-decisoes/decisao-monorepo-vs-monolito/).
* **Inteligência Semântica:** análise dos comentários por Large Language Models (LLMs) — sentimento graduado, categorias, palavras-chave e aspectos (ABSA), sintetizados em insights e recomendações —, além do diagnóstico do escopo e da geração automática das perguntas do formulário. Todo trabalho de IA roda **assíncrono, por fila** (worker no API Gateway), e cada empresa usa a **própria conta OpenRouter** (chave cifrada no banco).
* **Qualidade de Software:** CI no GitHub Actions com lint, checagem de tipos e testes automatizados de unidade e de integração com banco e rede mockados (Vitest) nos três serviços. Não há testes e2e automatizados: a suíte Playwright saiu da Web em agosto de 2026, e os casos de uso são conferidos por um [runbook manual](https://tcc-feedback-analytics.github.io/feedback-analytics/guias/testes/manuais-web/).

---

### Repositórios do projeto

| Repositório | Visibilidade | Papel |
|---|---|---|
| **[feedback-analytics](https://github.com/TCC-Feedback-Analytics/feedback-analytics)** (este) | Público | Documentação central (site MkDocs) + `database/` (dump SQL legado, só para consulta) |
| **[feedback-analytics-web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web)** | Público | Frontend React — área pública (formulário de coleta por QR Code, link ou NFC) e painel da empresa |
| **[feedback-analytics-api-gateway](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway)** | Público | API Gateway / BFF — ponto único de entrada do backend: autenticação, regras de negócio, métricas e fila da IA |
| **[feedback-analytics-ia-analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze)** | Público | Serviço isolado de IA (análise, síntese, diagnóstico do escopo e geração das perguntas), chamado só pelo Gateway |
| **[feedback-analytics-contracts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-contracts)** | Público | Pacote `@feedback/lib-shared` — tipos e contratos compartilhados |

A **referência técnica** de cada serviço (arquitetura interna, endpoints, testes) vive no `docs/` do respectivo repositório de código. Este repositório concentra concepção, decisões arquiteturais, requisitos e a referência do banco. A fonte única do schema são as migrations Drizzle do [API Gateway](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle); o `database/sql/` é um dump antigo, mantido só como histórico.

O roadmap e o acompanhamento dos próximos passos do TCC2 ficam fora deste repositório, que
mantém só a documentação do sistema.

---

### Stack Tecnológica Geral

* **Frontend:** React 19 (TypeScript) + Vite + Tailwind CSS 4.x
* **Backend:** Node.js (TypeScript) + Express 5 + Drizzle ORM
* **Autenticação:** Better Auth — e-mail e senha ou Google, com sessão em cookie httpOnly
* **Banco de Dados:** PostgreSQL hospedado no Supabase (só hospedagem: sem Supabase Auth nem Data API)
* **IA/Analytics:** provedor LLM externo — OpenRouter, com chave e modelo configurados por empresa (BYO-key)
* **E-mail:** SMTP Brevo (confirmação de cadastro e recuperação de senha)
* **CI/CD & Infra:** GitHub Actions (CI a cada push e pull request em `main` e `developer`; deploy manual na Vercel) e Vercel Serverless Functions

---

### Rodar a documentação localmente

O site é gerado com [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

```bash
pip install -r requirements-docs.txt
mkdocs serve          # http://127.0.0.1:8000
mkdocs build --strict # valida links quebrados (mesmo gate do CI)
```

O deploy para o GitHub Pages é automático no push a `main` (workflow `deploy-docs.yml`).
