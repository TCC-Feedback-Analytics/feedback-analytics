# Inventário de dados pessoais

> **Em uma frase:** a lista de cada dado pessoal que o Feedback Analytics guarda ou repassa: de quem é, onde fica, para que serve, para quem sai e por quanto tempo fica.

É a base da etapa de segurança e LGPD. O [mapa de ameaças](mapa-de-ameacas.md), o registro de [controlador e operador](controlador-e-operador.md) e o [roteiro de incidente](roteiro-de-incidente.md) partem desta lista. Ela foi levantada no schema do banco (`drizzle/schema/` do gateway) e no código em 02/11/2026, e revista em 03/11/2026, depois da exclusão de conta pelo Perfil, e em 16/11/2026.

## De quem são os dados

| Titular | Quem é | Como chega ao sistema |
|---|---|---|
| **Gestor** | Quem cria a conta da empresa e usa o painel | Cadastro com nome do negócio, e-mail, telefone e senha, ou login com Google seguido do "Complete seu cadastro" (nome do negócio e telefone) |
| **Cliente final** | Quem responde o formulário pelo QR Code, link ou etiqueta NFC | Formulário público, sem login. Nome, e-mail e gênero são opcionais |

O sistema **não guarda CPF nem CNPJ** (removidos na migration `0009` do gateway, porque nada os usava).

## Onde tudo fica

Todos os dados abaixo ficam num único banco **PostgreSQL hospedado no Supabase**, acessado só pelo gateway. A Data API do Supabase está desligada desde 22/10/2026, então não há acesso ao banco por fora do app.

## Gestor

| Dado | Onde (tabela.coluna) | Para que serve | Sai para |
|---|---|---|---|
| Nome do negócio | `user.name` | Pedido no cadastro como "Nome do negócio" (no login com Google, o nome do Google vem como sugestão). Aparece no topo do painel e no formulário público, depois do envio | Provedor de IA, no contexto do negócio |
| E-mail | `user.email` | Login, confirmação de conta e recuperação de senha | Brevo (e-mails); Google, no login com Google |
| E-mail confirmado | `user.email_verified` | Liberar o login só depois da confirmação | — |
| Telefone | `user.phone` | Pedido no cadastro, ou no "Complete seu cadastro" de quem entra com o Google (`+55`), único por conta. Hoje nenhum fluxo usa o telefone: não há SMS nem contato automático | — |
| Foto | `user.image` | Gravada pelo Better Auth no login com Google, mas não usada: o avatar do painel é uma letra fixa e a API não devolve a foto | — |
| Senha | `account.password` | Login por e-mail e senha. Guardada só como **hash**, nunca em texto | — |
| Tokens do Google | `account.access_token`, `account.refresh_token`, `account.id_token` | **Não são gravados** desde o PR #109 do gateway. A migration `0015_apagar_tokens_google.sql` (PR #110) apaga os das contas antigas. As duas mudanças estão na `developer` e ainda não na `main`. O Better Auth lê o perfil com eles no login com Google, e o gateway grava os três vazios (`discardOAuthTokens`); o sistema não chama o Google depois do login | — |
| Sessão | `session.token`, `session.ip_address`, `session.user_agent`, `session.expires_at` | Manter o gestor logado. O IP e o navegador são gravados quando a sessão nasce: no login com Google, na entrada pelo link de confirmação e, desde o PR #110 do gateway (na `developer`), no login com e-mail e senha. Na `main`, esse login ainda grava os dois vazios. Nada lê esses campos hoje | — |
| Links de nova senha e login com Google | `verification` | Validar o link de nova senha (guarda o id do usuário, vale 1 hora) e o retorno do login com Google (vale 10 minutos). O link de confirmação e o de troca de e-mail não ficam no banco: são um token assinado, com o e-mail dentro, que vale 1 hora | — |
| Aceite dos termos | `enterprise.terms_version`, `enterprise.terms_accepted_at` | Provar qual versão dos Termos e da Política foi aceita, e quando | — |
| Progresso do guia | `user_onboarding` | Não repetir o guia já feito | — |
| Limites de tentativa | `auth_rate_limit.key` | Frear abuso no login, no cadastro, na nova senha e no "reenviar confirmação". Guarda só um **HMAC** do IP e do e-mail, não o valor | — |

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
| IP do aparelho | `tracked_devices.ip_address` | Gravado a cada envio. Nada o lê depois: o anti-spam compara só o identificador do aparelho, calculado na hora | Ninguém fora do servidor |
| Navegador (*user agent*) | `tracked_devices.user_agent` | Gravado a cada envio, como o IP. Nada o lê depois | Ninguém fora do servidor |
| Identificador do aparelho | `tracked_devices.device_fingerprint` | Anti-spam (1 envio por aparelho, por ponto de coleta, por dia) e a métrica "Clientes que voltam". É o hash MD5 de navegador e IP, sem o dia e sem sal (`qrcode.controller.ts`): é um pseudônimo, não um dado anônimo | Ninguém fora do servidor |
| Bloqueio | `tracked_devices.is_blocked`, `blocked_reason` | Barrar um aparelho que abusa. O painel não tem esse botão: hoje o bloqueio só é feito direto no banco | — |

O `GET /api/protected/user/feedbacks` (`feedbackList.repository.ts`) devolve ao gestor, em cada feedback, só a quantidade de envios do aparelho e se ele está bloqueado, além do nome, do e-mail e do gênero do primeiro cliente que se identificou naquele aparelho. O vínculo é pelo aparelho, não pelo feedback: um envio anônimo do mesmo aparelho aparece com o nome de quem se identificou antes, e quem se identifica depois num aparelho já vinculado fica gravado em `customer` sem aparecer no painel. IP, navegador e identificador do aparelho ficam no servidor (minimização, desde 05/11/2026).

## Dados que a IA produz

| Dado | Onde | O que guarda |
|---|---|---|
| Análise de cada comentário | `feedback_analysis` | Sentimento (com intensidade e confiança), categorias, palavras-chave e aspectos do comentário |
| Resumo e recomendações | `feedback_insights_report` | Resumo do escopo e recomendações, por empresa e por item |
| Diagnóstico do escopo | `scope_diagnosis.result` | Texto do diagnóstico com os números do período |
| Fila de análises | `ia_analysis_job` | Andamento das análises e quem pediu (`requested_by`, o id do gestor). Enquanto a análise roda, `options` guarda uma cópia do pacote enviado à IA, com os comentários. O job apaga a cópia quando termina, com sucesso ou com falha de vez. Na análise dos comentários e no resumo, a falha de vez só apaga a cópia desde o PR #110 (na `developer`). Enquanto o job ainda vai tentar de novo, a cópia fica para retomar |

## O que sai do sistema e para quem

| Para quem | O que recebe | Por quê |
|---|---|---|
| **Supabase** | Tudo acima (hospeda o banco) | Hospedagem do PostgreSQL |
| **Vercel** | As requisições da Web e da API, com IP e navegador nos registros de acesso. Nos registros do `ia-analyze`, o adaptador do OpenRouter grava só código, modelo, tarefa, contagens e status, sem chave, prompt nem comentário; o adaptador do Gemini grava só o status, o nome e o código do erro, sem a mensagem do SDK | Hospedagem da Web, do gateway e do `ia-analyze` |
| **OpenRouter e o modelo escolhido pela empresa** | Comentários, notas, respostas, pergunta própria, data do feedback, nomes do ponto de coleta e do item, o nome do negócio e o contexto do negócio. **Nunca** nome, e-mail, gênero ou IP do cliente | Análise dos comentários, diagnóstico do escopo e geração das perguntas, com a chave da própria empresa |
| **Brevo** | E-mail do gestor e os links de confirmação, de troca de e-mail e de nova senha | Envio dos e-mails da conta |
| **Google** | O pedido de login com Google | Login social, quando o gestor escolhe |

Na `developer` da Web (PR #152), as fontes saem da própria Web (`styles/fonts.css`). A `main` ainda carrega o Google Fonts, que recebe o IP e o navegador de quem abre a página, até o próximo deploy.

Os papéis de cada fornecedor na LGPD ficam no registro de [controlador e operador](controlador-e-operador.md).

## Por quanto tempo fica

Nenhuma rotina agendada apaga dados. Só há limpezas no caminho de outras ações:

| Dado | Situação atual |
|---|---|
| Conta, empresa, feedbacks e análises | Ficam até o gestor excluir a conta. Desde 02/11/2026, o botão "Excluir minha conta", no Perfil, apaga numa transação a empresa e tudo dela (feedbacks, clientes, aparelhos, análises, configuração de IA) e depois o usuário, com sessões e contas de login (`src/auth/enterpriseOnDelete.ts`). A exclusão também pode ser pedida por e-mail, como dizem os Termos |
| Sessões (`session`) | A sessão é apagada ao sair da conta, ao redefinir a senha (todas as sessões da pessoa, `revokeSessionsOnPasswordReset`, na `developer`) ou quando o navegador volta com o cookie vencido. Se o cookie não volta, a linha vencida fica no banco |
| Links (`verification`) | O Better Auth apaga todos os vencidos a cada nova consulta de link (nova senha ou login com Google). O link de nova senha usado também sai |
| IP e navegador do cliente (`tracked_devices`) | Sem prazo |
| Limites de tentativa (`auth_rate_limit`) | A cada pedido de login, cadastro, nova senha ou reenvio, o gateway apaga até 100 linhas vencidas |

## O que este inventário mostrou

Pontos para o mapa de ameaças e para o plano da etapa. O 4 e o 6 foram resolvidos, e o 2 está resolvido na `developer` do gateway, ainda não na `main`:

1. **IP e navegador do cliente sem prazo de guarda.** O anti-spam olha só o dia: 1 envio por aparelho, por ponto de coleta, até a meia-noite de Brasília. Ele compara só o identificador do aparelho, calculado a cada envio; o IP e o navegador gravados não são lidos depois. O identificador fica sem prazo de propósito, porque mantém o bloqueio entre dias e conta os "Clientes que voltam". Candidato: apagar o IP e o navegador depois de um prazo e manter só o identificador.
2. **Tokens do Google: resolvido na `developer` do gateway.** O gateway grava os três vazios (`discardOAuthTokens`, PR #109), e a migration `0015` apaga os tokens gravados antes (PR #110). Cifrar não bastaria, porque o `id_token` ficaria legível. Falta chegar à `main`.
3. **O comentário vai à IA como foi escrito.** O sistema não manda os dados de identificação do cliente, mas o próprio texto pode trazer um telefone ou e-mail.
4. **Exclusão de conta pela tela: resolvido em 02/11/2026.** O direito de exclusão (LGPD, art. 18) dependia de um e-mail; hoje o gestor exclui a conta no Perfil.
5. **Sessões vencidas podem ficar no banco.** Links e limites vencidos já são apagados no caminho, a cada consulta de link e a cada pedido de login, cadastro, nova senha ou reenvio. A sessão só some ao sair da conta, ao redefinir a senha ou quando o cookie vencido volta. O risco é baixo.
6. **IP, navegador e identificador do aparelho chegavam ao gestor: resolvido em 05/11/2026.** Eles servem só ao anti-spam, e a lista de feedbacks deixou de devolvê-los ao painel.
