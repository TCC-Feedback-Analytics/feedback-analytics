# 06 — Novo canal de coleta por NFC

> **Em uma frase:** permitir que o cliente abra o formulário de feedback só encostando o celular numa etiqueta (a mesma tecnologia do "pagamento por aproximação"), além do QR Code que já existe.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 4-5 |
| **Esforço** | Baixo-Médio |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | Nada crítico. Combina muito bem com a [02 — Métricas por período e comparação](./02-metricas-por-periodo-e-comparacao.md), que ganha um eixo novo de comparação ("por canal") |
| **Camadas afetadas** | Frontend · Backend · Banco · RLS |

## Para qualquer leitor

Hoje, para deixar um feedback, o cliente precisa abrir a câmera do celular, mirar no QR Code e tocar no link que aparece. Funciona, mas tem fricção: nem todo mundo sabe que a câmera lê QR Code, alguns precisam baixar um aplicativo, e em ambientes com pouca luz a leitura falha.

O **NFC** (sigla para "comunicação por aproximação") é a mesma tecnologia que você usa quando paga com o celular encostando-o na maquininha. A ideia aqui é colar uma pequena **etiqueta** (uma "tag", do tamanho de uma moeda ou de um adesivo) na mesa, no balcão ou no produto. O cliente só **encosta o celular** na etiqueta e o formulário de feedback abre sozinho — sem abrir a câmera, sem mirar, sem app.

O detalhe mais importante, e que vale explicar com calma: **por baixo dos panos, NFC e QR Code são quase a mesma coisa.** O QR Code nada mais é do que um desenho que "esconde" um endereço de internet (uma URL). Quando a câmera lê o QR, ela só descobre esse endereço e o abre. A etiqueta NFC guarda **exatamente o mesmo endereço** — só que em vez de a câmera "ler o desenho", o celular "lê a etiqueta" por aproximação. O resultado é idêntico: abre o mesmo formulário de feedback que já temos hoje. Por isso funciona tanto em iPhone quanto em Android.

Então o trabalho aqui não é construir um sistema novo do zero. É (1) ensinar o sistema a saber que aquele feedback chegou "por etiqueta" e não "por QR", para podermos **comparar qual canal funciona melhor**, e (2) oferecer um jeito de **gravar a etiqueta** com o endereço certo.

## O que muda para quem usa o sistema

- **Para o cliente que dá o feedback:** uma forma mais rápida e moderna de responder — encostar o celular em vez de abrir a câmera. Menos passos, menos chance de desistir no meio.
- **Para o gestor:** passa a oferecer dois "canais" de coleta no mesmo lugar (QR Code e etiqueta NFC) e, mais importante, **consegue comparar os dois**: "as etiquetas na mesa trouxeram mais respostas do que o cartaz com QR?".
- **Para o gestor (operacional):** uma tela para **cadastrar uma etiqueta** como ponto de coleta e gravar nela o endereço correto, do mesmo jeito que hoje ele gera um QR Code.
- **Honestidade desde já:** a etiqueta é um item físico que precisa ser comprado e colado. Isso tem um custo pequeno por unidade e exige logística (alguém precisa instalar). Não é "de graça" como imprimir um QR.

## Como vai funcionar

A grande sacada é que **o formulário não muda em nada**. Hoje ele é só uma página na internet com um endereço como `…/feedback/qrcode?enterprise=ID-DA-EMPRESA`. Esse mesmo endereço é o que vai dentro da etiqueta NFC.

**Antes (só QR Code):**

1. O gestor gera um QR Code que aponta para o endereço do formulário.
2. Imprime e cola num cartaz/adesivo.
3. O cliente abre a câmera, mira no QR, toca no link e responde.

**Depois (QR Code + NFC, convivendo):**

1. O gestor cadastra um ponto de coleta do tipo **NFC** e grava o endereço do formulário na etiqueta.
2. Cola a etiqueta na mesa/balcão/produto.
3. O cliente **encosta o celular** na etiqueta → o formulário abre direto → responde.
4. O sistema registra que aquele feedback veio **pelo canal NFC**, e o gestor vê isso lado a lado com o QR nos relatórios.

**O ponto delicado — gravar a etiqueta.** "Ler/abrir" a etiqueta funciona em **qualquer celular** (iPhone e Android). Mas **escrever** o endereço na etiqueta pelo navegador só funciona no **Chrome do Android** — o iPhone (Safari) não deixa o navegador gravar etiquetas. Então a gravação é feita de duas formas, e vamos deixar isso claro na tela:

- **Caminho principal:** abrir a tela no **Chrome de um celular Android** e gravar a etiqueta com um toque.
- **Caminho alternativo (fallback):** usar um aplicativo gratuito de "NFC writer" (existem vários) e colar o endereço que a nossa tela mostra. Serve para quem só tem iPhone à mão.

A boa notícia: gravar a etiqueta é uma tarefa feita **uma vez**, na instalação. O uso do dia a dia (encostar e responder) é universal.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

A coluna `type` da tabela `collection_points` já é **texto livre** (`"type" text NOT NULL`, ver `database/sql/tables/public.collection_points.sql:11`), então adicionar o valor `'NFC'` não exige migração de schema — só ampliar as regras que hoje assumem `'QR_CODE'`. O modelo já está preparado para ser **multicanal**; o que falta é destravar os três pontos que cravam o tipo na unha.

**Os três pontos que hoje chumbam `'QR_CODE'` (todos precisam aceitar o novo canal):**

1. **A query do backend** em `feedback-analytics-api-gateway/src/controllers/public/qrcode.controller.ts:63`:
   ```ts
   .eq('type', 'QR_CODE')
   ```
   Trocar por um filtro que aceite o conjunto de canais válidos, p. ex. `.in('type', ['QR_CODE', 'NFC'])`. O resto do controller (perguntas por escopo, anti-duplicação por `tracked_device`, inserção) é **agnóstico ao canal** e não muda.

2. **A policy RLS de leitura anônima** de `collection_points` (`database/sql/tables/public.collection_points.sql:62-66`), hoje chamada *"Anon pode ler pontos QR_CODE ativos"*, que tem `(type = 'QR_CODE'::text)` no `USING`. Precisa passar a aceitar `type IN ('QR_CODE','NFC')`.

3. **A policy RLS de insert anônimo** de `feedback` (`database/sql/tables/public.feedback.sql:39-43`), *"Anon pode inserir feedback via QR_CODE com checks"*, cujo `WITH CHECK` exige `cp.type = 'QR_CODE'`. Precisa aceitar `cp.type IN ('QR_CODE','NFC')`, **mantendo todos os demais checks** (empresa bate, `tracked_device` não bloqueado, ponto ativo).

**Recomendação de modelagem (segurança ao ampliar tipos):** em vez de espalhar literais `IN (...)` pelo código e pelas policies, adicionar um **`CHECK constraint`** em `collection_points.type` (`CHECK (type IN ('QR_CODE','NFC'))`) para que o banco rejeite canais desconhecidos. Assim, ampliar o tipo vira uma decisão central e auditável, e a RLS continua sendo a fronteira de segurança — não a query de aplicação. Versionar essa constraint em `database/sql/`.

**Atribuição de canal nas métricas.** A `collection_point_id` já é gravada em cada `feedback` (`qrcode.controller.ts:277`), e dela se chega ao `type`. Para os relatórios, basta um `JOIN feedback → collection_points` agrupando por `cp.type`. Isso alimenta o eixo "por canal" da [etapa 02](./02-metricas-por-periodo-e-comparacao.md). Vale criar um índice em `collection_points (enterprise_id, type)` para a agregação.

**Frontend — tela de "gravar etiqueta".** Nova tela no painel (`feedback-analytics-web`) que:
- monta a mesma URL pública do formulário (`/feedback/qrcode?enterprise=:id`, opcionalmente com o ponto/escopo) que o QR já usa;
- detecta suporte a **Web NFC** (`'NDEFReader' in window`); se houver (Chrome/Android), oferece botão "Gravar etiqueta" que chama `new NDEFReader().write({ records: [{ recordType: 'url', data: url }] })`;
- se **não** houver suporte (iOS/desktop), esconde o botão e mostra o **fallback**: exibe a URL com botão "copiar" e instruções de usar um app NFC writer.

> Decisão de nomenclatura/rota: a rota e o `type` literal `'QR_CODE'` aparecem no nome do arquivo do controller e da URL. Para não fazer um rename arriscado agora, mantemos a **rota e o nome de arquivo atuais** e só ampliamos os filtros; o canal vira um dado (`type`), não um endpoint novo. Um rename cosmético (ex.: `feedback/collect`) pode entrar depois, fora do caminho crítico.

## Riscos e decisões em aberto

- **Web NFC só no Chrome/Android.** Escrever etiqueta pelo navegador não funciona no iPhone — por isso o fallback via app é parte do plano, não um "extra". É preciso comunicar isso na tela com clareza para não frustrar quem só tem iPhone.
- **Custo e logística das etiquetas físicas.** Tags NFC (NTAG213/215) são baratas por unidade, mas há custo de compra, gravação e instalação. Para o TCC, basta uma pequena quantidade para demonstração.
- **Segurança da RLS ao ampliar os tipos.** Ao trocar `= 'QR_CODE'` por `IN (...)` nas policies, é fácil afrouxar uma checagem sem querer. Mitigação: alterar **só** o predicado de tipo, manter todos os outros checks, e fechar o conjunto de valores com um `CHECK constraint` no banco.
- **Etiquetas regraváveis.** Uma tag não bloqueada pode ser reescrita por terceiros. Para demonstração não é crítico; em produção, considerar **travar (lock)** a tag após gravar. Decisão em aberto.
- **Compatibilidade de hardware.** Aparelhos muito antigos podem não ter chip NFC. Como o QR continua existindo lado a lado, isso não bloqueia ninguém — é fallback natural.
- **Em aberto:** vamos diferenciar canal **apenas** por `type`, ou também por ponto de coleta individual (uma etiqueta por mesa)? Começar simples (por `type`) e evoluir se a [02](./02-metricas-por-periodo-e-comparacao.md) pedir granularidade.

## Como vamos saber que deu certo

- [ ] É possível cadastrar um ponto de coleta com `type = 'NFC'` no painel.
- [ ] Encostar um celular (iPhone **e** Android) numa etiqueta gravada abre o formulário público correto, já com a empresa/escopo certos.
- [ ] Um feedback enviado por NFC é **persistido** com sucesso (a policy RLS de insert anônimo aceita `type = 'NFC'`).
- [ ] A policy RLS continua **rejeitando** insert para qualquer `type` fora do conjunto permitido (teste negativo).
- [ ] No Chrome/Android, o botão "Gravar etiqueta" grava a URL na tag em um toque.
- [ ] No iPhone/desktop, a tela esconde o botão e mostra o fallback (URL copiável + instrução).
- [ ] Os relatórios mostram a contagem de feedbacks **separada por canal** (QR_CODE × NFC).

## Etapas de entrega

1. **Banco e RLS (fundação):** adicionar `CHECK (type IN ('QR_CODE','NFC'))` em `collection_points`; ampliar as duas policies (`collection_points` leitura e `feedback` insert) para aceitar `'NFC'`; versionar em `database/sql/`. Entrega: feedback por NFC já é aceito pelo banco.
2. **Backend:** trocar `.eq('type','QR_CODE')` por `.in('type', ['QR_CODE','NFC'])` no `qrcode.controller.ts`. Entrega: o endpoint público serve pontos NFC.
3. **Frontend — gravação:** tela de "gravar etiqueta" com Web NFC no Android e fallback de URL copiável + app NFC writer. Entrega: gestor consegue preparar uma etiqueta sozinho.
4. **Métricas por canal:** `JOIN`/agrupamento por `cp.type` e índice de apoio; expor a quebra "por canal" alimentando a [etapa 02](./02-metricas-por-periodo-e-comparacao.md). Entrega: comparação QR × NFC visível.

## O que isso demonstra no TCC

- **Arquitetura omnichannel (multicanal):** um mesmo fluxo de coleta servido por canais distintos, com modelagem **extensível de canal** (basta um valor novo em `type` + ampliar predicados), em vez de endpoints duplicados.
- **Web NFC / NDEF na prática:** uso de uma API de plataforma emergente (escrita de registros NDEF do tipo URL pelo navegador) com **degradação graciosa** (fallback) por limitação de plataforma — um caso real de compatibilidade cross-platform.
- **Segurança em camadas ao evoluir o modelo:** ampliar tipos mantendo a RLS como fronteira e fechando o domínio com `CHECK constraint` — um bom exemplo de "estender sem afrouxar".

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [02 — Métricas por período e comparação](./02-metricas-por-periodo-e-comparacao.md) — recebe o eixo de comparação "por canal" que esta etapa habilita
- [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md) — coleta anônima e RLS no canal público
