# Coleta via QR Code de Baixo Atrito

## O Que É

É o mecanismo central de entrada de dados do sistema. O cliente escaneia um QR Code físico com a câmera do celular e cai diretamente no formulário de feedback — sem criar conta, sem instalar nenhum app, sem digitar nenhuma URL.

Um scan. Uma avaliação. Pronto.

O mesmo formulário também abre por mais dois **canais de coleta**: um **link** (para enviar por mensagem, e-mail ou redes) e uma **etiqueta NFC** (o cliente encosta o celular e o formulário abre). Os três levam às mesmas perguntas e às mesmas métricas do escopo.

---

## Por Que Existe

A maior inimiga da coleta de feedback é a **fricção**. Toda etapa extra que o cliente precisa executar antes de conseguir avaliar reduz drasticamente a taxa de resposta.

Formulários em papel são lentos e difíceis de agregar. Apps exigem instalação. Links digitados geram erros de digitação. E-mails ficam para "responder depois" (e nunca são respondidos).

O QR Code resolve tudo isso: está no balcão, na embalagem, no cardápio, na nota fiscal. O cliente já tem a câmera na mão, o que reduz bastante as barreiras de acesso.

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
Sem ponto de coleta ativo → tela de erro ("QR Code indisponível")
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

Cada escopo (a avaliação da empresa ou um item do catálogo) tem a seção **Canais de coleta** na configuração, com um card por canal:

| Canal | Como o gestor usa | Marca na URL |
|---|---|---|
| **QR Code** | Baixa a imagem em `.png` e imprime | `canal=qr` |
| **Link** | Copia ou compartilha (pelo compartilhamento do celular, quando existe) | `canal=link` |
| **Etiqueta NFC** | Grava o endereço numa etiqueta: direto pelo navegador no Chrome do Android (Web NFC) ou, no iPhone, por um app gravador de NFC | `canal=nfc` |

- Os três apontam para o **mesmo ponto de coleta** do escopo: a marca só diz por onde o cliente chegou. Ela é gravada em `feedback.channel` (`QR`, `LINK` ou `NFC`), e o Dashboard mostra quantas avaliações chegaram por canal ("Por onde chegaram").
- Marca ausente, desconhecida ou o antigo valor `QRCODE` grava `null` (sem canal), sem recusar a resposta.
- **Testar o formulário:** o painel abre o formulário com `canal=teste`. Esses feedbacks ficam marcados como `TEST` e aparecem na lista de Feedbacks recebidos com a marca "Teste", mas ficam **fora** de todas as métricas, do mínimo de feedbacks e da análise da IA.
- Com a coleta do escopo pausada, nenhum canal recebe respostas.

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
- Antes de exibir o formulário, o backend confirma que a empresa existe (view `enterprise_public`) e resolve o ponto de coleta do tipo QR Code com status `ACTIVE`. Sem ele, o formulário não é exibido — o cliente vê uma tela de erro explicativa
- O envio também exige o ponto de coleta ativo (senão `404 collection_point_not_found`) e respostas que batam exatamente com as perguntas ativas do escopo (senão `400 invalid_payload`)
- A submissão **não requer autenticação** — é uma rota pública com proteção via fingerprint (1 envio por aparelho, por ponto de coleta, por dia)
- O comentário aceita até 5000 caracteres. Dos dados opcionais de quem respondeu, só nome, e-mail e gênero são gravados (no cadastro do cliente, deduplicado por e-mail na empresa)
- A imagem do QR Code é gerada em PNG por um serviço externo (`api.qrserver.com`) a partir do endereço do formulário e pode ser baixada; o botão de compartilhar envia o link (pelo `navigator.share` ou, sem ele, copiando)

---

## Referência Técnica

- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Anti-Spam por Fingerprint → anti-spam-fingerprint.md](./anti-spam-fingerprint.md)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
