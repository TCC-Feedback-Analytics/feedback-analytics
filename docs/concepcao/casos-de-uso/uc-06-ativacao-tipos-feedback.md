# UC-06: Ativação de Tipos de Feedback

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Definir quais categorias de coleta a empresa utiliza: produtos, serviços ou departamentos |
| **Gatilho** | Gestor acessa o Catálogo pelo menu ("Configuração da coleta" → "Catálogo", `/user/edit/types-feedback`) |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a tela do Catálogo ("O que você quer acompanhar?"), que abre com o cabeçalho de página (PageHeader, com breadcrumb e título).
2. O sistema exibe os 3 tipos gerenciáveis em cards — **Produtos**, **Serviços** e **Departamentos** —, cada um com o interruptor e o status salvo, e o contador "N de 3 tipos selecionados". A avaliação da empresa está sempre disponível e não aparece aqui.
3. O gestor ativa ou desativa os tipos pelos interruptores. Enquanto houver mudança não salva, a tela avisa "Suas alterações ainda não foram salvas.", e o card de um tipo recém-ativado mostra "Salve para liberar o catálogo."
4. O gestor clica em "Salvar seleção" (o botão fica travado, como "Seleção salva", quando não há mudança).
5. O sistema confirma com o toast "Configurações salvas!".
6. Os tipos salvos como ativos passam a exibir o selo **"Ativo"** e o link **"Configurar catálogo"** no próprio card. O link aponta direto para a tela de **lista** do tipo (`/user/edit/feedback-products`, `/user/edit/feedback-services` ou `/user/edit/feedback-departments`), onde os itens são cadastrados e removidos (UC-07).

> **Rota antiga.** O antigo hub `/user/edit/feedback-settings` foi descontinuado e **redireciona** para `/user/edit/types-feedback`.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Gestor ativa um interruptor mas não salva | O interruptor muda visualmente, mas o tipo não está ativo — o selo "Ativo" e o link de catálogo não aparecem até o salvamento |
| Erro ao salvar as configurações | Exibe o toast "Erro ao salvar" — o estado salvo não é alterado |
| Gestor desativa um tipo que já tem itens de catálogo cadastrados | Desativar não apaga os itens do banco, mas o gateway marca **todos os itens do tipo como inativos**: eles somem da lista do catálogo e dos seletores de escopo. Reativar o tipo depois **não** traz esses itens de volta. Desativar Produtos também limpa o campo `main_products_or_services` do contexto da IA. O QR Code de cada item não é pausado por isso (ver UC-07) |

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela cobria apenas um **smoke test de carregamento de página** (verificava que a página `/user/edit/types-feedback` carregava e listava as opções — Produtos/Serviços/Departamentos), e o fluxo de **ação** (ativar, salvar e ver o badge) nunca teve E2E. Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC06-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página de tipos de feedback carrega exibindo as opções disponíveis (Produtos/Serviços/Departamentos). (Spec: `[CT-UC06-01] Página de tipos de feedback carrega com as opções disponíveis`.) **Não** cobre ativar/salvar.
- **[CT-UC06-02]** 📝 *Planejado / não implementado* - Caminho feliz — ativar: gestor ativa o tipo "Produtos", salva e verifica que o selo "Ativo" e o link "Configurar catálogo" aparecem no card. O link aponta para a tela de **lista** do tipo (`/user/edit/feedback-products`), não mais para um hub de configurações de catálogo.
- **[CT-UC06-03]** 📝 *Planejado / não implementado* - Caminho feliz — desativar: gestor desativa um tipo ativo, salva e verifica que o badge e o link de catálogo desaparecem.
- **[CT-UC06-04]** ❌ *Cenário não coberto* - Comportamento antes de salvar: ativar um interruptor sem salvar deve exibir o aviso de alteração não salva e "Salve para liberar o catálogo.", sem mostrar o selo "Ativo" ou o link de catálogo.
- **[CT-UC06-05]** ❌ *Cenário não coberto* - Exceção — erro ao salvar: simular falha de rede durante o salvamento deve exibir toast de erro sem alterar o estado salvo dos tipos.
