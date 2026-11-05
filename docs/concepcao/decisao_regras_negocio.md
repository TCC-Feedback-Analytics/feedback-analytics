# Decisões de Regras de Negócio

Este documento registra as decisões que definem como o sistema se comporta — escritas antes de qualquer linha de código, em linguagem acessível para qualquer pessoa do projeto.

Cada regra aqui é uma decisão consciente de produto ou de segurança. O código implementa essas decisões; este documento explica o porquê delas existirem.

O detalhamento técnico de como cada regra é implementada está em [regras-negocio.md](../produto/regras-negocio.md).

!!! note "Conferido contra o código (03/11/2026)"
    As decisões foram escritas em junho de 2026. Nesta revisão, cada uma foi conferida no código. As que o sistema deixou de seguir estão marcadas como **decisão substituída**, com o que vale hoje; as que valem com uma ressalva ganharam um parágrafo **Hoje**.

---

## Segurança e Privacidade

### Cada empresa enxerga somente os seus próprios dados

**Decisão:** nenhuma empresa pode ver, acidentalmente ou intencionalmente, os dados de outra. Isso vale para feedbacks, configurações, análises e qualquer outra informação cadastrada.

**Por quê:** o sistema atende múltiplas empresas ao mesmo tempo. Se uma empresa pudesse acessar os dados de outra, isso seria uma falha grave de privacidade e quebraria qualquer confiança no produto.

**Como se manifesta:** toda ação autenticada carrega a identidade da empresa automaticamente. O sistema nunca aceita "me dê os dados da empresa X" vindo do lado do cliente — ele sempre usa a identidade de quem está logado.

---

### A conta só pode ser de CPF ou CNPJ

**Decisão substituída (migration `0009` do gateway).** O sistema não pede nem guarda mais CPF ou CNPJ: o cadastro pede o **nome do negócio**, que vale para pessoa física e jurídica. Nada no sistema usava o documento, e não guardar o que não é necessário é regra da LGPD (necessidade). A decisão original fica abaixo como registro.

**Decisão original:** ao cadastrar uma conta, o tipo de documento deve ser CPF (pessoa física) ou CNPJ (pessoa jurídica). Outros formatos não são aceitos.

**Por quê:** o produto atende tanto profissionais autônomos quanto empresas formais. Dois tipos cobrem todos os casos de uso previstos. Aceitar formatos abertos criaria inconsistências nos dados e dificultaria processos futuros de cobrança ou conformidade legal.

---

### O sistema não revela quais e-mails têm cadastro

**Decisão:** nas telas de login, cadastro e recuperação de senha, o sistema nunca confirma se um e-mail específico já está cadastrado. Quem erra a senha, tenta entrar com uma conta ainda não confirmada ou digita um e-mail que não existe recebe sempre a **mesma** mensagem genérica. No cadastro com e-mail já em uso, o fluxo segue normalmente para a tela de sucesso, sem avisar que o e-mail já existe.

**Por quê:** se o sistema dissesse "essa conta existe mas não foi confirmada" ou "esse e-mail já está cadastrado", um atacante poderia testar listas de e-mails em massa e descobrir quem tem conta na plataforma — o primeiro passo para ataques direcionados. Mensagens genéricas tornam essa varredura inviável. O custo é pequeno: um gestor legítimo com conta não confirmada ainda consegue reenviar o e-mail de ativação pelos fluxos de cadastro e de link expirado.

**Observação:** por enquanto a regra vale para o e-mail. O telefone ainda é validado de forma explícita no cadastro (telefone de outra conta é recusado); o documento deixou de ser pedido.

---

## Conta e Acesso

### Toda conta nova começa com 4 meses de acesso gratuito

**Decisão:** ao criar uma conta, o sistema automaticamente concede 4 meses de acesso completo sem nenhuma cobrança. Só depois disso o acesso precisa ser convertido para um plano pago.

**Por quê:** decidimos que 4 meses é tempo suficiente para uma empresa configurar o sistema, coletar feedbacks reais e perceber valor antes de precisar pagar. Períodos de trial curtos demais não permitem esse ciclo completo.

**Estados possíveis de uma conta:**

| Status | O que significa |
|---|---|
| Em teste (TRIAL) | Acesso completo durante os 4 meses gratuitos |
| Ativa (ACTIVE) | Assinatura paga em vigor |
| Expirada (EXPIRED) | O trial encerrou sem conversão para plano pago |
| Cancelada (CANCELED) | O gestor encerrou a assinatura manualmente |

**Hoje:** o trial de 4 meses e o status `TRIAL` são gravados no cadastro, e o painel mostra o status com os dias restantes. Ainda não há cobrança: nada no código muda o status depois do cadastro nem bloqueia o acesso quando o trial termina.

---

### O e-mail de confirmação de cadastro expira em 1 hora

**Decisão:** após o cadastro, o sistema envia um link de confirmação por e-mail. Esse link é válido por apenas 1 hora.

**Por quê:** links de confirmação sem prazo são um risco de segurança. Se o e-mail cair em mãos erradas tempos depois, não deve ser possível ativar a conta. Uma hora é tempo mais do que suficiente para quem acabou de se cadastrar confirmar o acesso.

**O que acontece se o link expirar:** o usuário é direcionado para uma página dedicada onde pode informar o e-mail e solicitar um novo link de confirmação sem precisar refazer o cadastro.

---

## Coleta de Feedbacks (QR Code, link e NFC)

### Um dispositivo envia no máximo um feedback por ponto de coleta por dia

**Decisão:** o mesmo celular ou computador não pode enviar mais de um feedback para o mesmo ponto de coleta no mesmo dia.

**Por quê:** feedbacks duplicados do mesmo dispositivo distorcem as análises. Uma empresa não deve tomar decisões baseadas em respostas repetidas da mesma pessoa no mesmo dia. O bloqueio é por dia corrido (meia-noite a meia-noite), não por janela de 24 horas — quem enviou às 23h de hoje pode enviar novamente às 0h de amanhã.

**Hoje:** a meia-noite é a de Brasília, embora o servidor rode em UTC. O limite é do ponto de coleta, não do canal: quem respondeu pelo QR Code não envia de novo no mesmo dia pelo link ou pela etiqueta NFC do mesmo escopo.

---

### Cada escopo tem até 3 perguntas configuráveis

**Decisão:** a empresa configura **até 3 perguntas** (de 1 a 3 efetivas) para cada contexto de coleta (empresa geral, produto, serviço ou departamento). Cada pergunta pode ter até 3 subperguntas. Se um campo de pergunta for deixado em branco, ele é apenas **desativado** (não é apagado): o histórico de respostas já recebidas é preservado e a pergunta volta a valer se for reativada.

**Por quê:** pedir demais cansa o cliente e reduz a taxa de resposta. Até três perguntas é o ponto de equilíbrio entre coletar informação útil e não tornar o formulário cansativo — mas a empresa não é obrigada a preencher as três. O limite de 3 subperguntas segue o mesmo raciocínio.

**Tamanho das perguntas:** entre 20 e 150 caracteres. Muito curto não tem contexto; muito longo confunde quem está respondendo pelo celular.

---

### Se um item não tem perguntas próprias, o formulário coleta só a nota

**Decisão:** quando um item de catálogo (produto, serviço ou departamento) não tem perguntas ativas configuradas, o formulário daquele item exibe **apenas a nota geral (estrelas) e o campo de mensagem** — **não** há fallback para as perguntas gerais da empresa.

**Hoje:** o campo de mensagem segue a configuração do escopo, que pode mostrar o convite padrão, uma pergunta própria ou ficar oculto.

**Por quê:** cada escopo deve refletir exatamente o que foi configurado para ele. Aproveitar as perguntas gerais da empresa em um item específico distorceria as métricas por escopo, atribuindo respostas a perguntas que não pertencem àquele item. Coletar só a nota mantém o dado limpo e ainda assim não bloqueia a coleta enquanto o gestor não configura perguntas próprias.

---

### As respostas têm uma escala fixa de 5 níveis

**Decisão:** as respostas às perguntas do formulário seguem sempre a mesma escala: Péssimo, Ruim, Mediana, Boa, Ótima — convertidas internamente para pontuações de 1 a 5.

**Por quê:** uma escala consistente permite comparar resultados entre empresas, produtos e períodos de tempo. Se cada empresa pudesse criar sua própria escala, as análises seriam incomparáveis.

---

### O texto do feedback é salvo junto com o contexto em que foi respondido

**Decisão:** quando um cliente responde o formulário, o sistema salva não só a resposta, mas também o texto exato da pergunta que foi feita naquele momento.

**Por quê:** as perguntas podem ser editadas ao longo do tempo. Se salvássemos só o ID da pergunta, perdemos o contexto histórico. Com o texto salvo na coleta, uma análise de feedbacks antigos sempre mostrará a pergunta como era quando a resposta foi dada.

---

## Catálogo de Produtos, Serviços e Departamentos

### Remover um item do catálogo não apaga os feedbacks associados a ele

**Decisão:** quando um produto, serviço ou departamento é removido da lista, ele passa a ser marcado como inativo — mas seus feedbacks e análises são preservados no histórico.

**Por quê:** apagar um item apagaria também o histórico de feedback dos clientes que responderam sobre ele. Isso destruiria dados que a empresa pode querer consultar depois, mesmo que o item não exista mais.

---

### Desativar o tipo "Produtos" limpa automaticamente a lista de produtos do contexto de IA

**Decisão:** se a empresa desativar a opção de catalogar produtos, o campo que lista os produtos para o contexto de inteligência artificial é zerado automaticamente.

**Por quê:** manter uma lista de produtos no contexto de IA enquanto o tipo está desativado criaria análises incoerentes — a IA saberia de produtos que a empresa disse que não usa. A limpeza automática garante que o contexto reflita a configuração atual.

---

## Análise por Inteligência Artificial

### A IA só analisa se a empresa descreveu o próprio negócio

**Decisão:** antes de rodar qualquer análise, o sistema verifica se a empresa preencheu três informações: o objetivo da empresa, o objetivo analítico e um resumo do negócio. Sem esses três campos, a análise não é executada.

**Por quê:** a IA precisa de contexto para gerar análises úteis. Sem saber o que a empresa faz e o que ela quer descobrir nos feedbacks, os resultados seriam genéricos e sem valor. Decidimos que é melhor bloquear a análise e pedir o contexto do que gerar um resultado ruim.

---

### São necessários pelo menos 10 feedbacks para rodar a análise

**Decisão:** a análise de IA exige um mínimo de 10 feedbacks não analisados. Com menos do que isso, o sistema não executa.

**Por quê:** análises com pouquíssimos feedbacks produzem conclusões estatisticamente frágeis — uma única resposta negativa pode parecer um padrão quando não é. Dez feedbacks é o piso mínimo para que os padrões identificados tenham algum significado.

**Hoje:** o piso de 10 vale para o escopo, não só para os pendentes. Só contam feedbacks com comentário e fora do "Testar o formulário". Se o escopo já tem 10 ou mais, os pendentes podem ser menos de 10; o relatório exige pelo menos 10 feedbacks já analisados no escopo.

---

### O mesmo feedback nunca é analisado duas vezes

**Decisão:** antes de enviar os feedbacks para análise, o sistema remove automaticamente os que já foram analisados anteriormente.

**Por quê:** reprocessar feedbacks antigos infla os resultados e desperdiça créditos de API. A deduplicação garante que cada feedback contribui para as análises apenas uma vez.

---

### Feedbacks são analisados separadamente por escopo

**Decisão:** feedbacks da empresa geral são analisados em conjunto; feedbacks de um produto específico são analisados em conjunto com outros feedbacks desse mesmo produto — nunca misturados.

**Por quê:** misturar feedbacks de contextos diferentes dilui os insights. O que os clientes acham do Produto A pode ser muito diferente do que acham do Produto B. Analisar separadamente permite identificar padrões específicos por contexto.

---

### Os resultados globais de análise são substituídos a cada execução

**Decisão:** o relatório de insights por escopo é sempre sobrescrito com os dados da última análise. Não há acúmulo de múltiplos relatórios antigos.

**Por quê:** insights globais representam a fotografia atual do conjunto de feedbacks analisados. Manter versões antigas em paralelo seria confuso — o gestor quer saber o que está acontecendo agora, não uma média histórica de análises passadas.

---

## Qualidade das Análises de IA

### Palavras que o próprio cliente selecionou no formulário não viram keywords

**Decisão:** as palavras e frases que aparecem nas opções do formulário (como "péssimo", "ótima", "Como foi o atendimento?") são bloqueadas de aparecer como palavras-chave ou categorias nas análises.

**Por quê:** se o cliente selecionou "Boa" numa pergunta de escala, "boa" não é uma insight — é só a opção que ele clicou. As keywords e categorias devem refletir o que o cliente escreveu com suas próprias palavras na mensagem livre, não as opções estruturadas que o formulário ofereceu.

---

### Keywords precisam estar presentes na mensagem do cliente

**Decisão:** uma palavra-chave sugerida pela IA só é aceita se ela ou parte dela estiver de fato presente no texto que o cliente escreveu.

**Por quê:** a IA pode "inventar" termos que parecem relevantes mas que o cliente nunca usou. Exigir que a keyword esteja ancorada na mensagem original reduz essas alucinações e ajuda a manter o resultado fiel ao que foi dito.

---

### Se a IA não conseguir extrair keywords úteis, o sistema usa as palavras mais relevantes da mensagem

**Decisão:** quando nenhuma keyword sugerida pela IA passa pela validação, o sistema extrai automaticamente as palavras mais relevantes diretamente do texto do cliente (ignorando palavras comuns como "de", "que", "para") e usa essas como fallback.

**Por quê:** é melhor ter algumas keywords básicas do que nenhuma. Mesmo um fallback simples já permite filtros e agrupamentos na interface.

---

### Se a IA não encontrar categorias, usa as primeiras keywords como substituto

**Decisão:** quando nenhuma categoria é validada, o sistema usa as duas primeiras keywords extraídas como categorias temporárias.

**Por quê:** deixar o campo de categorias vazio quebraria funcionalidades que dependem dele. As keywords são a aproximação mais próxima de uma categoria quando a categorização falha.

---

### Um sentimento inválido descarta só aquele feedback, não cancela a análise inteira

**Decisão substituída.** Hoje o `ia-analyze` exige um resultado válido para cada feedback do lote (`iaBatchResponse.validation.ts`). Um sentimento fora de positivo, neutro ou negativo invalida o lote inteiro (`invalid_ai_response_schema`), e a análise falha sem gravar resultado parcial. Os lotes já gravados numa execução anterior continuam salvos, e uma nova tentativa busca só os pendentes. A troca evita que o relatório avance com feedbacks faltando. A decisão original fica abaixo como registro.

**Decisão original:** se a IA classificar um sentimento de um feedback com um valor desconhecido (qualquer coisa que não seja positivo, neutro ou negativo), aquele feedback específico é descartado — mas os demais do mesmo lote continuam sendo processados normalmente.

**Por quê:** cancelar toda a análise por causa de um único feedback com dado inválido seria desproporcional. O ideal é aproveitar o que for válido e descartar silenciosamente o que não for.
