# Painel de Insights com Relatório Global de IA

## O Que É

É onde o ciclo do produto se fecha. O painel de insights (`/user/insights/reports`) permite que o gestor dispare a análise de inteligência artificial sobre os feedbacks coletados e visualize um relatório estruturado com:

- **Resumo situacional** — o que os clientes estão dizendo, de forma consolidada
- **Recomendações acionáveis** — o que fazer com base nos padrões identificados
- **Distribuição de sentimentos** — proporção de feedbacks positivos, neutros e negativos, com **Saldo de sentimento** (Net Sentiment Score)
- **Top categorias e keywords** — os temas e termos mais relevantes extraídos dos textos
- **Assuntos que mais impactam** — aspectos (ABSA) ordenados pelo peso na percepção do cliente

Em torno do relatório, o painel ainda oferece a aba de **Estatísticas** (métricas estatísticas consagradas) e a aba de **Perguntas** (avaliação determinística pergunta a pergunta), detalhadas abaixo.

---

## Por Que Existe

Coletar feedback é apenas metade do trabalho. A outra metade é **entender o que os dados estão dizendo**.

Uma empresa com 200 feedbacks mensais não pode ler cada um individualmente para extrair padrões. Sem análise automatizada, o dado coletado envelhece numa tabela sem nunca gerar valor.

O painel de insights resolve isso: em segundos, converte centenas de textos brutos em um relatório legível, contextualizado ao negócio da empresa e segmentado por escopo.

> A coleta captura a voz do cliente. O painel de insights traduz essa voz em ação gerencial.

---

## Como Funciona

O painel oferece dois tipos de operação:

### 1. Analisar Feedbacks Brutos
Processa os feedbacks que **ainda não passaram pela IA**. Ideal para rodar periodicamente, à medida que novos feedbacks chegam.

```
Gestor clica em "Analisar feedbacks"
        ↓
API busca feedbacks não presentes em feedback_analysis
        ↓
Agrupa por escopo (Empresa, Produto, Serviço, Departamento)
        ↓
Envia para o motor de IA com contexto de negócio
        ↓
IA retorna sentimento, categorias e keywords por feedback
        ↓
Resultados salvos em feedback_analysis
```

### 2. Gerar Insights Globais
Recalcula o **resumo e as recomendações** com base nos feedbacks já analisados — sem reprocessar tudo do zero. Útil quando novos feedbacks foram analisados e o gestor quer um relatório atualizado.

```
Gestor clica em "Gerar insights"
        ↓
API agrupa todos os feedback_analysis existentes por escopo
        ↓
IA gera sumário situacional + recomendações consolidadas
        ↓
Resultados salvos em feedback_insights_report
        ↓
Painel exibe o relatório atualizado
```

---

## Seletor de Escopo

O painel usa um **seletor radial animado** para escolher qual escopo visualizar:

| Escopo | Cor | Disponível quando |
|---|---|---|
| Empresa | Indigo | Sempre |
| Produto | Verde | `uses_company_products = true` **e** ≥ 1 item cadastrado |
| Serviço | Âmbar | `uses_company_services = true` **e** ≥ 1 item cadastrado |
| Departamento | Rosa | `uses_company_departments = true` **e** ≥ 1 item cadastrado |

Cada escopo tem seu próprio relatório independente.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Escala** | Processa dezenas ou centenas de feedbacks em segundos |
| **Contexto de negócio** | O relatório é personalizado com os dados da empresa (objetivo, segmento, produtos) |
| **Segmentação** | Relatórios separados por escopo permitem comparar áreas da empresa |
| **Decisão gerencial** | Recomendações que servem de ponto de partida para a ação do gestor |
| **Assincronismo** | O processamento não bloqueia a experiência do cliente durante a coleta |

---

## O Que o Relatório Contém

Além do resumo situacional e das recomendações geradas pela IA, o relatório agrega o **Net Sentiment Score** (Saldo de sentimento) e os **"Assuntos que mais impactam"** (aspectos ABSA), trazendo a leitura quantitativa do que pesa na percepção do cliente. O exemplo abaixo reflete os campos reais retornados pelo endpoint de análise (`GET /feedbacks/analysis`):

```json
{
  "summary": {
    "totalAnalyzed": 47,
    "sentiments": { "positive": 34, "neutral": 8, "negative": 5 },
    "netSentimentScore": 61.7,
    "sentimentCIs": {
      "positive": { "lower": 0.582, "upper": 0.823 },
      "neutral": { "lower": 0.088, "upper": 0.314 },
      "negative": { "lower": 0.046, "upper": 0.234 }
    },
    "confidenceTier": "moderate",
    "topCategories": [
      { "name": "qualidade do produto", "count": 30, "proportion": 0.638, "ci": { "lower": 0.494, "upper": 0.762 } },
      { "name": "tempo de espera", "count": 12, "proportion": 0.255, "ci": { "lower": 0.152, "upper": 0.394 } }
    ],
    "topKeywords": [
      { "name": "saboroso", "count": 22, "proportion": 0.468, "ci": { "lower": 0.333, "upper": 0.607 } },
      { "name": "demora", "count": 10, "proportion": 0.213, "ci": { "lower": 0.119, "upper": 0.349 } }
    ],
    "aspectSentiments": [
      {
        "aspect": "sabor",
        "positive": 28, "neutral": 3, "negative": 1, "count": 32,
        "netSentimentScore": 84.4,
        "ci": { "lower": 0.681, "upper": 0.947 }
      },
      {
        "aspect": "tempo de espera",
        "positive": 1, "neutral": 2, "negative": 9, "count": 12,
        "netSentimentScore": -66.7,
        "ci": { "lower": 0.015, "upper": 0.350 }
      }
    ]
  },
  "items": [
    {
      "id": "…",
      "message": "Comida ótima, mas esperei 40 minutos.",
      "rating": 5,
      "sentiment": "negative",
      "sentiment_score": -0.35,
      "confidence": 0.82,
      "categories": ["tempo de espera"],
      "keywords": ["demora"],
      "aspects": [
        { "aspect": "sabor", "sentiment": "positive", "sentiment_score": 0.7 },
        { "aspect": "tempo de espera", "sentiment": "negative", "sentiment_score": -0.6 }
      ],
      "discrepancy": "silent_detractor"
    }
  ]
}
```

> O resumo textual (`summary`/`recommendations`) e o clima do relatório vêm do `feedback_insights_report`. O clima passou a ser derivado do **Net Sentiment Score** (Clima Positivo / Neutro / de Atenção, com banda neutra de ±5), e não mais do voto majoritário de sentimento.

---

## Aba de Estatísticas — métricas estatísticas consagradas

A aba **Estatísticas** deixou de ser uma contagem simples: ela é alimentada pelo módulo `feedback-analytics-api-gateway/src/libs/statistics/index.ts` — um conjunto de **funções puras** com métodos de referência de mercado. A regra de ouro: **a matemática vive no backend; o frontend apenas apresenta**. As estatísticas combinam duas lentes complementares.

### Lente SATISFAÇÃO (as estrelas — não dependem da IA)

Mede a nota objetiva de 1 a 5 que o cliente deu, com honestidade estatística:

| Métrica | O que é | Como é calculada |
|---|---|---|
| **Nota média + faixa** (`starMean`, `starMeanCI`) | Média das estrelas com a faixa provável | Média de notas 1–5 com **intervalo de confiança t** (clampado em [1,5]) |
| **Saldo de satisfação** (`netSatisfaction`) | Equilíbrio entre quem amou e quem desgostou | %(top-2) − %(bottom-2), resultado em [-100, 100] |
| **Clientes satisfeitos / CSAT** (`csat`) | % de notas 4–5 (Top-2-Box) | **CSAT Top-2-Box** com **intervalo de Wilson** |

### Lente SENTIMENTO da IA (o texto — depende da análise)

Lê o que o cliente escreveu. Só aparece quando há feedbacks analisados (`totalAnalyzed > 0`):

- **Saldo de sentimento / Net Sentiment Score** (`netSentimentScore`): `(positivos − negativos) / total × 100`, resultando em [-100, 100]. É a principal métrica de clima textual.
- Distribuição positivo/neutro/negativo com **ICs de Wilson** por fração (`sentimentCIs`).

### Camadas de confiança (`confidenceTier`)

Toda métrica carrega uma **camada de confiança** derivada do tamanho da amostra (n), na base de Cochran:

| Faixa (n) | Camada | Leitura |
|---|---|---|
| < 10 | `insufficient` (Dados insuficientes) | Números apenas ilustrativos |
| 10–29 | `low` (Confiança baixa) | Tendência, sem firmeza |
| 30–99 | `moderate` (Confiança média) | Direcionamento confiável |
| 100+ | `good` (Confiança alta) | Base sólida para decisão |

### Ranqueamento honesto de temas

`topCategories` e `topKeywords` não são ordenados pela contagem crua — são ranqueados pelo **limite inferior do intervalo de Wilson** (`wilsonLowerBound`), critério justo para amostras pequenas (um termo citado 2 vezes não supera um citado 30). Cada termo traz `{ name, count, proportion, ci }`.

### Aspectos ABSA — "Assuntos que mais impactam"

A análise por aspecto (**ABSA**, *Aspect-Based Sentiment Analysis*) agrega os aspectos extraídos de cada texto (`aspectSentiments`):

- Cada aspecto recebe seu próprio saldo de sentimento (NSS) e IC de Wilson.
- **Gate de menção mínima**: um aspecto só entra na lista com **≥ 3 menções** — evita destacar ruído.
- Ordenados por **impacto = volume × |NSS|** (top 12): o que aparece muito **e** divide opiniões sobe ao topo.

### Discrepância nota × texto

Quando a estrela e o texto contam histórias opostas, o item é marcado em `discrepancy`:

- **`silent_detractor`** — nota alta (4–5) com texto negativo: o cliente "perdoou" na nota, mas a crítica está no texto.
- **`rating_misuse`** — nota baixa (1–2) com texto positivo: o cliente provavelmente errou a escala.

> **Referências de mercado:** Net Sentiment Score (Thematic), Net Satisfaction / CSAT Top-2-Box (Qualtrics/ACSI), intervalo de Wilson (Brown, Cai & DasGupta, 2001), intervalo t para média e média Bayesiana / encolhimento estilo IMDb.

---

## Aba Perguntas

A aba **Perguntas** (`/user/insights/questions`) responde a uma pergunta diferente: **"como cada pergunta do meu formulário está sendo avaliada?"**. As métricas aqui são **100% determinísticas** — calculadas sobre as respostas estruturadas (escala 1–5) e **independem da IA**.

Para cada pergunta (e suas subperguntas aninhadas), no escopo selecionado:

| Campo | Significado |
|---|---|
| `mean` | Nota média da pergunta (/5) |
| `ci` | Faixa provável (intervalo de confiança t) da média |
| `satisfiedPct` | % de respostas satisfeitas (BOA + ÓTIMA) |
| `distribution` | Mini-distribuição: PESSIMO / RUIM / MEDIANA / BOA / OTIMA |
| `confidenceTier` | Selo de confiança pelo n de respostas |

A lista vem ordenada **pior → melhor** (menor nota no topo), para o gestor atacar primeiro o que mais incomoda. O escopo vazio retorna `{ questions: [] }`.

### Estados de cada redação

Como as perguntas evoluem ao longo do tempo (e usam soft-delete para preservar histórico), cada redação carrega um `status`:

- **`current`** (Atuais) — pergunta ativa e com o texto atual da configuração.
- **`deactivated`** (Desativadas) — existe na config, mas o toggle está desligado; reativar traz o histórico de volta (id estável).
- **`past`** (Antigas) — redação antiga (texto editado depois) ou pergunta removida da config.

O frontend (`feedbacksInsightsQuestions.tsx`, via `useScopedFeedbackQuestions`) agrupa visualmente essas três famílias.

---

## Confiabilidade dos números

Para não passar uma falsa sensação de precisão, a interface comunica **quão sólida é cada métrica**:

- **Selo de confiança** (`ConfidenceBadge`): um badge clicável que mostra a camada da amostra — **Dados insuficientes** (< 10), **Confiança baixa** (10–29), **Confiança média** (30–99) e **Confiança alta** (100+). Ao clicar, abre o `ConfidenceInfoModal`, que explica em linguagem simples como a confiança funciona.
- **Faixa provável** (intervalos de confiança): médias e proporções nunca aparecem como número seco. A "faixa provável" (IC de Wilson para proporções, IC t para médias) mostra o intervalo onde o valor real provavelmente está — quanto menor a amostra, mais larga a faixa.

> **Ajuda contextual:** ícones de "?" espalhados pelas métricas (componentes `MetricHelp` e `HelpHint` sobre `HelpPopover`, alimentados por `metricExplanations.ts` e `helpTopics.ts`) explicam cada conceito sem que o gestor precise sair da tela.

---

## Detalhes Técnicos

- Mínimo de **10 feedbacks** para iniciar análise relevante (retorna 422 se insuficiente)
- `collecting_data` da empresa deve estar preenchido — objetivo e resumo são usados no prompt da IA
- Os dois botões ficam desabilitados enquanto uma operação está em andamento (sem duplo disparo)
- Cada execução processa até 50 feedbacks por padrão (máx. 100), subdivididos em lotes (batches) de até 20 feedbacks por chamada à IA (configurável via `IA_MAX_FEEDBACKS_PER_BATCH`)

---

## Referência Técnica

- [Motor de IA com Filtro Semântico → filtro-semantico-ia.md](./filtro-semantico-ia.md)
- [Serviço IA Analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/docs/visao-geral.md)
- [Endpoints de Análise IA](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
