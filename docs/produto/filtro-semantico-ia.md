# Motor de IA com Filtro Semântico Anti-Poluição

## O Que É

É o pipeline de inteligência artificial que transforma os comentários dos clientes em insights estruturados — sentimentos (com intensidade e confiança), aspectos por feedback (ABSA), categorias e palavras-chave. O diferencial está no **Filtro Semântico Anti-Poluição**: as categorias e palavras-chave precisam sair do que o cliente **escreveu**, e não do texto das perguntas do formulário nem dos rótulos das respostas.

---

## Por Que Existe

### O problema sem o filtro

Imagine que a empresa pergunta: *"Como foi o atendimento?"*, *"Como foi a qualidade?"* e *"Como foi o custo-benefício?"*.

Sem o filtro, a IA recebe essas perguntas junto com cada feedback e tende a devolvê-las como tema: **"atendimento"**, **"qualidade"** e **"custo-benefício"** aparecem em quase todos os resultados, junto com os rótulos marcados ("boa", "ótima"), mesmo quando o cliente não escreveu nada sobre isso.

**Resultado**: a análise dos comentários mostra que os clientes falam muito de "atendimento" e "qualidade". Isso parece verdade, mas é inútil — são as palavras das perguntas, não a voz real do cliente.

### A solução com o filtro

Com o Filtro Anti-Poluição, as perguntas respondidas em cada feedback vão para a IA só como **contexto**: ela é instruída a não copiá-las, e o resultado é conferido contra o texto do comentário. O que sobra são as palavras que o cliente usou espontaneamente:

- "demora" → o cliente está reclamando do tempo de espera
- "simpático" → o atendente foi bem avaliado
- "caro" → há percepção negativa sobre preço

Essas são as palavras que geram decisões reais.

---

## Como Funciona

```
Gestor clica em "Analisar comentários com IA"
        ↓
API enfileira um job (202) e o worker assume
        ↓
Worker busca os feedbacks do escopo com comentário e ainda não analisados
(os do "Testar o formulário" ficam de fora)
        ↓
Confere: contexto da empresa completo, chave de IA da empresa
e pelo menos 10 feedbacks com comentário no escopo
        ↓
Agrupa por escopo (Empresa, Produto, Serviço, Departamento) e item,
e fatia em lotes de até 20 feedbacks
        ↓
Para cada lote, monta o payload:
  - Texto de cada comentário (e a pergunta própria do escopo, quando houver)
  - Nota em estrelas e respostas às perguntas, com o texto de cada pergunta
  - Ponto de coleta e item do catálogo
  - Contexto do negócio (objetivo, meta de análise, resumo, produtos)
        ↓
Payload enviado ao LLM da empresa (OpenRouter, com a chave e o modelo dela)
        ↓
Resposta validada: um resultado para cada feedback, sentimento válido,
resumo e recomendações em pt-BR
        ↓
Por feedback: sentimento, intensidade (sentiment_score ∈ [-1,1]),
confiança (confidence ∈ [0,1]), aspectos (ABSA), categorias e keywords
        ↓
Categorias e keywords passam pelo saneamento (filtro) e pela taxonomia
        ↓
Resultados persistidos em feedback_analysis
        ↓
No relatório: os insights de cada lote são consolidados numa síntese final
(resumo + recomendações) → feedback_insights_report
```

---

## As Três Camadas do Filtro

1. **No prompt.** A IA recebe a regra de que categorias e palavras-chave vêm **exclusivamente** do comentário. Ela não pode copiar o texto das perguntas nem das subperguntas, nem usar os rótulos "péssimo", "ruim", "mediana", "boa" e "ótima". Quando o escopo tem pergunta própria no campo de comentário, o texto é lido como resposta a ela, e a pergunta também não pode virar termo.
2. **No saneamento.** Cada categoria e palavra-chave devolvida pela IA é normalizada (minúsculas, sem acento e sem pontuação) e descartada quando:
    - é um dos rótulos de resposta ou um valor marcado pelo cliente;
    - é igual ao texto inteiro de uma pergunta ou subpergunta que o cliente respondeu naquele feedback;
    - não está **ancorada** no comentário, ou seja, não aparece no texto nem divide com ele ao menos uma palavra relevante (4 letras ou mais, fora as palavras muito comuns);
    - repete um termo já aceito.

    Ficam no máximo **6 palavras-chave** e **4 categorias** por feedback.
3. **Na taxonomia.** As categorias aceitas são mapeadas para rótulos fixos por escopo (veja abaixo).

> O saneamento compara cada termo com a pergunta **inteira**, não palavra por palavra. Uma palavra que está na pergunta (como "atendimento") só fica no resultado se o cliente a escreveu no comentário — aí ela é a voz dele.

---

## Importância e Impacto

| Aspecto | Sem o Filtro | Com o Filtro |
|---|---|---|
| **Top keywords** | "atendimento", "qualidade" (termos das perguntas) | "demora", "simpático", "caro" (voz do cliente) |
| **Categorias identificadas** | Genéricas, repetitivas | Específicas e acionáveis |
| **Qualidade dos insights** | Alta frequência, baixo valor | Alta relevância, alto valor |
| **Decisões geradas** | Nenhuma — os dados não dizem nada novo | Direcionadas — o gestor identifica com mais clareza o que resolver |

> O filtro é a diferença entre um painel de IA que impressiona na demo e um que realmente funciona no dia a dia.

---

## Resiliência: Fallback Local

O fallback local cobre o caso em que a IA responde, mas **nenhuma palavra-chave sobrevive ao saneamento** de um feedback:

- As palavras-chave saem do próprio comentário: palavras com 4 letras ou mais, sem as palavras muito comuns do português (artigos, preposições, conjunções) e sem os cinco rótulos de resposta — até **4** palavras
- Sem nenhuma categoria válida, o feedback fica com as **2 primeiras palavras-chave** como categorias
- Esse caminho não remove as palavras das perguntas: ele só usa o que está escrito no comentário

Quando a chamada ao LLM **falha** — provedor fora do ar, JSON inválido, resposta incompleta ou fora do pt-BR depois da nova tentativa —, não há resultado local. O serviço de IA devolve erro sem resultado parcial, e nada é gravado para aquele lote. No gateway, o job tenta de novo os erros temporários e termina como falho nos demais, com o código do erro; os feedbacks do lote continuam aguardando análise.

---

## Detalhes Técnicos

- O contexto de negócio da empresa (`collecting_data_enterprise`) é injetado no prompt para personalizar as análises. A análise exige os três campos de contexto preenchidos: `company_objective`, `analytics_goal` e `business_summary`
- O processamento é **assíncrono**, numa fila com worker: o pedido responde `202` na hora e a Web acompanha o job, sem bloquear a coleta nem a tela
- Só feedbacks **com comentário** vão para a IA. O mínimo é de **10** feedbacks com comentário no escopo; sem isso, o job falha com `insufficient_feedbacks_for_analysis`
- A Web não limita a quantidade: cada execução pega todos os comentários pendentes do escopo, do mais antigo para o mais novo. A API aceita um `limit` opcional, de no máximo 100
- Os lotes têm até **20** feedbacks por chamada ao LLM (`IA_MAX_FEEDBACKS_PER_BATCH`, no gateway), para a resposta caber no teto de tokens de saída do modelo
- Os resultados são persistidos em `feedback_analysis` (por feedback) e `feedback_insights_report` (por escopo)
- O serviço usa o OpenRouter com a chave e o modelo configurados no perfil de cada empresa. Sem chave, o job falha com `ia_config_required`. O Gateway cifra a credencial no banco e a envia ao `ia-analyze` apenas nos headers internos `x-llm-*`; `IA_ANALYZE_REMOTE_URL` aponta somente a URL do serviço
- Para proteger o teto de tokens do modelo, cada mensagem de feedback é truncada em **2000 caracteres** (`MAX_FEEDBACK_MESSAGE_CHARS`, com marca `… [truncado]`) e as respostas dinâmicas enviadas no payload são limitadas a **20** (`MAX_DYNAMIC_ANSWERS`) — o conteúdo útil de praticamente todo feedback real cabe nesses limites

---

## Taxonomia Fixa de Categorias por Escopo

O saneamento anti-poluição decide **quais** termos sobrevivem; a taxonomia decide **como** rotulá-los de forma comparável. É o complemento natural do filtro: depois que as categorias saneadas são extraídas, elas passam por uma **taxonomia fixa de drivers de CX por escopo** (`COMPANY`, `PRODUCT`, `SERVICE`, `DEPARTMENT`).

Cada categoria saneada é **canonicalizada** para um rótulo de driver quando bate com o canônico ou um de seus sinônimos — por exemplo, no escopo `COMPANY`, `"suporte"` e `"atendente"` viram **`atendimento`**, e `"preço"`, `"valor"` ou `"caro"` viram **`preco`**. Quando não há correspondência, o termo é **preservado como emergente**, sem perda de sinal.

Por que isso importa:

- **Categorias comparáveis e tendenciáveis**: vocabulário livre da IA converge para um conjunto estável de rótulos, permitindo agrupar e acompanhar a evolução ao longo do tempo.
- **Sem perda de sinal**: termos que não se encaixam na taxonomia continuam aparecendo (emergentes), então temas novos não são silenciados.
- **Ancorada no escopo**: o conjunto de drivers e sinônimos é específico de cada escopo, e os rótulos canônicos também alimentam um *nudge* no prompt para guiar a IA.

> Implementada em `lib/categoryTaxonomy.ts` (`TAXONOMY_BY_SCOPE`, `canonicalizeCategories`, `getTaxonomyLabels`); a `categorization.service` recebe o `scopeType` e canonicaliza a saída da IA.

---

## Referência Técnica

- [Análise dos comentários → painel-insights-ia.md](./painel-insights-ia.md)
- [Serviço IA Analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/docs/visao-geral.md)
- [Endpoints de Análise IA](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
