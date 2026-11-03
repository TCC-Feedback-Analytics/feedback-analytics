# Higienização de Dados Sensíveis no JWT (LGPD)

## O Que É

É o cuidado de **não deixar dado pessoal sensível do gestor circular na sessão** e de guardar só o que o sistema usa.

A página nasceu na época do **Supabase Auth**: o provedor guardava os dados do cadastro (CPF/CNPJ e telefone) no payload interno do usuário, que podia ir parar no token JWT. Um trigger no banco apagava esses campos do payload e os movia para a tabela `enterprise`, protegida por RLS.

> **Situação atual:** a autenticação migrou para o **Better Auth**, e não há mais JWT. A sessão é um **cookie httpOnly** com um token opaco, conferido no banco a cada requisição. O CPF/CNPJ **deixou de ser pedido e guardado** (migration `0009` do gateway). O trigger de higienização não existe mais: o problema que ele resolvia sumiu com a troca do provedor. O princípio continua valendo e está descrito abaixo.

---

## Por Que Existe

### O problema com dados sensíveis em token

Um token JWT circula entre cliente e servidor a cada requisição autenticada. Embora seja assinado (não pode ser alterado), ele pode ser **decodificado por qualquer pessoa** que o intercepte — o conteúdo do payload não é criptografado, apenas codificado em Base64.

Se documento e telefone ficassem dentro do token:

- Qualquer ferramenta de inspeção de rede exibiria esses dados em texto plano
- Logs de servidor poderiam capturar e armazenar informações pessoais sem intenção
- Uma eventual exposição do token significaria exposição de documento e telefone do gestor
- O sistema iria contra a **minimização** pedida pela **LGPD** (Lei Geral de Proteção de Dados)

### Como o sistema trata isso hoje

- **A sessão não carrega dados.** O cookie leva só o token da sessão, assinado pelo Better Auth. Usuário, e-mail e telefone ficam no banco e são lidos pelo gateway quando ele valida a sessão.
- **O navegador não lê o token.** O cookie é `httpOnly`: o JavaScript da página não tem acesso a ele, e a Web não guarda sessão em `localStorage`.
- **O que não é usado não é guardado.** O CPF/CNPJ (e o tipo de conta CPF/CNPJ) saiu do cadastro e do banco, porque nada no sistema o usava.

---

## Como Funciona

```
Gestor se cadastra (e-mail e senha) ou entra com o Google
        ↓
Better Auth cria o usuário (user), a credencial (account) e,
no login, a sessão (session)
        ↓
Gateway cria a empresa (enterprise) com o aceite dos termos e as 3 perguntas padrão
        ↓
Resposta do login define o cookie httpOnly com o token da sessão
        ↓
A cada requisição protegida, o middleware requireAuth valida a sessão
no banco e resolve a empresa do usuário (req.enterpriseId)
        ↓
Todas as consultas filtram pelo enterprise_id resolvido no servidor
```

---

## O Que Fica no Cookie vs. O Que Fica no Banco

| Dado | Cookie de sessão | Banco |
|---|---|---|
| Token da sessão | ✅ Só ele, assinado | ✅ `session.token` |
| ID do usuário | ❌ | ✅ `user.id` (`enterprise.auth_user_id` liga a empresa) |
| E-mail | ❌ | ✅ `user.email` |
| Telefone | ❌ | ✅ `user.phone` (único por conta) |
| Termos de aceite | ❌ | ✅ `enterprise.terms_version`, `enterprise.terms_accepted_at` |
| CPF / CNPJ | ❌ | ❌ Não é mais guardado |

O telefone e o e-mail só voltam para a Web no `GET /api/protected/user/auth_user`, para o próprio gestor, a partir da sessão.

---

## Isolamento e Acesso ao Banco

- **Isolamento por empresa na aplicação.** O `enterprise_id` vem da sessão, nunca do payload, e todo repositório filtra por ele (`src/db/tenantScope.ts` do gateway).
- **Papel `feedback_app`.** O gateway entra no banco com um papel que só lê e escreve dados: não cria, altera nem apaga tabelas, não desliga a RLS nem cria usuários (migration `0013`).
- **RLS ligada em todas as tabelas,** com uma policy que deixa passar só o `feedback_app`. Ela barra outros papéis, como o `anon` e o `authenticated` do Supabase, mas não separa uma empresa da outra: essa separação é a da aplicação (veja [ORM × RLS](../arquitetura/orm-rls-decisao.md)).

---

## Exclusão da Conta

O gestor pode apagar a conta e todos os dados da empresa pelo **Perfil**, na seção "Excluir minha conta" (LGPD, art. 18).

- A Web pede a senha a quem tem uma e a palavra EXCLUIR para liberar o botão. Quem só entra pelo Google precisa ter entrado nas últimas 24 horas.
- O gateway apaga, numa transação, a empresa e tudo dela (feedbacks, análises, catálogo, perguntas, pontos de coleta, aparelhos, clientes, contexto da empresa, configuração de IA, jobs e diagnósticos). Depois o Better Auth apaga o usuário, as sessões e as credenciais.
- Não há volta.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Apoio à conformidade LGPD** | Dado pessoal não trafega em token legível; o que não é usado não é coletado |
| **Princípio da minimização** | O cookie carrega só o token; o CPF/CNPJ saiu do sistema |
| **Sessão protegida no navegador** | Cookie `httpOnly`: um script na página não consegue ler a sessão |
| **Isolamento multi-tenant** | A empresa vem da sessão e filtra todas as consultas |
| **Direito de exclusão** | O próprio gestor apaga a conta e os dados da empresa |

---

## Detalhes Técnicos

- A configuração da sessão fica em `src/auth/auth.ts` do gateway: cookie `httpOnly`, `SameSite=Lax` (ou `None` com `Secure` quando Web e API estão em domínios diferentes) e `Secure` em produção
- O middleware `requireAuth` chama `getAuth().api.getSession()` e resolve a empresa com `SELECT id FROM enterprise WHERE auth_user_id = <usuário>`. Não há header `Authorization: Bearer`
- A empresa é criada por `provisionEnterpriseForUser` (`src/auth/enterpriseOnSignup.ts`), chamado pelo cadastro com senha, pelo "Complete seu cadastro" e na primeira entrada com o Google. Ela substitui o antigo trigger do Supabase
- A exclusão de conta é o `POST /api/auth/delete-user` do Better Auth, com `deleteEnterpriseOfUser` (`src/auth/enterpriseOnDelete.ts`) rodando antes de apagar o usuário
- Para a lista completa de dados pessoais, veja o [inventário de dados](../seguranca/inventario-de-dados.md)

---

## Referência Técnica

- [Requisitos Não Funcionais — RNF02](../concepcao/requisitos-e-funcionalidades.md#requisitos-não-funcionais-rnf)
- [Regras de Negócio — RNE-011](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
- [Endpoints de Autenticação](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
