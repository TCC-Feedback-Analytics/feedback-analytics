# UC-08: Configuração de Dados de Coleta (Contexto IA)

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Informar o contexto do negócio que a IA usa nas análises e conectar a IA da empresa (chave OpenRouter e modelo); com os dois prontos, a IA cria as 3 perguntas do formulário geral |
| **Gatilho** | Primeira entrada na área logada (o contexto é obrigatório) ou, depois, o botão "Editar contexto e LLM" no card "Contexto e LLM da empresa" do Perfil. A IA também se configura em "Configuração da coleta" → "Configuração de IA" |

---

## Fluxo Principal (Caminho Feliz)

1. Na primeira entrada, a área logada abre o dialog **"Contexto e configuração de IA"** com o selo "Obrigatório", que não pode ser fechado. Depois do onboarding, o mesmo dialog abre pelo botão "Editar contexto e LLM" do Perfil (`/user/profile`); por ali o clique fora não fecha; ele fecha ao salvar ou pelo X, que descarta a edição.
2. O dialog tem **4 passos** num seletor no topo, que indica o passo atual e os já preenchidos ("A IA é opcional; o contexto da empresa é obrigatório"):
   - **1. Seu negócio** — "O que seu negócio faz e para quem?"
   - **2. Sua meta** — "O que você mais quer melhorar nos próximos meses?", com sugestões para tocar
   - **3. O que descobrir** — "O que você gostaria de saber pela opinião dos clientes?", com sugestões para tocar
   - **4. Modelo LLM** — a conexão com a IA
3. Em cada passo de contexto, o gestor lê a dica e o "Para que serve", escreve o texto (o contador mostra os caracteres) e segue por "Próximo Passo", que só avança com o campo preenchido. "Anterior" volta.
4. No passo **Modelo LLM**, o gestor clica em **"Conectar com OpenRouter"**, entra (ou cria a conta) no OpenRouter, autoriza e volta conectado, com o texto digitado preservado; quem já tem uma chave pode colá-la em "Já tenho uma chave". Em seguida escolhe o modelo: a lista começa com os gratuitos e "Mostrar também modelos pagos" inclui os demais. Com chave já salva, só escolhe o modelo.
5. O gestor clica em **"Configurar IA e salvar"** (ou "Salvar e concluir", quando a IA já está como deseja). Também pode usar **"Salvar sem configurar IA"** e configurar depois.
6. O sistema salva a IA, depois o contexto, e confirma com o toast "Contexto salvo!".
7. Com a IA configurada e o contexto completo, o gateway enfileira a **geração automática das 3 perguntas** do formulário geral (só enquanto elas ainda são as padrão). No onboarding, a tela **"Preparando sua conta"** espera a geração e leva ao Dashboard ao concluir; fora dele, o fim vira o toast "Perguntas personalizadas!".

### Fluxo alternativo — Tela "Configuração de IA"

1. O gestor abre "Configuração da coleta" → "Configuração de IA" (`/user/edit/ia-settings`).
2. Sem chave salva, a tela mostra o selo "Configuração obrigatória", o botão "Conectar com OpenRouter" e, recolhido em "Já tenho uma chave", o campo do token. Com chave salva, mostra "Chave configurada", o modelo ativo, o final da chave, "Remover chave" e a caixinha "Avisar quando a IA demorar".
3. O gestor escolhe o modelo e salva; a troca de modelo usa só a chave já guardada no gateway, que nunca volta ao navegador.
4. Salvar a chave, conectar ou trocar o modelo também dispara a geração automática das perguntas, nas mesmas condições do passo 7.

> **Nota:** a interface exige os três textos de contexto — o dialog não deixa salvar com algum em branco. Os três são enviados juntos, independentemente do passo em que o gestor estiver. A IA é opcional: sem ela, não há geração das perguntas, análise dos comentários nem diagnóstico.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Campo de contexto em branco | "Próximo Passo" não avança e os botões de salvar ficam travados; ao tentar salvar, mostra "Complete os campos obrigatórios" — "Preencha os três campos do contexto da empresa." |
| Erro de rede ao salvar o contexto | Exibe o toast "Erro ao salvar informações" — os textos permanecem para nova tentativa |
| Erro ao salvar a chave ou o modelo | Exibe o toast "Erro na configuração da LLM" com o motivo (chave inválida, modelo indisponível, restrição da conta etc.) |
| Falha ao conectar com o OpenRouter | A volta mostra "Não deu para conectar" e o botão "Voltar e tentar de novo" (sem código, pedido vencido após 15 minutos ou recusa do gateway) |
| Geração das perguntas demora | Depois de 40 segundos, "Preparando sua conta" mostra "A IA está demorando" e a troca rápida de modelo; "Continuar com as perguntas padrão" aparece na falha ou depois de 3 minutos |
| Geração das perguntas falha | No onboarding, mostra o motivo com "Tentar de novo" e a troca de modelo (ou "Revisar chave", se o erro é da conta). Fora dele, um aviso fica no topo do layout até ser resolvido, com "Tentar de novo", "Trocar modelo" (ou "Revisar chave") e "Manter perguntas padrão". Sem pedido novo, a tela explica o motivo: perguntas já editadas, tempo de espera ("Aguarde N minutos para tentar de novo."), chave ausente ou contexto incompleto |
| Gestor tenta disparar análise de IA sem o contexto completo | A análise é bloqueada no UC-11, com mensagem e link para preencher os dados da empresa |

---

## Informações Complementares

- O card **"Contexto e LLM da empresa"** do Perfil mostra os quatro itens (Seu negócio, Sua meta, O que descobrir e Modelo LLM) e o selo "Configurado" só com o contexto completo e o modelo salvo; senão, "Incompleto".
- O campo **"Principais produtos ou serviços"** (`main_products_or_services`) **não** faz parte dos passos editáveis: continua sendo preenchido **automaticamente** ao salvar o catálogo de produtos no UC-07.
- A antiga tela `/user/edit/collecting-data-enterprise` não existe mais: o endereço redireciona para `/user/profile#contexto-da-ia`, e a action da rota segue recebendo o contexto salvo pelo dialog.

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela continha um smoke de carregamento e dois testes de salvamento condicionais (com `test.skip()` quando o campo correspondente não estava visível), escritos para a antiga tela `/user/edit/collecting-data-enterprise`, que hoje só redireciona para o Perfil. O contexto agora se edita no dialog aberto por "Editar contexto e LLM". Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC08-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página de configuração de coleta carrega com o formulário visível. (Spec: `[CT-UC08-01] Página de configuração de coleta carrega com formulário visível`.) Hoje o equivalente é abrir o dialog pelo Perfil.
- **[CT-UC08-02]** ✅ *Coberto E2E (skip condicional)* - Caminho feliz — salvar objetivo: gestor preenche o objetivo da empresa (passo "Sua meta"), salva e recebe confirmação de sucesso. Contém `test.skip()` quando o campo de objetivo não está visível. (Spec: `[CT-UC08-02] Salvar objetivo da empresa persiste e exibe confirmação`.)
- **[CT-UC08-03]** ⛔ *Obsoleto na interface* - Campos em branco: o dialog não deixa mais salvar com algum campo de contexto vazio. O gateway ainda aceita os campos nulos no `PATCH /collecting_data`.
- **[CT-UC08-04]** ✅ *Coberto E2E (skip condicional)* - Caminho feliz — salvar resumo do negócio: gestor preenche o resumo do negócio (passo "Seu negócio"), salva e recebe confirmação de sucesso. Contém `test.skip()` quando o campo de resumo não está visível. (Spec: `[CT-UC08-04] Resumo do negócio pode ser preenchido e salvo`.)
- **[CT-UC08-05]** 🟠 *Integração já atende* - Caminho feliz — atualização parcial: gestor edita apenas o resumo do negócio, salva e confirma que os demais campos permanecem inalterados.
- **[CT-UC08-06]** ❌ *Cenário não coberto* - Exceção — erro ao salvar: simular falha de rede deve exibir toast de erro sem alterar os dados do formulário.
