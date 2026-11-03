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
- **Excluir minha conta** — a exclusão definitiva da conta (LGPD, art. 18).

O **logout** e o **Guia do Sistema** ficam no **menu de conta no topo do layout** (`AccountMenu`), com "Minha conta" (atalho para `/user/profile`) e "Sair". As perguntas gerais da empresa, o campo de comentário e os canais de coleta ficam na tela **"Avaliação da empresa"** (`/user/edit/feedback-general`) — ver UC-05.

---

## Fluxo Principal (Caminho Feliz)

**Atualizar nome:**

1. O gestor clica em "Editar" no campo "Nome completo" e altera o valor.
2. Confirma a alteração.
3. O sistema valida o nome (de 2 a 120 caracteres) e salva.
4. O sistema confirma com o toast "Nome atualizado!" e o nome atualizado aparece no perfil.

**Atualizar telefone (dois passos):**

1. O gestor clica em "Editar" no campo de telefone — a tela muda para o modo de edição.
2. Informa o novo número no formato `+55` seguido do DDD e do número e clica em "Enviar SMS".
3. O gateway já grava o novo número nesse passo e a tela mostra o toast "Código enviado!". **Não há provedor de SMS:** nenhum código é enviado de fato.
4. A tela muda para o modo de verificação ("Digite o código de 6 dígitos que você recebeu").
5. O gestor digita um código e clica em "Confirmar" (ver a limitação abaixo).
6. O gestor pode cancelar no modo de edição ou de verificação para voltar ao modo de visualização. Depois de "Enviar SMS", o número novo já está salvo.

**Excluir a conta:**

1. No fim do Perfil, o gestor clica em "Excluir minha conta" ("Apaga a conta, a empresa e todos os feedbacks. Não dá para desfazer.").
2. O dialog lista o que será apagado e pede a senha, se a conta tem login por senha, e a palavra **EXCLUIR** para liberar o botão "Excluir para sempre".
3. O gateway apaga a conta, a empresa e todos os dados dela (feedbacks, análises, catálogo, perguntas, pontos de coleta, aparelhos, configuração de IA, jobs e diagnósticos) e limpa o cookie de sessão.
4. O dialog mostra "Sua conta foi excluída." e o botão "Ir para o início", que recarrega a página em `/`.

> **Limitações conhecidas.**
>
> - **Troca de e-mail:** o campo "Email" é editável e diz "Após alterar, confirme nos dois emails (antigo e novo)", mas a troca **não acontece**. O gateway sempre responde `400 update_failed`, porque o `changeEmail` do Better Auth não está ligado. A action do Perfil não trata o erro: a falha sobe para a tela de erro da área logada, que hoje não renderiza nada, e a área logada fica **em branco** até recarregar a página.
> - **Confirmação do telefone:** a Web envia só o código para `POST /api/protected/user/phone/verify`, e o gateway exige também o telefone, então responde `400 invalid_payload`. A falha cai na mesma tela em branco. O número já foi gravado no passo "Enviar SMS".
> - **Falhas ao salvar o nome:** também não são tratadas pela action e levam à mesma tela em branco, em vez de um toast de erro.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Nome vazio ou com menos de 2 caracteres | A validação do campo bloqueia o envio |
| Telefone fora do padrão (`+55` + DDD + número) | A validação do formulário bloqueia o envio antes de chamar a API |
| Troca de e-mail | Sempre falha no gateway (`400 update_failed`) e a área logada fica em branco (ver as limitações acima) |
| Confirmação do código do telefone | Falha no gateway (`400 invalid_payload`) e a área logada fica em branco (ver as limitações acima) |
| Exclusão com senha errada | O dialog mostra "Senha incorreta. Confira e tente de novo." |
| Exclusão sem senha (conta só com Google) e entrada há mais de 24 h | O dialog mostra "Por segurança, saia, entre de novo e volte aqui para excluir a conta." |
| Outra falha na exclusão | O dialog mostra "Não foi possível excluir a conta agora. Tente de novo em instantes." |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC12-01]** ✅ *Coberto E2E* - Carregamento: a página de perfil carrega com os dados da empresa (perfil/empresa/nome/e-mail). (Spec: `[CT-UC12-01] Página de perfil carrega com dados da empresa`.)
- **[CT-UC12-02]** ✅ *Coberto E2E* - E-mail exibido: o e-mail do usuário autenticado é exibido no perfil. (Spec: `[CT-UC12-02] E-mail do usuário autenticado é exibido no perfil`.)
- **[CT-UC12-03]** ✅ *Coberto E2E (skip condicional)* - QR Code não fica mais no perfil: o link de QR Code deixou de existir na tela de perfil, então o cenário cai em `test.skip()` quando o link não está visível. Quando presente, ele navega e o spec ainda asserta o padrão da **rota legada `/user/qrcode/enterprise`** (`toHaveURL(/\/user\/qrcode\/enterprise/)`); no código, essa rota redireciona para `/user/edit/feedback-general` (`user.tsx`), mas o spec não verifica o destino final do redirect. (Spec: `[CT-UC12-03] Link para QR Code da empresa está presente no perfil`.)
- **[CT-UC12-04]** ✅ *Coberto E2E — atualizado/realocado* - Catálogo acessível fora do perfil: o cenário não valida mais um link de catálogo dentro do perfil. Agora acessa diretamente `/user/edit/types-feedback` (área "Configuração da coleta", fora do perfil) e confirma que a tela responde na rota. (Spec: `[CT-UC12-04] Configuração do catálogo é acessível`.)
- **[CT-UC12-06]** ✅ *Coberto E2E* - Logout: o logout redireciona para a página de login. (Spec: `[CT-UC12-06] Logout redireciona para página de login`.)
- **[CT-UC12-07]** ✅ *Coberto E2E* - Rota protegida: usuário não autenticado é redirecionado para o login ao acessar rota protegida. (Spec: `[CT-UC12-07] Usuário não autenticado é redirecionado para login ao acessar rota protegida`.)
- **[CT-UC12-08]** 📝 *Planejado / não implementado* - Caminho feliz — nome: gestor edita o nome, salva e confirma que o novo nome aparece no perfil.
- **[CT-UC12-09]** 📝 *Planejado / não implementado* - Caminho feliz — e-mail: gestor informa novo e-mail válido e recebe a mensagem de sucesso (a confirmação nos dois e-mails é feita fora do app). **Hoje falha:** o gateway responde `400 update_failed` e a área logada fica em branco (ver as limitações conhecidas).
- **[CT-UC12-10]** 📝 *Planejado / não implementado* - Caminho feliz — telefone: gestor informa novo número, clica em "Enviar SMS", insere o código e o telefone é atualizado. **Hoje:** não há SMS, o número é gravado no primeiro passo e a confirmação falha com `400 invalid_payload` (ver as limitações conhecidas).
- **[CT-UC12-11]** 📝 *Planejado / não implementado* - Caminho feliz — cancelar telefone: durante o modo de edição ou verificação, clicar em "Cancelar" deve voltar ao modo de visualização sem alterar o número.
- **[CT-UC12-12]** 🔵 *Unidade já atende* - Exceção — nome vazio: tentar salvar com campo de nome vazio deve bloquear o envio.
- **[CT-UC12-13]** 🔵 *Unidade já atende* - Exceção — telefone inválido: informar número fora do padrão `+55 DDD NÚMERO` deve bloquear o formulário antes de enviar o SMS.
- **[CT-UC12-14]** ⛔ *Obsoleto* - Exceção — código inválido: sem provedor de SMS, o gateway não confere o código (`/phone/verify` é um no-op), então não existe código errado a testar.
