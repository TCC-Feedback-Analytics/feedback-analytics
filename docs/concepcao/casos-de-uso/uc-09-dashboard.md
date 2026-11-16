# UC-09: Visualização do Dashboard

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Ter uma visão geral e atualizada da situação dos feedbacks da empresa e abrir o detalhe da nota e dos clientes e canais |
| **Gatilho** | Gestor faz login ou navega para o dashboard (ou para as páginas Nota e Clientes e canais) |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa o dashboard ("Visão geral", `/user/dashboard`). A página não tem cabeçalho próprio: o nome dela fica no breadcrumb.
2. O dashboard segue o **escopo** e o **período** escolhidos na barra de controles abaixo do cabeçalho: escopo Geral, Produto, Serviço ou Departamento (com o item escolhido quando aplicável) e período (todo o período, 7 ou 30 dias, 3 ou 6 meses ou personalizado), com a comparação com o período anterior. O sistema carrega em paralelo as estatísticas e as métricas por pergunta **dentro desse recorte**. Feedbacks de teste (`channel = 'TEST'`) não entram nas métricas.
3. Só no Dashboard, a barra de controles traz o botão **"QR Code"** (no celular, só o ícone), que leva à tela de canais do escopo selecionado: a Avaliação da empresa no escopo Geral, a tela do item quando há item escolhido e a lista do catálogo do tipo quando o tipo está selecionado sem item. Ao lado fica o botão "Analisar comentários com IA" (UC-11), com o mesmo desenho.
4. Os comentários aguardando análise da IA no escopo aparecem no **sino** do cabeçalho ("N comentários novos" ou "Tudo em dia!"). O sino também tem o link **"Ver todos os feedbacks"**, que leva à listagem completa (`/user/feedbacks/all`, UC-10).
5. O dashboard exibe um resumo por grupo, com link para o detalhe. Cada seção tem uma **etiqueta de escopo** clicável (ex.: "Avaliação geral da empresa", "Produto · Pizza") que abre o seletor de escopo. A ordem é:
   - **Avaliação por estrelas:** cards de **Média** (`4,2 /5 ★ Boa · 128 avaliações`, com o indicador de **Precisão**), **Positivas (4–5★)**, **Neutras (3★)** e **Críticas (1–2★)**, com contagem e %. O link **"Ver a nota completa"** abre a página Nota (`/user/ratings`, ver o fluxo alternativo abaixo). Com itens comparáveis no catálogo, aparece também **"Comparar dois itens"** (`/user/compare`).
   - **Perguntas do formulário:** as perguntas **atuais**, na ordem do formulário (até 3), cada uma com nota /5, rótulo, respostas, % de satisfeitos e Precisão, e o link **"Ver todas as métricas desta pergunta"** (`/user/questions/:questionId`). Com um tipo escolhido sem item, a seção pede para escolher um item. No fim, o link **"Perguntas que saíram do formulário"** aparece quando houver alguma.
   - **Por onde chegaram:** quantas avaliações e a média de estrelas por canal (QR Code, link compartilhado e etiqueta NFC). As avaliações sem marca de canal (anteriores à marcação ou de QR Codes impressos antes dela) ficam numa linha à parte. O link **"Ver horários de pico e clientes que voltam"** abre a página Clientes e canais (`/user/customers`, ver o fluxo alternativo abaixo).
   - **Análise dos comentários ✨IA:** quem escreve comentário (o comentário é opcional), o bloco **Tom dos comentários** (barra positivo/neutro/negativo, saldo em palavras e Precisão) e o **Resumo dos comentários e recomendações**, com o link **"Ver a análise completa dos comentários"** (`/user/insights/overview`).
   - **Diagnóstico do escopo ✨IA:** a IA junta estrelas, perguntas e comentários do escopo no período, compara com o período anterior e diz o que fazer. O gestor clica em "Gerar diagnóstico" (ou "Atualizar diagnóstico", "Gerar para o período selecionado", "Gerar de novo"), e o job roda em segundo plano. Quando já há diagnóstico, o link **"Ver o histórico de diagnósticos"** abre `/user/diagnosis`, também no menu ("Diagnósticos ✨"). Com 10 ou mais avaliações no período, a seção abre o dashboard, antes da Avaliação por estrelas; com menos, fica no fim.
6. Ao acessar o dashboard logo após o login (`?login=success`), o sistema exibe o toast "Login realizado com sucesso." e tira o parâmetro da URL.

> **Conta nova.** Enquanto falta algum passo, os **"Primeiros passos"** aparecem no topo: "Ativar QR Code" (o QR geral da Avaliação da empresa) e "Testar o formulário (opcional)", cujo teste não entra nas métricas. Sem nenhum feedback na conta, o dashboard mostra as boas-vindas ("Seu painel está pronto. Falta o primeiro feedback.") e, no lugar das seções, a prévia **"O que vai aparecer aqui"**, com as seções do Dashboard em dados de exemplo e as perguntas reais do formulário. O guia do sistema não abre sozinho: o dashboard convida o gestor, que pode começar ou adiar.

### Fluxo alternativo — Página Nota

1. O gestor clica em **"Ver a nota completa"**, na Avaliação por estrelas, ou abre **"Nota"** no menu (`/user/ratings`; breadcrumb "Visão geral › Nota").
2. A página segue o mesmo escopo e período da barra de controles e mostra:
   - **Avaliação por estrelas:** os mesmos cards do Dashboard (Média, Positivas, Neutras e Críticas), com a comparação com o período anterior.
   - **Distribuição das avaliações:** quantas avaliações de 1 a 5★ (só quando há avaliações no recorte).
   - **Movimento das avaliações:** as barras mostram quantas avaliações chegaram em cada dia, semana ou mês; a linha, a média das estrelas no mesmo intervalo.

### Fluxo alternativo — Página Clientes e canais

1. O gestor clica em **"Ver horários de pico e clientes que voltam"**, em Por onde chegaram, ou abre **"Clientes e canais"** no menu (`/user/customers`; breadcrumb "Visão geral › Clientes e canais").
2. A página segue o mesmo escopo e período da barra de controles e mostra:
   - **Por onde chegaram:** a mesma seção do Dashboard.
   - **Dias e horários de pico:** em que dia da semana e faixa do dia os clientes mais avaliam ("Mais avaliações") e onde a média cai ("Pior média"). A cor é a quantidade e o número é a média.
   - **Clientes que voltam:** quanto das avaliações vem de quem já tinha avaliado e se quem volta está mais ou menos satisfeito que quem avalia pela primeira vez ("Quem volta está mais satisfeito", "Quem volta está menos satisfeito", "As notas são iguais" ou "Diferença incerta: ainda há poucas avaliações para saber"). O cliente é o aparelho, então o número é aproximado.

> **Menu e guia.** No menu, "Nota" e "Clientes e canais" vêm logo depois de "Visão geral". As páginas que não cabem na largura do cabeçalho vão para o botão **"Mais"**. O guia do sistema passa por elas nos passos "Nota", "Movimento das avaliações" e "Clientes e canais".

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Escopo sem nenhum feedback coletado ainda | "Avaliação por estrelas" mostra "Ainda sem avaliações {no escopo}" em vez de "0,0". Cada pergunta do formulário mostra "Ainda sem respostas {no escopo}". O tom dos comentários mostra "Ainda sem comentários analisados pela IA {no escopo}" e o resumo mostra "Ainda não há resumo dos comentários para este escopo". "Por onde chegaram" não aparece, e com ela o link para Clientes e canais (a página continua no menu). Na página Nota e em Clientes e canais, cada seção mostra "Ainda sem avaliações {no escopo}". |
| Escopo de item sem perguntas no formulário | "Perguntas do formulário" mostra "Este {produto, serviço ou departamento} não tem perguntas no formulário" (no Geral: "O formulário geral não tem perguntas ativas"). |
| Campo de comentário oculto no escopo | O tom dos comentários avisa que o campo está oculto e que não há comentários para a IA ler |
| IA não configurada ou contexto da empresa incompleto | O diagnóstico mostra "Configure a IA para receber o diagnóstico." com o link "Configurar a IA", ou "A IA precisa conhecer a empresa para recomendar." com o link "Preencher os dados da empresa" |
| Falha ao gerar o diagnóstico | Mostra "Não foi possível gerar o diagnóstico" com o motivo e, quando o erro pede, o atalho para a Configuração de IA |
| Erro ao carregar as estatísticas | Exibe a mensagem de erro inline no topo do dashboard ("Não foi possível carregar os dados do dashboard. Tente novamente mais tarde.") — a página permanece acessível, não há redirecionamento |
| Erro ao carregar a página Nota | No lugar das seções, mostra "Não foi possível carregar as avaliações agora. Tente novamente em instantes.". Se só o movimento falhar, a seção mostra "Não foi possível carregar o movimento agora." |
| Erro ao carregar a página Clientes e canais | No lugar de Por onde chegaram, mostra "Não foi possível carregar os canais agora. Tente novamente em instantes.". As outras seções carregam os próprios dados e falham à parte: "Não foi possível carregar os dias e horários agora." e "Não foi possível carregar os clientes que voltam agora." |
| Sessão expirada durante a navegação | Redireciona automaticamente para `/login` |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC09-01]** ✅ *Coberto manual (runbook)* - Caminho feliz: gestor autenticado acessa `/user/dashboard`, vê o item "Visão geral" destacado no menu e a barra de escopo e período com o botão "QR Code", que leva à tela de canais do escopo. O Dashboard não tem título nem breadcrumb próprios.
- **[CT-UC09-02]** ✅ *Coberto manual (runbook)* - Avaliação por estrelas: o card "Média" mostra a nota /5, o rótulo (Ótima, Boa, Mediana, Ruim ou Péssima) e o número de avaliações, ou "Ainda sem avaliações" no escopo; a etiqueta de escopo aparece no canto da seção e, com um período escolhido, os cards trazem a comparação com o período anterior.
- **[CT-UC09-03]** ✅ *Coberto manual (runbook)* - Positivas, neutras e críticas: os cards "Positivas (4–5★)", "Neutras (3★)" e "Críticas (1–2★)" aparecem com contagem e %. O link "Ver a nota completa" leva a `/user/ratings` e, com pelo menos dois itens do mesmo tipo no catálogo, "Comparar dois itens" leva a `/user/compare`.
- **[CT-UC09-04]** ✅ *Coberto manual (runbook)* - Análise dos comentários: aparecem o bloco "Tom dos comentários" (ou "Ainda sem comentários analisados pela IA") e o card "Resumo dos comentários e recomendações" (ou "Ainda não há resumo dos comentários para este escopo"); o link "Ver a análise completa dos comentários" leva a `/user/insights/overview`.
- **[CT-UC09-05]** ✅ *Coberto manual (runbook)* - Navegação: abrir o sino do cabeçalho e clicar em "Ver todos os feedbacks" leva à listagem completa (`/user/feedbacks/all`).
- **[CT-UC09-06]** 📝 *Planejado / não implementado* - Caminho feliz — toast de login: acessar o dashboard com `?login=success` na URL deve exibir o toast "Login realizado com sucesso." e remover o parâmetro da URL.
- **[CT-UC09-07]** ❌ *Cenário não coberto* - Exceção — erro de carregamento: simular falha na API de estatísticas deve exibir a mensagem de erro inline no topo, sem redirecionar.
- **[CT-UC09-08]** 📝 *Planejado / não implementado* - Exceção — sessão expirada: acessar o dashboard com sessão inválida deve redirecionar para `/login`. (Coberto de forma análoga em UC-12 via rota protegida.)
- **[CT-UC09-09]** ✅ *Coberto manual (runbook)* - Por onde chegaram: com um canal só, aparece "Todas as avaliações marcadas ... vieram pelo QR Code" (ou "Link compartilhado" / "Etiqueta NFC"); com mais de um, uma linha por canal com contagem, % e média. As avaliações sem a marca de canal ficam numa linha à parte, com a orientação de baixar o QR Code de novo. Sem avaliações no escopo, a seção não aparece, e os envios do "Testar o formulário" não entram.
- **[CT-UC09-10]** ✅ *Coberto manual (runbook)* - Diagnóstico do escopo e histórico: com a IA configurada, o contexto completo e 10 ou mais avaliações no recorte, "Gerar diagnóstico" mostra "A IA está lendo os números e os comentários. Leva alguns segundos." (ou "Aguardando a vez na cota da IA…") e depois o diagnóstico com "O que fazer, em ordem", "O que vai bem", "O que preocupa" e "O que mudou"; o botão passa a "Gerar de novo", "Atualizar diagnóstico" ou "Gerar para o período selecionado". "Ver o histórico de diagnósticos" (ou o menu "Diagnósticos ✨") abre `/user/diagnosis`. Sem IA, sem contexto ou com menos de 10 avaliações, a seção mostra o aviso correspondente ("São precisas pelo menos 10 avaliações ..." com o botão desabilitado); sem diagnóstico, `/user/diagnosis` mostra "Ainda não há diagnóstico ..." com o link "Gerar o primeiro no Dashboard". Consome a cota da IA.
- **[CT-UC09-11]** ✅ *Coberto manual (runbook)* - Nota completa: "Ver a nota completa" leva a `/user/ratings`, com "Avaliação por estrelas" (com "Neutras (3★)"), "Distribuição das avaliações" e "Movimento das avaliações", cada uma com "Ainda sem avaliações ..." quando o escopo não tem dados. Os dias e horários de pico e os clientes que voltam ficam em Clientes e canais (CT-UC09-15).
- **[CT-UC09-12]** ✅ *Coberto manual (runbook)* - Comparar dois itens: em "Comparar itens" (`/user/compare`), sem dois itens do mesmo tipo aparece o passo a passo ("Cadastre os itens no Catálogo", "Ative a coleta de cada item", "Volte aqui e escolha os dois"); com eles, a tabela compara "Nº de avaliações", "Média", "Positivas (4–5★)", "Neutras (3★)", "Críticas (1–2★)", "Tom dos comentários", "Escreveram comentário" e "Precisão da média", com a coluna "Quem está melhor" ("Diferença incerta" quando as margens se sobrepõem).
- **[CT-UC09-13]** ✅ *Coberto manual (runbook)* - Primeiros passos e "Testar o formulário": com a coleta pausada, o cartão mostra "Ativar a coleta da empresa" e "Testar o formulário (opcional)", desabilitado com "Ative o QR Code para poder testar.". "Ativar QR Code" vira "Coleta ativada"; o teste enviado mostra "Pronto! Seu teste chegou." e o cartão passa a "Tudo pronto ✓". O feedback aparece na listagem com a marca "Teste" e o canal "Teste do formulário", fora das métricas. Se o aparelho já respondeu no dia, a janela mostra "Você já respondeu por este aparelho."; "Pular" conclui o passo sem testar.
- **[CT-UC09-14]** 📝 *Planejado / não implementado* - Caminho feliz — página Nota: clicar em "Ver a nota completa" (ou em "Nota" no menu) abre `/user/ratings` com "Avaliação por estrelas" (Média, Positivas, Neutras e Críticas), "Distribuição das avaliações" e "Movimento das avaliações", no escopo e no período da barra; trocar o escopo atualiza os números. Com falha na API, mostra "Não foi possível carregar as avaliações agora. Tente novamente em instantes.".
- **[CT-UC09-15]** 📝 *Planejado / não implementado* - Caminho feliz — página Clientes e canais: clicar em "Ver horários de pico e clientes que voltam" (ou em "Clientes e canais" no menu) abre `/user/customers` com "Por onde chegaram", "Dias e horários de pico" e "Clientes que voltam", no escopo e no período da barra. Com falha na API das estatísticas, mostra "Não foi possível carregar os canais agora. Tente novamente em instantes." e as outras duas seções seguem carregando.
