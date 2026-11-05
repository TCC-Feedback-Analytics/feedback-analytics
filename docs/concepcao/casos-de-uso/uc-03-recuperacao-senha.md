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
2. O link passa pelo `GET /api/public/auth/callback` do gateway, que grava o token no cookie httpOnly `ba_reset` (vale 1 h e só é enviado para a troca de senha) e abre direto a tela de redefinição (`/auth/reset-password`, "Redefina sua senha").
3. O gestor digita a nova senha (mínimo de 10 caracteres) e a confirmação e clica em "Redefinir senha".
4. O sistema valida a senha com a mesma regra do cadastro e salva usando o cookie `ba_reset`, não a sessão; com sucesso, o cookie é apagado.
5. O gestor é redirecionado para o login (`/login?reset=success`) para acessar com a nova senha. A tela de login lê esse parâmetro e mostra "Senha alterada. Entre com a nova senha."

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| E-mail informado não está cadastrado | Exibe a mesma mensagem genérica de sucesso (não revela se o e-mail existe) |
| Muitas tentativas, falha do servidor, sem conexão ou e-mail malformado | Exibe o toast "Não foi possível enviar" com o motivo |
| Link de redefinição expirado ou inválido | A tela de redefinição abre normalmente; ao enviar a nova senha, o gateway recusa (`401 reset_password_invalid_token`) e a tela mostra o toast "Erro ao redefinir senha" com "O link de redefinição expirou ou é inválido. Solicite um novo." |
| Nova senha não atende aos requisitos mínimos | Bloqueia o envio e indica o que precisa ser corrigido (menos de 10 caracteres no formulário; senha fácil de adivinhar, recusada pelo gateway com `reset_password_weak`) |
| Campos de senha e confirmação não coincidem | Bloqueia o envio e destaca a inconsistência |

---

## Base para Teste E2E

> **Este UC não possui cobertura E2E automatizada.** A suíte Playwright (e2e) foi **removida** e, mesmo antes disso, este fluxo nunca teve spec próprio — depende de recebimento de e-mail em tempo real, inviável em testes automatizados. Os cenários abaixo descrevem o comportamento esperado e a estratégia de cobertura por outros meios (unidade/manual): a verificação manual dos demais fluxos de interface do Web está no [runbook de testes manuais do Web](../../guias/testes/manuais-web.md), e a classificação de cada cenário está mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC03-01]** 📝 *Planejado / não implementado* - Caminho feliz: gestor informa e-mail válido, recebe link, acessa a tela de redefinição, define nova senha e consegue fazer login com ela. Sem cobertura E2E (depende de e-mail real).
- **[CT-UC03-02]** 📝 *Planejado / não implementado* - Exceção — e-mail inexistente: informar e-mail não cadastrado deve exibir a mesma mensagem genérica de sucesso (sem revelar que não existe). Sem cobertura E2E.
- **[CT-UC03-03]** ❌ *Cenário não coberto* - Exceção — link expirado: acessar link de redefinição já expirado deve exibir mensagem de link inválido com orientação.
- **[CT-UC03-04]** 🔵 *Unidade já atende* - Exceção — senhas divergentes: digitar senhas diferentes nos dois campos deve bloquear o envio com mensagem de inconsistência.
