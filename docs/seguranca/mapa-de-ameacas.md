# Mapa de ameaças (STRIDE)

> **Em uma frase:** para cada parte do Feedback Analytics, o que um atacante (ou um erro nosso) poderia fazer, o que já protege no código e o que ainda está aberto.

Parte do [inventário de dados pessoais](inventario-de-dados.md): ele diz **o que** proteger; este documento diz **contra o quê**. Levantado no código do gateway, da Web e do ia-analyze em 02/11/2026; a situação das mitigações foi revista em 03/11/2026 e em 16/11/2026.

## Como ler

Cada ameaça leva uma letra do **STRIDE**, um método da Microsoft para não esquecer nenhum tipo de ataque:

| Letra | Ameaça | Pergunta |
|---|---|---|
| **S** | *Spoofing* (falsificação) | Alguém consegue se passar por outra pessoa ou aparelho? |
| **T** | *Tampering* (adulteração) | Alguém consegue alterar um dado que não deveria? |
| **R** | *Repudiation* (repúdio) | Alguém consegue negar que fez algo, sem que possamos provar? |
| **I** | *Information disclosure* (vazamento) | Um dado pode chegar a quem não deveria vê-lo? |
| **D** | *Denial of service* (indisponibilidade) | Alguém consegue derrubar o serviço ou gastar a cota? |
| **E** | *Elevation of privilege* (elevação) | Alguém consegue fazer mais do que deveria poder? |

A situação de cada uma: ✅ protegida · ⚠️ protegida em parte · ❌ aberta.

## Visão geral do sistema

```mermaid
flowchart LR
  C[Cliente final] -->|QR, link, NFC| W[Web na Vercel]
  G[Gestor] -->|login| W
  W -->|/api| GW[Gateway na Vercel]
  GW --> DB[(Postgres no Supabase)]
  GW --> IA[ia-analyze] --> OR[OpenRouter e modelo da empresa]
  GW --> BR[Brevo: e-mails]
  GW --> GO[Google: login]
```

## 1. Formulário público (cliente final)

Qualquer pessoa com o QR, o link ou a etiqueta abre e envia, sem login.

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **S** | Uma pessoa envia várias respostas fingindo ser clientes diferentes | Uma resposta por aparelho, ponto de coleta e dia. O aparelho é identificado por um hash de navegador e IP (`qrcode.controller.ts`), e o dia vira à meia-noite de Brasília. Um aparelho pode ser bloqueado (`is_blocked`), mas só direto no banco: o painel não tem esse botão | ⚠️ Trocar de rede ou de navegador burla o limite, e um script burla só trocando o cabeçalho User-Agent. Aceitável para métrica de satisfação, não para votação |
| **T** | Alterar a marca de canal ou o ponto de coleta na URL | O ponto de coleta precisa estar **ativo** e ser **da empresa** do pedido. A marca de canal serve só a métricas | ✅ |
| **T** | Enviar dado malformado ou gigante | O schema do contrato (`publicFeedbackSchema`) valida tudo: nota de 1 a 5, comentário até 5.000 caracteres, nome até 120 | ✅ |
| **I** | Ver respostas de outros clientes pelo formulário | O formulário só lê o nome da empresa e as perguntas; nenhuma rota pública devolve feedbacks | ✅ |
| **D** | Disparar milhares de envios para encher o banco | O limite por aparelho e dia, mas sem limite por IP nem por tempo no endpoint | ⚠️ |

## 2. Login e sessão (gestor)

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **S** | Roubar a conta adivinhando a senha | Senha guardada só como hash e força mínima da senha (`passwordStrength.ts`). O login conta as tentativas erradas no banco, por e-mail e por IP, guardando só o HMAC dos valores (`authRateLimit.ts`): 10 erros por e-mail e 100 por IP a cada 15 minutos. O login certo devolve a vaga. Bloqueado, responde `429 rate_limited`. Login com Google como alternativa | ✅ Feito (PR #110). As rotas nativas de e-mail e senha do Better Auth (`/api/auth/sign-in/email` e afins) respondem 404 desde a PR #113, então não há outra porta para tentar senhas. Em produção, o IP chega pelo repasse da Vercel e pode ser o mesmo para vários usuários |
| **S** | Não conseguir trocar a senha pelo link estando logado | O `requireAuth` lê o cookie de recuperação antes da sessão, então quem abre o link no navegador em que já está logado troca a senha (PR #113, `requireAuthResetToken.test.ts`) | ✅ |
| **S** | Continuar dentro da conta com a senha antiga depois da troca | A nova senha encerra todas as sessões da pessoa (`revokeSessionsOnPasswordReset`, `auth.ts`, PR #110) | ✅ |
| **S** | Descobrir se um e-mail tem conta (enumeração) | Cadastro sem login automático e com confirmação obrigatória de e-mail, respondendo igual nos dois casos (`register.controller.ts`). O login responde "E-mail ou senha inválidos." também para conta não confirmada (`errorMap.ts`) | ⚠️ O cadastro avisa "Telefone já cadastrado.", o que revela se um telefone tem conta |
| **S** | Roubar a sessão pelo navegador | Cookie `httpOnly` (o JavaScript da página não lê), `secure` em produção e `sameSite` | ✅ |
| **D** | Usar o "reenviar confirmação" para mandar spam | Limite por IP e por e-mail, com contagem no banco e só o HMAC dos valores (`resendRateLimit.ts`) | ✅ |
| **D** | Usar o cadastro ou a nova senha para mandar e-mails em massa | 5 pedidos por e-mail por hora e 20 por IP a cada 15 minutos, contados no banco (`authRateLimit.ts`). Na nova senha, o 429 vale para qualquer e-mail e não revela quem tem conta (PR #110) | ✅ |
| **I** | Vazar os tokens do Google guardados | Não são mais gravados: o hook `discardOAuthTokens` apaga os tokens antes de gravar a conta (`auth.ts`). A migration `0015_apagar_tokens_google.sql` apaga os tokens das contas Google antigas no deploy (PR #109 e PR #110) | ✅ |

## 3. API do painel (gateway)

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **E** | Um gestor ler ou alterar dados de **outra empresa** | A empresa vem da sessão, nunca do pedido (`middlewares/auth.ts`). Toda leitura de feedback passa por um filtro único que exige a empresa e falha se ela faltar (`db/tenantScope.ts`), com testes | ✅ |
| **S** | Outro site chamar a API usando o cookie do gestor | Cookie `sameSite=lax` e CORS só para as origens da Web (`index.ts`). Em produção, `localhost` não entra no CORS nem nas origens confiáveis do Better Auth (`localWebOrigins.ts`) | ✅ |
| **R** | Um gestor negar que pediu uma análise ou mudou algo | A fila de análises guarda quem pediu (`ia_analysis_job.requested_by`) e o aceite dos termos tem data e versão | ⚠️ Não há registro de quem alterou o quê nas configurações |
| **I** | Um erro devolver detalhes internos | As rotas devolvem códigos de erro tipados (`sendTypedError`), sem pilha de execução | ✅ |

## 4. Banco de dados

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **I** | Acessar o banco por fora do app | Data API do Supabase desligada desde 22/10/2026. RLS ligada nas 24 tabelas (migration `0013`), com uma policy que só deixa passar o papel do app, `feedback_app`; os papéis `anon` e `authenticated` do Supabase não veem nenhuma linha das tabelas. Exceções: a view `enterprise_public` (id e nome de cada empresa) roda como dona, e restam 3 funções antigas `SECURITY DEFINER`; por isso a Data API precisa continuar desligada | ✅ |
| **E** | Uma credencial do app vazar e dar acesso total | Em produção, o gateway entra no banco como `feedback_app`, que só lê e escreve dados ([banco com o mínimo de privilégio](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/banco-menor-privilegio.md)). As migrations rodam como `postgres`, com a senha só no secret do GitHub | ⚠️ Com a senha do app vazada, ainda dá para ler, alterar e apagar os dados de todas as empresas, mas não apagar tabelas, desligar a RLS nem criar papéis |
| **I** | Ler a chave de IA de uma empresa no banco | Chave cifrada com AES-256-GCM (`utils/crypto.ts`), com a chave mestra fora do banco, nas variáveis da Vercel | ✅ |
| **T** | Perder dados por erro ou ataque | Backups do Supabase | ⚠️ A confirmar no plano contratado; a restauração está no [roteiro de incidente](roteiro-de-incidente.md) |
| **I** | Guardar dado além do necessário | Sem CPF/CNPJ (migration `0009`) | ⚠️ IP do cliente sem prazo de guarda |

## 5. Análise por IA

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **I** | Dado pessoal do cliente sair para o provedor de IA | Só vão comentário, nota, respostas e contexto do negócio; nome, e-mail, gênero e IP do cliente nunca vão | ⚠️ O texto do comentário vai como foi escrito e pode conter um telefone ou e-mail |
| **T** | Um cliente escrever no comentário uma instrução para a IA ("ignore as regras e…") | A resposta da IA é validada no formato antes de ser gravada (`ia-analyze/src/validations`) | ⚠️ Não há defesa específica: um comentário pode tentar enviesar o resumo |
| **D** | Esgotar a cota de IA da empresa ou do sistema | Fila assíncrona com até 3 tentativas e um só pedido ativo por tipo e escopo. O orçamento por janela (`ia_rate_budget`) existe, mas só limita com `IA_RPM_LIMIT` e `IA_RPD_LIMIT` preenchidos | ⚠️ Cada empresa gasta a própria chave, e só o gestor dela pede análises |
| **S** | Usar a chave de IA de outra empresa | A chave é escolhida pela empresa da sessão e decifrada só no gateway | ✅ |

## 6. E-mail

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **S** | Usar um link de confirmação ou de nova senha velho ou de outra pessoa | Links com prazo de 1 hora, validados pelo Better Auth. O de nova senha usa um token guardado na tabela `verification` e apagado no uso. O de confirmação e o de troca de e-mail são um token assinado com o `BETTER_AUTH_SECRET`, sem registro no banco | ✅ |
| **I** | A credencial do Brevo vazar | Fica só nas variáveis da Vercel, fora do repositório | ✅ |

## 7. Web (navegador)

| | Ameaça | O que já protege | Situação |
|---|---|---|---|
| **T** | Um comentário com código (`<script>`) rodar no painel do gestor (XSS) | O React escreve o comentário como texto, nunca como HTML | ✅ |
| **I** | Segredos no código da Web | A Web não tem chave nenhuma; tudo passa pelo gateway em `/api` | ✅ |
| **T** | Embutir o painel num site falso (*clickjacking*) | — | ❌ Sem cabeçalhos de segurança (`X-Frame-Options`, `Content-Security-Policy`) na Vercel |

## Lacunas, por prioridade

| # | Lacuna | Por que importa | Onde entra |
|---|---|---|---|
| 1 | Gateway entra no banco como superusuário | Uma senha vazada vira acesso total | Etapa 07, código, item 3. **Feito:** o app entra como `feedback_app` em produção (migration `0013`) |
| 2 | Sem "Excluir minha conta" | Direito do titular (LGPD, art. 18) | Etapa 07, código, item 2. **Feito:** botão no Perfil, publicado em 02/11/2026 |
| 3 | Nove tabelas sem RLS | Coerência com a decisão de RLS em todas | Etapa 07, código, item 3. **Feito:** RLS nas 24 tabelas (migration `0013`) |
| 4 | Sem cabeçalhos de segurança na Web e no gateway | *Clickjacking* e defesa extra contra XSS | Novo, pequeno. O gateway não anuncia mais o Express (`x-powered-by` desligado, PR #110). Faltam `X-Frame-Options` e `Content-Security-Policy` |
| 5 | Sem limite de tentativas de login | Ataque de senha, até de um só IP | **Feito (PR #110):** o login, o cadastro e a nova senha contam as tentativas no banco, como o reenvio. As rotas nativas de e-mail e senha do Better Auth foram desligadas (PR #113) |
| 6 | Sem limite por IP no envio público | Encher o banco com respostas | Novo, pequeno |
| 7 | IP do cliente sem prazo | Guardar além do necessário | Etapa 07, código, item 4 (opcional) |
| 8 | Tokens do Google guardados sem uso | Dado sensível sem finalidade | Novo, pequeno. **Feito:** não são mais gravados (PR #109), e a migration `0015` apaga os antigos (PR #110) |
| 9 | Comentário com dado pessoal ou instrução para a IA | Dado saindo do sistema; resumo enviesado | Decisão em aberto |
| 10 | Backups não confirmados | Recuperação depois de um incidente | [Roteiro de incidente](roteiro-de-incidente.md) |
