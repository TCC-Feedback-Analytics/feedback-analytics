# UC-06: Ativação de Tipos de Feedback

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Definir quais categorias de coleta a empresa utiliza: produtos, serviços ou departamentos |
| **Gatilho** | Gestor acessa a tela de tipos de feedback no dashboard |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a tela de tipos de feedback.
2. O sistema exibe os 3 tipos gerenciáveis: **Produtos**, **Serviços** e **Departamentos**, com o status salvo de cada um. O tipo **Empresa (Geral)** está sempre disponível e não aparece aqui.
3. O gestor ativa ou desativa os tipos usando os toggles. Ao ativar um tipo ainda não salvo, a interface exibe um aviso: *"Salve para confirmar a ativação e liberar as configurações deste tipo."*
4. O gestor clica em "Salvar Alterações".
5. O sistema confirma com toast de sucesso.
6. Os tipos salvos como ativos passam a exibir o badge **"Ativo"** e o link de configuração de catálogo (ex.: *"Configurar catálogo de produtos"*) diretamente no card, na mesma tela. Esse link **não** leva mais a um hub de configurações de catálogo: ele aponta direto para a tela de **LISTA** do tipo (`/user/edit/feedback-products`, `/user/edit/feedback-services` ou `/user/edit/feedback-departments`), onde os itens são adicionados/removidos.

> **Navegação e acesso ao catálogo.** A tela `/user/edit/types-feedback` agora abre com um cabeçalho de página (**PageHeader**, com breadcrumb e título) e um bloco **"Como funciona"** em 4 passos (Ative os tipos → Configure o catálogo → Gere os QR Codes → Receba insights). O catálogo de cada tipo ativo é alcançado tanto pelo link no próprio card quanto pela seção de menu **"Configuração da coleta" → "Catálogo"**, que abre esta mesma tela de tipos. A antiga rota de hub `/user/edit/feedback-settings` foi descontinuada e agora **redireciona** para `/user/edit/types-feedback`. O comportamento de ativar, salvar e exibir o badge **"Ativo"** permanece inalterado.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Gestor ativa um toggle mas não salva | O toggle muda visualmente, mas o tipo não está ativo — o badge "Ativo" e o link de catálogo não aparecem até o salvamento |
| Erro ao salvar as configurações | Exibe toast de erro — o estado salvo não é alterado |
| Gestor desativa um tipo que já tem itens de catálogo cadastrados | Desativar não exclui os itens — apenas oculta o tipo da interface e bloqueia novos envios via QR Code |

---

## Base para Teste E2E

> **O E2E atual deste UC é apenas um smoke test de carregamento de página** ([uc-06-ativacao-tipos-feedback.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-06-ativacao-tipos-feedback.spec.ts)): verifica que a página `/user/edit/types-feedback` carrega e lista as opções (Produtos/Serviços/Departamentos). O fluxo de **ação** (ativar, salvar e ver o badge) **não está coberto por E2E**. Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC06-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página de tipos de feedback carrega exibindo as opções disponíveis (Produtos/Serviços/Departamentos). (Spec: `[CT-UC06-01] Página de tipos de feedback carrega com as opções disponíveis`.) **Não** cobre ativar/salvar.
- **[CT-UC06-02]** 📝 *Planejado / não implementado* - Caminho feliz — ativar: gestor ativa o tipo "Produtos", salva e verifica que o badge "Ativo" e o link "Configurar catálogo de produtos" aparecem no card. O link continua sendo exibido no próprio card, mas agora aponta para a tela de **lista** do tipo (`/user/edit/feedback-products`), não mais para um hub de configurações de catálogo.
- **[CT-UC06-03]** 📝 *Planejado / não implementado* - Caminho feliz — desativar: gestor desativa um tipo ativo, salva e verifica que o badge e o link de catálogo desaparecem.
- **[CT-UC06-04]** ❌ *Cenário não coberto* - Comportamento antes de salvar: ativar um toggle sem salvar deve exibir o aviso em âmbar, sem mostrar o badge "Ativo" ou o link de catálogo.
- **[CT-UC06-05]** ❌ *Cenário não coberto* - Exceção — erro ao salvar: simular falha de rede durante o salvamento deve exibir toast de erro sem alterar o estado salvo dos tipos.
