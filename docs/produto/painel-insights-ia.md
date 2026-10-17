# Análise dos comentários com IA

## O Que É

É onde o ciclo do produto se fecha. A seção **Análise dos comentários ✨IA** (antigo "Painel de Insights") permite que o gestor dispare a análise de inteligência artificial sobre o que os clientes **escreveram** e veja o resultado em duas páginas:

- **Visão geral** (`/user/insights/overview`):
    - **Tom dos comentários** — barra positivo/neutro/negativo, o **Saldo de sentimento** (Net Sentiment Score) em número e em palavras ("+45 · Positivo") e o indicador de Precisão;
    - **Assuntos que mais impactam** — aspectos (ABSA) ordenados pelo peso na percepção do cliente; enquanto não há assuntos com 3 ou mais menções, as **categorias** aparecem como reserva;
    - **Resumo e recomendações da IA** — o que os clientes estão dizendo, de forma consolidada, e o que fazer com base nos padrões identificados.
- **Comentários** (`/user/insights/comments`) — a lista dos comentários analisados, com filtros **Todos · Positivos · Neutros · Negativos · Nota e texto não combinam**.

No Dashboard, o bloco "Análise dos comentários" mostra o tom e o resumo da IA, com um link para a Visão geral. O que o cliente **marcou** (estrelas e perguntas do formulário) não depende da IA e fica no Dashboard e nas páginas de detalhe, descritas em [Métricas e estatísticas](metricas-e-estatisticas.md#organização-decidida).

> **Reorganização de 16/10/2026:** as antigas páginas Relatórios, Emocional, Estatísticas e Feedbacks › Analisados viraram as duas páginas acima, e os endereços antigos redirecionam para elas. Palavras-chave, termômetro, clima emocional e momentos emocionais saíram das telas. Detalhes em [Métricas e estatísticas](metricas-e-estatisticas.md#catálogo-de-métricas).

---

## Por Que Existe

Coletar feedback é apenas metade do trabalho. A outra metade é **entender o que os dados estão dizendo**.

Uma empresa com 200 feedbacks mensais não pode ler cada um individualmente para extrair padrões. Sem análise automatizada, o dado coletado envelhece numa tabela sem nunca gerar valor.

A análise dos comentários resolve isso: em segundos, converte centenas de textos brutos em um resumo legível, contextualizado ao negócio da empresa e segmentado por escopo.

> A coleta captura a voz do cliente. A análise dos comentários traduz essa voz em ação gerencial.

---

## Como Funciona

O botão **"Analisar comentários com IA"**, na barra abaixo do cabeçalho, abre uma janela com as duas etapas do processamento. O botão principal, **"Processar e analisar comentários com IA"**, roda as duas em sequência num único job. As opções **"Apenas Analisar"** e **"Apenas gerar o resumo"** rodam uma etapa só.

### 1. Analisar novos feedbacks
Processa os feedbacks que **ainda não passaram pela IA**. Ideal para rodar periodicamente, à medida que novos feedbacks chegam.

```
Gestor clica em "Apenas Analisar" (ou no botão principal)
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

### 2. Escrever o resumo e as recomendações
Recalcula o **resumo e as recomendações** com base nos feedbacks já analisados — sem reprocessar tudo do zero. Útil quando novos feedbacks foram analisados e o gestor quer um resumo atualizado.

```
Gestor clica em "Apenas gerar o resumo" (ou no botão principal)
        ↓
API agrupa todos os feedback_analysis existentes por escopo
        ↓
IA gera sumário situacional + recomendações consolidadas
        ↓
Resultados salvos em feedback_insights_report
        ↓
Visão geral e Dashboard exibem o "Resumo e recomendações da IA" atualizado
```

---

## Seletor de Escopo

O escopo é escolhido no **seletor do cabeçalho**, o mesmo do Dashboard. Cada seção mostra uma **etiqueta de escopo** clicável (ex.: "Avaliação geral da empresa", "Produto · Pizza") que abre esse seletor.

| Escopo | Disponível quando |
|---|---|
| Geral (só a avaliação geral da empresa) | Sempre |
| Produto | `uses_company_products = true` **e** ≥ 1 item cadastrado |
| Serviço | `uses_company_services = true` **e** ≥ 1 item cadastrado |
| Departamento | `uses_company_departments = true` **e** ≥ 1 item cadastrado |

Cada escopo tem seu próprio resumo independente. "Geral" não é a empresa inteira: veja [Escopos](metricas-e-estatisticas.md#escopos).

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Escala** | Processa dezenas ou centenas de feedbacks em segundos |
| **Contexto de negócio** | O resumo é personalizado com os dados da empresa (objetivo, segmento, produtos) |
| **Segmentação** | Resumos separados por escopo permitem comparar áreas da empresa |
| **Decisão gerencial** | Recomendações que servem de ponto de partida para a ação do gestor |
| **Assincronismo** | O processamento não bloqueia a experiência do cliente durante a coleta |

---

## O Que a Análise Retorna

Além do resumo situacional e das recomendações geradas pela IA, a Visão geral mostra o **Net Sentiment Score** (Saldo de sentimento) no bloco "Tom dos comentários" e os **"Assuntos que mais impactam"** (aspectos ABSA), trazendo a leitura quantitativa do que pesa na percepção do cliente. O exemplo abaixo reflete os campos reais retornados pelo endpoint de análise (`GET /feedbacks/analysis`). A API ainda devolve `topKeywords` e `confidenceTier`, mas as telas não os usam mais:

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

> O resumo textual (`summary`/`recommendations`) vem do `feedback_insights_report`. O antigo "clima" do relatório deu lugar ao resumo em palavras do bloco **Tom dos comentários**, derivado do **Net Sentiment Score** (Positivo / Neutro / Atenção, com banda neutra de ±5).

---

## Métricas estatísticas por trás das telas

As métricas são alimentadas pelo módulo `feedback-analytics-api-gateway/src/libs/statistics/index.ts` — um conjunto de **funções puras** com métodos de referência de mercado. A regra de ouro: **a matemática vive no backend; o frontend apenas apresenta**. Elas combinam duas lentes complementares. A página [Métricas e estatísticas](metricas-e-estatisticas.md) tem o catálogo completo, com as fórmulas.

### Lente SATISFAÇÃO (as estrelas — não dependem da IA)

Mede a nota objetiva de 1 a 5 que o cliente deu. Aparece no Dashboard, na seção **"Avaliação por estrelas"**, e na página **"Todas as métricas de estrelas"** (`/user/ratings`):

| Métrica | Na tela | Como é calculada |
|---|---|---|
| **Nota média + faixa** (`starMean`, `starMeanCI`) | Card **Média** (`4,2 /5 ★ Boa · 128 avaliações`) com o indicador de Precisão | Média de notas 1–5 com **intervalo de confiança t** (clampado em [1,5]) |
| **Clientes satisfeitos / CSAT** (`csat`) | O % do card **Positivas (4–5★)** | **CSAT Top-2-Box** com **intervalo de Wilson** |
| **Saldo de satisfação** (`netSatisfaction`) | Não aparece mais: é o % de positivas menos o de críticas | %(top-2) − %(bottom-2), resultado em [-100, 100] |

### Lente SENTIMENTO da IA (o texto — depende da análise)

Lê o que o cliente escreveu. Só aparece quando há feedbacks analisados (`totalAnalyzed > 0`), no bloco **Tom dos comentários**:

- **Saldo de sentimento / Net Sentiment Score** (`netSentimentScore`): `(positivos − negativos) / total × 100`, resultando em [-100, 100]. É a principal métrica do tom dos comentários.
- Distribuição positivo/neutro/negativo com **ICs de Wilson** por fração (`sentimentCIs`). O IC dos positivos alimenta o indicador de Precisão do bloco.

### Ranqueamento honesto de temas

`topCategories` e `topKeywords` não são ordenados pela contagem crua — são ranqueados pelo **limite inferior do intervalo de Wilson** (`wilsonLowerBound`), critério justo para amostras pequenas (um termo citado 2 vezes não supera um citado 30). Cada termo traz `{ name, count, proportion, ci }`. Na tela, só as categorias aparecem, e apenas como reserva dos assuntos.

### Aspectos ABSA — "Assuntos que mais impactam"

A análise por aspecto (**ABSA**, *Aspect-Based Sentiment Analysis*) agrega os aspectos extraídos de cada texto (`aspectSentiments`):

- Cada aspecto recebe seu próprio saldo de sentimento (NSS) e IC de Wilson.
- **Gate de menção mínima**: um aspecto só entra na lista com **≥ 3 menções** — evita destacar ruído.
- Ordenados por **impacto = volume × |NSS|** (top 12): o que aparece muito **e** divide opiniões sobe ao topo.

### Discrepância nota × texto

Quando a estrela e o texto contam histórias opostas, o item é marcado em `discrepancy`:

- **`silent_detractor`** — nota alta (4–5) com texto negativo: o cliente "perdoou" na nota, mas a crítica está no texto.
- **`rating_misuse`** — nota baixa (1–2) com texto positivo: o cliente provavelmente errou a escala.

Na lista de **Comentários**, esses itens levam o selo "Nota e texto não combinam" e têm um filtro próprio.

> **Referências de mercado:** Net Sentiment Score (Thematic), Net Satisfaction / CSAT Top-2-Box (Qualtrics/ACSI), intervalo de Wilson (Brown, Cai & DasGupta, 2001), intervalo t para média e média Bayesiana / encolhimento estilo IMDb.

---

## Perguntas do formulário

As perguntas respondem a uma pergunta diferente: **"como cada pergunta do meu formulário está sendo avaliada?"**. As métricas aqui são **100% determinísticas** — calculadas sobre as respostas estruturadas (escala 1–5) e **independem da IA**. Por isso não ficam na Análise dos comentários: a antiga aba Perguntas (`/user/insights/questions`) saiu e redireciona para o Dashboard.

- **Dashboard, seção "Perguntas do formulário":** as perguntas **atuais**, na ordem do formulário, cada uma com nota, rótulo, respostas, % de satisfeitos e Precisão.
- **Página de uma pergunta** (`/user/questions/:questionId`): a pergunta e cada subpergunta, com a distribuição de péssimo a ótimo e o histórico recolhido.
- **Perguntas que saíram do formulário** (`/user/questions/removed`).

Campos retornados por `GET /feedbacks/questions` para cada pergunta (e suas subperguntas aninhadas), no escopo selecionado:

| Campo | Significado |
|---|---|
| `mean` | Nota média da pergunta (/5) |
| `ci` | Faixa provável (intervalo de confiança t) da média |
| `satisfiedPct` | % de respostas satisfeitas (BOA + ÓTIMA) |
| `distribution` | Mini-distribuição: PESSIMO / RUIM / MEDIANA / BOA / OTIMA |
| `confidenceTier` | Camada de confiança pelo n de respostas (a tela usa o indicador de Precisão) |

A API devolve a lista ordenada **pior → melhor** (menor nota no topo); a tela reordena as atuais na ordem do formulário. O escopo vazio retorna `{ questions: [] }`.

### Estados de cada redação

Como as perguntas evoluem ao longo do tempo (e usam soft-delete para preservar histórico), cada redação carrega um `status`:

- **`current`** (Atuais) — pergunta ativa e com o texto atual da configuração.
- **`deactivated`** (Desativadas) — existe na config, mas o toggle está desligado; reativar traz o histórico de volta (id estável).
- **`past`** (Antigas) — redação antiga (texto editado depois) ou pergunta removida da config.

No Dashboard aparecem só as atuais; as desativadas e antigas ficam no histórico recolhido da página da pergunta e em "Perguntas que saíram do formulário".

---

## Confiabilidade dos números

Para não passar uma falsa sensação de precisão, a interface comunica **quão sólida é cada métrica** com um indicador só:

- **Precisão alta, média ou baixa** (`PrecisionBadge`): calculada pela largura da **faixa provável** (IC de Wilson para proporções, IC t para médias), com a trava de **menos de 10 respostas = baixa**. Precisão alta fica discreta; média e baixa aparecem em destaque. Ao clicar, abre um painel com a faixa em linguagem simples, o número de respostas, o porquê do nível, como melhorar e o aviso de que quem respondeu pode não representar todos os clientes. Os limites estão em [Métricas e estatísticas](metricas-e-estatisticas.md#operacionais-e-de-confiabilidade).
- **Etiqueta de escopo** (`ScopeTag`): diz de qual escopo cada seção está falando.

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
