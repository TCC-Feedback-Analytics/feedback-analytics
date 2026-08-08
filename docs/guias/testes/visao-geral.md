# Testes — Visão Geral

## Cobertura por Domínio

| Domínio | Pasta | Arquivos de teste | Status |
|---|---|---|---|
| **Frontend** | `feedback-analytics-web` | 23 | Coberto (unitários + componentes + actions) |
| **IA Analyze** | `feedback-analytics-ia-analyze` | 6 | Coberto (unitários + integração de rotas) |
| **Backend (API Gateway)** | `feedback-analytics-api-gateway` | 8 | Coberto (unitários puros + rotas com banco mockado) |
| **E2E / integração com ambiente** | — | manual | Removido do CI — reproduzido à mão nos runbooks [Web](./manuais-web.md) e [API Gateway](./manuais-api-gateway.md) |


---

## Pirâmide de Testes Global

O projeto adota uma estratégia de testes distribuída em múltiplas camadas que cobrem o frontend, a API Gateway, o serviço Serverless de IA e a integração geral do ecossistema.

```
        ╔═════════════════════════════╗
        ║   E2E — manual (runbooks)   ║  ← Jornada real integrada (front + back + banco reais), reproduzida à mão; suíte Playwright removida do CI
        ╚═════════════════════════════╝
        ╔═══════════════════════════╗
        ║     Integração (71)       ║  ← Express mockado (43 api-gateway + 10 ia-analyze) e Actions/Loaders (18 frontend) — sem banco/rede reais
        ╚═══════════════════════════╝
     ╔═════════════════════════════════╗
     ║        Unidade (180)            ║  ← Regras puras (110 frontend + 36 ia-analyze + 34 api-gateway) e componentes isolados
     ╚═════════════════════════════════╝
```

* **Testes de Unidade (180 testes):** Validam a menor unidade lógica de forma isolada e rápida. Incluem 110 testes unitários e de componentes no [Frontend](./web.md), 36 testes utilitários no [Serviço de IA](./ia-analyze.md) (termos 14 + sentimentos 9 + taxonomia de categorias 7 + extração de aspectos 6) e 34 testes de regras puras no [API Gateway](./api-gateway.md) (estatísticas 22 + avaliação do classificador 12). O API Gateway agora também contém suítes **unitárias puras** (`statistics`, `classifierEval`), além das de integração.
* **Testes de Integração (71 testes):** Validam o contrato e o fluxo de dados cruzando fronteiras de múltiplos módulos, com o banco e a rede **mockados** (por isso seguem no CI). Incluem 18 testes de Actions e Loaders do React Router no [Frontend](./web.md), 43 testes de controllers e rotas no [API Gateway](./api-gateway.md) (auth 15 + feedbacks 7 + health 1 + ia-analyze 6 + qrcode 8 + ia-analyze-scope 6) e 10 testes de rotas no [Serviço de IA](./ia-analyze.md) (analyze 8 + health 2).
* **Testes E2E (manuais):** As jornadas ponta a ponta dos 11 Casos de Uso integrados (UC-01, UC-02 e UC-04 a UC-12; o UC-03 não possui roteiro E2E) eram automatizadas em navegador Chrome real via Playwright. A suíte Playwright foi **removida do CI** e essa cobertura passou a ser **manual**, reproduzível pelo runbook [Testes manuais — Web](./manuais-web.md). No API Gateway, os antigos testes de **integração** (banco real) e o **e2e de cutover** também saíram do CI e viraram o runbook [Testes manuais — API Gateway](./manuais-api-gateway.md).

> **O que roda no CI hoje:** apenas as camadas de **Unidade** e **Integração mockada** (Vitest) dos três serviços, mais o **smoke de migrations** do API Gateway (`schema-migrations.yml`: sobe um Postgres efêmero no runner, sem credenciais, e roda `drizzle-kit check`). A execução ponta a ponta e os cenários dependentes de banco/ambiente foram convertidos nos runbooks manuais [Web](./manuais-web.md) e [API Gateway](./manuais-api-gateway.md).

---

## Como Rodar

Cada serviço roda seus próprios testes **a partir do seu repositório**. Os nomes exatos dos scripts estão no `package.json` de cada repo; em geral:

```bash
# Unidade + integração mockada (Vitest) — dentro de cada repositório
npm test
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
