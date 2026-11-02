# Controlador e operador

> **Em uma frase:** quem responde por cada dado perante a LGPD. O Feedback Analytics é o **controlador** dos dados da conta do negócio e **operador** dos feedbacks que os clientes do negócio deixam; os fornecedores são operadores (ou suboperadores) que tratam os dados em nosso nome.

Parte da etapa de segurança e LGPD, ao lado do [inventário de dados pessoais](inventario-de-dados.md) e do [mapa de ameaças](mapa-de-ameacas.md). Segue o que a [Política de Privacidade](https://feedback-analytics-web.vercel.app/privacidade) publicada já diz ao usuário.

## Os papéis na LGPD

| Papel | Quem é (art. 5º) | Responde por |
|---|---|---|
| **Controlador** | Quem decide o que coletar e para quê | Base legal, atender o titular, avisar a ANPD num incidente |
| **Operador** | Quem trata os dados em nome do controlador, seguindo as instruções dele | Tratar só como combinado, proteger os dados e avisar o controlador num incidente |
| **Encarregado** | Canal entre o controlador, os titulares e a ANPD | Receber pedidos e reclamações |

Terceirizar a hospedagem **não** terceiriza a responsabilidade: perante o titular, quem responde é o controlador, mesmo que o vazamento aconteça num fornecedor (art. 42).

## O Feedback Analytics tem dois papéis

O sistema é um serviço (SaaS) usado por negócios. Por isso o papel muda conforme o dado:

| Dado | Controlador | Feedback Analytics é | Por quê |
|---|---|---|---|
| **Conta do negócio:** nome, e-mail, telefone, senha, sessão, chave de IA, contexto do negócio | **Feedback Analytics** | Controlador | Nós decidimos o que o cadastro pede e para quê |
| **Feedbacks dos clientes do negócio:** nota, comentário, respostas, nome, e-mail e gênero opcionais, IP e aparelho | **O negócio** | Operador | O negócio decide coletar a opinião dos clientes dele; nós guardamos e analisamos a pedido dele |

Consequência prática: num incidente com feedbacks, **avisamos o negócio**, e cabe a ele, como controlador, avisar a ANPD e os clientes dele. Num incidente com dados de conta, quem avisa somos nós. O [roteiro de incidente](roteiro-de-incidente.md) segue essa divisão.

## Os fornecedores (operadores e suboperadores)

| Fornecedor | O que faz | Que dado recebe | Onde fica | A conferir |
|---|---|---|---|---|
| **Supabase** | Hospeda o PostgreSQL | Todos os dados do banco | Fora do Brasil (região do projeto a confirmar no painel) | Acordo de tratamento de dados (DPA) aceito; plano de backup |
| **Vercel** | Hospeda a Web e o gateway | Todas as requisições, com IP e navegador nos registros de acesso | Fora do Brasil | DPA aceito; por quanto tempo guarda os registros |
| **OpenRouter** e o **provedor do modelo** escolhido pelo negócio | Roda a análise dos comentários e o diagnóstico | Comentários, notas, respostas, pergunta própria, nomes dos itens e contexto do negócio. Nunca nome, e-mail, gênero ou IP do cliente | Fora do Brasil | Política de retenção do OpenRouter e do provedor escolhido. A chamada usa a **chave do próprio negócio**, então o negócio também tem um contrato direto com o OpenRouter |
| **Brevo** | Envia os e-mails da conta | E-mail do gestor e os links de confirmação e de nova senha | Fora do Brasil (União Europeia) | DPA aceito |
| **Google** | Login com Google | O pedido de login; devolve nome, e-mail e foto do perfil | Fora do Brasil | Configuração do OAuth publicada |

**Transferência internacional:** todos os fornecedores ficam fora do Brasil. A Política de Privacidade já avisa e cita o art. 33 da LGPD. Os acordos de tratamento de dados (DPA) dos fornecedores são o instrumento que cobre essa transferência.

## Base legal de cada tratamento

As mesmas da Política de Privacidade:

| Tratamento | Base legal (art. 7º) |
|---|---|
| Criar e manter a conta, login e e-mails da conta | Execução de contrato (V) |
| Receber os feedbacks e gerar as métricas e as análises | Execução de contrato com o negócio (V) |
| Anti-spam: IP, navegador e identificador do aparelho | Legítimo interesse (IX) |
| Nome, e-mail e gênero que o cliente escolhe informar | Consentimento (I) |

## Encarregado e canal do titular

A ANPD dispensa os agentes de pequeno porte, como startups, de indicar um encarregado (Resolução CD/ANPD nº 2/2022), desde que mantenham um **canal de comunicação** com o titular. O canal do Feedback Analytics é o e-mail **Feedbackanalytics2026@gmail.com**, publicado na Política de Privacidade e nos Termos.

## Divergências encontradas entre a Política e o sistema

Pontos para corrigir na Web, sem mudança nesta revisão:

1. **E-mail:** a Política diz que os e-mails saem pelo **SendGrid**, mas em produção quem envia é o **Brevo** (gateway, configuração SMTP).
2. **Limpeza de registros:** a Política diz que os registros de sessão e de controle de envios "são apagados quando deixam de ser necessários", mas nada os apaga hoje ([inventário](inventario-de-dados.md#por-quanto-tempo-fica)).
3. **Exclusão da conta:** a Política descreve o que acontece quando a conta é excluída, mas a exclusão ainda depende de um pedido por e-mail, porque não há botão.
