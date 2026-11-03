# UC-02: Login da Empresa

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Autenticar-se e acessar o dashboard da empresa |
| **Gatilho** | Gestor acessa a tela de login |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a tela de login (`/login`).
2. Preenche e-mail e senha e, se quiser, marca "Lembrar de mim".
3. Clica em "Entrar". O botão fica em "Entrando..." até o dashboard carregar.
4. O sistema valida as credenciais pelo **Better Auth** (endpoint `POST /api/public/auth/login` no api-gateway).
5. A sessão é criada e entregue em um **cookie httpOnly**; o gestor é redirecionado para `/user/dashboard?login=success`, que mostra o toast "Login realizado com sucesso." e tira o parâmetro da URL.

> **Como funciona:** a autenticação usa o **Better Auth** por baixo — o web só chama os endpoints do api-gateway e envia as requisições com credencial (cookie). As tabelas de sessão/usuário ficam no Postgres. Toda tela da área logada confere a sessão antes de abrir: sem sessão, volta para `/login`; sem telefone cadastrado (primeira entrada com o Google), vai para "Complete seu cadastro".

### Fluxo alternativo — Entrar com Google

Disponível só quando a Web está com `VITE_GOOGLE_AUTH_ENABLED=true`.

1. Na tela de login, o gestor clica em "Continuar com Google" e autoriza no Google.
2. Na volta, o gateway entrega o cookie de sessão. Conta que já existe vai para o dashboard; conta nova vai para "Complete seu cadastro" (UC-01).
3. Mesmo e-mail com senha e com Google é a mesma conta.

### Fluxo alternativo — Problemas para entrar

O link fixo "Problemas para entrar?" abre um dialog com "Redefinir senha" (UC-03) e "Reenviar e-mail de confirmação" (`/resend-confirmation`). Depois de uma tentativa recusada por credenciais inválidas, esse dialog abre sozinho. Nenhuma das opções põe o e-mail na URL.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Credenciais inválidas (e-mail ou senha errados) | Exibe o toast "E-mail ou senha incorretos." sem revelar qual campo está incorreto e abre o dialog "Problemas para entrar?" |
| Muitas tentativas seguidas (rate limit) | Exibe "Muitas tentativas de login." — "Aguarde alguns instantes antes de tentar novamente." |
| Servidor de autenticação indisponível | Exibe "Serviço de login temporariamente indisponível." |
| Sem conexão com a internet | Exibe "Falha de conexão." pedindo para verificar a internet |
| Conta não ativada (e-mail não confirmado) | Por segurança (RNE-014 — proteção contra enumeração de usuários), exibe a **mesma** mensagem genérica de credenciais inválidas, sem revelar que a conta existe mas ainda não foi confirmada. O reenvio de confirmação continua disponível no dialog "Problemas para entrar?", na tela pós-cadastro e na de link de ativação expirado |
| Falha ao entrar com o Google | Volta para `/login?error=google`, e o botão mostra "Não deu para entrar com o Google. Tente de novo ou use e-mail e senha." |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC02-01]** ✅ *Coberto E2E* - Caminho feliz: gestor insere credenciais válidas, clica em "Entrar" e é redirecionado para o dashboard.
- **[CT-UC02-02]** ✅ *Coberto E2E* - Exceção — credenciais inválidas: inserir senha errada deve exibir mensagem de erro sem redirecionar.
- **[CT-UC02-03]** 🚫 *Não é possível testar com Playwright* - Exceção — rate limit: após múltiplas tentativas incorretas, deve exibir mensagem de bloqueio temporário.
- **[CT-UC02-04]** 🔵 *Unidade já atende* - Exceção — campos vazios: tentar enviar o formulário sem preencher os campos deve destacá-los como obrigatórios.
