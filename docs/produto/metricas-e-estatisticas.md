# Métricas e Estatísticas

## Introdução

Toda métrica do Feedback Analytics nasce de três fontes de dados coletadas no feedback do cliente: a **nota de 1 a 5** (a estrela), o **texto livre** que ele escreveu e a **análise de IA** feita sobre esse texto (sentimento, temas e aspectos). A partir desses dados brutos, o backend calcula — com métodos estatísticos consagrados na literatura (ex.: intervalo de Wilson, IC t) — um conjunto de métricas que respondem, de forma honesta, a perguntas como "os clientes estão satisfeitos?", "o que eles elogiam ou reclamam?" e "posso confiar nesses números?". A regra de ouro: **a matemática vive no backend** (módulo de funções puras `feedback-analytics-api-gateway/src/libs/statistics`); o frontend apenas apresenta. Toda métrica também respeita o **escopo selecionado** (Empresa, Produto, Serviço ou Departamento).

---

## Tabela-resumo

| Métrica | O que mede | Onde aparece |
|---|---|---|
| **Nota média + faixa provável** (`starMean`, `starMeanCI`) | Média das estrelas (1–5) com intervalo de confiança | Dashboard / Estatísticas |
| **CSAT Top-2-Box** (`csat`) | % de clientes satisfeitos (notas 4–5) | Estatísticas |
| **Net Satisfaction** (`netSatisfaction`) | Saldo entre quem amou e quem desgostou | Estatísticas |
| **Net Sentiment Score** (`netSentimentScore`) | Clima do que foi escrito (saldo de sentimento da IA) | Estatísticas / Relatório |
| **Distribuição de sentimentos** | Proporção positivo / neutro / negativo (IA) com IC | Estatísticas / Relatório |
| **sentiment_score** | Intensidade graduada do sentimento de cada texto | Relatório (por item) |
| **Camada de confiança** (`confidenceTier`) | Quão sólida é a amostra (pelo tamanho `n`) | Dashboard / Estatísticas / Perguntas |
| **Top categorias / keywords** | Temas e termos mais relevantes nos textos, com IC | Estatísticas / Relatório |
| **Aspectos ABSA** (`aspectSentiments`) | "Assuntos que mais impactam" — sentimento por aspecto | Estatísticas / Relatório |
| **Discrepância nota × texto** (`discrepancy`) | Itens onde a estrela e o texto se contradizem | Relatório (por item) |
| **Métricas por pergunta** (`mean`, `satisfiedPct`, `distribution`) | Avaliação determinística de cada pergunta/subpergunta | Perguntas |

---

## Satisfação (as estrelas)

A lente de **Satisfação** mede a nota objetiva de 1 a 5 que o cliente deu. **Não depende da IA** — vale mesmo para feedbacks que ainda não foram analisados.

### Nota média + faixa provável (`starMean`, `starMeanCI`)

- **O que é:** a média aritmética das notas 1–5 do escopo, acompanhada de uma **faixa provável** (intervalo de confiança).
- **Como se lê:** `starMean` é o número central (ex.: 4,2). `starMeanCI` mostra o intervalo onde a média real provavelmente está (ex.: 4,05 a 4,35). Quanto **menor a amostra, mais larga a faixa** — sinal de que o número é menos estável.
- **Como é calculada:** média das notas com **intervalo de confiança t** a 95% (`mean ± t · erro padrão`). Para amostras com até 30 graus de liberdade usa-se o valor crítico de `t`; acima disso, aproxima-se por `z` (1,96). A faixa é **clampada em [1, 5]** (a unidade é a própria nota, nunca sai da escala).

### CSAT Top-2-Box (`csat`)

- **O que é:** o **CSAT** (Customer Satisfaction Score) no formato **Top-2-Box** — a porcentagem de clientes que deram as duas notas mais altas (4 ou 5).
- **Como se lê:** `csat.pct` é a % de satisfeitos (ex.: 66,7%). `csat.ci` é a faixa provável dessa porcentagem (ex.: 57,8% a 74,5%).
- **Como é calculada:** `%(notas 4–5)` sobre o total, com **intervalo de Wilson** em porcentagem (preciso mesmo em amostras pequenas e perto de 0% ou 100%). Referência: Qualtrics/ACSI.

### Net Satisfaction (`netSatisfaction`)

- **O que é:** o **saldo de satisfação** — o equilíbrio entre quem amou e quem desgostou.
- **Como se lê:** resultado em **[-100, 100]**. Positivo = mais satisfeitos do que insatisfeitos; negativo = o contrário; perto de zero = empate.
- **Como é calculada:** `%(top-2: notas 4–5) − %(bottom-2: notas 1–2)`. Notas 3 (neutras) não contam para nenhum lado.

---

## Sentimento (IA)

A lente de **Sentimento** lê **o que o cliente escreveu**. Só aparece quando há feedbacks já analisados pela IA (`totalAnalyzed > 0`). É importante notar que sentimento (texto) e satisfação (estrela) **podem divergir** — são leituras complementares.

### Net Sentiment Score / NSS (`netSentimentScore`)

- **O que é:** a principal métrica de **clima textual** — o saldo entre feedbacks positivos e negativos identificados pela IA.
- **Como se lê:** resultado em **[-100, 100]**. No relatório, o NSS define o **clima** exibido — Clima Positivo, Neutro ou de Atenção — com uma **banda neutra de ±5** (não mais o voto majoritário de sentimento).
- **Como é calculada:** `(positivos − negativos) / total × 100`. Referência: Net Sentiment Score (Thematic).

### Distribuição de emoções

- **O que é:** a proporção de feedbacks **positivos / neutros / negativos** classificados pela IA.
- **Como se lê:** cada classe vem com seu **IC de Wilson** por fração (`sentimentCIs`, em [0, 1]) — a faixa provável daquela proporção.
- **Como é calculada:** contagem por classe sobre o total analisado; o IC de cada fração usa o intervalo de Wilson.

### sentiment_score graduado

- **O que é:** a **intensidade** do sentimento de cada texto, individualmente, além do rótulo categórico (positive/neutral/negative).
- **Como se lê:** número em **[-1, 1]** — quanto mais próximo de -1, mais negativo; de +1, mais positivo. Refina o sentimento categórico com a magnitude.
- **Como é calculada:** atribuído pela IA por feedback (coluna `sentiment_score` em `feedback_analysis`). Cada item também traz `confidence` em **[0, 1]**, indicando o grau de certeza da classificação.

---

## Confiabilidade dos números

Para não passar uma falsa sensação de precisão, **toda métrica comunica quão sólida ela é**. Quanto menor a amostra, mais cautela.

### Camadas de confiança (`confidenceTier`)

Cada métrica carrega uma camada derivada do tamanho da amostra (`n`), na base de Cochran:

| Faixa (n) | Camada | Leitura |
|---|---|---|
| < 10 | `insufficient` (Dados insuficientes) | Números apenas ilustrativos |
| 10–29 | `low` (Confiança baixa) | Tendência, sem firmeza |
| 30–99 | `moderate` (Confiança média) | Direcionamento confiável |
| 100+ | `good` (Confiança alta) | Base sólida para decisão |

Na interface, isso vira o **selo de confiança** (`ConfidenceBadge`): um badge clicável que abre uma explicação em linguagem simples. **"Amostra pequena"** significa, na prática, um `n` baixo (especialmente abaixo de 30): a métrica ainda é mostrada, mas a faixa provável fica larga e a leitura deve ser tratada como tendência, não como verdade fechada.

### Intervalo de Wilson (proporções)

Usado para **porcentagens e proporções** (CSAT, distribuição de sentimento, categorias, keywords, aspectos). É preciso mesmo com poucos dados e perto dos extremos (0% / 100%), onde o método clássico (Wald) falha. Calculado a 95%; pode ser apresentado em fração [0, 1] ou em porcentagem. Referência: Brown, Cai & DasGupta (2001).

### Intervalo de confiança t da média

Usado para **médias de nota** (média de estrelas e média por pergunta). É a "faixa provável" da média: `mean ± t · erro padrão`, a 95%. Para amostras pequenas usa o valor crítico de `t`; o resultado é clampado em [1, 5].

### Média Bayesiana (encolhimento)

- **O que é:** um ajuste estilo IMDb que **puxa a média de um item com poucos votos em direção à média global**, evitando que um item com 2 avaliações pareça melhor (ou pior) do que um com 200.
- **Como é calculada:** `WR = (v·R + m·C) / (v + m)`, onde `v` = nº de votos do item, `R` = média do item, `C` = média global (o "prior") e `m` = força do prior (quantos "votos" equivalentes). Disponível como função pura no módulo de estatística.

> Em resumo: médias e proporções **nunca aparecem como número seco**. A "faixa provável" (IC de Wilson para proporções, IC t para médias) mostra o intervalo onde o valor real provavelmente está.

---

## Temas e aspectos (ABSA)

A IA extrai dos textos os **temas** (categorias e keywords) e faz **ABSA** (*Aspect-Based Sentiment Analysis*) — o sentimento por aspecto mencionado.

### Top categorias e keywords

- **O que é:** os temas (`topCategories`) e termos (`topKeywords`) mais relevantes nos textos do escopo.
- **Como se lê:** cada item traz `{ name, count, proportion, ci }` — nome, contagem de menções, proporção sobre o total e o intervalo de Wilson da proporção.
- **Como é calculada — ranqueamento honesto:** a lista **não** é ordenada pela contagem crua. É ordenada pelo **limite inferior do intervalo de Wilson** (`wilsonLowerBound`) — critério justo para amostras pequenas, em que um termo citado 2 vezes não supera um citado 30. Top 10 de cada.

### Aspectos por impacto — "Assuntos que mais impactam"

- **O que é:** os aspectos extraídos de cada texto (`aspectSentiments`), agregados para mostrar o que mais pesa na percepção do cliente.
- **Como se lê:** cada aspecto recebe seu próprio **Net Sentiment Score** e **IC de Wilson**. O topo da lista combina volume e polarização.
- **Como é calculada:**
  - **Gate de menção mínima:** um aspecto só entra na lista com **≥ 3 menções** (evita destacar ruído).
  - **Ordenação por impacto = volume × |NSS|** (top 12): o que aparece **muito** e **divide opiniões** sobe ao topo.

### Discrepância nota × texto (`discrepancy`)

Quando a estrela e o texto contam histórias opostas, o item é marcado:

- **`silent_detractor`** — nota alta (4–5) com texto negativo: o cliente "perdoou" na nota, mas a crítica está no texto.
- **`rating_misuse`** — nota baixa (1–2) com texto positivo: o cliente provavelmente errou a escala.
- **`null`** — nota e texto coerentes entre si.

---

## Métricas determinísticas por pergunta/subpergunta

Respondem a outra pergunta: **"como cada pergunta do meu formulário está sendo avaliada?"**. São **100% determinísticas** — calculadas só sobre as respostas estruturadas (escala 1–5) e **independem da IA**. Alimentam a aba **Perguntas** (endpoint `/feedbacks/questions`), no escopo selecionado, com cada pergunta e suas subperguntas aninhadas.

Os rótulos de resposta mapeiam para uma nota: `PESSIMO` = 1, `RUIM` = 2, `MEDIANA` = 3, `BOA` = 4, `OTIMA` = 5.

| Campo | Significado |
|---|---|
| `mean` | Nota média da pergunta (escala 1–5) |
| `ci` | Faixa provável (IC t) da média |
| `satisfiedPct` | % de respostas satisfeitas (BOA + ÓTIMA) |
| `distribution` | Mini-distribuição por rótulo: PESSIMO / RUIM / MEDIANA / BOA / OTIMA |
| `confidenceTier` | Selo de confiança pelo `n` de respostas |
| `status` | Estado da redação: `current` (atual), `deactivated` (desativada), `past` (antiga) |

A lista vem ordenada **pior → melhor** (menor nota no topo), para o gestor atacar primeiro o que mais incomoda. Escopo sem feedbacks (ou item inexistente) retorna `{ questions: [] }`.

> Como as perguntas evoluem (e usam soft-delete para preservar histórico), cada redação distinta de uma mesma pergunta vira uma entrada própria: o `question_id` é estável, mas o snapshot de texto pode mudar — o que separa "atuais" de "antigas".

---

## Para detalhes da API

Os formatos completos de requisição e resposta dos endpoints que expõem essas métricas — `GET /feedbacks/stats`, `GET /feedbacks/questions` e `GET /feedbacks/analysis` — estão na [Referência de Endpoints](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md).
