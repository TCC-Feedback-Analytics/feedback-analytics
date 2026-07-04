# UC-03: Recuperação de Senha

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Redefinir a senha da conta quando o acesso for perdido |
| **Gatilho** | Gestor clica em "Esqueci minha senha" na tela de login |

---

## Fluxo Principal (Caminho Feliz)

**Etapa 1 — Solicitar redefinição:**

1. O gestor acessa a tela de recuperação de senha.
2. Informa o e-mail cadastrado.
3. Clica em "Enviar".
4. O sistema exibe uma mensagem genérica confirmando o envio (independente do e-mail existir ou não — por segurança).
5. O gestor recebe o e-mail com o link de redefinição.

**Etapa 2 — Redefinir a senha:**

1. O gestor clica no link recebido por e-mail.
2. O link abre a tela de redefinição de senha com uma sessão temporária ativa.
3. O gestor digita a nova senha e confirma.
4. O sistema valida e salva a nova senha.
5. O gestor é redirecionado para o login para acessar com a nova senha.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| E-mail informado não está cadastrado | Exibe a mesma mensagem genérica de sucesso (não revela se o e-mail existe) |
| Muitas tentativas de solicitação (rate limit) | Bloqueia temporariamente e exibe mensagem pedindo para aguardar |
| Link de redefinição expirado ou inválido | Exibe mensagem informando que o link não é mais válido e orienta a solicitar um novo |
| Nova senha não atende aos requisitos mínimos | Bloqueia o envio e indica o que precisa ser corrigido |
| Campos de senha e confirmação não coincidem | Bloqueia o envio e destaca a inconsistência |

---

## Base para Teste E2E

> **Este UC não possui cobertura E2E no Playwright.** Não existe arquivo `uc-03-*.spec.ts` em `feedback-analytics-web/e2e/` — o fluxo depende de recebimento de e-mail em tempo real e esbarra no rate limit de e-mail do Supabase em testes automatizados. Os cenários abaixo descrevem o comportamento esperado e a estratégia de cobertura por outros meios (unidade/manual), mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC03-01]** 📝 *Planejado / não implementado* - Caminho feliz: gestor informa e-mail válido, recebe link, acessa a tela de redefinição, define nova senha e consegue fazer login com ela. Sem cobertura E2E (depende de e-mail real).
- **[CT-UC03-02]** 📝 *Planejado / não implementado* - Exceção — e-mail inexistente: informar e-mail não cadastrado deve exibir a mesma mensagem genérica de sucesso (sem revelar que não existe). Sem cobertura E2E.
- **[CT-UC03-03]** ❌ *Cenário não coberto* - Exceção — link expirado: acessar link de redefinição já expirado deve exibir mensagem de link inválido com orientação.
- **[CT-UC03-04]** 🔵 *Unidade já atende* - Exceção — senhas divergentes: digitar senhas diferentes nos dois campos deve bloquear o envio com mensagem de inconsistência.
