# Roteiro de incidente

> **Em uma frase:** o passo a passo para o pior dia. Se um dado vazar ou uma credencial cair em mãos erradas, seguimos este roteiro: detectar, conter, avaliar, avisar e aprender, sem improvisar sob pressão.

Parte da etapa de segurança e LGPD. Usa o [inventário de dados pessoais](inventario-de-dados.md) para saber o que foi exposto, o [mapa de ameaças](mapa-de-ameacas.md) para saber por onde, e o registro de [controlador e operador](controlador-e-operador.md) para saber quem avisa quem.

## O que conta como incidente

Qualquer evento que **exponha, altere, apague ou torne indisponível** um dado pessoal sem autorização. Exemplos no Feedback Analytics:

- uma credencial (senha do banco, segredo do login, chave de cifra) publicada no GitHub ou num print;
- um gestor que consegue ver dados de outra empresa;
- o banco apagado ou corrompido;
- um aviso do Supabase, da Vercel ou de outro fornecedor sobre um incidente do lado deles.

## Quem faz o quê

| Papel | Quem | O que faz |
|---|---|---|
| **Responsável pelo incidente** | Fernando Sergio | Decide, coordena e assina os avisos |
| **Apoio técnico** | _a definir com a equipe_ | Investiga, executa a contenção e registra a linha do tempo |
| **Canal do titular** | Feedbackanalytics2026@gmail.com | Recebe pedidos e envia os avisos |

Os acessos que o roteiro exige (painéis do Supabase, da Vercel, do Brevo, do Google Cloud e do GitHub) precisam estar com pelo menos duas pessoas.

## 1. Detectar

Sinais de que algo aconteceu:

- aviso de um fornecedor (Supabase, Vercel, Brevo, Google, OpenRouter);
- alerta de segredo exposto do GitHub (*secret scanning*);
- erros ou acessos estranhos nos registros da Vercel;
- um usuário avisando pelo e-mail de contato.

Ao suspeitar: **anote a data e a hora**, abra o registro do incidente (modelo no fim) e chame o responsável. O prazo de aviso conta a partir de quando ficamos sabendo.

## 2. Conter

Primeiro parar o vazamento; investigar a fundo vem depois. O que fazer para cada credencial (variáveis da Vercel do gateway):

| O que vazou | Como conter | Efeito colateral |
|---|---|---|
| Senha do banco (`DATABASE_URL`) | Trocar a senha no painel do Supabase, atualizar `DATABASE_URL` na Vercel e fazer um novo deploy | Alguns minutos fora do ar |
| Segredo do login (`BETTER_AUTH_SECRET`) | Trocar na Vercel, fazer um novo deploy e apagar as sessões (`DELETE FROM session`) | Todos os gestores precisam entrar de novo |
| Chave de cifra das chaves de IA (`IA_CONFIG_ENCRYPTION_KEY`) | Trocar na Vercel. As chaves gravadas deixam de abrir: pedir a cada negócio que **revogue a chave no OpenRouter** e cadastre uma nova | Análises param até o negócio cadastrar a chave. Não há script para cifrar de novo |
| Chave de IA de um negócio | Avisar o negócio para revogar no OpenRouter e cadastrar outra | Análises daquele negócio param até a troca |
| Credencial de e-mail (`SMTP_USER`, `SMTP_PASS`) | Gerar outra no Brevo e atualizar na Vercel | E-mails param por alguns minutos |
| Segredo do Google (`GOOGLE_CLIENT_SECRET`) | Gerar outro no Google Cloud e atualizar na Vercel | Login com Google para por alguns minutos |
| Tokens internos (`IA_ANALYZE_REMOTE_TOKEN`, `WORKER_TICK_TOKEN`, `RESEND_RATE_LIMIT_SECRET`) | Trocar na Vercel do gateway e, quando houver, no serviço que o usa | Análises param até os dois lados terem o mesmo valor |
| Falha que deixa ver dados de outra empresa | Tirar a rota do ar (reverter o deploy na Vercel), corrigir e só então subir de novo | A funcionalidade fica fora do ar |

**Preserve as provas antes de apagar qualquer coisa:** exporte os registros da Vercel do período e anote as linhas afetadas no banco.

## 3. Avaliar

Com o [inventário](inventario-de-dados.md) em mãos, responder no registro:

1. **Que dados** foram expostos (conta do negócio, feedbacks, IP, chaves)?
2. **De quantos** titulares e de quantos negócios?
3. **Que risco** isso traz? Senha (só o hash) e IP pesam menos que e-mail e telefone juntos. Um comentário pode conter qualquer coisa.
4. **Quem é o controlador** desses dados: nós (conta do negócio) ou o negócio (feedbacks)?

## 4. Avisar

| Dados afetados | Quem avisa | Quem é avisado | Prazo |
|---|---|---|---|
| Conta do negócio | Feedback Analytics | ANPD e os gestores afetados | 3 dias úteis |
| Feedbacks dos clientes | Feedback Analytics avisa o negócio | O negócio, que avisa a ANPD e os clientes dele | Sem demora, para o negócio cumprir os 3 dias úteis dele |

O prazo de **3 dias úteis** a partir do conhecimento do incidente é o do Regulamento de Comunicação de Incidente de Segurança da ANPD (Resolução CD/ANPD nº 15/2024), que detalha o art. 48 da LGPD. A ANPD é avisada pelo formulário do site dela. Se ainda faltar informação no prazo, o aviso sai com o que se sabe e é completado depois.

A ANPD só precisa ser avisada quando o incidente puder trazer **risco ou dano relevante** aos titulares. Na dúvida, avise. Em todo caso, o incidente fica registrado (passo 5).

### Modelo de aviso ao titular

> **Assunto:** Aviso de incidente de segurança no Feedback Analytics
>
> Olá, [nome].
>
> No dia [data], identificamos [o que aconteceu, em uma frase]. Os dados afetados foram: [lista]. Não foram afetados: [lista, se ajudar a tranquilizar].
>
> Já fizemos o seguinte: [ações de contenção]. Recomendamos que você [ação, por exemplo trocar a senha].
>
> Comunicamos o ocorrido à Autoridade Nacional de Proteção de Dados (ANPD). Dúvidas: Feedbackanalytics2026@gmail.com.

### Modelo de aviso ao negócio (feedbacks dos clientes dele)

> No dia [data], identificamos [o que aconteceu]. Foram afetados [quantos] feedbacks dos seus clientes, com os dados: [lista]. Como você é o controlador desses dados, cabe a você avaliar o aviso à ANPD e aos seus clientes. Seguem as informações para isso: [natureza dos dados, titulares, riscos, medidas tomadas].

## 5. Recuperar e aprender

- Voltar ao normal: novo deploy com a correção e, se houve perda, restaurar o backup do Supabase.
- Registrar o incidente, **mesmo que não precise de aviso**. A ANPD pede que o registro fique guardado por 5 anos.
- Em até uma semana: reunião curta sobre o que falhou, o que funcionou e o que muda no código, neste roteiro ou no [mapa de ameaças](mapa-de-ameacas.md).

## Modelo de registro do incidente

| Campo | Preencher |
|---|---|
| Data e hora em que ficamos sabendo | |
| Como ficamos sabendo | |
| O que aconteceu | |
| Dados e titulares afetados (quantos) | |
| Controlador dos dados afetados | |
| Contenção feita (o quê e quando) | |
| Avisos enviados (para quem e quando) | |
| Causa | |
| O que muda depois | |

## Ensaio de mesa

Um roteiro nunca ensaiado costuma falhar no dia real. Uma vez, com a equipe, leia o cenário abaixo e siga o roteiro **sem mexer em nada de verdade**, só dizendo o que faria e onde. Anote o que travou.

**Cenário:** numa segunda-feira, o GitHub avisa que a `DATABASE_URL` de produção foi publicada num commit há três dias.

| Pergunta | Resposta no ensaio |
|---|---|
| Quem foi chamado e em quanto tempo? | |
| Quem tem acesso ao Supabase e à Vercel para trocar a senha? | |
| Que dados alguém com essa senha conseguiria ler? | |
| Os registros mostram algum acesso estranho nesses três dias? | |
| Precisa avisar a ANPD? Quem são os controladores dos dados? | |
| O que travou ou faltou no roteiro? | |

**Data do ensaio:** _a preencher_ · **Participantes:** _a preencher_
