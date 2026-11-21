# UC-12: Gestão de Perfil

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Atualizar os dados pessoais e de contato da conta, consultar os dados da empresa e, se quiser, excluir a conta |
| **Gatilho** | Gestor abre "Minha conta" no menu da conta, no cabeçalho |

---

## Visão Geral da Tela

A tela de perfil (`/user/profile`) abre com o `PageHeader` (breadcrumb + título **"Perfil"**) e tem quatro seções:

- **Dados pessoais e acesso** — nome completo, e-mail e telefone (componente `Information`), com o atalho "Ver dados da empresa".
- **Dados e configurações da empresa** (`#dados-da-empresa`) — o cadastro da empresa: "Conta criada em" e "Status da conta" (Período de teste, Conta ativa, Teste encerrado ou Conta cancelada). Não há CPF/CNPJ: o sistema não usa nem guarda esse dado (LGPD).
- **Contexto da empresa para IA** — o card "Contexto e LLM da empresa", com "Editar contexto e LLM" (ver UC-08).
- **Excluir minha conta** — o pedido de exclusão da conta, confirmado por um link no e-mail e com 15 dias para desistir (LGPD, art. 18).

O **logout** e o **Guia do Sistema** ficam no **menu de conta no topo do layout** (`AccountMenu`), com "Minha conta" (atalho para `/user/profile`) e "Sair". As perguntas gerais da empresa, o campo de comentário e os canais de coleta ficam na tela **"Avaliação da empresa"** (`/user/edit/feedback-general`) — ver UC-05.

---

## Fluxo Principal (Caminho Feliz)

**Atualizar nome:**

1. O gestor clica em "Editar" no campo "Nome do negócio" e altera o valor.
2. Confirma a alteração.
3. O sistema valida o nome (de 2 a 120 caracteres) e salva.
4. O sistema confirma com o toast "Nome atualizado!" e o nome atualizado aparece no perfil.

**Atualizar e-mail:**

1. O gestor clica em "Editar" no campo "Email" (dica "Primeiro aprove no e-mail atual, depois confirme no novo"), informa o novo endereço e salva.
2. O gateway (`PATCH /api/protected/user/email`) pede a troca ao `changeEmail` do Better Auth, que manda primeiro o e-mail "Aprove a troca do e-mail da sua conta" para o endereço **atual**. A tela mostra o toast "Aprove a troca no seu e-mail atual!".
3. O link "Aprovar a troca" volta para `/auth/success?tipo=troca-aprovada`. Só então o e-mail "Confirme seu novo e-mail" vai para o endereço novo.
4. A troca só vale depois que o gestor clica no link do endereço novo: até lá, a conta continua com o e-mail antigo. O link passa pelo `/api/auth/verify-email` do Better Auth e volta para `/auth/success?tipo=email-trocado`. A rota nativa `POST /api/auth/change-email` está desligada (responde 404).

**Atualizar telefone:**

1. O gestor clica em "Editar" no campo de telefone — a tela muda para o modo de edição.
2. Informa o novo número no formato `+55` seguido do DDD e do número e clica em "Salvar".
3. O gateway grava o número direto — **não há provedor de SMS** nem código de confirmação — e a tela mostra o toast "Telefone atualizado!" e volta ao modo de visualização.
4. "Cancelar" volta ao modo de visualização sem alterar o número.

**Excluir a conta:**

1. No fim do Perfil, o gestor clica em "Excluir minha conta" ("A conta fica parada por 15 dias e depois é apagada, com a empresa e todos os feedbacks.").
2. O dialog lista o que será apagado e pede a senha, se a conta tem login por senha, e a palavra **EXCLUIR** para liberar o botão "Enviar link de confirmação". Quem só entra pelo Google não digita senha, mas precisa ter entrado nas últimas 24 horas.
3. O gateway (`POST /api/protected/user/account-deletion`) manda ao e-mail da conta o link "Confirme a exclusão da sua conta", que vale 1 hora e só funciona no navegador logado. O dialog mostra "Confira o seu e-mail." Nada é apagado nesse passo.
4. O link abre `/conta/excluir`. Abrir o link sozinho não confirma: o gestor clica em "Confirmar a exclusão". O gateway (`POST /api/protected/user/account-deletion/confirm`) marca a exclusão para daqui a 15 dias, encerra todas as sessões da conta e manda o e-mail "Sua conta será excluída em dd/mm/aaaa". A página mostra "Exclusão agendada" com a data.
5. Durante os 15 dias, a conta fica parada: o painel fecha e o formulário público (QR Code, link e NFC) não abre nem grava respostas. Quem entra de novo vê `/conta/exclusao-agendada`, com a data e os botões "Cancelar exclusão" e "Sair". Entrar sozinho não cancela. "Cancelar exclusão" volta a conta ao normal e manda o e-mail "A exclusão da sua conta foi cancelada".
6. No fim do prazo, uma rotina diária apaga a conta, a empresa e todos os dados dela (feedbacks, análises, catálogo, perguntas, pontos de coleta, aparelhos, configuração de IA, jobs e diagnósticos) e manda o e-mail "Sua conta foi excluída".

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Nome vazio ou com menos de 2 caracteres | A validação do campo bloqueia o envio |
| Telefone fora do padrão (`+55` + DDD + número) | A validação do formulário bloqueia o envio antes de chamar a API |
| Falha ao salvar nome, e-mail ou telefone | Toast de erro ("Erro ao atualizar nome", "Erro ao atualizar email" ou "Erro ao atualizar telefone") e o gestor continua no Perfil |
| Novo e-mail já usado por outra conta | A tela mostra o mesmo toast de sucesso, mas nenhum e-mail sai e a troca não acontece: o Better Auth não revela que o endereço já existe |
| Erro inesperado na área logada | Tela "Algo deu errado", com "Tentar de novo" e "Voltar ao início" (`/user/dashboard`) |
| Exclusão com senha errada | O dialog mostra "Senha incorreta. Confira e tente de novo." |
| Exclusão sem senha (conta só com Google) e entrada há mais de 24 h | O dialog mostra "Por segurança, saia, entre de novo e volte aqui para excluir a conta." |
| Mais de 5 pedidos de exclusão na mesma hora | O dialog mostra "Muitos pedidos seguidos. Aguarde um pouco e tente de novo." |
| Outra falha no pedido de exclusão | O dialog mostra "Não foi possível enviar o pedido agora. Tente de novo em instantes." |
| Link de exclusão já usado ou vencido | A página `/conta/excluir` mostra "Este link já foi usado ou venceu. Peça a exclusão de novo no Perfil." |
| Link de exclusão aberto em outro navegador ou sem sessão | A página pede para abrir o link no navegador logado e nada é confirmado |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC12-01]** ✅ *Coberto manual (runbook)* - Carregamento: em `/user/profile`, aparecem as seções "Dados pessoais e acesso" (com "Nome do negócio" e "Email"), "Dados e configurações da empresa", o card "Contexto e LLM da empresa" e, no fim, "Excluir minha conta".
- **[CT-UC12-02]** ✅ *Coberto manual (runbook)* - E-mail exibido: o e-mail da conta logada aparece no perfil.
- **[CT-UC12-03]** ✅ *Coberto manual (runbook)* - Endereço antigo do QR Code: o Perfil não tem mais link de QR Code. Abrir direto `/user/qrcode/enterprise` leva a `/user/edit/feedback-general`, com a seção "Canais de coleta".
- **[CT-UC12-04]** ✅ *Coberto manual (runbook)* - Catálogo acessível fora do perfil: o catálogo fica em "Configuração da coleta" › "Catálogo", não no Perfil. Abrir `/user/edit/types-feedback` mostra a tela do catálogo.
- **[CT-UC12-06]** ✅ *Coberto manual (runbook)* - Logout: no menu de conta do cabeçalho ("Minha conta", "Guia do Sistema" e "Sair"), clicar em "Sair" leva a `/login`.
- **[CT-UC12-07]** ✅ *Coberto manual (runbook)* - Rota protegida: sem sessão, abrir `/user/dashboard` redireciona para `/login`.
- **[CT-UC12-08]** 📝 *Planejado / não implementado* - Caminho feliz — nome: gestor edita o nome, salva e confirma que o novo nome aparece no perfil.
- **[CT-UC12-09]** ✅ *Coberto manual (runbook)* - Caminho feliz — e-mail: numa conta descartável, o gestor edita o "Email" e salva. Aparece o toast "Aprove a troca no seu e-mail atual!" e, ao recarregar, o Perfil ainda mostra o e-mail antigo. No endereço atual, o e-mail "Aprove a troca do e-mail da sua conta" leva a `/auth/success?tipo=troca-aprovada`, e o Perfil continua com o e-mail antigo. No endereço novo, o link "Confirmar meu novo e-mail" do e-mail "Confirme seu novo e-mail" abre `/auth/success?tipo=email-trocado`, e depois o Perfil mostra o e-mail novo. Com um e-mail que já é de outra conta, o toast é o mesmo, mas nada é enviado nem trocado.
- **[CT-UC12-10]** ✅ *Coberto manual (runbook)* - Caminho feliz — telefone: o gestor edita o telefone no formato `+55` + DDD + número e clica em "Salvar"; aparece o toast "Telefone atualizado!", o campo volta ao modo de visualização com o número novo, e não há passo de código.
- **[CT-UC12-11]** 📝 *Planejado / não implementado* - Caminho feliz — cancelar telefone: durante o modo de edição, clicar em "Cancelar" deve voltar ao modo de visualização sem alterar o número.
- **[CT-UC12-12]** 📝 *Planejado / não implementado* - Exceção — nome vazio: tentar salvar com campo de nome vazio deve bloquear o envio. Nenhum teste de unidade confere esse bloqueio hoje.
- **[CT-UC12-13]** 📝 *Planejado / não implementado* - Exceção — telefone inválido: informar número fora do padrão `+55 DDD NÚMERO` deve bloquear o formulário antes de chamar a API. Nenhum teste de unidade confere esse bloqueio hoje.
- **[CT-UC12-14]** ⛔ *Obsoleto* - Exceção — código inválido: sem provedor de SMS, a tela não tem mais o passo do código e salva o número direto, então não existe código errado a testar.
- **[CT-UC12-15]** ✅ *Coberto manual (runbook)* - Excluir minha conta: numa conta descartável com senha, "Excluir minha conta" abre a janela que lista o que será apagado, e "Enviar link de confirmação" só habilita com a senha e a palavra `EXCLUIR`. Com a senha errada, aparece "Senha incorreta. Confira e tente de novo." e nada é enviado. Com a certa, a janela mostra "Confira o seu e-mail." e nada é apagado ainda. O link "Confirmar a exclusão", no e-mail "Confirme a exclusão da sua conta", abre `/conta/excluir`, e só o clique em "Confirmar a exclusão" mostra "Exclusão agendada" com a data, daqui a 15 dias. A sessão é encerrada. Ao entrar de novo, aparece `/conta/exclusao-agendada`, e "Cancelar exclusão" leva ao painel e manda o e-mail "A exclusão da sua conta foi cancelada". Usar o mesmo link de novo mostra "Este link já foi usado ou venceu. Peça a exclusão de novo no Perfil.". Numa conta só com Google, a janela não pede senha. Com a entrada há mais de 24 h, mostra "Por segurança, saia, entre de novo e volte aqui para excluir a conta.".
- **[CT-UC12-16]** ✅ *Coberto manual (runbook)* - Rotas antigas redirecionam: `/user/insights`, `/user/insights/reports`, `/user/insights/emotional` e `/user/insights/statistics` levam a `/user/insights/overview`; `/user/feedbacks/analytics/all`, `/positive` e `/negative` levam a `/user/insights/comments` (os dois últimos com `?filtro=positivos` e `?filtro=negativos`); `/user/insights/questions` leva a `/user/dashboard`; `/user/edit/feedback-settings` leva a `/user/edit/types-feedback`; `/user/qrcode/enterprise` leva a `/user/edit/feedback-general`; `/user/edit/collecting-data-enterprise` leva a `/user/profile#contexto-da-ia`.
