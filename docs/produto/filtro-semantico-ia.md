# Motor de IA com Filtro Semântico Anti-Poluição

## O Que É

É o pipeline de inteligência artificial que transforma feedbacks de texto livre em insights estruturados — sentimentos (com intensidade e confiança), aspectos por feedback (ABSA), categorias e palavras-chave. O diferencial está no **Filtro Semântico Anti-Poluição**: antes de extrair as palavras mais relevantes, o sistema remove automaticamente os termos que fazem parte das próprias perguntas do formulário.

---

## Por Que Existe

### O problema sem o filtro

Imagine que a empresa pergunta: *"Como foi o atendimento?"*, *"Como foi a qualidade?"* e *"Como foi o custo-benefício?"*.

Sem o filtro, as palavras **"atendimento"**, **"qualidade"** e **"custo-benefício"** aparecem em absolutamente todos os feedbacks — afinal, os clientes as leem nas perguntas. A IA identifica essas palavras como as mais frequentes e as coloca no topo de todas as nuvens de palavras e categorias.

**Resultado**: o painel de insights mostra que os clientes falam muito de "atendimento" e "qualidade". Isso é verdade, mas é completamente inútil — são as palavras das perguntas, não a voz real do cliente.

### A solução com o filtro

Com o Filtro Anti-Poluição, o motor de IA recebe as perguntas configuradas pela empresa e é instruído a **ignorar esses termos** na extração. O que sobra são as palavras que o cliente usou espontaneamente:

- "demora" → o cliente está reclamando do tempo de espera
- "simpático" → o atendente foi bem avaliado
- "caro" → há percepção negativa sobre preço

Essas são as palavras que geram decisões reais.

---

## Como Funciona

```
Gestor dispara análise pelo painel
        ↓
API busca feedbacks ainda não analisados
        ↓
Feedbacks são agrupados por escopo (Empresa, Produto, Serviço, Departamento)
        ↓
Para cada batch, o sistema monta o payload:
  - Textos dos feedbacks
  - Perguntas configuradas pela empresa (para o filtro)
  - Dados de contexto do negócio (objetivo, resumo da empresa)
        ↓
Payload enviado ao provedor LLM externo configurável
        ↓
LLM retorna por feedback (excluindo os termos das perguntas):
  - sentimento (positivo / neutro / negativo)
  - intensidade graduada do sentimento geral (sentiment_score ∈ [-1,1])
  - confiança da classificação (confidence ∈ [0,1])
  - categorias e keywords
  - aspectos (ABSA): cada aspecto com sentimento e intensidade próprios
        ↓
Sistema monta insights globais: resumo situacional + recomendações
        ↓
Resultados persistidos → painel atualizado
```

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

Caso o provedor LLM externo esteja indisponível ou retorne uma resposta inválida (alucinações, JSON malformado), o sistema aciona um **mecanismo de fallback local** baseado em *stopwords*:

- Filtra palavras comuns do português (artigos, preposições, conjunções)
- Remove os termos das perguntas (mesmo filtro anti-poluição)
- Extrai as palavras restantes como keywords brutas
- O feedback continua sendo processado mesmo quando a IA externa falha — o fallback local evita que ele seja descartado nesses casos

Isso garante que uma instabilidade do provedor externo não corrompa o painel com dados vazios.

> Observação: o saneamento de termos (remoção das palavras das perguntas e de *stopwords*) roda **sempre** no pós-processamento das keywords devolvidas pelo LLM — não é um caminho de exceção. O fallback a partir da própria mensagem só entra em ação quando a lista saneada fica vazia.

---

## Detalhes Técnicos

- O contexto de negócio da empresa (`collecting_data`) é injetado no prompt para personalizar as análises
- O processamento é **assíncrono** — não bloqueia a interface do cliente durante a coleta
- Limite padrão: 50 feedbacks por execução (máx. 100), com mínimo de 10 para análise relevante
- Os resultados são persistidos em `feedback_analysis` (por feedback) e `feedback_insights_report` (por escopo)
- O serviço usa o Google Gemini (`@google/genai`, modelo `gemini-2.5-flash` fixo no código), configurável via `GEMINI_API_KEY`; trocar de provedor exige alteração de código. A variável `IA_ANALYZE_REMOTE_URL` apenas aponta a URL do próprio serviço `ia-analyze`, não troca de fornecedor
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

- [Painel de Insights → painel-insights-ia.md](./painel-insights-ia.md)
- [Serviço IA Analyze](https://github.com/TCC-Feedback-Analytics/feedback-analytics-ia-analyze/blob/main/docs/visao-geral.md)
- [Endpoints de Análise IA](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
