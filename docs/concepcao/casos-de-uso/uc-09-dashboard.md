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
4. O dashboard exibe:
   - **4 cards de métricas (nesta ordem):** média de satisfação (em estrelas), feedbacks recebidos (total), feedbacks positivos (notas 4★ e 5★) e feedbacks críticos (notas 1★ e 2★).
   - **Gráfico de distribuição de avaliações** por nota.
   - **Satisfação e sentimento:** indicadores que combinam satisfação (notas) e sentimento (texto, via IA) — Saldo de satisfação, Clientes satisfeitos (CSAT) e Saldo de sentimento da IA, acompanhados de um **selo de confiança** (baseado no volume de respostas do escopo).
   - **Perguntas com menor nota:** as 3 perguntas com menor nota média no escopo (apenas perguntas atuais), cada uma com a nota /5 e o selo de confiança, e um link para a aba **Perguntas** (`/user/insights/questions`). A seção fica **oculta** quando não há respostas de perguntas no escopo.
   - **Relatório de Insights:** resumo e recomendações da IA para o escopo selecionado, com link para o relatório completo (`/user/insights/reports`).
   - Um link **"Ver feedbacks"** na saudação que leva à listagem completa (`/user/feedbacks/all`).
5. Um **cartão de compartilhamento do QR** (ShareQrCard) na saudação aponta para o formulário/QR do escopo selecionado (QR geral da empresa no escopo Empresa; QR do item quando há item escolhido; lista do catálogo do tipo quando o tipo está selecionado sem item).
6. Ao acessar o dashboard logo após o login, o sistema exibe um toast de boas-vindas.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Escopo sem nenhum feedback coletado ainda | Exibe o dashboard com todos os contadores zerados; a saudação convida a "Compartilhe o formulário pelo QR Code para começar a coletar feedbacks", a seção "Satisfação e sentimento" mostra "Sem dados para o escopo selecionado" e a seção "Perguntas com menor nota" fica oculta. |
| Erro ao carregar estatísticas ou lista de feedbacks | Exibe mensagem de erro inline no topo do dashboard — a página permanece acessível, não há redirecionamento |
| Sessão expirada durante a navegação | Redireciona automaticamente para `/login` |

---

## Base para Teste E2E

> Os testes E2E já estão implementados no Playwright ([uc-09-dashboard.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-09-dashboard.spec.ts)).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC09-01]** ✅ *Coberto E2E* - Caminho feliz: gestor autenticado acessa o dashboard e visualiza a saudação personalizada ("Olá, ..."). (Spec: `[CT-UC09-01] Dashboard carrega e exibe saudação personalizada`.)
- **[CT-UC09-02]** ✅ *Coberto E2E* - Métrica de total: o dashboard exibe a métrica de total de feedbacks. (Spec: `[CT-UC09-02] Dashboard exibe métrica de total de feedbacks`.)
- **[CT-UC09-03]** ✅ *Coberto E2E* - Distribuição de sentimentos: o dashboard exibe a distribuição de sentimentos (positivo/neutro/negativo). (Spec: `[CT-UC09-03] Dashboard exibe distribuição de sentimentos`.)
- **[CT-UC09-04]** ✅ *Coberto E2E* - Relatório de insights: o dashboard exibe a seção de relatório de insights. (Spec: `[CT-UC09-04] Dashboard exibe seção de relatório de insights`.)
- **[CT-UC09-05]** ✅ *Coberto E2E* - Navegação: clicar em "Ver feedbacks" navega para a listagem completa (`/user/feedbacks/all`). (Spec: `[CT-UC09-05] Clique em "Ver feedbacks" navega para listagem completa`.)
- **[CT-UC09-06]** 📝 *Planejado / não implementado* - Caminho feliz — toast de login: acessar o dashboard com `?login=success` na URL deve exibir o toast de boas-vindas e remover o parâmetro da URL.
- **[CT-UC09-07]** ❌ *Cenário não coberto* - Exceção — erro de carregamento: simular falha na API de estatísticas deve exibir a mensagem de erro inline no topo, sem redirecionar.
- **[CT-UC09-08]** 📝 *Planejado / não implementado* - Exceção — sessão expirada: acessar o dashboard com sessão inválida deve redirecionar para `/login`. (Coberto de forma análoga em UC-12 via rota protegida.)
