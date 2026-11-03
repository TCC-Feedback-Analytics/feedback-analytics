# UC-07: Configuração do Catálogo

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Cadastrar itens de catálogo (produtos, serviços ou departamentos) numa tela de lista por tipo e, em uma tela dedicada por item, configurar dados, perguntas, campo de comentário e os canais de coleta daquele item |
| **Gatilho** | Gestor clica em "Configurar catálogo" no card de um tipo ativo (UC-06), que abre a lista do tipo (`/user/edit/feedback-{products,services,departments}`) |

---

## Fluxo Principal (Caminho Feliz)

> A configuração do catálogo tem **duas telas**: a **lista por tipo**, onde se cadastram e removem itens, e a **tela dedicada por item**, onde se configuram dados, perguntas, campo de comentário e canais de coleta daquele item.

### Parte 1 — Gerenciar itens na lista por tipo

1. O gestor acessa a lista de um tipo do catálogo (`/user/edit/feedback-{products,services,departments}`).
2. O sistema exibe os itens cadastrados, cada um com seu nome, eventual descrição e um selo de status do QR Code ("QR ativo" ou "QR inativo"). Com itens na lista, o gestor pode buscar por nome ou descrição e filtrar pelo status do QR Code ("Limpar filtros" volta ao padrão).
3. Para **cadastrar** um item, o gestor clica em "Cadastrar {item}", informa o nome e, se quiser, a descrição no dialog e clica em "Cadastrar"; para **remover**, usa o botão "Remover" do item. Ambas as ações disparam o **salvamento em lote** do catálogo.
4. O sistema confirma com o toast "Catálogo atualizado!" e a lista é atualizada.
   - **Efeito colateral:** ao salvar o catálogo de produtos, o sistema atualiza automaticamente o campo de contexto de IA (`main_products_or_services`) com os itens cadastrados.
5. Para configurar um item, o gestor clica em "Configurar", que abre a tela dedicada do item em `/user/edit/feedback/:kind/:itemId`.

### Parte 2 — Configurar o item na tela dedicada

A tela dedicada do item espelha a Avaliação da empresa e tem **quatro blocos independentes**, cada um com seu próprio salvamento:

6. **Dados do {item}** — o gestor edita o nome e a descrição (opcional) e clica em "Salvar dados do item". O botão fica travado até haver alteração (dirty-tracking); ao salvar, o sistema confirma com o toast "Dados salvos!".
7. **Perguntas** — o botão "Configurar perguntas" abre uma configuração guiada:
   - Primeiro o gestor escolhe quantas perguntas o item terá: **0 ("Somente nota", só as estrelas)**, 1, 2 ou 3.
   - Depois escreve cada pergunta (de 20 a 150 caracteres), com até 3 subperguntas opcionais no mesmo limite.
   - Por fim revisa o resumo com a **prévia do formulário** como o cliente verá (há a opção "Expandir") e clica em "Salvar perguntas". O sistema confirma com o toast "Perguntas atualizadas!".
8. **Campo de comentário** — o gestor escolhe como o comentário aparece no formulário deste item: "Convite padrão", "Pergunta própria" (de 10 a 150 caracteres, com sugestões) ou "Ocultar o campo", e clica em "Salvar campo de comentário". O sistema confirma com o toast "Campo de comentário salvo!". Ao ocultar, a tela avisa que a "Análise dos comentários" fica vazia para o item.
9. **Canais de coleta** — o mesmo bloco da Avaliação da empresa (UC-05), com o QR Code, o link e a etiqueta NFC deste item.

### Parte 3 — Controlar a coleta do item

10. Em "Canais de coleta", o gestor liga ou pausa a coleta do item ("Ativar coleta" / "Pausar coleta").
11. O sistema confirma a mudança imediatamente com o toast "QR Code ativado!" ou "QR Code desativado!" — sem necessidade de salvar os outros blocos. O link, o QR Code e o endereço da etiqueta do item só existem com a coleta ativa.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Pergunta com menos de 20 caracteres | Não avança na configuração guiada: "Escreva uma pergunta com pelo menos 20 caracteres para continuar." O campo não aceita mais de 150 |
| Subpergunta preenchida fora do intervalo (20–150 caracteres) | Bloqueia o salvamento: "Cada subpergunta deve ter entre 20 e 150 caracteres." |
| Pergunta própria do comentário fora do intervalo (10–150 caracteres) | Não deixa salvar o campo de comentário |
| Acesso à lista de um tipo não ativado | O link "Configurar catálogo" só aparece com o tipo salvo como ativo (UC-06). A Web não bloqueia o endereço digitado direto: a lista abre normalmente |
| Gestor abre a tela dedicada de um item inexistente (rota `/user/edit/feedback/:kind/:itemId` com `itemId` removido/inválido) | Exibe "Item não encontrado" com a mensagem de que o item não está mais disponível e um link "Voltar ao catálogo" que retorna à lista do tipo |
| Erro ao salvar o catálogo (itens) | Exibe o toast "Erro ao salvar" — os dados anteriores não são alterados |
| Erro ao salvar os dados do item (nome/descrição) | Exibe o toast "Erro ao salvar" — os outros blocos não são afetados |
| Erro ao salvar as perguntas de um item | Exibe o toast "Não foi possível salvar" — outros itens não são afetados |
| Erro ao salvar o campo de comentário | Exibe o toast "Não deu para salvar" |
| Erro ao ativar ou pausar a coleta de um item | Exibe o toast "Erro na operação" — o estado não é alterado |
| Gestor remove um item da lista | O item não é apagado do banco: fica inativo e some da lista, preservando o histórico. A coleta do item **não** é pausada por isso: o gateway não confere o status do item, e o formulário daquele QR continua aceitando respostas enquanto o ponto de coleta estiver ativo. Para parar a coleta, pause-a na tela do item antes de removê-lo |
| Gestor pausa a coleta de um item | O formulário público daquele item mostra a tela de erro "QR Code indisponível" e bloqueia novos envios (UC-04) |

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela cobria apenas um **smoke test de carregamento de página** na **lista** `/user/edit/feedback-products` (verificava que a página carregava ou exibia o bloqueio de tipo não ativado). Os fluxos de **ação** nunca tiveram E2E — e configurar perguntas e QR Code agora vive na **tela dedicada por item** (`/user/edit/feedback/:kind/:itemId`), não mais na lista. Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC07-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página de lista do catálogo de produtos carrega corretamente — exibe o conteúdo principal ou a mensagem de tipo não ativado. (Spec: `[CT-UC07-01] Página de catálogo de produtos carrega corretamente`.) **Não** cobre adicionar/remover item nem a tela dedicada por item (dados, perguntas, QR Code).
- **[CT-UC07-02]** 📝 *Planejado / não implementado* - Caminho feliz — cadastrar item: na lista, o gestor cadastra um produto com nome válido, o salvamento em lote confirma e o item aparece na lista.
- **[CT-UC07-03]** 📝 *Planejado / não implementado* - Caminho feliz — editar dados do item: na tela dedicada do item, o gestor edita o nome no bloco "Dados do {item}", clica em "Salvar dados do item" e confirma a atualização.
- **[CT-UC07-04]** 📝 *Planejado / não implementado* - Caminho feliz — salvar perguntas: na tela dedicada do item, o gestor abre "Configurar perguntas", escreve uma pergunta válida (20–150 chars), revisa, clica em "Salvar perguntas" e recebe confirmação de sucesso.
- **[CT-UC07-05]** 📝 *Planejado / não implementado* - Caminho feliz — coleta por item: em "Canais de coleta", o gestor ativa ou pausa a coleta do item — deve exibir toast de sucesso e atualizar o estado visualmente sem necessidade de salvar os outros blocos.
- **[CT-UC07-06]** 🔵 *Unidade já atende* - Exceção — pergunta inválida (curta): tentar salvar pergunta com menos de 20 caracteres deve bloquear o envio e destacar o campo com erro.
- **[CT-UC07-07]** 🔵 *Unidade já atende* - Exceção — pergunta inválida (longa): tentar salvar pergunta com mais de 150 caracteres deve bloquear o envio.
- **[CT-UC07-08]** ❌ *Cenário não coberto* - Exceção — item removido: remover um produto com a coleta ativa e verificar o formulário público daquele item. Pelo código atual, o formulário **continua** abrindo e aceitando respostas (ver a exceção "Gestor remove um item da lista").
- **[CT-UC07-09]** ❌ *Cenário não coberto* - Exceção — coleta pausada por item: pausar a coleta de um item e verificar que o formulário público bloqueia novos envios para aquele item.
