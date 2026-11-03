# Testes — Visão Geral

!!! info "Conferido em 03/11/2026"
    Inventário refeito contra os três repositórios de código. As contagens agora são de **arquivos** de teste: o número de testes muda a cada PR e sai no fim do Vitest de cada repositório.

## Cobertura por Domínio

| Domínio | Pasta | Arquivos de teste | Status |
|---|---|---|---|
| **Frontend** | `feedback-analytics-web` | 112 | Coberto (utilitários, hooks, componentes, páginas, layouts, actions e loaders) |
| **IA Analyze** | `feedback-analytics-ia-analyze` | 13 | Coberto (unitários, provedores com rede mockada e rotas) |
| **Backend (API Gateway)** | `feedback-analytics-api-gateway` | 48 | Coberto (regras puras, SQL gerado, serviços, fila/worker e rotas com banco mockado); 1 suíte opt-in contra Postgres real |
| **E2E / integração com ambiente** | — | manual | Removido do CI — reproduzido à mão nos runbooks [Web](./manuais-web.md) e [API Gateway](./manuais-api-gateway.md) |


---

## Pirâmide de Testes Global

O projeto adota uma estratégia de testes distribuída em múltiplas camadas que cobrem o frontend, a API Gateway, o serviço Serverless de IA e a integração geral do ecossistema.

```
        ╔═════════════════════════════╗
        ║   E2E — manual (runbooks)   ║  ← Jornada real integrada (front + back + banco reais), reproduzida à mão; suíte Playwright removida em 08/08/2026
        ╚═════════════════════════════╝
        ╔═══════════════════════════╗
        ║  Integração (mockada)     ║  ← Rotas Express via Supertest (14 arquivos no api-gateway, 3 no ia-analyze) e Actions/Loaders (5 no frontend) — sem banco/rede reais
        ╚═══════════════════════════╝
     ╔═════════════════════════════════╗
     ║          Unidade                ║  ← Regras puras, SQL gerado, serviços, componentes e páginas isolados — a maior parte dos 173 arquivos
     ╚═════════════════════════════════╝
```

* **Testes de Unidade:** Validam a menor unidade lógica de forma isolada e rápida. No [Frontend](./web.md), utilitários, hooks, services, componentes, páginas e layouts (107 arquivos); no [Serviço de IA](./ia-analyze.md), saneamento de termos, taxonomia, sentimento, aspectos, prompts, validações e os adaptadores OpenRouter e Gemini com a rede mockada; no [API Gateway](./api-gateway.md), funções estatísticas, avaliação do classificador, isolamento multi-tenant, o SQL montado pelo Drizzle (sem conectar), serviços da análise e do diagnóstico e o worker da fila.
* **Testes de Integração (mockada):** Validam o contrato e o fluxo de dados cruzando fronteiras de múltiplos módulos, com o banco e a rede **mockados** (por isso seguem no CI). Incluem as Actions e Loaders do React Router no [Frontend](./web.md), as rotas Express exercitadas via Supertest no [API Gateway](./api-gateway.md) (feedbacks, coleta pública, configuração de IA, análise assíncrona, diagnóstico do escopo, onboarding, saúde etc.) e as rotas internas do [Serviço de IA](./ia-analyze.md) (`analyze`, `synthesize-insights`, `diagnose-scope` e saúde).
* **Integração com Postgres real:** No CI, só o **smoke de migrations** do API Gateway (`schema-migrations.yml`), que sobe um Postgres efêmero no runner. Fora dele, o Gateway tem uma suíte opt-in, `onboarding.database.test.ts`, que só roda com `ONBOARDING_TEST_DATABASE_URL` definida.
* **Testes E2E (manuais):** As jornadas ponta a ponta dos 11 Casos de Uso integrados (UC-01, UC-02 e UC-04 a UC-12; o UC-03 não possui roteiro E2E) eram automatizadas em navegador Chrome real via Playwright. A suíte Playwright foi **removida** da Web e do CI e essa cobertura passou a ser **manual**, reproduzível pelo runbook [Testes manuais — Web](./manuais-web.md). No API Gateway, os antigos testes de **integração** (banco real) e o **e2e de cutover** também saíram do CI e viraram o runbook [Testes manuais — API Gateway](./manuais-api-gateway.md).

> **O que roda no CI hoje:** apenas as camadas de **Unidade** e **Integração mockada** (Vitest) dos três serviços, mais o **smoke de migrations** do API Gateway (`schema-migrations.yml`: sobe um Postgres efêmero no runner, sem credenciais, aplica as migrations e roda `drizzle-kit check`). A execução ponta a ponta e os cenários dependentes de banco/ambiente foram convertidos nos runbooks manuais [Web](./manuais-web.md) e [API Gateway](./manuais-api-gateway.md).

---

## Como Rodar

Cada serviço roda seus próprios testes **a partir do seu repositório**:

```bash
# Unidade + integração mockada (Vitest), execução única
npm test               # feedback-analytics-api-gateway e feedback-analytics-ia-analyze
npm run test -- run    # feedback-analytics-web (o `npm test` da Web fica em modo watch)
```

A execução **ponta a ponta (E2E)** e os cenários de **integração dependentes de banco/ambiente** não são mais automatizados. Reproduza-os manualmente pelos runbooks: [Testes manuais — Web](./manuais-web.md) e [Testes manuais — API Gateway](./manuais-api-gateway.md).

---

## Documentação por Domínio

- [Plano de Teste Estratégico](./plano-estrategico.md)
- [Frontend — `feedback-analytics-web`](./web.md)
- [IA Analyze — `feedback-analytics-ia-analyze`](./ia-analyze.md)
- [Backend — `feedback-analytics-api-gateway`](./api-gateway.md)
- [Testes manuais — Web (UCs)](./manuais-web.md)
- [Testes manuais — API Gateway](./manuais-api-gateway.md)
