# Coleta de Baixo Atrito: QR Code, Link e NFC

## O Que É

É o mecanismo central de entrada de dados do sistema. O cliente chega ao formulário público de feedback por um dos três **canais de coleta** — sem criar conta, sem instalar nenhum app, sem digitar nenhuma URL:

- **QR Code:** o cliente aponta a câmera do celular para o código impresso;
- **Link:** a empresa envia o endereço por mensagem, e-mail ou redes sociais;
- **Etiqueta NFC:** o cliente encosta o celular na etiqueta e o formulário abre.

Um scan, um clique ou um toque. Uma avaliação. Pronto. Os três levam às mesmas perguntas e às mesmas métricas do escopo.

---

## Por Que Existe

A maior inimiga da coleta de feedback é a **fricção**. Toda etapa extra que o cliente precisa executar antes de conseguir avaliar reduz drasticamente a taxa de resposta.

Formulários em papel são lentos e difíceis de agregar. Apps exigem instalação. Links digitados geram erros de digitação. E-mails ficam para "responder depois" (e nunca são respondidos).

Os canais de coleta resolvem isso: o QR Code e a etiqueta NFC ficam no balcão, na embalagem, no cardápio ou na nota fiscal, e o link chega pela conversa que o cliente já tem com a empresa. O celular já está na mão, o que reduz bastante as barreiras de acesso.

> **Sem coleta, não há dado. Sem dado, não há análise. Sem análise, o produto não existe.**
> Esta é a funcionalidade que alimenta todo o resto do sistema.

---

## Como Funciona

```
Cliente escaneia o QR Code (ou abre o link, ou encosta na etiqueta NFC)
        ↓
Abre o formulário público (/feedback/qrcode) com a empresa, o ponto de coleta
ou o item e a marca do canal na URL (canal=qr | link | nfc)
        ↓
Frontend chama o API Gateway (GET /api/public/enterprise/:id)
        ↓
API confirma que a empresa existe e resolve o ponto de coleta ATIVO do escopo
        ↓
Sem ponto de coleta ativo → tela de erro (coleta desativada)
        ↓
Formulário é exibido com as perguntas do escopo e o campo de comentário dele
        ↓
Cliente dá a nota (obrigatória), responde as perguntas e, se quiser,
comenta e informa nome, e-mail e gênero
        ↓
Envio (POST /api/public/qrcode/feedback) com o canal; o servidor calcula
o fingerprint do aparelho (anti-spam)
        ↓
Feedback persistido no banco → tela de confirmação exibida
```

---

## Canais de Coleta

Cada escopo (a avaliação da empresa, em `/user/qrcode/enterprise`, ou um item do catálogo) tem a seção **Canais de coleta** na configuração. No topo fica o interruptor **Coleta de respostas**, que liga ou pausa a coleta do escopo; abaixo, um card por canal:

| Canal | Como o gestor usa | Marca na URL |
|---|---|---|
| **QR Code** | Baixa a imagem em `.png` e imprime | `canal=qr` |
| **Link** | Copia ou compartilha (pelo compartilhamento do celular, quando existe) | `canal=link` |
| **Etiqueta NFC** | Grava o endereço numa etiqueta (recomendada: NTAG215): com um toque pelo Chrome do Android (Web NFC) ou, fora dele, copiando o endereço e gravando por um app como o NFC Tools | `canal=nfc` |

- Os três apontam para o **mesmo ponto de coleta** do escopo: a marca só diz por onde o cliente chegou. Ela é gravada em `feedback.channel` (`QR`, `LINK` ou `NFC`).
- Marca ausente, desconhecida ou o antigo valor `QRCODE` grava `null` (sem canal), sem recusar a resposta.
- **Testar o formulário:** o painel abre o formulário com `canal=teste`. Esses feedbacks ficam marcados como `TEST` e aparecem na lista de Feedbacks recebidos com a marca "Teste", mas ficam **fora** de todas as métricas, do mínimo de feedbacks e da análise da IA.
- Com a coleta do escopo pausada, nenhum canal recebe respostas.

### Por onde chegaram

- O Dashboard tem a seção **"Por onde chegaram"**: quantas avaliações vieram de cada canal e a média das estrelas de cada um. As avaliações sem marca de canal (de antes dela) ficam à parte.
- A lista de Feedbacks recebidos mostra o canal de cada feedback.
- O diagnóstico do escopo feito pela IA também recebe os números por canal.

---

## Campo de Comentário por Escopo

O comentário é **opcional** para o cliente e configurável em cada escopo:

| Modo | No formulário |
|---|---|
| **Padrão** (`DEFAULT`) | O convite "Conte-nos mais sobre sua experiência" |
| **Pergunta própria** (`CUSTOM`) | Uma pergunta do gestor, de 10 a 150 caracteres, no lugar do convite. Ela é guardada junto com o comentário (`feedback.comment_prompt`) e vai para a IA, que lê o texto como resposta a ela |
| **Oculto** (`HIDDEN`) | Sem campo de comentário; se algum texto chegar, o servidor o descarta |

Sem comentário, o feedback não vai para a IA nem conta como "aguardando análise".

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Taxa de resposta** | Tende a aumentar a coleta ao reduzir barreiras de acesso |
| **Presença física** | QR Code e etiqueta NFC podem estar em qualquer lugar: balcões, embalagens, mesas, recibos |
| **Acessibilidade** | Funciona em qualquer smartphone com câmera (ou com NFC), sem instalar nada |
| **Tempo de resposta** | O cliente avalia no momento exato da experiência, enquanto a memória é fresca |
| **Volume de dados** | Mais feedbacks coletados = análises de IA mais precisas e representativas |

---

## Detalhes Técnicos

- O endereço do formulário leva `enterprise`, e opcionalmente `collection_point` e `item`, mais a marca `canal`. Na etiqueta NFC o `item` fica de fora, para o endereço caber na memória da etiqueta
- Antes de exibir o formulário, o backend confirma que a empresa existe (view `enterprise_public`) e resolve o ponto de coleta do tipo `QR_CODE` (o nome técnico vale para os três canais) com status `ACTIVE`. Sem ele, o formulário não é exibido — o cliente vê uma tela de erro explicativa
- O envio também exige o ponto de coleta ativo (senão `404 collection_point_not_found`) e respostas que batam exatamente com as perguntas ativas do escopo (senão `400 invalid_payload`)
- A submissão **não requer autenticação** — é uma rota pública com proteção via fingerprint (1 envio por aparelho, por ponto de coleta, por dia)
- O comentário aceita até 5000 caracteres. Dos dados opcionais de quem respondeu, só nome, e-mail e gênero são gravados (no cadastro do cliente, deduplicado por e-mail na empresa)
- A imagem do QR Code é gerada em PNG por um serviço externo (`api.qrserver.com`) a partir do endereço do formulário e pode ser baixada; o botão de compartilhar envia o link (pelo `navigator.share` ou, sem ele, copiando)

---

## Referência Técnica

- [Pontos de Coleta por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Anti-Spam por Fingerprint → anti-spam-fingerprint.md](./anti-spam-fingerprint.md)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
