# Política de Privacidade

> **Última atualização:** 2 de novembro de 2026

Esta página reproduz o texto publicado na Web, em `/privacidade` (`pages/public/privacy.tsx` e a data em `src/lib/constants/legal.ts`, no repositório da Web). Quem se cadastra aceita esse texto, na versão `v1` dos termos. Quando ele mudar na Web, esta página muda junto.

!!! warning "Pontos que o código não cumpre (conferido em 16/11/2026)"
    O texto abaixo é o publicado. Estes trechos não batem com o que o sistema faz e estão sendo corrigidos num PR da Web:

    - **Seção 2:** "dados da sessão: endereço IP e navegador usados para entrar". No login com e-mail e senha, o Gateway não grava o IP nem o navegador da sessão.
    - **Seções 1 e 2:** os feedbacks chegam pelo QR Code, pelo link ou pela etiqueta NFC, não só pelo QR Code. O identificador do aparelho também conta os clientes que voltam a avaliar.
    - **Seção 5:** todas as páginas da Web carregam as fontes do Google Fonts, que recebe o IP e o navegador de quem as abre, inclusive o cliente no formulário.
    - **Seção 6:** o navegador não guarda o tema; guarda alguns ajustes do painel, como o aviso de IA lenta, o convite do guia e uma análise em andamento. O progresso do guia fica no servidor.
    - **Seção 7:** nada apaga os registros de controle de envios. O IP, o navegador e o identificador do aparelho de quem envia feedback ficam enquanto a conta do negócio existir.
    - **Seção 9:** num incidente com feedbacks, quem avisa os clientes e a ANPD é o negócio, que é o controlador desses dados (ver o [Roteiro de incidente](roteiro-de-incidente.md)).

    Os detalhes estão no [Inventário de dados pessoais](inventario-de-dados.md) e em [Controlador e operador](controlador-e-operador.md).

Esta política explica quais dados o Feedback Analytics trata, para quê, com quem compartilha e como você exerce seus direitos, nos termos da Lei Geral de Proteção de Dados (Lei nº 13.709/2018, LGPD).

## 1. Quem trata os dados

O Feedback Analytics é o controlador dos dados da conta do negócio (quem se cadastra na plataforma).

Os feedbacks que os clientes do negócio deixam pelo QR Code pertencem ao negócio, que é o controlador desses dados. O Feedback Analytics os trata em nome do negócio, como operador, só para guardá-los e gerar as análises que o próprio negócio pede.

## 2. Quais dados coletamos

Da conta do negócio:

- nome do negócio, e-mail e telefone;
- senha, guardada só de forma cifrada (hash), nunca em texto;
- ao entrar com o Google: nome, e-mail e foto do perfil que o Google informa;
- o contexto do negócio digitado na configuração (o que faz e quais são os objetivos);
- a chave de API do OpenRouter, guardada criptografada, e o modelo de IA escolhido;
- dados da sessão: endereço IP e navegador usados para entrar.

Dos clientes que deixam feedback pelo QR Code:

- a nota, o comentário (opcional) e as respostas às perguntas do formulário;
- nome, e-mail e gênero, só se a pessoa quiser informar;
- endereço IP, navegador e um identificador do aparelho, para evitar envios repetidos e spam.

Não pedimos CPF, CNPJ nem dados sensíveis (como saúde, religião ou opinião política).

## 3. Para que usamos

- criar e manter a conta, permitir o login e enviar os e-mails de confirmação e de recuperação de senha;
- receber os feedbacks e gerar as métricas e as análises por IA que o negócio vê no painel;
- proteger a plataforma contra abuso, spam e acesso indevido.

Não vendemos dados e não os usamos para publicidade.

## 4. Bases legais

- execução do contrato com o negócio (art. 7º, V, da LGPD), para oferecer o serviço;
- legítimo interesse (art. 7º, IX), para segurança e prevenção de spam;
- consentimento (art. 7º, I), para os dados opcionais que o cliente escolhe informar no feedback.

## 5. Com quem compartilhamos

Só com os serviços necessários para a plataforma funcionar:

- Vercel, que hospeda o site e a API;
- Supabase, que hospeda o banco de dados;
- Brevo, que envia os e-mails da conta;
- Google, quando a pessoa escolhe entrar com o Google;
- OpenRouter e o provedor do modelo de IA escolhido pelo negócio, que recebem os comentários, as respostas e o contexto do negócio para gerar as análises, usando a chave de API do próprio negócio.

Alguns desses serviços ficam fora do Brasil. A transferência internacional segue o art. 33 da LGPD. Também compartilhamos dados quando uma lei ou uma ordem de autoridade exigir.

## 6. Cookies e armazenamento no navegador

Usamos um cookie essencial para manter a sessão de quem entra na conta. O navegador também guarda preferências, como o tema e o andamento do guia.

Não usamos cookies de publicidade nem de rastreamento.

## 7. Por quanto tempo guardamos

Os dados ficam guardados enquanto a conta do negócio existir. Quando a conta é excluída, os dados da conta e os feedbacks dela são apagados, salvo o que a lei obrigar a manter.

Os registros de sessão e de controle de envios são apagados quando deixam de ser necessários.

## 8. Seus direitos

Pela LGPD (art. 18), você pode pedir:

- a confirmação de que tratamos seus dados e o acesso a eles;
- a correção de dados incompletos, inexatos ou desatualizados;
- a anonimização, o bloqueio ou a exclusão de dados desnecessários;
- a portabilidade dos dados e a exclusão da conta;
- informações sobre com quem compartilhamos;
- a revogação do consentimento, quando for essa a base legal.

Os pedidos são feitos pelo e-mail [feedbackanalytics2026@gmail.com](mailto:feedbackanalytics2026@gmail.com). Se você deixou um feedback para um negócio, também pode falar com ele diretamente. Você ainda pode reclamar na Autoridade Nacional de Proteção de Dados (ANPD).

## 9. Segurança

Os dados trafegam com criptografia (HTTPS). A senha é guardada só em hash e a chave de API, criptografada. Cada negócio só acessa os próprios dados.

Se houver um incidente que traga risco a você, avisaremos você e a ANPD.

## 10. Mudanças nesta política

Quando esta política mudar, a data no topo muda. Se a mudança for relevante, avisaremos pela plataforma ou por e-mail.
