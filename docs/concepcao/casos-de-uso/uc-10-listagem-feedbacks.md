# UC-10: Listagem e Filtragem de Feedbacks

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Navegar pelo histórico de feedbacks, aplicar filtros e visualizar os detalhes de cada avaliação |
| **Gatilho** | Gestor acessa "Feedbacks" → "Recebidos" no menu ou o link "Ver feedbacks" do dashboard |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a listagem de feedbacks (`/user/feedbacks/all`).
2. O sistema carrega em paralelo os feedbacks paginados (mais recentes primeiro) e as estatísticas gerais (exibidas no cabeçalho da página).
3. O gestor aplica um ou mais filtros opcionais em "Filtrar feedbacks". Os filtros ficam na URL (`page`, `limit`, `rating`, `search`, `item`):
   - **Busca por mensagem** — texto livre no comentário, com debounce de 450ms.
   - **Escopo** — lista com pesquisa ("Escopo: Geral") para escolher um item de produto, serviço ou departamento; a lista atualiza assim que o item é escolhido.
   - **Nota** — seleciona uma nota de 1 a 5 estrelas ("Todos os ratings" limpa).
   - **Itens por página** — seleciona entre 5, 10, 20 ou 50 itens (padrão: 10).
4. A lista é atualizada com os feedbacks que correspondem aos filtros aplicados. Cada card mostra a nota, o comentário (ou "Sem comentário"), as respostas, o canal, a categoria, o item e o cliente, e os feedbacks do "Testar o formulário" trazem a marca **"Teste"**. A navegação entre páginas é feita pela paginação na base da lista.
5. O gestor clica em um feedback para abrir o modal "Detalhes do Feedback", que exibe:
   - **Cabeçalho:** nota, data de criação e data de atualização (quando disponível).
   - **Mensagem completa** do cliente (sem truncamento), ou "Sem comentário". Com pergunta própria no escopo, a pergunta que o cliente viu aparece acima do comentário (também no card da lista). Feedback de teste traz o aviso de que foi enviado pelo "Testar o formulário" e não entra nas métricas nem na análise da IA.
   - **Ponto de Coleta:** canal (QR Code, link, etiqueta NFC ou teste), tipo, identificador, categoria (Empresa/Produto/Serviço/Departamento) e nome do item.
   - **Perguntas Dinâmicas:** até 3 respostas com o texto da pergunta e o label da resposta.
   - **Dispositivo:** total de feedbacks enviados pelo dispositivo e status de bloqueio ("Bloqueado"). IP, navegador e fingerprint ficam só no servidor (LGPD).
   - **Cliente:** nome, e-mail e gênero (quando o cliente forneceu dados pessoais).
6. O gestor fecha o modal e continua navegando pela lista.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Nenhum feedback encontrado com os filtros aplicados | Exibe "Nenhum feedback encontrado" com "Tente ajustar os filtros de busca" |
| Empresa sem nenhum feedback ainda | Exibe "Nenhum feedback encontrado" com "Ainda não há feedbacks registrados" |
| Erro no carregamento da lista | Substitui a página por uma mensagem de erro centralizada — sem botão de tentar novamente |

> **Filtro por categoria.** A tela não tem mais o controle de categoria (Empresa/Produto/Serviço/Departamento). O parâmetro `category` ainda é aplicado quando vem na URL, e o gateway continua aceitando-o.

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela cobria apenas um **smoke test de carregamento de página** (verificava que a página `/user/feedbacks/all` carregava a lista de feedbacks ou exibia o estado vazio), e os fluxos de **ação** (filtros, busca, paginação, modal de detalhes) nunca tiveram E2E. Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC10-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a listagem carrega os feedbacks paginados ou exibe o estado vazio. (Spec: `[CT-UC10-01] Listagem carrega feedbacks ou exibe estado vazio`.) **Não** cobre abrir o modal de detalhes nem aplicar filtros.
- **[CT-UC10-02]** 📝 *Planejado / não implementado* - Caminho feliz — modal de detalhes: clicar em um feedback deve abrir o modal com todas as seções (ponto de coleta, perguntas, dispositivo, cliente).
- **[CT-UC10-03]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por nota: selecionar nota 5 deve exibir apenas feedbacks com aquela avaliação.
- **[CT-UC10-04]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por categoria: com `?category=PRODUCT` na URL, a lista deve exibir apenas feedbacks de pontos de coleta do tipo produto (a tela não tem mais o controle de categoria).
- **[CT-UC10-05]** 📝 *Planejado / não implementado* - Caminho feliz — busca textual: digitar um termo deve filtrar feedbacks que contenham aquele texto na mensagem (com debounce de ~450ms antes da requisição).
- **[CT-UC10-06]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por escopo: escolher um item na lista "Escopo" deve filtrar feedbacks daquele produto/serviço/departamento.
- **[CT-UC10-07]** 📝 *Planejado / não implementado* - Caminho feliz — paginação: mudar de página deve carregar o próximo conjunto de feedbacks mantendo os filtros ativos.
- **[CT-UC10-08]** 📝 *Planejado / não implementado* - Exceção — filtro sem resultado: aplicar filtro que não retorna feedbacks deve exibir o empty state de "ajuste os filtros".
- **[CT-UC10-09]** 📝 *Planejado / não implementado* - Exceção — sem feedbacks: empresa sem histórico deve exibir o empty state de "nenhum feedback recebido" (o smoke CT-UC10-01 já aceita este estado como válido).
