# 02 — Métricas por período + comparação entre intervalos

> **Em uma frase:** dar ao gestor a opção de olhar os números de um recorte de tempo (ex.: "só o mês passado") e comparar dois períodos lado a lado para ver, de relance, se a coisa melhorou ou piorou.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 1-2 (filtro por período) → Mês 2-3 (comparação) |
| **Esforço** | Médio |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | [01 — Camada de dados e ORM](./01-camada-de-dados-e-orm.md) (consultas via Drizzle) + criação do índice em `feedback.created_at` |
| **Camadas afetadas** | Banco · Backend · Frontend |

## Para qualquer leitor

Hoje o painel mostra os números do negócio (total de feedbacks, nota média, distribuição de notas, sentimento) considerando **toda a história desde o começo**. Isso responde "como estamos no geral?", mas não responde a pergunta que mais importa para quem gerencia: **"e agora, está melhorando ou piorando?"**. Uma nota média de 4,2 acumulada em dois anos pode esconder um mês recente bem ruim — os números antigos "diluem" o que acabou de acontecer.

Esta etapa entrega duas capacidades novas, simples de explicar:

1. **Filtrar por período.** Um seletor de datas no topo do painel ("este mês", "últimos 30 dias", ou um intervalo personalizado). Ao escolher um período, todos os números passam a refletir só aquele recorte de tempo — como trocar a lente de uma câmera para focar num pedaço da foto.

2. **Comparar dois períodos.** Mostrar o período atual ao lado de um período de referência (por exemplo, "mês passado" contra "mês retrasado") e exibir a **variação** de forma visual: um número grande para o período atual, um número menor para o de referência, e uma setinha colorida indicando se subiu (▲ verde) ou caiu (▼ vermelho) e em quanto. É o mesmo recurso que aplicativos de banco e de saúde usam para dizer "você gastou 12% a menos que no mês anterior".

O benefício é direto: o gestor deixa de olhar um retrato estático e passa a enxergar **tendência**. Decisões como "a mudança que fizemos no atendimento surtiu efeito?" deixam de depender de impressão e passam a ter um número com seta ao lado.

## O que muda para quem usa o sistema

- **Para o gestor:**
  - Pode focar os números em qualquer janela de tempo, em vez de ver sempre o acumulado de toda a história.
  - Vê de relance se um período foi melhor ou pior que o anterior, com cor e seta — sem precisar anotar números num caderno e fazer a conta na mão.
  - Ganha **atalhos prontos** ("mês passado × mês retrasado", "últimos 30 dias × 30 dias anteriores") para não ter que montar datas manualmente.
  - Continua podendo combinar o período com o **escopo** que já existe hoje (empresa inteira, um produto, um serviço ou um departamento específico).
- **Para o cliente que dá o feedback:** nada muda. Esta etapa mexe só no painel de quem analisa; o formulário público continua igual.

## Como vai funcionar

**Antes (hoje):**

| O gestor quer... | Hoje ele consegue? |
|---|---|
| Ver os números gerais da empresa | ✅ Sim |
| Filtrar por produto/serviço/departamento | ✅ Sim (já existe o seletor de escopo) |
| Ver só o último mês | ❌ Não — sempre aparece o histórico inteiro |
| Comparar mês atual com o anterior | ❌ Não — não há nenhuma noção de tempo |

**Depois (com esta etapa):**

1. O gestor abre o painel e vê um **seletor de período** no topo, ao lado do seletor de escopo que já existe.
2. Escolhe um período (um atalho pronto ou um intervalo personalizado). Os cartões de métrica se atualizam para refletir só aquele recorte.
3. Liga a **comparação** e escolhe um atalho (ex.: "mês passado × mês retrasado"). O painel passa a mostrar, para cada métrica:
   - o **número grande** do período principal,
   - o **número de referência** (menor, ao lado),
   - o **delta** — a diferença, com seta e cor (▲ +12% em verde, ▼ −8% em vermelho).

Atalhos de comparação previstos (presets):

| Atalho | Período principal | Período de referência |
|---|---|---|
| Mês passado × mês retrasado | Mês civil anterior | Dois meses atrás |
| Últimos 30 dias × 30 dias anteriores | Dias −30 a hoje | Dias −60 a −30 |
| Este mês × mesmo mês do ano anterior | Mês corrente | Mesmo mês, ano passado |
| Esta semana × semana passada | Semana corrente | Semana anterior |

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

### Estado atual (verificado no código)

- **Endpoint:** `GET /api/protected/user/feedbacks/stats` → `getFeedbacksStatsController` em `feedback-analytics-api-gateway/src/controllers/protected/feedbacks.controller.ts` (a partir da linha ~340).
  - Aceita `scope_type` e `catalog_item_id`; resolve os `collection_point` do escopo via `resolveScopeCollectionPointIds` (`repositories/scope.repository.ts`).
  - Consulta `feedback` filtrando por `enterprise_id` (+ `collection_point_id` quando há escopo) e faz `.select('id, rating')`. **Não há filtro por `created_at`** — sempre lê o histórico inteiro.
  - **Toda a agregação é em JavaScript**: `totalFeedbacks` (length do array), `averageRating` (reduce/soma), `ratingDistribution` (cinco `.filter(...).length`), `sentimentBreakdown` e as estatísticas de satisfação (`ratingStats`, `csatTopTwoBox`, `netSatisfaction`) em `libs/statistics/`.
- **Banco:** `database/sql/tables/public.feedback.sql` define `created_at timestamp with time zone default now()`, mas a tabela só tem índice na PK (`id`) e na FK (`feedback_enterprise_id_fkey`). **Não há índice em `created_at`** — confirmado no DDL.
- **Frontend:**
  - `feedback-analytics-web/src/services/serviceFeedbacks.ts` → `ServiceGetFeedbackStats` monta a query string.
  - `feedback-analytics-web/src/routes/load/loadFeedbackStats.ts` e `feedback-analytics-web/src/routes/loaders/loaderUserDashboard.ts` carregam o estado inicial (escopo `COMPANY`).
  - `feedback-analytics-web/pages/user/dashboard.tsx` re-busca os stats quando o escopo muda, lendo `scope`/`catalogItemId` do contexto `feedback-analytics-web/src/lib/context/insightsControls.tsx`.
  - Renderização em `feedback-analytics-web/components/user/pages/dashboard/`: `SectionMetric`, `SectionEvaluationDistribution`, `SectionSatisfactionRadar`. **Não existe nenhum seletor de data.**

### Banco — índice de período

Criar índice composto para sustentar o filtro por data sem varredura completa. O par `(enterprise_id, created_at)` cobre o caso comum (toda consulta já filtra por empresa e ordena/recorta por data):

```sql
CREATE INDEX IF NOT EXISTS idx_feedback_enterprise_created_at
  ON public.feedback (enterprise_id, created_at DESC);
```

Versionar em `database/sql/` no mesmo padrão dos demais arquivos. Avaliar incluir `collection_point_id` se o filtro por escopo dominar as consultas mais pesadas. **Criar o índice antes de liberar o filtro** — sem ele, cada filtro de período faz scan da tabela inteira.

### Backend — filtro `start_date`/`end_date`

- Em `getFeedbacksStatsController`: ler `start_date`/`end_date` da query (ISO 8601), validar e aplicar o recorte **no SQL** (não em JS). Com o ORM da etapa 01, isso vira algo como `where(gte(feedback.createdAt, start), lte(feedback.createdAt, end))`. Se a etapa 01 ainda não estiver pronta, o equivalente Supabase é `.gte('created_at', start).lte('created_at', end)`.
- **Extrair a lógica de cálculo para um helper reutilizável** — ex.: `computeFeedbackStats({ enterpriseId, collectionPointIds, startDate, endDate })` que devolve o objeto `FeedbackStats` já montado. Esse helper é a peça-chave: a comparação simplesmente o chama **duas vezes** (um intervalo por chamada).
- **Migração progressiva para agregação em SQL:** começar mantendo a contagem em JS (o helper só passa a receber filtros de data) e, num passo seguinte, mover `count`/`avg`/distribuição para o banco (`GROUP BY rating`) via Drizzle. Para os volumes de um TCC isso não é bloqueante, mas a versão em SQL é o que se quer demonstrar academicamente.

### Backend — rota de comparação

Duas opções; **recomendado: rota separada**, para manter o contrato de `/stats` simples:

```
GET /api/protected/user/feedbacks/stats/comparison
  ?scope_type=...&catalog_item_id=...
  &primary_start=...&primary_end=...
  &reference_start=...&reference_end=...
→ { primary: FeedbackStats, reference: FeedbackStats, deltas: {...} }
```

O cálculo dos atalhos (qual data é "mês passado") fica idealmente no **frontend** (ele conhece o fuso do gestor), e o backend recebe as quatro datas já resolvidas — assim o backend não precisa saber o que "mês passado" significa.

### Contratos / tipos

- Estender o tipo de opções de stats (em `shared/interfaces/`, junto de `feedback.domain.ts`) com `start_date?`/`end_date?`.
- Criar `FeedbackStatsComparison` (`primary`, `reference`, `deltas`) em `shared/`, reutilizado por backend e frontend.

### Frontend — componentes novos

- `serviceFeedbacks.ts`: repassar `start_date`/`end_date`; nova função para a comparação.
- **Seletor de período** (ex.: `feedback-analytics-web/components/user/pages/dashboard/DateRangeSelector.tsx`) com os atalhos + intervalo personalizado.
- **Bloco de comparação** (ex.: `SectionComparisonMetrics.tsx`) com os cartões de número grande + referência + delta (seta/cor).
- Integrar período ao contexto `insightsControls` (hoje só guarda escopo), para que período e escopo combinem numa única seleção.
- Datas: já existe `feedback-analytics-web/src/lib/utils/FormatDate.ts`. Avaliar `date-fns` (leve, bom para "início do mês anterior") — confirmar antes em `feedback-analytics-web/package.json` para não duplicar dependência.

### Decisão de fuso horário

`created_at` é `timestamptz`. Definir e **documentar** se "mês passado" é interpretado no fuso do gestor (provável: `America/Sao_Paulo`) ou em UTC. Recomendação: resolver os limites do intervalo no fuso do gestor no frontend e enviar instantes ISO absolutos ao backend — o backend só compara timestamps, sem lógica de calendário.

## Riscos e decisões em aberto

- **Fuso horário.** Se "mês passado" for calculado em UTC mas o gestor pensar em horário de Brasília, um feedback da virada do mês pode cair no balde errado. Precisa de decisão explícita e documentada (ver acima).
- **Agregação em JS para grandes volumes.** Hoje as contas são feitas sobre o array carregado na memória. Funciona para o TCC, mas é o ponto a migrar para SQL (`GROUP BY`) quando o volume crescer.
- **Empty state e divisão por zero no delta.** Período sem feedbacks precisa de um estado vazio claro. Na comparação, se o período de referência tem zero feedbacks, não dá para calcular "variação %" (divisão por zero) — definir o comportamento (ex.: mostrar "—" ou "novo" em vez de um percentual sem sentido).
- **Insights de IA × período.** O texto gerado pela IA (`feedback_insights_report`) **não é segmentado por data** hoje. Esta etapa cobre as **métricas quantitativas**; comparar os **insights textuais** por período é trabalho separado (exigiria gerar/armazenar insights por janela de tempo) e fica fora do escopo aqui.
- **Métricas de satisfação com amostra pequena.** Recortar por período reduz a amostra; os intervalos de confiança e o `confidenceTier` que já existem ajudam a sinalizar quando o número é pouco confiável — manter visíveis também na comparação.

## Como vamos saber que deu certo

- [ ] Existe índice em `feedback(enterprise_id, created_at)` versionado em `database/sql/`.
- [ ] `/feedbacks/stats` aceita `start_date`/`end_date` e o recorte é feito **no SQL** (verificável pelo plano de execução usando o índice, não filtrando em JS).
- [ ] O painel tem um seletor de período que atualiza todos os cartões de métrica do escopo selecionado.
- [ ] Existe rota/contrato de comparação devolvendo período principal, referência e deltas.
- [ ] O bloco de comparação mostra número grande + referência + delta com seta e cor corretas (▲ verde / ▼ vermelho).
- [ ] Os atalhos ("mês passado × retrasado", "últimos 30d × 30d anteriores", etc.) produzem os intervalos esperados no fuso decidido.
- [ ] Período sem dados mostra estado vazio; referência com zero feedbacks não quebra o cálculo do delta.

## Etapas de entrega

1. **Índice + filtro de período (leitura).** Criar o índice, adicionar `start_date`/`end_date` ao endpoint (filtro em SQL) e o seletor de período no painel. Já entrega valor sozinho.
2. **Helper reutilizável + comparação.** Extrair o cálculo para um helper, criar a rota/tipo de comparação (helper chamado duas vezes) e o bloco visual com número grande, referência, deltas e os atalhos.
3. **Polimento.** Atalhos adicionais, gráficos de distribuição sobrepostos/lado a lado, tratamento fino de empty states e — se necessário pelo volume — migração da agregação de JS para SQL.

## O que isso demonstra no TCC

- **Agregação de dados em SQL** (count/avg/distribuição com `GROUP BY` e filtro temporal) em vez de processamento na aplicação.
- **Indexação e desempenho:** criação de índice composto orientado ao padrão de consulta e leitura do plano de execução.
- **UX de comparação de dados:** representação visual de variação entre períodos (número de referência + delta com codificação de cor/direção), um padrão consagrado de visualização de informação.
- Tratamento honesto de casos de borda (fuso horário, amostra pequena, divisão por zero) — material para a discussão de decisões de projeto.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [01 — Camada de dados e ORM](./01-camada-de-dados-e-orm.md) — pré-requisito: as consultas agregadas e o filtro de período são feitos via ORM (Drizzle); esta etapa também motiva o índice em `created_at`.
- [03 — Análise assíncrona](./03-analise-assincrona.md) — relacionada por também tocar o pipeline de feedbacks/insights.
