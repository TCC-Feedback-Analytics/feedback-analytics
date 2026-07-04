# Higienização de Dados Sensíveis no JWT (LGPD)

## O Que É

Quando uma empresa se cadastra, o provedor de autenticação (Supabase Auth) naturalmente armazena e trafega os dados do cadastro — incluindo CPF/CNPJ e telefone — em seu payload interno, que pode ser codificado dentro do token JWT.

O sistema intercepta esse momento e **remove proativamente esses dados sensíveis** do payload do provedor de Auth, transferindo-os exclusivamente para a tabela `enterprise`, que é protegida por Row Level Security (RLS). O objetivo é que os dados pessoais sensíveis não sejam incluídos no payload do JWT.

---

## Por Que Existe

### O problema com dados sensíveis no JWT

O token JWT é um token de sessão que circula entre cliente e servidor a cada requisição autenticada. Embora seja assinado (não pode ser alterado), ele pode ser **decodificado por qualquer pessoa** que o intercepte — o conteúdo do payload não é criptografado, apenas codificado em Base64.

Se CPF/CNPJ e telefone ficassem no payload do provedor de Auth e consequentemente no JWT:

- Qualquer ferramenta de inspeção de rede exibiria esses dados em texto plano
- Logs de servidor poderiam capturar e armazenar informações pessoais sem intenção
- Uma eventual exposição do token significaria exposição de documento e telefone do gestor
- A empresa estaria em não-conformidade com a **LGPD** (Lei Geral de Proteção de Dados)

### A solução

O sistema trata o problema na origem: os dados sensíveis são **apagados do payload do provedor** antes que qualquer token seja gerado, e armazenados apenas em uma tabela relacional com isolamento por empresa (RLS).

---

## Como Funciona

```
Empresa finaliza o cadastro
        ↓
Supabase Auth processa o signUp e armazena os dados no payload interno
        ↓
Trigger no banco dispara imediatamente
        ↓
Função apaga CPF/CNPJ e telefone do payload JSON do provedor de Auth
        ↓
Esses dados são transferidos exclusivamente para a tabela enterprise
        ↓
A tabela enterprise tem RLS: cada empresa só acessa seus próprios dados
        ↓
O JWT gerado não contém nenhum dado sensível — apenas identificadores seguros
```

---

## O Que Fica no JWT vs. O Que Fica no Banco

| Dado | JWT | Tabela `enterprise` (RLS) |
|---|---|---|
| ID do usuário (`auth_user_id`) | ✅ Sim | ✅ Sim |
| E-mail | ✅ Sim | ✅ Sim |
| Role / `enterprise_id` (claims) | ✅ Sim | ✅ Sim |
| CPF / CNPJ | ❌ Nunca | ✅ Sim, protegido por RLS |
| Telefone | ❌ Nunca | ✅ Sim, protegido por RLS |
| Termos de aceite | ❌ Nunca | ✅ Sim, protegido por RLS |

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Apoio à conformidade LGPD** | Reduz o risco de dados pessoais sensíveis trafegarem em tokens que podem ser inspecionados |
| **Princípio da minimização** | O JWT carrega apenas o necessário para autenticação — nada além disso |
| **Segurança por design** | A proteção existe na camada de banco, não dependendo de configuração ou disciplina do desenvolvedor |
| **Isolamento multi-tenant** | RLS garante que nenhuma empresa acesse dados de outra, mesmo que o token seja comprometido |
| **Rastreabilidade** | Dados sensíveis ficam em um único lugar auditável, não espalhados pelo sistema |

---

## Detalhes Técnicos

- O trigger é implementado como função PostgreSQL executada no evento de criação de conta no Supabase Auth
- Os campos removidos do payload: documento (CPF/CNPJ), telefone, e termos de aceite
- O JWT customizado carrega apenas claims seguros: `role`, `enterprise_id` (via `jwt_custom_claims`)
- A tabela `enterprise` tem políticas RLS que usam `auth.uid() = auth_user_id` para isolamento
- A remoção é feita via operações `jsonb` no PostgreSQL, de forma transacional, minimizando a janela em que os dados ficariam acessíveis

---

## Referência Técnica

- [Requisitos Não Funcionais — RNF02](../concepcao/requisitos-e-funcionalidades.md#requisitos-não-funcionais-rnf)
- [Regras de Negócio — RNE-011](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
- [Endpoints de Autenticação](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
