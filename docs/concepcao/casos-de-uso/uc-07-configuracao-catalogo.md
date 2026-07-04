# UC-07: Configuração do Catálogo

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Cadastrar itens de catálogo (produtos, serviços ou departamentos) numa tela de lista por tipo e, em uma tela dedicada por item, configurar dados, perguntas de avaliação e o QR Code individual daquele item |
| **Gatilho** | Gestor acessa a tela de lista de um dos tipos de catálogo ativados (`/user/edit/feedback-{products,services,departments}`) |

---

## Fluxo Principal (Caminho Feliz)

> A configuração do catálogo deixou de ser um único formulário com tudo embutido. Agora existem **duas telas**: a **lista por tipo**, onde se adiciona/remove itens, e a **tela dedicada por item**, onde se configura dados, perguntas e QR Code daquele item.

### Parte 1 — Gerenciar itens na lista por tipo

1. O gestor acessa a lista de um tipo do catálogo (`/user/edit/feedback-{products,services,departments}`).
2. O sistema exibe os itens cadastrados, cada um com seu nome, eventual descrição e um selo de status do QR Code ("QR ativo" ou "QR inativo").
3. Para **adicionar** um item, o gestor digita o nome no campo "Adicionar {item}" e clica em "Adicionar"; para **remover**, usa o botão de lixeira do item. Ambas as ações disparam o **salvamento em lote** do catálogo.
4. O sistema confirma com notificação de sucesso ("Catálogo atualizado!") e a lista é atualizada.
   - **Efeito colateral:** ao salvar o catálogo de produtos, o sistema atualiza automaticamente o campo de contexto de IA (`main_products_or_services`) com os itens cadastrados.
5. Para configurar um item, o gestor clica em "Configurar", que abre a tela dedicada do item em `/user/edit/feedback/:kind/:itemId`.

### Parte 2 — Configurar o item na tela dedicada

A tela dedicada do item tem **três blocos independentes**, cada um com seu próprio salvamento:

6. **Dados do item** — o gestor edita o nome e a descrição (opcional) e clica em "Salvar dados do item". O botão fica travado até haver alteração (dirty-tracking); ao salvar, o sistema confirma com notificação de sucesso.
7. **Perguntas de avaliação** — editor unificado com abas **Editar | Prévia**, até **3 perguntas × 3 subperguntas** (cada texto entre 20 e 150 caracteres). O gestor clica em "Salvar perguntas do item" e o sistema confirma com notificação de sucesso.
   - A aba **Prévia** mostra ao vivo o formulário público real como o cliente verá, rotulando como "Não enviada" a pergunta cujo texto está vazio.
   - A **visibilidade da pergunta deriva do texto**: pergunta com texto vira pergunta no formulário; pergunta deixada em branco exibe apenas a nota (estrelas), sem o campo de texto.
8. **QR Code do item** — bloco com toggle próprio de ativação, link/URL de coleta e geração/download do QR Code daquele item.

### Parte 3 — Controlar o QR Code do item

9. No bloco "QR Code do item", o gestor ativa ou desativa o QR Code pelo toggle independente.
10. O sistema confirma a mudança imediatamente com toast de sucesso ("QR Code ativado!" / "QR Code desativado!") — sem necessidade de salvar os outros blocos.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Pergunta com texto abaixo de 20 ou acima de 150 caracteres | Rejeita o salvamento das perguntas daquele item e indica o campo com erro |
| Subpergunta com texto fora do intervalo (20–150 caracteres) | Mesma validação aplicada às subperguntas |
| Tentativa de acessar catálogo de tipo não ativado | A rota não está acessível — o gestor precisa ativar o tipo no UC-06 primeiro |
| Gestor abre a tela dedicada de um item inexistente (rota `/user/edit/feedback/:kind/:itemId` com `itemId` removido/inválido) | Exibe "Item não encontrado" com a mensagem de que o item não está mais disponível e um link "Voltar ao catálogo" que retorna à lista do tipo |
| Erro ao salvar o catálogo (itens) | Exibe notificação de erro — os dados anteriores não são alterados |
| Erro ao salvar os dados do item (nome/descrição) | Exibe notificação de erro — os blocos de perguntas e de QR Code não são afetados |
| Erro ao salvar as perguntas de um item | Exibe notificação de erro para aquele item — outros itens não são afetados |
| Erro ao ativar ou desativar o QR Code de um item | Exibe toast de erro — o estado do toggle não é alterado |
| Gestor desativa um item do catálogo (status inativo) | O formulário público exibe tela de erro fatal para aquele item — novos envios são bloqueados sem excluir o histórico |
| Gestor desativa o QR Code de um item (toggle) | O formulário público daquele item bloqueia novos envios, igual ao estado de item inativo |

---

## Base para Teste E2E

> **O E2E atual deste UC é apenas um smoke test de carregamento de página** ([uc-07-configuracao-catalogo.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-07-configuracao-catalogo.spec.ts)): o smoke continua na **lista** `/user/edit/feedback-products`, verificando que a página carrega (ou exibe o bloqueio de tipo não ativado). Os fluxos de **ação** **não estão cobertos por E2E** — e configurar perguntas e QR Code agora vive na **tela dedicada por item** (`/user/edit/feedback/:kind/:itemId`), não mais na lista. Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC07-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página de lista do catálogo de produtos carrega corretamente — exibe o conteúdo principal ou a mensagem de tipo não ativado. (Spec: `[CT-UC07-01] Página de catálogo de produtos carrega corretamente`.) **Não** cobre adicionar/remover item nem a tela dedicada por item (dados, perguntas, QR Code).
- **[CT-UC07-02]** 📝 *Planejado / não implementado* - Caminho feliz — adicionar item: na lista, o gestor adiciona um produto com nome válido, o salvamento em lote confirma e o item aparece na lista.
- **[CT-UC07-03]** 📝 *Planejado / não implementado* - Caminho feliz — editar dados do item: na tela dedicada do item, o gestor edita o nome no bloco "Dados do item", clica em "Salvar dados do item" e confirma a atualização.
- **[CT-UC07-04]** 📝 *Planejado / não implementado* - Caminho feliz — salvar perguntas: na tela dedicada do item, o gestor configura uma pergunta dinâmica válida (20–150 chars), clica em "Salvar perguntas do item" e recebe confirmação de sucesso.
- **[CT-UC07-05]** 📝 *Planejado / não implementado* - Caminho feliz — toggle QR Code por item: no bloco "QR Code do item", o gestor ativa ou desativa o QR Code via toggle — deve exibir toast de sucesso e atualizar o estado visualmente sem necessidade de salvar os outros blocos.
- **[CT-UC07-06]** 🔵 *Unidade já atende* - Exceção — pergunta inválida (curta): tentar salvar pergunta com menos de 20 caracteres deve bloquear o envio e destacar o campo com erro.
- **[CT-UC07-07]** 🔵 *Unidade já atende* - Exceção — pergunta inválida (longa): tentar salvar pergunta com mais de 150 caracteres deve bloquear o envio.
- **[CT-UC07-08]** ❌ *Cenário não coberto* - Exceção — item inativo: desativar um produto e verificar que o formulário público daquele item exibe tela de erro fatal.
- **[CT-UC07-09]** ❌ *Cenário não coberto* - Exceção — QR Code desativado por item: desativar o QR Code de um item via toggle e verificar que o formulário público bloqueia novos envios para aquele item.
