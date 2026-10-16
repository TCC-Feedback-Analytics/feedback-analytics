# UC-11: Análise dos comentários com IA

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Processar os comentários dos feedbacks com IA e ver o tom, os assuntos que mais impactam, o resumo com recomendações e a lista de comentários analisados |
| **Gatilho** | Gestor acessa a seção "Análise dos comentários ✨IA" (antigo painel de insights) |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a **Visão geral** da Análise dos comentários (`/user/insights/overview`). O endereço `/user/insights` e os antigos (Relatórios, Emocional, Estatísticas) levam para ela.
2. O sistema carrega a análise e o resumo existentes (se houver) para o **escopo selecionado no cabeçalho**: Geral (só o QR geral da empresa), Produto, Serviço ou Departamento. Com um tipo escolhido, o seletor já escolhe o primeiro item.
3. O gestor clica em **"Analisar comentários com IA"**, na barra abaixo do cabeçalho. A janela mostra as duas etapas:
   - **1. Analisar novos feedbacks** — a IA lê os feedbacks ainda não analisados e classifica o tom (positivo, neutro, negativo), as categorias e os assuntos.
   - **2. Escrever o resumo e as recomendações** — a IA usa os feedbacks analisados para escrever o resumo estratégico e as recomendações.

    O botão principal, **"Processar e analisar comentários com IA"**, roda as duas etapas num único job. **"Apenas Analisar"** e **"Apenas gerar o resumo"** rodam uma etapa só. O processamento segue em segundo plano e o gestor pode fechar a janela.
4. Ao concluir, a Visão geral e o Dashboard são atualizados automaticamente.
5. Na **Visão geral**, o gestor vê:
   - **Tom dos comentários:** barra positivo/neutro/negativo com % e contagem, o **Saldo de sentimento (NSS)** em número e em palavras — `Positivo` acima de +5, `Atenção` abaixo de −5 e `Neutro` na banda de ±5 — e o indicador de **Precisão**.
   - **Assuntos que mais impactam:** aspectos (ABSA) com 3 ou mais menções, ordenados por impacto, cada um com seu saldo. Sem nenhum assunto ainda, aparecem as **categorias** mais citadas como reserva.
   - **Resumo e recomendações da IA:** o texto estratégico e a lista de ações sugeridas.
6. Na aba **Comentários** (`/user/insights/comments`), o gestor vê a lista dos comentários analisados no escopo, cada um com a nota em estrelas, o tom lido pela IA e as categorias. Os filtros **Todos · Positivos · Neutros · Negativos · Nota e texto não combinam** ficam no endereço (`?filtro=`). Os antigos endereços de Feedbacks › Analisados levam para esta lista, já filtrada.

> **Pré-condição para análise:** os três campos de contexto devem estar preenchidos em UC-08 — Objetivo da Empresa, Objetivo Analítico e Resumo do Negócio. Se algum estiver em branco, os botões ficam desabilitados e o sistema exibe mensagem orientando o gestor a completar as configurações.

> As métricas por **pergunta do formulário** não dependem da IA e saíram desta seção: ficam no Dashboard e na página de cada pergunta (UC-09).

---

## Confiança dos números e ajuda contextual

- **Precisão:** o tom dos comentários traz um indicador **Precisão alta, média ou baixa**, calculado pela largura da faixa provável do % de positivos; com menos de 10 comentários analisados é sempre baixa. O rótulo é clicável e abre um painel que explica a faixa em linguagem simples, o número de comentários, o porquê do nível e como melhorar.
- **Etiqueta de escopo:** cada seção diz de qual escopo está falando (ex.: "QR geral da empresa", "Produto · Pizza"); clicar nela abre o seletor.
- **Ajuda contextual:** ícones de ajuda (`?`) espalhados pelas telas explicam cada métrica em linguagem acessível ao passar/clicar, evitando que o gestor precise sair da página para entender um número.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Contexto de negócio incompleto (qualquer um dos 3 campos em branco) | Botões de análise ficam desabilitados; mensagem com link direto para a tela de configuração de coleta |
| Escopo não-Empresa selecionado sem escolher item de catálogo | Botões ficam desabilitados até o item ser selecionado |
| Menos de 10 feedbacks disponíveis para análise | Retorna mensagem "É necessário no mínimo 10 feedbacks" — a ação é bloqueada |
| Erro ao carregar o resumo existente | Exibe popup de erro dismissível no canto da tela — o resto da página permanece acessível |
| Erro ao analisar ou gerar o resumo | A janela mostra "Processamento interrompido" com o motivo — o resumo anterior (se existir) permanece visível |
| Escopo sem comentários analisados | O tom mostra "Ainda sem comentários analisados pela IA {no escopo}"; a lista de Comentários mostra o mesmo aviso |
| Filtro da lista sem nenhum comentário | A lista mostra "Nenhum comentário neste filtro {no escopo}" |
| Escopo sem resumo da IA | Mostra "Ainda não há resumo da IA para este escopo", orientando a usar "Analisar comentários com IA" |

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela continha dois smokes de carregamento da página de relatório e um teste do botão de regenerar (condicional, com `test.skip()` quando o botão não estava visível e com a chamada à API de IA mockada para não consumir créditos). Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC11-01]** ✅ *Coberto E2E (smoke)* - Carregamento da Visão geral: a página `/user/insights/overview` (antes `/user/insights/reports`) carrega exibindo o tom, os assuntos e o resumo da IA, ou os estados vazios. (Spec: `[CT-UC11-01] Página de relatório de insights carrega com sumário ou estado vazio`.) **Não** dispara a análise.
- **[CT-UC11-02]** ✅ *Coberto E2E (smoke)* - Tom e assuntos: a Visão geral exibe o tom dos comentários e os assuntos que mais impactam, ou o estado vazio (as palavras-chave saíram das telas em 16/10/2026). (Spec: `[CT-UC11-02] Página de insights exibe análise de sentimentos e keywords`.)
- **[CT-UC11-05]** ✅ *Coberto E2E (skip condicional)* - Gerar o resumo de novo: clicar em "Apenas gerar o resumo" (antes "regenerar insights") deve solicitar nova análise (chamada de IA mockada) e exibir feedback de processamento. Contém `test.skip()` quando o botão não está visível. (Spec: `[CT-UC11-05] Botão de regenerar insights solicita nova análise`.)
- **[CT-UC11-03]** 📝 *Planejado / não implementado* - Caminho feliz — analisar feedbacks: gestor com contexto preenchido e mínimo de 10 feedbacks clica em "Analisar comentários com IA" e em "Apenas Analisar" — deve processar e atualizar o tom dos comentários automaticamente.
- **[CT-UC11-04]** 📝 *Planejado / não implementado* - Caminho feliz — gerar o resumo: após a análise, clicar em "Apenas gerar o resumo" deve atualizar o "Resumo e recomendações da IA".
- **[CT-UC11-06]** 📝 *Planejado / não implementado* - Caminho feliz — escopo por produto: selecionar escopo "Produto" e um item de catálogo, gerar a análise e confirmar que o tom, os assuntos e o resumo refletem aquele item (a etiqueta de escopo mostra "Produto · {item}").
- **[CT-UC11-07]** 🔵 *Unidade já atende* - Caminho feliz — lista e filtros: na aba "Comentários", escolher um filtro (ex.: "Nota e texto não combinam") deve mostrar só os comentários daquele filtro e guardar a escolha em `?filtro=`; abrir um endereço antigo de Feedbacks › Analisados deve cair na lista já filtrada.
- **[CT-UC11-08]** 📝 *Planejado / não implementado* - Exceção — contexto incompleto: acessar a Análise dos comentários sem preencher todos os campos de contexto deve exibir os botões desabilitados e a mensagem de bloqueio com link para configuração.
- **[CT-UC11-09]** 📝 *Planejado / não implementado* - Exceção — item não selecionado: selecionar escopo "Produto" sem escolher item deve manter os botões desabilitados.
- **[CT-UC11-10]** 📝 *Planejado / não implementado* - Exceção — volume insuficiente: tentar analisar com menos de 10 feedbacks deve retornar a mensagem "É necessário no mínimo 10 feedbacks".
