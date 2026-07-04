# Coleta via QR Code de Baixo Atrito

## O Que É

É o mecanismo central de entrada de dados do sistema. O cliente escaneia um QR Code físico com a câmera do celular e cai diretamente no formulário de feedback — sem criar conta, sem instalar nenhum app, sem digitar nenhuma URL.

Um scan. Uma avaliação. Pronto.

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
Cliente escaneia o QR Code
        ↓
Redirecionado para URL pública única do ponto de coleta
        ↓
Frontend chama o API Gateway com o ID do ponto de coleta
        ↓
API valida se a empresa existe e está ativa
        ↓
Formulário é exibido com as perguntas configuradas
        ↓
Cliente preenche nota, mensagem e dados opcionais
        ↓
Submissão enviada com fingerprint do dispositivo (anti-spam)
        ↓
Feedback persistido no banco → tela de confirmação exibida
```

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Taxa de resposta** | Tende a aumentar a coleta ao reduzir barreiras de acesso |
| **Presença física** | QR Code pode estar em qualquer lugar: balcões, embalagens, mesas, recibos |
| **Acessibilidade** | Funciona em qualquer smartphone com câmera, sem instalar nada |
| **Tempo de resposta** | O cliente avalia no momento exato da experiência, enquanto a memória é fresca |
| **Volume de dados** | Mais feedbacks coletados = análises de IA mais precisas e representativas |

---

## Detalhes Técnicos

- Cada ponto de coleta tem uma **URL pública única** com o `collection_point_id` como parâmetro
- Antes de exibir o formulário, o backend valida se a empresa está ativa (`enterprise_public`)
- Se a empresa ou o item do catálogo estiver inativo, o formulário não é exibido — o cliente vê uma tela de erro explicativa
- A submissão **não requer autenticação** — é uma rota pública com proteção via fingerprint
- O QR Code é gerado como imagem vetorial e pode ser baixado em `.png` ou compartilhado via `navigator.share`

---

## Referência Técnica

- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Anti-Spam por Fingerprint → anti-spam-fingerprint.md](./anti-spam-fingerprint.md)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
