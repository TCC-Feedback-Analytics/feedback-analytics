# Anti-Spam por Fingerprint por Ponto de Coleta

## O Que É

É o sistema que ajuda a proteger a integridade dos dados coletados via QR Code, reduzindo submissões duplicadas e abusivas. Como o formulário é público — sem login, sem autenticação — qualquer pessoa poderia enviar dezenas de feedbacks e distorcer completamente as análises.

O mecanismo resolve isso identificando cada dispositivo de forma única e limitando a **1 feedback por dispositivo por ponto de coleta por dia**.

---

## Por Que Existe

Formulários públicos abertos são alvos naturais de submissões em massa — seja por acidente (cliente que tenta enviar duas vezes), seja por má-fé (concorrentes ou funcionários inflando/derrubando avaliações).

Se isso não for bloqueado, os relatórios de IA perdem toda a validade: médias distorcidas, sentimentos artificiais, categorias que não refletem a realidade. O produto deixa de ser confiável.

> Um banco de dados poluído é pior do que um banco vazio — porque você toma decisões erradas acreditando que são corretas.

---

## Como Funciona

```
Cliente submete o formulário
        ↓
API Gateway calcula o fingerprint do dispositivo:
  MD5(User-Agent + IP do cliente + época do dia atual)
        ↓
Verifica na tabela feedback se esse dispositivo (tracked_device_id)
já enviou feedback para esse collection_point_id hoje
        ↓
  ┌── Já enviou → retorna HTTP 409 Conflict
  │              (mensagem: DEVICE_ALREADY_SUBMITTED)
  │
  └── Ainda não enviou → prossegue com a submissão
        ↓
Fingerprint registrado em tracked_devices
        ↓
Feedback persistido com sucesso (HTTP 201)
```

---

## A Regra Inteligente: Por Ponto de Coleta

A limitação é **por ponto de coleta** — não por empresa. Isso é uma decisão deliberada e importante:

- Um cliente pode avaliar o **Produto A** e depois, no mesmo dia, avaliar o **Departamento de Suporte** → ambos são permitidos
- Um cliente **não pode** avaliar o mesmo produto duas vezes no mesmo dia → bloqueado com 409

Isso previne spam sem punir o cliente legítimo que interage com múltiplas áreas da empresa.

---

## Bloqueio Permanente de Dispositivo

Além do limite diário (HTTP 409), existe uma segunda camada: o **bloqueio permanente**.

Dispositivos marcados com `is_blocked = true` na tabela `tracked_devices` são permanentemente impedidos de enviar qualquer feedback, retornando **HTTP 403 Forbidden** — independentemente do dia ou do ponto de coleta.

| Situação | Código HTTP | Motivo |
|---|---|---|
| Segundo envio no mesmo dia, mesmo ponto | `409 Conflict` | Limite diário atingido |
| Dispositivo banido permanentemente | `403 Forbidden` | Dispositivo bloqueado por moderação |

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Integridade dos dados** | Reduz a probabilidade de feedbacks duplicados do mesmo dispositivo, ajudando a aproximar cada registro de uma experiência distinta |
| **Confiabilidade da IA** | Análises de sentimento e categorias só fazem sentido com dados limpos |
| **Sem necessidade de login** | A proteção funciona para usuários anônimos sem sacrificar a acessibilidade |
| **Flexibilidade** | Não penaliza clientes que interagem com múltiplos pontos de coleta |

---

## Detalhes Técnicos

- O fingerprint é calculado via `MD5(userAgent | clientIP | dayEpoch)` — muda a cada dia automaticamente
- O cálculo do MD5 é feito na **própria aplicação** (API Gateway, com o `crypto` do Node), assim como a verificação do limite diário. Existe uma função equivalente no banco — `generate_device_fingerprint` (e também `can_device_send_feedback` / `register_device_feedback`) — porém ela **não é invocada** pelo fluxo atual
- A tabela `tracked_devices` armazena o dispositivo: fingerprint, `is_blocked`/`blocked_*`, `feedback_count` e datas (`last_feedback_at`, `created_at`) — **não** possui `collection_point_id`. O vínculo por ponto de coleta/dia é consultado na tabela `feedback` (filtrando por `tracked_device_id` + `collection_point_id` + `created_at` do dia)
- O bloqueio diário (409) é por `collection_point_id` — o mesmo dispositivo em pontos diferentes passa normalmente
- O bloqueio permanente (403) é absoluto — bloqueia qualquer submissão daquele dispositivo

---

## Referência Técnica

- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Regras de Negócio → visao-geral.md#regras-de-negócio-rne](../concepcao/requisitos-e-funcionalidades.md)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
