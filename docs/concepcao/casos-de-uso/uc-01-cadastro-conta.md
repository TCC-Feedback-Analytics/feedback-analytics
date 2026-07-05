# UC-01: Cadastro de Conta Empresarial

| Campo | Valor |
|---|---|
| **Ator** | Empresa (novo cliente) |
| **Objetivo** | Criar uma conta e ativá-la para começar a usar o produto |
| **Gatilho** | Visitante clica em "Cadastrar" na landing page ou na tela de login |

---

## Fluxo Principal (Caminho Feliz)

1. O visitante acessa a tela de cadastro.
2. Preenche os dados: nome completo, e-mail, senha, documento (CPF ou CNPJ), telefone e aceite dos termos de uso.
3. Clica em "Criar conta".
4. O sistema valida os dados e cria a conta pelo **Better Auth** (o api-gateway registra o usuário; as tabelas de auth ficam no Postgres).
5. Na sequência, o onboarding cria a empresa (`enterprise`) com `trial_ends_at = NOW() + 4 meses` e `subscription_status = 'TRIAL'`, semeia as 3 perguntas padrão e higieniza os dados sensíveis do cadastro.
6. O **api-gateway** envia um e-mail de confirmação para o endereço informado, via SMTP (SendGrid em produção, Mailpit no local).
7. O visitante abre o e-mail e clica no link de ativação.
8. O sistema redireciona para a tela de sucesso confirmando a ativação.
9. A conta está ativa e o gestor já pode fazer login.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| E-mail já cadastrado na plataforma | O sistema segue normalmente para a tela de sucesso — não revela se o e-mail existe. O e-mail de confirmação não chegará. A tela de sucesso orienta o gestor sobre o que fazer caso isso aconteça (verificar spam, solicitar reenvio, esqueceu senha, ir para login) |
| Documento inválido (CPF ou CNPJ não passa na validação matemática) | Rejeita o cadastro e informa que o documento é inválido |
| Telefone fora do padrão brasileiro | Rejeita o campo e informa o formato esperado |
| Termos de uso não aceitos | Impede o envio do formulário |
| E-mail de confirmação não chegou | O gestor pode solicitar o reenvio do e-mail de ativação |
| Link de confirmação expirado | O sistema orienta o gestor a solicitar um novo e-mail de ativação |

---

## Base para Teste E2E

> Os testes E2E já estão implementados no Playwright ([uc-01-cadastro-conta.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-01-cadastro-conta.spec.ts)).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC01-01]** 📝 *Planejado / não implementado* - Caminho feliz: preencher todos os campos válidos, enviar, receber e-mail de confirmação e ativar a conta pelo link. Não há teste E2E correspondente no spec (depende de recebimento de e-mail real).
- **[CT-UC01-02]** ✅ *Coberto E2E* - Exceção — e-mail duplicado (prevenção de enumeração): tentar cadastrar com e-mail já existente deve **seguir para a tela de sucesso** normalmente, sem revelar que o e-mail já está em uso. (Spec: `[CT-UC01-02] Segue para a tela de sucesso ao tentar cadastrar com e-mail já existente`.)
- **[CT-UC01-03]** ✅ *Coberto E2E* - Exceção — documento já cadastrado: tentar cadastrar com um CPF/CNPJ já existente na base deve exibir mensagem de erro de documento duplicado. (Spec: `[CT-UC01-03] Exibe erro ao tentar cadastrar com documento já existente`.)
- **[CT-UC01-04]** 🔵 *Unidade já atende* - Exceção — documento inválido: inserir CPF ou CNPJ inválido (que não passa no cálculo matemático) deve bloquear o envio.
- **[CT-UC01-05]** 🔵 *Unidade já atende* - Exceção — telefone inválido: inserir telefone fora do padrão BR deve bloquear o campo.
- **[CT-UC01-06]** 🔵 *Unidade já atende* - Exceção — termos não aceitos: tentar enviar sem marcar os termos deve impedir o cadastro.
- **[CT-UC01-07]** ❌ *Cenário não coberto* - Exceção — reenvio de e-mail: solicitar reenvio do e-mail de confirmação deve funcionar e exibir confirmação de envio.
