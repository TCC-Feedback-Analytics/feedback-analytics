# Métricas e Estatísticas

## Introdução

Toda métrica do Feedback Analytics nasce de três fontes de dados coletadas no feedback do cliente: a **nota de 1 a 5** (a estrela), o **texto livre** que ele escreveu e a **análise de IA** feita sobre esse texto (sentimento, temas e aspectos). A partir desses dados brutos, o backend calcula — com métodos estatísticos consagrados na literatura (ex.: intervalo de Wilson, IC t) — um conjunto de métricas que respondem, de forma honesta, a perguntas como "os clientes estão satisfeitos?", "o que eles elogiam ou reclamam?" e "posso confiar nesses números?". A regra de ouro: **a matemática vive no backend** (módulo de funções puras `feedback-analytics-api-gateway/src/libs/statistics`); o frontend apenas apresenta. Toda métrica também respeita o **escopo selecionado** no cabeçalho — veja [Escopos](#escopos), porque "Geral" não significa "a empresa inteira".

---

## Escopos

Todas as métricas das telas seguem o escopo escolhido no cabeçalho. O escopo decide **quais pontos de coleta (QR Codes)** entram na conta (`resolveScopeCollectionPointIds`, em `feedback-analytics-api-gateway/src/repositories/scope.repository.ts`):

| Escolha no cabeçalho | O que entra na conta | Exemplo |
|---|---|---|
| **Geral** (`COMPANY`) | Só os feedbacks do **QR Code geral da empresa**. Produtos, serviços e departamentos **ficam de fora**. | Um cliente que avaliou o "Produto A" pelo QR do produto **não** aparece em "Geral". |
| **Produto / Serviço / Departamento**, sem item escolhido | A soma de **todos os itens daquele tipo**. | "Produto" sem item = todos os produtos juntos. |
| **Produto / Serviço / Departamento**, com item escolhido | Só os feedbacks daquele item. | "Produto A". |
| *(sem escopo)* | Todos os feedbacks da empresa. **Não existe na tela**: só acontece se a API for chamada sem `scope_type`. | — |

Consequências que importam para a leitura:

- **"Geral" ≠ empresa inteira.** O nome sugere o total, mas é só o canal geral da empresa. Hoje não há na interface uma visão do total da empresa.
- **Antes da reorganização, nenhuma métrica dizia na tela de qual escopo estava falando**: o escopo só aparecia no seletor do cabeçalho. Resolvido pela etiqueta de escopo (abaixo).
- O rótulo "Total acumulado no workspace", no card de feedbacks recebidos do Dashboard, era impreciso (o número é do escopo selecionado). O card saiu na reorganização.

### Decisão: etiqueta de escopo em cada seção (16/10/2026)

Cada seção do Dashboard ("Avaliação por estrelas", "Perguntas do formulário", "Análise dos comentários") e cada página de detalhe passa a ter, no topo, uma **etiqueta de escopo** clicável (abre o seletor). Ela não se repete em cada card e o texto descreve exatamente o que entra na conta:

| Escolha no cabeçalho | Etiqueta |
|---|---|
| Geral | **Avaliação geral da empresa** |
| Tipo sem item | **Todos os produtos (3)** · **Todos os serviços (2)** · **Todos os departamentos (4)** |
| Item | **Produto · Pizza** · **Serviço · Entrega** · **Departamento · Cozinha** |

- "Geral" vira "Avaliação geral da empresa" só na etiqueta. A renomeação do seletor fica para a visão total da empresa (ver abaixo).
- **Ajuste de 17/10/2026:** a etiqueta dizia "QR geral da empresa". Ela não cita mais um canal, porque o escopo da empresa vai juntar mais de um canal de coleta (QR Code hoje, NFC depois). Veja **Configuração da coleta: escopo, perguntas e canais**, abaixo.
- Textos de vazio e o painel de precisão citam o escopo (ex.: "Ainda sem avaliações na empresa (avaliação geral)").
- Um componente só para todas as telas, para o texto nunca divergir.

**Adiado:** a **visão total da empresa** (todos os escopos juntos) e a renomeação do "Geral" serão planejadas com cuidado mais à frente.

---

## Catálogo de métricas

> **Situação (16/10/2026):** inventário conferido no código das branches `developer` da Web e do API Gateway. A coluna **Decisão** registra o que o dono do produto decidiu na revisão de 16/10/2026, métrica por métrica. A coluna **Onde aparece hoje** descreve as telas **antes** da reorganização. As decisões foram **implementadas na Web** (só front-end, sem mudar API nem contratos) e as telas resultantes estão em **Organização decidida**, logo após o catálogo.

Legenda: **Mantém** · **Funde** (mesma informação de outra métrica) · **Renomeia** · **Muda de lugar** · **Sai**.

### Lente Notas (as estrelas)

Fonte: `GET /feedbacks/stats` (contrato `FeedbackStats`) e `GET /feedbacks/questions`. **Não dependem da IA.**

| Métrica (nome na tela) | O que mede | Onde aparece hoje | Ajuda o gestor a… | Decisão (16/10/2026) |
|---|---|---|---|---|
| **Média de satisfação** + faixa provável (`averageRating`, `starMeanCI`) | Média das notas 1–5, com o intervalo onde a média real provavelmente está | Dashboard (card); cabeçalho de Feedbacks › Recebidos ("Média") | Saber como está a avaliação geral | **Mantém** como card **Média**: `4,2 /5 ★ Boa · 128 avaliações`. Rótulo pela escala do formulário: 4,5–5,0 Ótima · 3,5–4,4 Boa · 2,5–3,4 Mediana · 1,5–2,4 Ruim · 1,0–1,4 Péssima. Sem avaliações: "Ainda sem avaliações". |
| **Feedbacks recebidos** (`totalFeedbacks`) | Quantos feedbacks existem no escopo | Dashboard (card, rótulo "Total acumulado no workspace"); Recebidos ("Total") | Dar contexto ao tamanho da amostra | **Sai como card.** O número de avaliações passa a aparecer no card da média. |
| **Feedbacks positivos** / **Feedbacks críticos** (`sentimentBreakdown.positive/negative`) | Contagem de notas 4–5 e de notas 1–2 | Dashboard (dois cards) | Ver quantos gostaram e quantos não | **Renomeia** para **Positivas (4–5★)** e **Críticas (1–2★)**, com contagem **e %** ("82 · 64% das avaliações"). |
| **Positivos / Neutros / Negativos** por nota (`sentimentBreakdown`) | Contagem de notas 4–5, 3 e 1–2 | Cabeçalho de Feedbacks › Recebidos | — usa as mesmas palavras do tom da IA | **Renomeia** para positivas / neutras / críticas, sempre indicando que são estrelas. |
| **Distribuição das avaliações** (`ratingDistribution`) | % de feedbacks em cada nota (1 a 5) | Dashboard (rótulo "nos últimos registros", mas é **todo** o escopo) | Ver se as notas estão concentradas ou divididas | **Muda de lugar:** sai do Dashboard para a página **"Todas as métricas de estrelas"**, com o rótulo corrigido e as **neutras (3★)**. |
| **Clientes satisfeitos** (CSAT, `csat`) | % de notas 4–5 | Dashboard (Satisfação e sentimento) | Responder "de cada 100, quantos ficaram satisfeitos?" | **Funde** no % do card de Positivas. |
| **Saldo de satisfação** (`netSatisfaction`) | % de notas 4–5 menos % de notas 1–2 | Dashboard (Satisfação e sentimento) | Ver o equilíbrio entre satisfeitos e insatisfeitos | **Sai do Dashboard:** é % positivas − % críticas, que os dois cards já mostram. |
| **Nota por pergunta** (`mean`, `ci`, `satisfiedPct`, `distribution`, `status`) | Média, % de satisfeitos e distribuição de cada pergunta e subpergunta, com faixa provável | Insights › Perguntas; Dashboard ("Perguntas com menor nota", as 3 piores, só a média) | Achar a pergunta que puxa a nota para baixo | **Muda de lugar:** seção **"Perguntas do formulário"** no Dashboard (perguntas atuais na ordem do formulário) e **uma página por pergunta** com suas subperguntas. Saem Insights › Perguntas e "Perguntas com menor nota". |

### Lente Comentários (o texto, lido pela IA)

Fonte: `GET /feedbacks/analysis` e `GET /feedbacks/insights/report`. **Só existem para feedbacks já analisados pela IA.**

| Métrica (nome na tela) | O que mede | Onde aparece hoje | Ajuda o gestor a… | Decisão (16/10/2026) |
|---|---|---|---|---|
| **Distribuição do tom** — "Distribuição de sentimentos", "Termômetro emocional", "Positivos/Neutros/Negativos" | Contagem e % de comentários positivos, neutros e negativos | Insights › Estatísticas; Insights › Emocional (**idêntico** ao de Estatísticas, sem a faixa); Feedbacks › Analisados › Todos | Saber se predominam elogios ou críticas no texto | **Funde** num bloco único, **"Tom dos comentários"**, que aparece **uma vez**: barra positivo/neutro/negativo com %, resumo em palavras e precisão. |
| **Saldo de sentimento** (`netSentimentScore`) | % de comentários positivos menos % de negativos | Dashboard; Relatório (define o "Clima emocional"); Estatísticas; Emocional | Resumir o tom geral num número | **Funde** no bloco "Tom dos comentários", como resumo (ex.: "+45 · Positivo"). |
| **Clima emocional** | Faixa do saldo de sentimento: Positivo, Neutro (±5) ou de Atenção | Relatório | Ler o saldo sem interpretar o número | **Funde** no resumo em palavras do bloco "Tom dos comentários". |
| **Categorias** (`topCategories`) | Temas mais citados nos comentários | Estatísticas; Analisados › Todos (top 3), Positivos e Negativos (top 5) | Saber sobre o que os clientes falam | **Fica como reserva:** só aparece quando ainda não há assuntos com 3 ou mais menções. |
| **Palavras-chave** (`topKeywords`) | Termos mais repetidos | Estatísticas; Analisados › Todos | Ver termos recorrentes | **Sai:** repete o que categorias e assuntos já mostram. |
| **Assuntos que mais impactam** (`aspectSentiments`) | Assuntos citados no texto com o saldo de sentimento de cada um, ordenados por impacto | Estatísticas | Priorizar o que mais incomoda ou agrada | **Mantém** como métrica principal de temas: diz do que falam e se falam bem ou mal. |
| **Momentos emocionais** | Grupos com até 5 exemplos: momentos que encantam, pontos de dor, neutros e divergências nota × texto | Insights › Emocional | Entender com exemplos reais o que desperta emoção | **Sai como bloco:** vira filtros da lista de comentários — **Positivos · Neutros · Negativos · Nota e texto não combinam**. A divergência era a única parte que não existia em outro lugar. |
| **Relatório de insights** (resumo e recomendações) | Texto da IA com pontos fortes, oportunidades e recomendações | Insights › Relatórios; Dashboard | Saber o que fazer a seguir | **Mantém** como "Resumo e recomendações da IA". O "clima" dele vai para o bloco do tom. |

### Operacionais e de confiabilidade

| Métrica (nome na tela) | O que mede | Onde aparece hoje | Decisão (16/10/2026) |
|---|---|---|---|
| **Aguardando análise** (`pendingCount`) | Feedbacks do escopo ainda não lidos pela IA | Dashboard (cabeçalho) | **Mantém** como aviso, não como métrica. |
| **Total analisado** (`totalAnalyzed`) | Feedbacks do escopo já lidos pela IA | Analisados › Todos; selos de confiança da lente Comentários | **Mantém** como contexto da lente Comentários. |
| **Selo de confiança** (`confidenceTier`) | Quão sólida é a amostra pelo tamanho `n` | Dashboard, Estatísticas, Emocional, Perguntas | **Funde** com a faixa provável no indicador **Precisão** (ver abaixo). |
| **Faixa provável** (intervalos de confiança) | Intervalo onde o valor real provavelmente está | Dashboard (média); Perguntas; Estatísticas (tom dos comentários) | **Funde** com o selo no indicador **Precisão** (ver abaixo). |

**Indicador de Precisão (decisão de 16/10/2026).** Faixa provável e selo de confiança respondem à mesma pergunta ("dá para confiar no número?") e passam a ser **um indicador só: Precisão alta, média ou baixa**.

- **Vocabulário próprio**, para não confundir com o rótulo da nota (ex.: "4,2 Boa").
- **Calculado pela largura da faixa provável**, que já considera a variação e a quantidade de respostas, com uma **quantidade mínima** como trava (poucas respostas iguais dariam uma faixa de largura zero). Limites usados, pela meia-largura da faixa (o ± dela):

    | Tipo de número | Alta | Média | Baixa |
    |---|---|---|---|
    | Médias (escala 1–5) | até ±0,25 | até ±0,5 | acima de ±0,5 |
    | Porcentagens (e frações, como o tom dos comentários) | até ±5 p.p. | até ±10 p.p. | acima de ±10 p.p. |

    Com **menos de 10 respostas**, a precisão é sempre **baixa** (mesmo corte do antigo selo "Dados insuficientes").
- **Métricas sem faixa** (saldos, contagens) herdam a precisão da base de onde vêm.
- **Representatividade** (se quem respondeu representa todos os clientes) não é medida por cálculo: aparece só como aviso no detalhe, nunca no rótulo.
- O rótulo abre um **painel na mesma tela** com a faixa em linguagem simples, o número de respostas, por que aquele nível, como melhorar e o aviso de representatividade.
- **Destaque só quando importa:** precisão alta fica discreta; média ou baixa aparecem em evidência.

Calculados, mas **sem uso em nenhuma tela hoje**: `sentiment_score` (intensidade por feedback), `confidence` da classificação, intervalos de Wilson de categorias e palavras-chave, e a média bayesiana.

---

## Organização decidida

Resultado da revisão com o dono do produto em 16/10/2026. O princípio: o sistema separa **o que o cliente marcou** (estrelas e perguntas) de **o que o cliente escreveu** (comentários lidos pela IA). No Dashboard fica o resumo; o detalhe fica em páginas próprias. **Implementado na Web** em cinco fases, uma PR por fase: fundações (rótulo da nota, Precisão e etiqueta de escopo), estrelas, perguntas, comentários e guia.

### Dashboard

```
Avaliação por estrelas                              📍 Avaliação geral da empresa
  Média: 4,2 /5 ★ Boa · 128 avaliações   Positivas (4–5★): 82 · 64%
  Críticas (1–2★): 10 · 8%                    Ver todas as métricas de estrelas →

Perguntas do formulário                             📍 Avaliação geral da empresa
  Pergunta 1 · "Como foi o atendimento?"  3,1 /5 Mediana · 64 respostas · 40% satisfeitos
                                          Ver todas as métricas desta pergunta →
  (até 3 perguntas, na ordem do formulário)

Análise dos comentários ✨IA                         📍 Avaliação geral da empresa
  Tom dos comentários: +45 · Positivo · 20 comentários analisados · Precisão
  Resumo e recomendações da IA       Ver a análise completa dos comentários →
```

- **Avaliação por estrelas.** O nome deixa claro que é só a nota de 1 a 5 ("feedback" sugeria tudo o que o cliente mandou). Os cards falam de **avaliações**. Saem do Dashboard o card "Feedbacks recebidos" e o bloco "Satisfação e sentimento".
- **Perguntas do formulário.**
  - Mostra só as perguntas **atuais**, na ordem do formulário, cada uma com nota, rótulo, respostas, % de satisfeitos e precisão.
  - **Tipo sem item escolhido:** a seção não lista perguntas (elas seriam de itens diferentes, sem identificação). Mostra "Cada produto tem as suas perguntas. Escolha um para vê-las", com os itens como links.
  - **Item sem perguntas:** "Este item não tem perguntas no formulário".
  - **Perguntas excluídas do formulário:** um link "Perguntas que saíram do formulário" no fim da seção.
- **Análise dos comentários ✨IA.** Novo nome da antiga seção "Insights": termo em português que diz de onde vêm os dados. Acompanham o nome o botão "Gerar Insights com IA", que vira **"Analisar comentários com IA"**, o "Relatório de Insights", que vira **"Resumo e recomendações da IA"**, os passos do guia e os títulos. No Dashboard, o bloco mostra o **tom dos comentários** e o **resumo da IA**; os assuntos ficam na Visão geral.

### Páginas de detalhe (dinâmicas, pelo escopo)

- **Todas as métricas de estrelas:** distribuição das avaliações (1 a 5★), com as neutras (3★), o movimento das avaliações no tempo, os dias e horários de pico e os clientes que voltam (veja **Métricas que não vêm só da nota**, abaixo).
- **Página de uma pergunta:** a pergunta escolhida e **cada subpergunta dela**, com nota, distribuição de péssimo a ótimo, % de satisfeitos e precisão. No fim, histórico recolhido (versões antigas do texto e subperguntas desativadas).

### Seção "Análise dos comentários" ✨IA: de 6 páginas para 2

Hoje: Relatórios, Emocional, Estatísticas e Feedbacks › Analisados (Todos, Positivos, Negativos). Passa a ser:

- **Visão geral** (`/user/insights/overview`): Tom dos comentários · Assuntos que mais impactam (categorias como reserva) · Resumo e recomendações da IA.
- **Comentários** (`/user/insights/comments`): a lista segue o escopo do cabeçalho (Feedbacks › Analisados o ignorava), com os filtros Todos · Positivos · Neutros · Negativos · Nota e texto não combinam. O filtro fica no endereço (`?filtro=`).

Os endereços antigos redirecionam: Relatórios, Emocional e Estatísticas levam à Visão geral; Feedbacks › Analisados (Todos, Positivos, Negativos) leva à lista, já com o filtro do tom.

### Guia do sistema

Os passos do guia acompanham a nova estrutura. Com a etapa 02 e as métricas novas (18/10/2026), são 15 passos, na ordem:

1. Dashboard;
2. **Escopo e período**;
3. **Avaliação por estrelas**;
4. **Movimento das avaliações**;
5. **Perguntas do formulário**, com o peso na nota e o "Melhore primeiro";
6. **Análise dos comentários** (o card do Dashboard);
7. **Visão geral da análise**;
8. **Comentários**;
9. **Comparar itens**;
10. **Todas as métricas de estrelas**;
11. Avaliação da empresa;
12. Catálogo;
13. Configuração de IA;
14. Perfil;
15. Dados da empresa.

Na conta sem feedbacks, a prévia das boas-vindas tem um card de exemplo para cada seção do Dashboard, para o guia ter onde parar. O card do Dashboard vem antes das páginas da análise, para o guia não pular de página no meio do Dashboard. O guia que passa por cada métrica do Dashboard fica para depois.

### O que sai

- Página **Insights › Perguntas** e o item do menu. O passo "Perguntas" do guia passa a apontar para as perguntas no Dashboard.
- **Palavras-chave**, "Perguntas com menor nota", o bloco "Satisfação e sentimento" e o card "Feedbacks recebidos".
- As páginas **Emocional** e **Estatísticas**, e o resumo de métricas de **Feedbacks › Analisados**, absorvidos pela nova estrutura.

### Configuração da coleta: escopo, perguntas e canais (17/10/2026)

A configuração separa três coisas que o nome "Feedback geral" misturava (e que parecia a lista de feedbacks recebidos):

| Camada | Pergunta que responde | Onde fica |
|---|---|---|
| **Escopo** | O que o cliente avalia? | A empresa como um todo (**Avaliação da empresa**) ou um item do **Catálogo** (produto, serviço, departamento) |
| **Perguntas** | O que se pergunta? | Seção **Perguntas** de cada escopo |
| **Canais de coleta** | Por onde a resposta chega? | Seção **Canais de coleta** de cada escopo: hoje **QR Code e link**; o **NFC** (etapa 06 do roadmap) entra como mais um card |

- A aba "Feedback geral" passou a se chamar **"Avaliação da empresa"**. O endereço continua `/user/edit/feedback-general`. No celular, o atalho se chama "Avaliação".
- A página do item do Catálogo segue o mesmo desenho: dados do item, **Perguntas** e **Canais de coleta**.
- Todas as respostas de um escopo entram nas mesmas métricas, seja qual for o canal. A comparação **por canal** ("o NFC trouxe mais respostas que o QR?") fica para depois, como filtro, junto com a etapa 02 (períodos). O canal não vira um escopo novo.

### Período e comparação (etapa 02, 17/10/2026)

As métricas deixam de mostrar sempre o histórico inteiro. O gestor escolhe um recorte de tempo e pode comparar o período com o anterior, ou dois itens entre si.

**Seletor de período.** Fica ao lado do escopo, na barra abaixo do cabeçalho. As opções são:

- Todo o período (padrão);
- Últimos 7 dias, Últimos 30 dias, Últimos 3 meses, Últimos 6 meses;
- Personalizado, com data inicial e final.

Como o período funciona:

- **Janelas móveis.** As janelas contam dias inteiros e incluem hoje: "Últimos 7 dias" é hoje e os 6 dias anteriores. No Personalizado, o dia final entra inteiro.
- **Fuso do gestor.** A Web resolve o período no fuso do navegador e envia ao gateway instantes absolutos (`start_date`/`end_date`, com o início incluído e o fim excluído).
- **Onde vale.** O período vale para o Dashboard, Todas as métricas de estrelas, as páginas de perguntas, o tom dos comentários e a lista de comentários.
- **Etiqueta de escopo.** A etiqueta passa a dizer o período ("Produto · Pizza · Últimos 30 dias"). Os textos de vazio e de precisão também ("no produto Pizza nos últimos 30 dias").

O que **não** segue o período:

- **Contagens e regras de toda a história.** O aviso "aguardando análise", os marcos de feedback e o mínimo de feedbacks para a IA continuam contando o histórico inteiro do escopo.
- **O resumo da IA.** Ele não é recortado por data. Com um período escolhido, aparece o aviso "O resumo considera todos os comentários analisados". O diagnóstico por período fica fora desta etapa.
- **A lista de Feedbacks recebidos.** Ela não tem período.

**Comparar com o período anterior.** Com um período escolhido, aparece o botão **Comparar com o período anterior**.

- **Período de referência.** O anterior tem o mesmo tamanho e vem logo antes. Por exemplo: "30 dias anteriores", "3 meses anteriores" ou, no Personalizado, as datas.
- **Onde aparecem as diferenças.** Cada métrica mostra a diferença com seta e cor: média, % positivas, % críticas (subir é piorar), nota de cada pergunta e tom dos comentários.
- **Diferença incerta.** Quando as margens de erro dos dois períodos se sobrepõem, a diferença aparece em cinza como **Diferença incerta**, porque pode ser só acaso. As margens são:
  - média e perguntas: o IC t que já vem do gateway;
  - positivas e críticas: Wilson;
  - tom: a margem do NSS, calculada pelas contagens de positivos, neutros e negativos.
- **Sem referência.** Se não há avaliações no período anterior, aparece **Sem dados no período anterior**.

**Comparar itens (A × B).** É uma página própria (`/user/compare`), no menu lateral e no link "Comparar dois itens" da Avaliação por estrelas.

- **Quais itens.** Compara dois itens do **mesmo tipo** (dois produtos, dois serviços ou dois departamentos), no mesmo período. "Geral" e "Todos os…" não entram, porque não são um item. Um tipo só aparece quando tem pelo menos 2 itens.
- **Quais métricas.** Mostra só as que os dois têm: nº de avaliações, média, % positivas, % críticas, tom e precisão da média. As perguntas ficam de fora, porque cada item tem as suas.
- **Quem está melhor.** Esta coluna diz o item e a diferença. Usa as mesmas margens da comparação com o período anterior, então também pode dizer **Diferença incerta**.

Ficam para depois: diagnóstico por período, comparar mais de 2 itens e o período na lista de Feedbacks recebidos.

### Métricas que não vêm só da nota (18/10/2026)

Até aqui, tudo o que não vinha da IA era **uma informação só, vista de vários jeitos**: a nota de 1 a 5 (estrelas) ou de Péssimo a Ótimo (perguntas). Média, positivas, críticas e satisfeitos saem da mesma distribuição de notas.

As quatro métricas abaixo usam dados que o sistema já guardava e não aproveitava:

- a data e a hora de cada avaliação;
- a nota de cada pergunta junto com as estrelas do mesmo feedback;
- o aparelho identificado pelo anti-spam.

Todas seguem o escopo e o período do cabeçalho, e cada uma tem a ajuda (?) em linguagem simples.

| Métrica | Pergunta que responde | Como é calculada | Onde aparece |
|---|---|---|---|
| **Movimento das avaliações** | Estou recebendo mais ou menos avaliações? A nota vem subindo ou caindo? | Quantidade e média por dia, semana ou mês, agrupadas no banco no fuso do gestor. Os intervalos sem avaliação contam como zero (`GET /feedbacks/timeline`) | Dashboard (compacta) e Todas as métricas de estrelas |
| **O que mais pesa na nota** | Melhorar qual ponto muda mais a nota geral? | Correlação de Spearman entre a nota da pergunta e as estrelas do mesmo feedback, com IC 95% (`ratingWeight` em `/feedbacks/questions`) | Selo em cada pergunta e "Melhore primeiro" nas Perguntas do formulário e na página da pergunta |
| **Dias e horários de pico** | Quando os clientes mais avaliam e em que horário a nota cai? | Quantidade e média por dia da semana × faixa de 6 horas (madrugada, manhã, tarde, noite), no fuso do gestor (`GET /feedbacks/heatmap`) | Todas as métricas de estrelas |
| **Clientes que voltam** | Os clientes voltam? Quem volta está mais satisfeito? | % das avaliações de quem já tinha avaliado a empresa, pelo `row_number()` por aparelho, e a média de quem volta × primeira vez, com IC (`GET /feedbacks/customers`) | Todas as métricas de estrelas |

Como cada métrica aparece e os cuidados de leitura:

- **Movimento das avaliações.**
  - **Gráfico:** barras com a quantidade e, embaixo, uma linha com a média, no mesmo eixo de tempo.
  - **Agrupamento:** por dia nos períodos de 7 e 30 dias, por semana nos de 3 e 6 meses. Sem período, por semana, ou por mês quando o histórico passa de 6 meses.
  - **Amostra pequena:** intervalos com menos de 5 avaliações aparecem com bolinha vazada, porque a média ali é pouco confiável.
- **O que mais pesa na nota.**
  - **Selos:** "Pesa muito na nota" (r ≥ 0,5), "Pesa na nota" (0,3 a 0,5) e "Pesa pouco na nota" (abaixo de 0,3).
  - **Amostra pequena:** com menos de 30 respostas, o selo diz "Poucas respostas para saber o peso".
  - **"Melhore primeiro":** aponta, entre as perguntas que pesam, a de menor nota, desde que ainda não seja Ótima.
  - **Limite:** mostra o que anda junto com a nota, não prova a causa.
- **Dias e horários de pico.**
  - **Mapa:** 7 dias × 4 faixas. A cor mostra a quantidade e o número, a média. Faixas com menos de 5 avaliações ficam em cinza.
  - **Por que faixas de 6 horas:** com pouco volume, a grade hora a hora ficaria vazia.
  - **Resumo:** diz onde há mais avaliações e onde está a pior média. A pior média só considera faixas com 10 ou mais avaliações.
- **Clientes que voltam.**
  - **Quem é o cliente:** o aparelho usado para avaliar, sem dados pessoais. O número é aproximado, porque a mesma pessoa em outro celular conta como outro cliente.
  - **Quando a avaliação conta como "de quem volta":** quando o mesmo aparelho já tinha avaliado a empresa antes, em qualquer escopo.
  - **Sem aparelho identificado:** essas avaliações ficam de fora.
  - **Comparação das notas:** usa a mesma regra de "Diferença incerta" da comparação de períodos.

Ficam de fora: peso das subperguntas, comparação por canal (etapa 06) e gênero (dado opcional e sensível pela LGPD). Detalhes da API em `docs/endpoints.md` do API Gateway.

---

## Problemas encontrados

Diagnóstico da revisão de 16/10/2026, base para a reorganização:

1. **Mesmas palavras, lentes diferentes.** "Positivos/Negativos" ora são notas (cards do Dashboard, cabeçalho de Recebidos), ora são o tom do texto pela IA (Analisados, Estatísticas). Na origem, o campo `sentimentBreakdown` do `/feedbacks/stats` é calculado **pelas estrelas**, apesar do nome (`getFeedbacksStatsController`).
2. **A mesma métrica repetida com nomes diferentes.** O tom da IA aparece como distribuição, termômetro, clima e saldo em quatro telas; Estatísticas e Emocional exibem o mesmo bloco.
3. **Redundância.** A contagem de "positivos" (notas 4–5) e o CSAT (% de notas 4–5) são a mesma informação; `averageRating` e `starMean` também.
4. **Rótulos imprecisos.** "Total acumulado no workspace" (é do escopo); "nos últimos registros" (é todo o escopo); "críticos" num card e "negativos" no resto.
5. **Sobreposição de menu.** Feedbacks › Analisados repete o resumo de categorias e tom que está em Insights › Estatísticas.
6. **Explicações incompletas.** O glossário da interface (`METRIC_EXPLANATIONS`, em `feedback-analytics-web/src/lib/constants/metricExplanations.ts`) cobre 10 termos, mas não média, total, distribuição por nota nem pendentes, e não diz a lente nem o escopo.
7. **Escopo invisível e "Geral" enganoso.** Ver [Escopos](#escopos).

Cada problema está endereçado em **Organização decidida** e no catálogo acima. Fica para depois a **visão total da empresa** e a renomeação do "Geral" (ver [Escopos](#escopos)).

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
- **Como se lê:** resultado em **[-100, 100]**. No bloco **"Tom dos comentários"**, o NSS aparece com um resumo em palavras: **Positivo**, **Neutro** ou **Atenção**, com uma **banda neutra de ±5** (ex.: "+45 · Positivo"). Esse resumo substitui o antigo "clima emocional" do relatório.
- **Como é calculada:** `(positivos − negativos) / total × 100`. Referência: Net Sentiment Score (Thematic).

### Distribuição de emoções

- **O que é:** a proporção de feedbacks **positivos / neutros / negativos** classificados pela IA.
- **Como se lê:** cada classe vem com seu **IC de Wilson** por fração (`sentimentCIs`, em [0, 1]) — a faixa provável daquela proporção.
- **Como é calculada:** contagem por classe sobre o total analisado; o IC de cada fração usa o intervalo de Wilson.

### sentiment_score graduado

- **O que é:** a **intensidade** do sentimento de cada texto, individualmente, além do rótulo categórico (positive/neutral/negative).
- **Como se lê:** número em **[-1, 1]** — quanto mais próximo de -1, mais negativo; de +1, mais positivo. Refina o sentimento categórico com a magnitude.
- **Como é calculada:** atribuído pela IA por feedback (coluna `sentiment_score` em `feedback_analysis`). Cada item também traz `confidence` em **[0, 1]**, indicando o grau de certeza da classificação.
- **Onde aparece:** em nenhuma tela hoje (revisão de 16/10/2026).

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

Na interface, as camadas deram lugar ao indicador **Precisão** (`PrecisionBadge`), que usa a largura da faixa provável e mantém o corte de 10 respostas (ver [Operacionais e de confiabilidade](#operacionais-e-de-confiabilidade)). O rótulo é clicável e abre uma explicação em linguagem simples. **"Amostra pequena"** significa, na prática, um `n` baixo (especialmente abaixo de 30): a métrica ainda é mostrada, mas a faixa provável fica larga e a leitura deve ser tratada como tendência, não como verdade fechada.

### Intervalo de Wilson (proporções)

Usado para **porcentagens e proporções** (CSAT, distribuição de sentimento, categorias, keywords, aspectos). É preciso mesmo com poucos dados e perto dos extremos (0% / 100%), onde o método clássico (Wald) falha. Calculado a 95%; pode ser apresentado em fração [0, 1] ou em porcentagem. Referência: Brown, Cai & DasGupta (2001).

### Intervalo de confiança t da média

Usado para **médias de nota** (média de estrelas e média por pergunta). É a "faixa provável" da média: `mean ± t · erro padrão`, a 95%. Para amostras pequenas usa o valor crítico de `t`; o resultado é clampado em [1, 5].

### Média Bayesiana (encolhimento)

- **O que é:** um ajuste estilo IMDb que **puxa a média de um item com poucos votos em direção à média global**, evitando que um item com 2 avaliações pareça melhor (ou pior) do que um com 200.
- **Como é calculada:** `WR = (v·R + m·C) / (v + m)`, onde `v` = nº de votos do item, `R` = média do item, `C` = média global (o "prior") e `m` = força do prior (quantos "votos" equivalentes). Disponível como função pura no módulo de estatística, mas **não é usada por nenhum endpoint nem tela** hoje (revisão de 16/10/2026).

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

Na interface, os itens marcados aparecem na lista de **Comentários**, no filtro **"Nota e texto não combinam"**, e cada um leva o selo com o mesmo nome.

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
