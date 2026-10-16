# UC-09: Visualização do Dashboard

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Ter uma visão geral e atualizada da situação dos feedbacks da empresa |
| **Gatilho** | Gestor faz login ou navega para o dashboard |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa o dashboard.
2. O dashboard segue o **escopo selecionado** no topo (Empresa, Produto, Serviço ou Departamento, com o item escolhido quando aplicável); o sistema carrega em paralelo as estatísticas e as métricas por pergunta **dentro desse escopo**.
3. Na **saudação** ("Olá, ..."), o sistema exibe a contagem de feedbacks aguardando análise no escopo selecionado (`pendingCount`) — por exemplo, "3 feedbacks aguardando análise neste escopo" ou "Tudo em dia — nenhum feedback aguardando análise neste escopo". Sem nenhum feedback ainda, convida o gestor a compartilhar o formulário pelo QR Code.
4. O dashboard exibe três seções, cada uma com uma **etiqueta de escopo** clicável no topo (ex.: "QR geral da empresa", "Produto · Pizza") que abre o seletor de escopo:
   - **Avaliação por estrelas:** 3 cards — **Média** (`4,2 /5 ★ Boa · 128 avaliações`, com o indicador de **Precisão**), **Positivas (4–5★)** e **Críticas (1–2★)**, com contagem e %. O link **"Ver todas as métricas de estrelas"** abre `/user/ratings`, com a distribuição por nota e as neutras (3★).
   - **Perguntas do formulário:** as perguntas **atuais**, na ordem do formulário (até 3), cada uma com nota /5, rótulo, respostas, % de satisfeitos e Precisão, e o link **"Ver todas as métricas desta pergunta"** (`/user/questions/:questionId`). A pior pode ter destaque. Com um tipo escolhido sem item, a seção pede para escolher um item. No fim, o link **"Perguntas que saíram do formulário"** aparece quando houver alguma.
   - **Análise dos comentários ✨IA:** o bloco **Tom dos comentários** (barra positivo/neutro/negativo, saldo em palavras e Precisão) e o **Resumo e recomendações da IA**, com o link **"Ver a análise completa dos comentários"** (`/user/insights/overview`).
   - Um link **"Ver feedbacks"** na saudação que leva à listagem completa (`/user/feedbacks/all`).
5. Um **cartão de compartilhamento do QR** (ShareQrCard) na saudação aponta para o formulário/QR do escopo selecionado (QR geral da empresa no escopo Empresa; QR do item quando há item escolhido; lista do catálogo do tipo quando o tipo está selecionado sem item).
6. Ao acessar o dashboard logo após o login, o sistema exibe um toast de boas-vindas.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Escopo sem nenhum feedback coletado ainda | A saudação convida a "Compartilhe o formulário pelo QR Code para começar a coletar feedbacks". "Avaliação por estrelas" mostra "Ainda sem avaliações {no escopo}" em vez de "0,0". Cada pergunta do formulário mostra "Ainda sem respostas {no escopo}". O tom dos comentários mostra "Ainda sem comentários analisados pela IA {no escopo}" e o resumo da IA mostra "Ainda não há resumo da IA para este escopo". |
| Escopo de item sem perguntas no formulário | "Perguntas do formulário" mostra "Este {produto, serviço ou departamento} não tem perguntas no formulário" (no Geral: "O formulário geral não tem perguntas ativas"). |
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
- **[CT-UC09-04]** ✅ *Coberto E2E* - Análise dos comentários: o dashboard exibe o tom dos comentários e o resumo e recomendações da IA. (Spec: `[CT-UC09-04] Dashboard exibe seção de relatório de insights`.)
- **[CT-UC09-05]** ✅ *Coberto E2E* - Navegação: clicar em "Ver feedbacks" navega para a listagem completa (`/user/feedbacks/all`). (Spec: `[CT-UC09-05] Clique em "Ver feedbacks" navega para listagem completa`.)
- **[CT-UC09-06]** 📝 *Planejado / não implementado* - Caminho feliz — toast de login: acessar o dashboard com `?login=success` na URL deve exibir o toast de boas-vindas e remover o parâmetro da URL.
- **[CT-UC09-07]** ❌ *Cenário não coberto* - Exceção — erro de carregamento: simular falha na API de estatísticas deve exibir a mensagem de erro inline no topo, sem redirecionar.
- **[CT-UC09-08]** 📝 *Planejado / não implementado* - Exceção — sessão expirada: acessar o dashboard com sessão inválida deve redirecionar para `/login`. (Coberto de forma análoga em UC-12 via rota protegida.)
