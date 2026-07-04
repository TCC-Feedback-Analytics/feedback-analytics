# Testes — Visão Geral

## Cobertura por Domínio

| Domínio | Pasta | Arquivos de teste | Status |
|---|---|---|---|
| **Frontend** | `feedback-analytics-web` | 23 | Coberto (unitários + componentes + actions) |
| **IA Analyze** | `feedback-analytics-ia-analyze` | 6 | Coberto (unitários + integração de rotas) |
| **Backend (API Gateway)** | `feedback-analytics-api-gateway` | 8 | Coberto (unitários puros + integração com banco mockado) |
| **Testes E2E (Playwright)** | `feedback-analytics-web/e2e` | 11 | Coberto (fluxos completos do sistema) |


---

## Pirâmide de Testes Global

O projeto adota uma estratégia de testes distribuída em múltiplas camadas que cobrem o frontend, a API Gateway, o serviço Serverless de IA e a integração geral do ecossistema.

```
           ╔═════════════════════╗
           ║     E2E (27)        ║  ← Playwright: Jornada real integrada (front + back + Supabase real)
           ╚═════════════════════╝
        ╔═══════════════════════════╗
        ║     Integração (71)       ║  ← Express (43 api-gateway + 10 ia-analyze) e Actions/Loaders (18 frontend)
        ╚═══════════════════════════╝
     ╔═════════════════════════════════╗
     ║        Unidade (180)            ║  ← Regras puras (110 frontend + 36 ia-analyze + 34 api-gateway) e componentes isolados
     ╚═════════════════════════════════╝
```

* **Testes de Unidade (180 testes):** Validam a menor unidade lógica de forma isolada e rápida. Incluem 110 testes unitários e de componentes no [Frontend](./web.md), 36 testes utilitários no [Serviço de IA](./ia-analyze.md) (termos 14 + sentimentos 9 + taxonomia de categorias 7 + extração de aspectos 6) e 34 testes de regras puras no [API Gateway](./api-gateway.md) (estatísticas 22 + avaliação do classificador 12). O API Gateway agora também contém suítes **unitárias puras** (`statistics`, `classifierEval`), além das de integração.
* **Testes de Integração (71 testes):** Validam o contrato e o fluxo de dados cruzando fronteiras de múltiplos módulos. Incluem 18 testes de Actions e Loaders do React Router no [Frontend](./web.md), 43 testes de controllers e rotas no [API Gateway](./api-gateway.md) (auth 15 + feedbacks 7 + health 1 + ia-analyze 6 + qrcode 8 + ia-analyze-scope 6) e 10 testes de rotas no [Serviço de IA](./ia-analyze.md) (analyze 8 + health 2).
* **Testes E2E (27 testes):** Validam cenários de negócio ponta a ponta em navegador Chrome real (via Playwright) cobrindo as jornadas de 11 Casos de Uso integrados (UC-01, UC-02 e UC-04 a UC-12; o UC-03 não possui spec E2E).

---

## Como Rodar

Cada serviço roda seus próprios testes **a partir do seu repositório**. Os nomes exatos dos scripts estão no `package.json` de cada repo; em geral:

```bash
# Unidade/integração (Vitest) — dentro de cada repositório
npm test

# E2E do Playwright — no feedback-analytics-web
npm run test:e2e        # navegador headless
npm run test:e2e:ui     # interface visual (UI mode)
```

---

## Documentação por Domínio

- [Plano de Teste Estratégico](./plano-estrategico.md)
- [Frontend — `feedback-analytics-web`](./web.md)
- [IA Analyze — `feedback-analytics-ia-analyze`](./ia-analyze.md)
- [Backend — `feedback-analytics-api-gateway`](./api-gateway.md)
