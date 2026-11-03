# Anti-Spam por Fingerprint por Ponto de Coleta

## O Que É

É o sistema que ajuda a proteger a integridade dos dados coletados pelo formulário público (QR Code, link ou etiqueta NFC), reduzindo submissões duplicadas e abusivas. Como o formulário é público — sem login, sem autenticação — qualquer pessoa poderia enviar dezenas de feedbacks e distorcer completamente as análises.

O mecanismo resolve isso identificando o aparelho por uma impressão digital (fingerprint) calculada no servidor e limitando a **1 feedback por aparelho por ponto de coleta por dia**.

---

## Por Que Existe

Formulários públicos abertos são alvos naturais de submissões em massa — seja por acidente (cliente que tenta enviar duas vezes), seja por má-fé (concorrentes ou funcionários inflando/derrubando avaliações).

Se isso não for bloqueado, os relatórios de IA perdem toda a validade: médias distorcidas, sentimentos artificiais, categorias que não refletem a realidade. O produto deixa de ser confiável.

> Um banco de dados poluído é pior do que um banco vazio — porque você toma decisões erradas acreditando que são corretas.

---

## Como Funciona

```
Cliente submete o formulário (POST /api/public/qrcode/feedback)
        ↓
API Gateway valida o payload, a empresa, o ponto de coleta ativo
e as respostas (precisam bater com as perguntas ativas do escopo)
        ↓
Calcula o fingerprint do aparelho:
  MD5(User-Agent | IP do cliente | início do dia atual)
        ↓
Procura o aparelho em tracked_devices (empresa + fingerprint)
        ↓
  ┌── Registro com is_blocked = true → HTTP 403 (DEVICE_BLOCKED)
  │
  ├── Registro já tem feedback neste collection_point_id desde o
  │   início do dia → HTTP 409 Conflict (DEVICE_ALREADY_SUBMITTED)
  │
  └── Senão → numa transação: cria o registro do aparelho (se for novo),
              grava o feedback e as respostas
        ↓
HTTP 200 { ok: true }
```

Na tela, o `409` vira o aviso de que aquele aparelho já respondeu hoje.

---

## A Regra Inteligente: Por Ponto de Coleta

A limitação é **por ponto de coleta** — não por empresa. Isso é uma decisão deliberada e importante:

- Um cliente pode avaliar o **Produto A** e depois, no mesmo dia, avaliar o **Departamento de Suporte** → ambos são permitidos
- Um cliente **não pode** avaliar o mesmo produto duas vezes no mesmo dia → bloqueado com 409

Isso previne spam sem punir o cliente legítimo que interage com múltiplas áreas da empresa.

O QR Code, o link e a etiqueta NFC de um mesmo escopo levam ao **mesmo ponto de coleta** (o canal é só uma marca na URL). Quem respondeu pelo QR Code não responde de novo pelo link no mesmo dia. O "Testar o formulário" do painel também passa por esse controle.

---

## O Efeito Real do Dia no Fingerprint

O início do dia entra no cálculo do hash. Por isso o fingerprint do mesmo aparelho **muda todo dia**, e cada dia vira um **registro novo** em `tracked_devices`. Na prática:

- **O limite diário vale dentro desse registro.** No dia seguinte o aparelho chega com outro fingerprint e responde de novo.
- **O dia vira no fuso do servidor.** O corte usa a meia-noite do horário local do servidor; em produção o servidor roda em UTC, então o dia do anti-spam vira à meia-noite UTC (21h no horário de Brasília).
- **O bloqueio (`is_blocked`) também vale só para o registro daquele dia** (ver [Bloqueio de Dispositivo](./bloqueio-dispositivo.md)).
- **Métricas que contam aparelhos enxergam um dia por vez.** O `feedback_count` do registro conta só os feedbacks daquele dia, e "Clientes que voltam" só reconhece quem avaliou de novo no mesmo dia (ver [Métricas e estatísticas](./metricas-e-estatisticas.md)).
- **O fingerprint não é único por pessoa.** Dois aparelhos que mandem o mesmo user agent pelo mesmo IP (por exemplo, na mesma rede Wi-Fi) geram o mesmo fingerprint e dividem o limite; a mesma pessoa em outra rede ou outro navegador gera outro.

---

## Bloqueio de Dispositivo

Além do limite diário (HTTP 409), existe uma segunda verificação: registros marcados com `is_blocked = true` em `tracked_devices` recebem **HTTP 403 Forbidden** em qualquer ponto de coleta da empresa. Como o fingerprint muda a cada dia, esse bloqueio só pega o registro do dia em que foi marcado.

| Situação | Código HTTP | Motivo |
|---|---|---|
| Segundo envio no mesmo dia, mesmo ponto | `409 Conflict` | Limite diário atingido |
| Registro do aparelho com `is_blocked = true` | `403 Forbidden` | Aparelho bloqueado |

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Integridade dos dados** | Reduz a probabilidade de feedbacks duplicados do mesmo aparelho no mesmo dia, ajudando a aproximar cada registro de uma experiência distinta |
| **Confiabilidade da IA** | Análises de sentimento e categorias só fazem sentido com dados limpos |
| **Sem necessidade de login** | A proteção funciona para usuários anônimos sem sacrificar a acessibilidade |
| **Flexibilidade** | Não penaliza clientes que interagem com múltiplos pontos de coleta |

---

## Detalhes Técnicos

- O fingerprint é calculado em `src/controllers/public/qrcode.controller.ts` do API Gateway, com o `crypto` do Node: `MD5(userAgent | clientIP | dayEpoch)`, em que `dayEpoch` é o início do dia (00:00 no horário local do servidor) em segundos. O cliente não envia fingerprint nenhum
- A verificação do limite diário também é feita na aplicação. As funções antigas do banco — `generate_device_fingerprint`, `can_device_send_feedback` e `register_device_feedback` — ainda existem (migration `0001` do gateway), mas **não são chamadas** pelo fluxo atual
- A tabela `tracked_devices` guarda, por empresa (`enterprise_id`), o fingerprint, o user agent, o IP, o vínculo opcional com o cliente (`customer_id`), `is_blocked`/`blocked_*`, `feedback_count` e datas (`last_feedback_at`, `created_at`) — **não** possui `collection_point_id`. O vínculo por ponto de coleta/dia é consultado na tabela `feedback` (filtrando por `tracked_device_id` + `collection_point_id` + `created_at` desde o início do dia)
- O bloqueio diário (409) é por `collection_point_id` — o mesmo aparelho em pontos diferentes passa normalmente
- O bloqueio por `is_blocked` (403) vale para todos os pontos de coleta da empresa, mas só para o registro (fingerprint) daquele dia
- Aparelho, feedback e respostas são gravados numa única transação; a atualização de `feedback_count`, `last_feedback_at`, user agent e IP do registro roda depois e não invalida o feedback se falhar

---

## Referência Técnica

- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Regras de Negócio (RNE)](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
