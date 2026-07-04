# Bloqueio Permanente de Dispositivo

## O Que É

É a segunda camada de proteção do sistema de coleta pública. Enquanto o anti-spam por fingerprint bloqueia submissões duplicadas no mesmo dia (HTTP 409), o bloqueio permanente vai além: dispositivos marcados como `is_blocked` são **impedidos indefinidamente** de enviar qualquer feedback, retornando HTTP 403.

---

## Por Que Existe

O limite diário (1 feedback por dispositivo por ponto de coleta por dia) resolve a maioria dos casos — o cliente que tenta enviar duas vezes por engano, o bot simples que não muda de IP.

Mas existem situações que exigem uma resposta mais definitiva:

- Um dispositivo enviou feedbacks claramente fraudulentos ou ofensivos
- Um ator mal-intencionado está rotacionando horários para burlar o limite diário
- É necessário banir permanentemente uma origem específica sem depender do ciclo de 24h

O bloqueio permanente existe para esses casos. É uma ferramenta de **moderação**, não de controle de frequência.

---

## A Diferença Entre 409 e 403

| Situação | Código | Significado | Duração |
|---|---|---|---|
| Mesmo dispositivo, mesmo ponto, mesmo dia | `409 Conflict` | Limite diário atingido | Até meia-noite — no dia seguinte libera |
| Dispositivo banido (`is_blocked = true`) | `403 Forbidden` | Dispositivo bloqueado permanentemente | Indefinido — só remove manualmente |

O `409` é automático e temporário — parte do fluxo normal. O `403` é intencional e permanente — resultado de uma decisão de moderação.

---

## Como Funciona

```
Cliente submete o formulário
        ↓
API calcula o fingerprint do dispositivo
        ↓
Consulta tabela tracked_devices pelo fingerprint
        ↓
  ┌── is_blocked = true → retorna HTTP 403 (DEVICE_BLOCKED)
  │
  └── is_blocked = false → verifica limite diário normalmente
```

O bloqueio é verificado **antes** da checagem de duplicidade diária — é a primeira barreira.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Moderação sem login** | Permite banir origens específicas sem exigir autenticação dos clientes |
| **Proteção persistente** | Não depende do ciclo de 24h — o bloqueio permanece ativo enquanto não for removido |
| **Separação de camadas** | 409 cuida da frequência; 403 cuida da moderação — responsabilidades distintas |
| **Integridade dos dados** | Dispositivos problemáticos não conseguem contaminar o banco mesmo rotacionando horários |

---

## Detalhes Técnicos

- O campo `is_blocked` fica na tabela `tracked_devices`, associado ao fingerprint do dispositivo
- A verificação ocorre no controller de submissão pública, antes de qualquer outra validação de negócio
- O erro retornado é `API_ERROR_DEVICE_BLOCKED` com status HTTP `403 Forbidden`
- O desbloqueio é manual — não há expiração automática para `is_blocked = true`
- Um dispositivo bloqueado em um ponto de coleta está bloqueado em **todos** os pontos — o bloqueio é global por fingerprint

---

## Referência Técnica

- [Anti-Spam por Fingerprint → anti-spam-fingerprint.md](./anti-spam-fingerprint.md)
- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [Regras de Negócio → visao-geral.md#regras-de-negócio-rne](../concepcao/requisitos-e-funcionalidades.md)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
