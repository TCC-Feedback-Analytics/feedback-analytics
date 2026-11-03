# UC-01: Cadastro de Conta Empresarial

| Campo | Valor |
|---|---|
| **Ator** | Empresa (novo cliente) |
| **Objetivo** | Criar uma conta e ativá-la para começar a usar o produto |
| **Gatilho** | Visitante clica em "Começar agora" na landing page, em "Registrar" no cabeçalho ou em "Cadastre-se" na tela de login |

---

## Fluxo Principal (Caminho Feliz)

1. O visitante acessa a tela de cadastro (`/register`).
2. Preenche os dados: nome do negócio (vale para pessoa física ou jurídica), e-mail, celular no formato `+55DDXXXXXXXXX`, senha, confirmação da senha e aceite dos termos. Um medidor mostra a força da senha enquanto ela é digitada. O cadastro não pede CPF nem CNPJ: o sistema não usa esse dado e não o guarda (LGPD).
3. Clica em "Criar Conta".
4. O sistema valida os dados e cria a conta pelo **Better Auth** (o api-gateway registra o usuário; as tabelas de auth ficam no Postgres).
5. Na sequência, o provisionamento cria a empresa (`enterprise`) com `trial_ends_at = NOW() + 4 meses` e `subscription_status = 'TRIAL'` e semeia as 3 perguntas padrão do formulário geral.
6. A tela passa a mostrar "Confirme seu e-mail", com o e-mail digitado, o botão "Abrir o <provedor>" quando reconhece o provedor do e-mail, o reenvio e o link "Já confirmei · Ir para login".
7. O **api-gateway** envia um e-mail de confirmação para o endereço informado, via SMTP (Brevo em produção, Mailpit no local).
8. O visitante abre o e-mail e clica no link de ativação, que passa pelo `/api/auth/verify-email` do Better Auth.
9. O sistema abre a tela "Conta verificada" e, em 1,5 s, leva ao dashboard: o Better Auth já abre a sessão ao verificar o e-mail. Na primeira entrada, o painel pede o contexto da empresa para a IA (UC-08).

### Fluxo alternativo — Criar conta com Google

Disponível só quando a Web está com `VITE_GOOGLE_AUTH_ENABLED=true` (as credenciais do Google ficam no gateway).

1. Na tela de cadastro, o visitante clica em "Criar conta com Google" e autoriza no Google.
2. Na volta, como a conta é nova, o sistema abre "Complete seu cadastro" (`/auth/complete-signup`), com o nome do negócio já preenchido com o nome vindo do Google.
3. O visitante informa o celular, aceita os termos e salva; o sistema vai para o dashboard.
4. Não há e-mail de confirmação: o Google já entrega o e-mail verificado. Enquanto o telefone não for informado, qualquer acesso à área logada volta para "Complete seu cadastro".

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| E-mail já cadastrado na plataforma | O sistema segue normalmente para a tela "Confirme seu e-mail" — não revela se o e-mail existe (RNE-014). O e-mail de confirmação não chegará; a tela oferece o reenvio e o link para o login |
| Telefone já cadastrado em outra conta | Exibe "Telefone ja cadastrado." e pede outro número (`409 phone_taken`); no "Complete seu cadastro", o erro aparece no campo de telefone |
| Telefone fora do padrão brasileiro | Rejeita o campo e informa o formato esperado (`+55DDXXXXXXXXX`, com DDD e número válidos) |
| Senha com menos de 10 caracteres ou fácil de adivinhar | Bloqueia o cadastro e explica o motivo: a senha precisa de nota 4 no zxcvbn, e nome do negócio, e-mail e telefone dentro dela derrubam a nota |
| Senha e confirmação diferentes | Bloqueia o envio com "As senhas não conferem" |
| Termos de uso não aceitos | Impede o envio do formulário |
| Muitas tentativas, cadastro indisponível ou sem conexão | Exibe toast com a orientação correspondente ("Muitas tentativas em pouco tempo", "Cadastro temporariamente indisponivel" ou "Falha de conexao") |
| E-mail de confirmação não chegou | O gestor pode pedir o reenvio na tela "Confirme seu e-mail", em `/resend-confirmation` (pelo "Problemas para entrar?" do login) ou na tela de link expirado. A resposta é sempre genérica, e o botão espera o tempo devolvido pelo gateway ("Solicitar novamente em mm:ss"): 60 s entre reenvios do mesmo e-mail, até 5 por hora por e-mail e 20 a cada 15 min por IP |
| Link de confirmação expirado ou inválido | O sistema leva a `/auth/link-expired`, que pede o e-mail e oferece um novo envio |
| Falha ao entrar com o Google | O botão mostra "Não deu para entrar com o Google. Tente de novo ou use e-mail e senha." |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC01-01]** 📝 *Planejado / não implementado* - Caminho feliz: preencher todos os campos válidos, enviar, receber e-mail de confirmação e ativar a conta pelo link. Não há teste E2E correspondente no spec (depende de recebimento de e-mail real).
- **[CT-UC01-02]** ✅ *Coberto E2E* - Exceção — e-mail duplicado (prevenção de enumeração): tentar cadastrar com e-mail já existente deve **seguir para a tela "Confirme seu e-mail"** normalmente, sem revelar que o e-mail já está em uso. (Spec: `[CT-UC01-02] Segue para a tela de sucesso ao tentar cadastrar com e-mail já existente`.)
- **[CT-UC01-03]** ⛔ *Obsoleto* - Exceção — documento já cadastrado: o cadastro não pede mais CPF/CNPJ, então o cenário não se aplica. A checagem de duplicidade que existe hoje é a do telefone (`409 phone_taken`), sem cenário próprio. (Spec antigo: `[CT-UC01-03] Exibe erro ao tentar cadastrar com documento já existente`.)
- **[CT-UC01-04]** ⛔ *Obsoleto* - Exceção — documento inválido: não há mais campo de CPF/CNPJ no cadastro.
- **[CT-UC01-05]** 🔵 *Unidade já atende* - Exceção — telefone inválido: inserir telefone fora do padrão BR deve bloquear o campo.
- **[CT-UC01-06]** 🔵 *Unidade já atende* - Exceção — termos não aceitos: tentar enviar sem marcar os termos deve impedir o cadastro.
- **[CT-UC01-07]** ❌ *Cenário não coberto* - Exceção — reenvio de e-mail: solicitar reenvio do e-mail de confirmação deve exibir a confirmação genérica de envio e iniciar a contagem até o próximo reenvio.
