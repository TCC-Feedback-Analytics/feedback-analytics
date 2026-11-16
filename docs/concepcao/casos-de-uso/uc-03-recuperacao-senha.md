# UC-03: Recuperação de Senha

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Redefinir a senha da conta quando o acesso for perdido |
| **Gatilho** | Gestor clica em "Esqueci minha senha" na tela de login (ou em "Redefinir senha", no dialog "Problemas para entrar?") |

---

## Fluxo Principal (Caminho Feliz)

**Etapa 1 — Solicitar redefinição:**

1. O gestor acessa a tela de recuperação de senha (`/forgot-password`, "Recupere seu acesso").
2. Informa o e-mail cadastrado.
3. Clica em "Enviar instruções".
4. O sistema exibe o toast "E-mail enviado!" com a mensagem genérica "Se este e-mail estiver cadastrado, você receberá as instruções em breve." (independente do e-mail existir ou não — por segurança).
5. O **api-gateway** dispara, via **Better Auth**, o e-mail com o link de redefinição (enviado por SMTP — Brevo em produção, Mailpit no local) e o gestor o recebe.

**Etapa 2 — Redefinir a senha:**

1. O gestor clica no link recebido por e-mail.
2. O link passa primeiro pelo `GET /api/auth/reset-password/<token>` do Better Auth, que confere o token, e depois pelo `GET /api/public/auth/callback` do gateway, que grava o token no cookie httpOnly `ba_reset` (vale 1 h e só é enviado para a troca de senha) e abre direto a tela de redefinição (`/auth/reset-password`, "Redefina sua senha").
3. O gestor digita a nova senha (mínimo de 10 caracteres) e a confirmação e clica em "Redefinir senha".
4. O sistema valida a senha com o mesmo tamanho mínimo e a mesma nota no zxcvbn do cadastro, mas sem checar o nome do negócio, o e-mail e o telefone dentro dela; a tela não tem medidor de força. Depois salva usando o cookie `ba_reset`, não a sessão; com sucesso, o cookie é apagado.
5. O gestor é redirecionado para o login (`/login?reset=success`) para acessar com a nova senha. A tela de login lê esse parâmetro e mostra "Senha alterada. Entre com a nova senha."

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| E-mail informado não está cadastrado | Exibe a mesma mensagem genérica de sucesso (não revela se o e-mail existe) |
| E-mail malformado | O formulário bloqueia o envio e mostra "E-mail inválido" abaixo do campo |
| Muitas tentativas, falha do servidor ou sem conexão | Exibe o toast "Não foi possível enviar" com o motivo |
| Link de redefinição expirado, inválido ou já usado | O Better Auth recusa o token e o callback do gateway leva o gestor de volta para a tela de recuperação (`/forgot-password?error=INVALID_TOKEN`), sem gravar o cookie. A tela mostra o aviso "O link de redefinição expirou ou já foi usado. Peça um novo abaixo." acima do formulário |
| Nova senha enviada depois que o prazo acabou | A tela de redefinição já estava aberta, mas o cookie `ba_reset` ou o token venceu: o gateway recusa (`401`) e a tela mostra o toast "Erro ao redefinir senha" com "O link de redefinição expirou ou é inválido. Solicite um novo." |
| Nova senha não atende aos requisitos mínimos | Bloqueia o envio e indica o que precisa ser corrigido (menos de 10 caracteres no formulário; senha fácil de adivinhar, recusada pelo gateway com `reset_password_weak`) |
| Campos de senha e confirmação não coincidem | Bloqueia o envio e destaca a inconsistência |

---

## Base para Teste E2E

> **Este UC não possui cobertura E2E automatizada.** A suíte Playwright (e2e) foi **removida** e, mesmo antes disso, este fluxo nunca teve spec próprio — depende de recebimento de e-mail em tempo real, inviável em testes automatizados. Os cenários abaixo descrevem o comportamento esperado e a estratégia de cobertura por outros meios (unidade/manual): a verificação manual dos demais fluxos de interface do Web está no [runbook de testes manuais do Web](../../guias/testes/manuais-web.md), e a classificação de cada cenário está mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC03-01]** ✅ *Coberto manual (runbook)* - Caminho feliz: gestor informa e-mail válido, recebe link, acessa a tela de redefinição, define nova senha e consegue fazer login com ela. No ambiente local, o e-mail chega no Mailpit.
- **[CT-UC03-02]** ✅ *Coberto manual (runbook)* - Exceção — e-mail inexistente: informar e-mail não cadastrado deve exibir a mesma mensagem genérica de sucesso (sem revelar que não existe).
- **[CT-UC03-03]** 🔵 *Unidade já atende* - Exceção — link expirado: abrir um link de redefinição vencido ou já usado leva a `/forgot-password?error=INVALID_TOKEN` com o aviso "O link de redefinição expirou ou já foi usado. Peça um novo abaixo.". Coberto pelos testes do callback no gateway (`src/tests/authCallback.test.ts`) e da tela na Web (`pages/tests/forgotPassword.test.tsx`).
- **[CT-UC03-04]** ✅ *Coberto manual (runbook)* - Exceção — senhas divergentes: digitar senhas diferentes nos dois campos deve bloquear o envio com "As senhas não coincidem". A regra existe no schema dos contratos, mas nenhum teste automatizado a confere.
