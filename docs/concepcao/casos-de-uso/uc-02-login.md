# UC-02: Login da Empresa

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Autenticar-se e acessar o dashboard da empresa |
| **Gatilho** | Gestor acessa a tela de login |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a tela de login.
2. Preenche e-mail e senha.
3. Clica em "Entrar".
4. O sistema valida as credenciais pelo **Better Auth** (endpoint `POST /api/public/auth/login` no api-gateway).
5. A sessão é criada e entregue em um **cookie httpOnly**; o gestor é redirecionado para o dashboard.

> **Como funciona:** a autenticação usa o **Better Auth** por baixo — o web só chama os endpoints do api-gateway e envia as requisições com credencial (cookie). As tabelas de sessão/usuário ficam no Postgres.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Credenciais inválidas (e-mail ou senha errados) | Exibe mensagem de erro sem revelar qual campo está incorreto |
| Muitas tentativas seguidas (rate limit) | Bloqueia temporariamente e exibe mensagem pedindo para aguardar antes de tentar novamente |
| Servidor de autenticação indisponível | Exibe mensagem informando que o serviço está temporariamente indisponível |
| Sem conexão com a internet | Exibe mensagem pedindo para verificar a conexão |
| Conta não ativada (e-mail não confirmado) | Por segurança (RNE-014 — proteção contra enumeração de usuários), exibe a **mesma** mensagem genérica de credenciais inválidas, sem revelar que a conta existe mas ainda não foi confirmada. O reenvio de confirmação continua disponível pelos fluxos de pós-cadastro e de link de ativação expirado |

---

## Base para Teste E2E

> Os testes E2E já estão implementados no Playwright ([uc-02-login.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-02-login.spec.ts)).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC02-01]** ✅ *Coberto E2E* - Caminho feliz: gestor insere credenciais válidas, clica em "Entrar" e é redirecionado para o dashboard.
- **[CT-UC02-02]** ✅ *Coberto E2E* - Exceção — credenciais inválidas: inserir senha errada deve exibir mensagem de erro sem redirecionar.
- **[CT-UC02-03]** 🚫 *Não é possível testar com Playwright* - Exceção — rate limit: após múltiplas tentativas incorretas, deve exibir mensagem de bloqueio temporário.
- **[CT-UC02-04]** 🔵 *Unidade já atende* - Exceção — campos vazios: tentar enviar o formulário sem preencher os campos deve destacá-los como obrigatórios.
