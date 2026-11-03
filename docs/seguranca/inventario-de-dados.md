# Inventário de dados pessoais

> **Em uma frase:** a lista de cada dado pessoal que o Feedback Analytics guarda ou repassa: de quem é, onde fica, para que serve, para quem sai e por quanto tempo fica.

É a base da etapa de segurança e LGPD. O [mapa de ameaças](mapa-de-ameacas.md), o registro de [controlador e operador](controlador-e-operador.md) e o [roteiro de incidente](roteiro-de-incidente.md) partem desta lista. Ela foi levantada no schema do banco (`drizzle/schema/` do gateway) e no código em 02/11/2026, e revista em 03/11/2026, depois da exclusão de conta pelo Perfil.

## De quem são os dados

| Titular | Quem é | Como chega ao sistema |
|---|---|---|
| **Gestor** | Quem cria a conta da empresa e usa o painel | Cadastro com e-mail e senha ou login com Google, mais o complemento do cadastro (nome e telefone) |
| **Cliente final** | Quem responde o formulário pelo QR Code, link ou etiqueta NFC | Formulário público, sem login. Nome, e-mail e gênero são opcionais |

O sistema **não guarda CPF nem CNPJ** (removidos na migration `0009` do gateway, porque nada os usava).

## Onde tudo fica

Todos os dados abaixo ficam num único banco **PostgreSQL hospedado no Supabase**, acessado só pelo gateway. A Data API do Supabase está desligada desde 22/10/2026, então não há acesso ao banco por fora do app.

## Gestor

| Dado | Onde (tabela.coluna) | Para que serve | Sai para |
|---|---|---|---|
| Nome | `user.name` | Saudação no painel | — |
| E-mail | `user.email` | Login, confirmação de conta e recuperação de senha | Brevo (e-mails); Google, no login com Google |
| E-mail confirmado | `user.email_verified` | Liberar o login só depois da confirmação | — |
| Telefone | `user.phone` | Contato com o gestor, pedido no complemento do cadastro (`+55`), único por conta | — |
| Foto | `user.image` | Avatar, quando o login é pelo Google | — |
| Senha | `account.password` | Login por e-mail e senha. Guardada só como **hash**, nunca em texto | — |
| Tokens do Google | `account.access_token`, `account.refresh_token`, `account.id_token` | Guardados pelo Better Auth no login com Google. O sistema **não usa** esses tokens depois do login | — |
| Sessão | `session.token`, `session.ip_address`, `session.user_agent`, `session.expires_at` | Manter o gestor logado e saber de que aparelho a sessão foi aberta | — |
| Links de confirmação e de nova senha | `verification` | Validar o link enviado por e-mail | — |
| Aceite dos termos | `enterprise.terms_version`, `enterprise.terms_accepted_at` | Provar qual versão dos Termos e da Política foi aceita, e quando | — |
| Progresso do guia | `user_onboarding` | Não repetir o guia já feito | — |
| Limite de reenvio de e-mail | `auth_rate_limit.key` | Frear abuso no "reenviar confirmação". Guarda só um **HMAC** do IP e do e-mail, não o valor | — |

## Empresa

Não são dados pessoais em si, mas podem citar pessoas se o gestor escrever.

| Dado | Onde | Para que serve | Sai para |
|---|---|---|---|
| Contexto do negócio (objetivo, resumo, principais produtos) | `collecting_data_enterprise` | Dar contexto à IA nas análises | Provedor de IA |
| Catálogo (produtos, serviços, departamentos) e perguntas | `catalog_items`, `questions_of_feedbacks` e afins | Montar o formulário e as métricas por item | Provedor de IA (nome e descrição do item) |
| Chave da API de IA | `enterprise_ia_config.api_key_ciphertext` (+ `iv`, `auth_tag`) | Chamar o modelo escolhido pela empresa. Guardada **cifrada** (AES-256-GCM, `src/utils/crypto.ts`); o painel mostra só o final (`key_hint`) | OpenRouter, a cada análise |

## Cliente final

| Dado | Onde | Para que serve | Sai para |
|---|---|---|---|
| Nome, e-mail e gênero (opcionais) | `customer.name`, `customer.email`, `customer.gender` | O gestor saber quem respondeu, quando o cliente quis se identificar | — (só o gestor da empresa vê) |
| Nota e respostas das perguntas | `feedback.rating`, `feedback_question_answers`, `feedback_subquestion_answers` | Métricas do painel | Provedor de IA (sem nome, e-mail nem IP) |
| Comentário | `feedback.message` | Ler a opinião e analisar o tom com a IA. É **texto livre**: o cliente pode escrever nele um nome, telefone ou e-mail | Provedor de IA, como foi escrito |
| Pergunta própria e canal | `feedback.comment_prompt`, `feedback.channel` | Contexto do comentário e métrica por canal | Provedor de IA (a pergunta) |
| IP do aparelho | `tracked_devices.ip_address` | Anti-spam: limitar respostas repetidas do mesmo aparelho | Gestor da empresa, no detalhe do feedback |
| Navegador (*user agent*) | `tracked_devices.user_agent` | Anti-spam | Gestor da empresa, no detalhe do feedback |
| Identificador do aparelho | `tracked_devices.device_fingerprint` | Anti-spam: hash MD5 de navegador, IP e dia (`qrcode.controller.ts`). Não identifica a pessoa sozinho | Gestor da empresa, no detalhe do feedback |
| Bloqueio | `tracked_devices.is_blocked`, `blocked_reason` | Barrar um aparelho que abusa. O painel não tem esse botão: hoje o bloqueio só é feito direto no banco | — |

O `GET /api/protected/user/feedbacks` (`feedbackList.repository.ts`) devolve ao gestor, em cada feedback, o IP, o navegador e o identificador do aparelho, além do nome, do e-mail e do gênero do cliente, quando ele os informou. A Web mostra esses dados na janela de detalhe do feedback.

## Dados que a IA produz

| Dado | Onde | O que guarda |
|---|---|---|
| Análise de cada comentário | `feedback_analysis` | Sentimento (com intensidade e confiança), categorias, palavras-chave e aspectos do comentário |
| Diagnóstico do escopo | `scope_diagnosis.result` | Texto do diagnóstico com os números do período |
| Fila de análises | `ia_analysis_job` | Andamento das análises e quem pediu (`requested_by`, o id do gestor) |

## O que sai do sistema e para quem

| Para quem | O que recebe | Por quê |
|---|---|---|
| **Supabase** | Tudo acima (hospeda o banco) | Hospedagem do PostgreSQL |
| **Vercel** | As requisições da Web e da API, com IP e navegador nos registros de acesso. Nos registros do `ia-analyze`, o adaptador do OpenRouter grava só código, modelo, tarefa, contagens e status, sem chave, prompt nem comentário; o adaptador do Gemini grava até 300 caracteres da mensagem de erro do SDK | Hospedagem da Web, do gateway e do `ia-analyze` |
| **OpenRouter e o modelo escolhido pela empresa** | Comentários, notas, respostas, pergunta própria, nomes de itens e o contexto do negócio. **Nunca** nome, e-mail, gênero ou IP do cliente | Análise dos comentários, diagnóstico do escopo e geração das perguntas, com a chave da própria empresa |
| **Brevo** | E-mail do gestor e os links de confirmação e de nova senha | Envio dos e-mails da conta |
| **Google** | O pedido de login com Google | Login social, quando o gestor escolhe |

Os papéis de cada fornecedor na LGPD ficam no registro de [controlador e operador](controlador-e-operador.md).

## Por quanto tempo fica

Hoje **nada é apagado automaticamente**:

| Dado | Situação atual |
|---|---|
| Conta, empresa, feedbacks e análises | Ficam até o gestor excluir a conta. Desde 02/11/2026, o botão "Excluir minha conta", no Perfil, apaga numa transação a empresa e tudo dela (feedbacks, clientes, aparelhos, análises, configuração de IA) e depois o usuário, com sessões e contas de login (`src/auth/enterpriseOnDelete.ts`). A exclusão também pode ser pedida por e-mail, como dizem os Termos |
| Sessões e links vencidos (`session`, `verification`) | Deixam de valer na data de vencimento, mas a linha continua no banco |
| IP e navegador do cliente (`tracked_devices`) | Sem prazo |
| Limite de reenvio (`auth_rate_limit`) | A janela vence, a linha fica |

## O que este inventário mostrou

Pontos para o mapa de ameaças e para o plano da etapa. Só o 4 foi resolvido até agora:

1. **IP e navegador do cliente sem prazo de guarda.** Só servem ao anti-spam, que olha poucos dias. Candidato a ser anonimizado depois de um prazo.
2. **Tokens do Google guardados sem uso.** O Better Auth os grava no login com Google, e o sistema nunca os usa. Vale avaliar não guardá-los ou cifrá-los.
3. **O comentário vai à IA como foi escrito.** O sistema não manda os dados de identificação do cliente, mas o próprio texto pode trazer um telefone ou e-mail.
4. **Exclusão de conta pela tela: resolvido em 02/11/2026.** O direito de exclusão (LGPD, art. 18) dependia de um e-mail; hoje o gestor exclui a conta no Perfil.
5. **Sessões, links e limites vencidos não são limpos.** O risco é baixo, mas o banco acumula dado que não serve mais.
6. **IP, navegador e identificador do aparelho chegam ao gestor.** Eles servem ao anti-spam, mas a lista de feedbacks os devolve ao painel, que os mostra no detalhe de cada feedback.
