# UC-10: Listagem e Filtragem de Feedbacks

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Navegar pelo histórico de feedbacks, aplicar filtros e visualizar os detalhes de cada avaliação |
| **Gatilho** | Gestor acessa a seção de feedbacks no dashboard |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a listagem de feedbacks.
2. O sistema carrega em paralelo os feedbacks paginados e as estatísticas gerais (exibidas no cabeçalho da página).
3. O gestor aplica um ou mais filtros opcionais:
   - **Busca por mensagem** — texto livre com debounce de 450ms.
   - **Nota** — seleciona uma nota de 1 a 5 estrelas.
   - **Categoria** — filtra por tipo de ponto de coleta: Empresa, Produto, Serviço ou Departamento.
   - **Item de catálogo** — texto livre para buscar por nome do produto, serviço ou departamento; também com debounce de 450ms.
   - **Itens por página** — seleciona entre 5, 10, 20 ou 50 itens (padrão: 10).
4. A lista é atualizada com os feedbacks que correspondem aos filtros aplicados. A navegação entre páginas é feita pela paginação na base da lista.
5. O gestor clica em um feedback para abrir o modal de detalhes, que exibe:
   - **Cabeçalho:** nota, data de criação e data de atualização (quando disponível).
   - **Mensagem completa** do cliente (sem truncamento).
   - **Ponto de Coleta:** canal, tipo, identificador, categoria (Empresa/Produto/Serviço/Departamento) e nome do item.
   - **Perguntas Dinâmicas:** até 3 respostas com o texto da pergunta e o label da resposta.
   - **Dispositivo:** fingerprint, total de feedbacks enviados pelo dispositivo, IP, user agent e status de bloqueio.
   - **Cliente:** nome, e-mail e gênero (quando o cliente forneceu dados pessoais).
6. O gestor fecha o modal e continua navegando pela lista.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Nenhum feedback encontrado com os filtros aplicados | Exibe empty state com mensagem de ajuste de filtros |
| Empresa sem nenhum feedback ainda | Exibe empty state com mensagem indicando que nenhum feedback foi recebido |
| Erro no carregamento da lista | Substitui a página por uma mensagem de erro centralizada — sem botão de tentar novamente |

---

## Base para Teste E2E

> **O E2E atual deste UC é apenas um smoke test de carregamento de página** ([uc-10-listagem-feedbacks.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-10-listagem-feedbacks.spec.ts)): verifica que a página `/user/feedbacks/all` carrega a lista de feedbacks ou exibe o estado vazio. Os fluxos de **ação** (filtros, busca, paginação, modal de detalhes) **não estão cobertos por E2E**. Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC10-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a listagem carrega os feedbacks paginados ou exibe o estado vazio. (Spec: `[CT-UC10-01] Listagem carrega feedbacks ou exibe estado vazio`.) **Não** cobre abrir o modal de detalhes nem aplicar filtros.
- **[CT-UC10-02]** 📝 *Planejado / não implementado* - Caminho feliz — modal de detalhes: clicar em um feedback deve abrir o modal com todas as seções (ponto de coleta, perguntas, dispositivo, cliente).
- **[CT-UC10-03]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por nota: selecionar nota 5 deve exibir apenas feedbacks com aquela avaliação.
- **[CT-UC10-04]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por categoria: selecionar "Produto" deve exibir apenas feedbacks de pontos de coleta do tipo produto.
- **[CT-UC10-05]** 📝 *Planejado / não implementado* - Caminho feliz — busca textual: digitar um termo deve filtrar feedbacks que contenham aquele texto na mensagem (com debounce de ~450ms antes da requisição).
- **[CT-UC10-06]** 📝 *Planejado / não implementado* - Caminho feliz — filtro por item: digitar um nome de item deve filtrar feedbacks daquele produto/serviço/departamento.
- **[CT-UC10-07]** 📝 *Planejado / não implementado* - Caminho feliz — paginação: mudar de página deve carregar o próximo conjunto de feedbacks mantendo os filtros ativos.
- **[CT-UC10-08]** 📝 *Planejado / não implementado* - Exceção — filtro sem resultado: aplicar filtro que não retorna feedbacks deve exibir o empty state de "ajuste os filtros".
- **[CT-UC10-09]** 📝 *Planejado / não implementado* - Exceção — sem feedbacks: empresa sem histórico deve exibir o empty state de "nenhum feedback recebido" (o smoke CT-UC10-01 já aceita este estado como válido).
