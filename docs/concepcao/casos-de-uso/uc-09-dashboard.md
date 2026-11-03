# UC-09: Visualização do Dashboard

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Ter uma visão geral e atualizada da situação dos feedbacks da empresa |
| **Gatilho** | Gestor faz login ou navega para o dashboard |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa o dashboard ("Visão geral", `/user/dashboard`).
2. O dashboard segue o **escopo** e o **período** escolhidos na barra de controles abaixo do cabeçalho: escopo Empresa, Produto, Serviço ou Departamento (com o item escolhido quando aplicável) e período (todo o período, 7 ou 30 dias, 3 ou 6 meses ou personalizado), com a comparação com o período anterior. O sistema carrega em paralelo as estatísticas e as métricas por pergunta **dentro desse recorte**. Feedbacks de teste (`canal=teste`) não entram nas métricas.
3. Na **saudação** ("Olá, ..."), o sistema exibe a contagem de comentários aguardando análise da IA no escopo selecionado (`pendingCount`) — por exemplo, "3 comentários aguardando análise da IA neste escopo" ou "Tudo em dia — nenhum comentário aguardando análise neste escopo". Sem nenhum feedback no escopo, convida o gestor a compartilhar o formulário pelo QR Code. O link **"Ver feedbacks"** leva à listagem completa (`/user/feedbacks/all`).
4. Um **cartão de compartilhamento do QR** (ShareQrCard) na saudação aponta para a tela de canais do escopo selecionado (a Avaliação da empresa no escopo Geral; a tela do item quando há item escolhido; a lista do catálogo do tipo quando o tipo está selecionado sem item).
5. O dashboard exibe as seções abaixo, cada uma com uma **etiqueta de escopo** clicável (ex.: "Avaliação geral da empresa", "Produto · Pizza") que abre o seletor de escopo:
   - **Avaliação por estrelas:** cards de **Média** (`4,2 /5 ★ Boa · 128 avaliações`, com o indicador de **Precisão**), **Positivas (4–5★)** e **Críticas (1–2★)**, com contagem e %. O link **"Ver todas as métricas de estrelas"** abre `/user/ratings`, com a distribuição por nota, as neutras (3★), o movimento, os dias e horários de pico e os clientes que voltam. Com itens comparáveis no catálogo, aparece também **"Comparar dois itens"** (`/user/compare`).
   - **Por onde chegaram:** quantas avaliações e a média de estrelas por canal (QR Code, link compartilhado e etiqueta NFC). As avaliações sem marca de canal (anteriores à marcação ou de QR Codes impressos antes dela) ficam numa linha à parte.
   - **Movimento das avaliações:** quantas avaliações chegaram e a média ao longo do tempo.
   - **Perguntas do formulário:** as perguntas **atuais**, na ordem do formulário (até 3), cada uma com nota /5, rótulo, respostas, % de satisfeitos e Precisão, e o link **"Ver todas as métricas desta pergunta"** (`/user/questions/:questionId`). Com um tipo escolhido sem item, a seção pede para escolher um item. No fim, o link **"Perguntas que saíram do formulário"** aparece quando houver alguma.
   - **Análise dos comentários ✨IA:** quem escreve comentário (o comentário é opcional), o bloco **Tom dos comentários** (barra positivo/neutro/negativo, saldo em palavras e Precisão) e o **Resumo dos comentários e recomendações**, com o link **"Ver a análise completa dos comentários"** (`/user/insights/overview`).
   - **Diagnóstico do escopo ✨IA:** a IA junta estrelas, perguntas e comentários do escopo no período, compara com o período anterior e diz o que fazer. O gestor clica em "Gerar diagnóstico" (ou "Atualizar diagnóstico", "Gerar para o período selecionado", "Gerar de novo"), e o job roda em segundo plano. O link **"Ver o histórico de diagnósticos"** abre `/user/diagnosis`, também no menu ("Diagnósticos ✨"). Com 10 ou mais avaliações no período, a seção abre o dashboard; com menos, fica no fim.
6. Ao acessar o dashboard logo após o login (`?login=success`), o sistema exibe o toast "Login realizado com sucesso." e tira o parâmetro da URL.

> **Conta nova.** Enquanto falta algum passo, os **"Primeiros passos"** aparecem no topo: "Ativar QR Code" (o QR geral da Avaliação da empresa) e "Testar o formulário (opcional)", cujo teste não entra nas métricas. Sem nenhum feedback na conta, o dashboard mostra as boas-vindas e a prévia do formulário no lugar das seções. O guia do sistema não abre sozinho: o dashboard convida o gestor, que pode começar ou adiar.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Escopo sem nenhum feedback coletado ainda | A saudação convida a "Compartilhe o formulário pelo QR Code para começar a coletar feedbacks". "Avaliação por estrelas" mostra "Ainda sem avaliações {no escopo}" em vez de "0,0". Cada pergunta do formulário mostra "Ainda sem respostas {no escopo}". O tom dos comentários mostra "Ainda sem comentários analisados pela IA {no escopo}" e o resumo mostra "Ainda não há resumo dos comentários para este escopo". "Por onde chegaram" não aparece. |
| Escopo de item sem perguntas no formulário | "Perguntas do formulário" mostra "Este {produto, serviço ou departamento} não tem perguntas no formulário" (no Geral: "O formulário geral não tem perguntas ativas"). |
| Campo de comentário oculto no escopo | O tom dos comentários avisa que o campo está oculto e que não há comentários para a IA ler |
| IA não configurada ou contexto da empresa incompleto | O diagnóstico mostra "Configure a IA para receber o diagnóstico." com o link "Configurar a IA", ou "A IA precisa conhecer a empresa para recomendar." com o link "Preencher os dados da empresa" |
| Falha ao gerar o diagnóstico | Mostra "Não foi possível gerar o diagnóstico" com o motivo e, quando o erro pede, o atalho para a Configuração de IA |
| Erro ao carregar estatísticas ou lista de feedbacks | Exibe mensagem de erro inline no topo do dashboard — a página permanece acessível, não há redirecionamento |
| Sessão expirada durante a navegação | Redireciona automaticamente para `/login` |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC09-01]** ✅ *Coberto E2E* - Caminho feliz: gestor autenticado acessa o dashboard e visualiza a saudação personalizada ("Olá, ..."). (Spec: `[CT-UC09-01] Dashboard carrega e exibe saudação personalizada`.)
- **[CT-UC09-02]** ✅ *Coberto E2E* - Avaliação por estrelas: o dashboard exibe a média com o número de avaliações (o card de total saiu na reorganização de 16/10/2026). (Spec: `[CT-UC09-02] Dashboard exibe métrica de total de feedbacks`.)
- **[CT-UC09-03]** ✅ *Coberto E2E* - Positivas e críticas: o dashboard exibe os cards Positivas (4–5★) e Críticas (1–2★) com contagem e %. (Spec: `[CT-UC09-03] Dashboard exibe distribuição de sentimentos`.)
- **[CT-UC09-04]** ✅ *Coberto E2E* - Análise dos comentários: o dashboard exibe o tom dos comentários e o resumo dos comentários e recomendações. (Spec: `[CT-UC09-04] Dashboard exibe seção de relatório de insights`.)
- **[CT-UC09-05]** ✅ *Coberto E2E* - Navegação: clicar em "Ver feedbacks" navega para a listagem completa (`/user/feedbacks/all`). (Spec: `[CT-UC09-05] Clique em "Ver feedbacks" navega para listagem completa`.)
- **[CT-UC09-06]** 📝 *Planejado / não implementado* - Caminho feliz — toast de login: acessar o dashboard com `?login=success` na URL deve exibir o toast "Login realizado com sucesso." e remover o parâmetro da URL.
- **[CT-UC09-07]** ❌ *Cenário não coberto* - Exceção — erro de carregamento: simular falha na API de estatísticas deve exibir a mensagem de erro inline no topo, sem redirecionar.
- **[CT-UC09-08]** 📝 *Planejado / não implementado* - Exceção — sessão expirada: acessar o dashboard com sessão inválida deve redirecionar para `/login`. (Coberto de forma análoga em UC-12 via rota protegida.)
