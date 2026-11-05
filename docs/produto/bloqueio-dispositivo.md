# Bloqueio Permanente de Dispositivo

## O Que É

É a segunda camada de proteção do sistema de coleta pública. Enquanto o anti-spam por fingerprint barra submissões duplicadas no mesmo dia (HTTP 409), o bloqueio impede **qualquer** envio de um registro de aparelho marcado como `is_blocked`, retornando HTTP 403.

> **Situação atual:** a verificação existe no envio e, desde que o fingerprint deixou de levar o dia, o bloqueio vale entre dias. Mas não há tela nem endpoint para marcar um aparelho como bloqueado: a marca só pode ser feita direto no banco. Detalhes abaixo.

---

## Por Que Existe

O limite diário (1 feedback por aparelho por ponto de coleta por dia) resolve a maioria dos casos — o cliente que tenta enviar duas vezes por engano, o bot simples que não muda de IP.

Mas existem situações que pedem uma resposta mais definitiva:

- Um aparelho enviou feedbacks claramente fraudulentos ou ofensivos
- Um ator mal-intencionado está tentando burlar o limite diário
- É preciso barrar uma origem específica sem depender do limite por ponto de coleta

O bloqueio foi pensado para esses casos. É uma ferramenta de **moderação**, não de controle de frequência.

---

## A Diferença Entre 409 e 403

| Situação | Código | Significado | Duração na prática |
|---|---|---|---|
| Mesmo aparelho, mesmo ponto, mesmo dia | `409 Conflict` | Limite diário atingido | Até a meia-noite de Brasília |
| Registro do aparelho com `is_blocked = true` | `403 Forbidden` | Aparelho bloqueado | Até a marca ser desfeita, enquanto o aparelho usar o mesmo navegador e a mesma rede |

O `409` é automático e temporário — parte do fluxo normal. O `403` depende de uma marca feita por alguém no registro do aparelho.

---

## Como Funciona

```
Cliente submete o formulário
        ↓
API valida payload, empresa, ponto de coleta e respostas
        ↓
API calcula o fingerprint: MD5(User-Agent | IP)
        ↓
Consulta tracked_devices pela empresa + fingerprint
        ↓
  ┌── is_blocked = true → retorna HTTP 403 (DEVICE_BLOCKED)
  │
  └── senão → verifica o limite diário normalmente
```

O bloqueio é verificado **antes** da checagem de duplicidade diária, mas **depois** das validações do formulário (payload, empresa, ponto de coleta ativo e respostas).

---

## Limites do Bloqueio

- **Navegador e rede.** O fingerprint é navegador + IP. O mesmo aparelho em outra rede (ou outro navegador) chega com outro fingerprint, e a consulta cria um registro novo, com `is_blocked = false`.
- **Sem ferramenta de moderação.** Nenhuma tela nem endpoint grava `is_blocked = true`, nem as colunas `blocked_reason`, `blocked_at` e `blocked_by`. O código só **lê** a marca. Na Web, o detalhe de um feedback em Feedbacks recebidos mostra se o registro do aparelho está bloqueado ("Bloqueado: Sim/Não"), sem botão para mudar.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Moderação sem login** | Permite barrar uma origem específica sem exigir autenticação dos clientes |
| **Separação de camadas** | 409 cuida da frequência; 403 cuida da moderação — responsabilidades distintas |
| **Alcance** | O bloqueio de um registro vale para todos os pontos de coleta da empresa, em qualquer dia |
| **Limite atual** | Sem tela para bloquear, a camada hoje depende de uma marca feita no banco |

---

## Detalhes Técnicos

- O campo `is_blocked` fica na tabela `tracked_devices`, associado ao fingerprint e à empresa (`enterprise_id`); a consulta é sempre por empresa + fingerprint
- A verificação ocorre em `src/controllers/public/qrcode.controller.ts` do API Gateway, depois das validações do formulário e antes da checagem do limite diário
- O erro retornado é `DEVICE_BLOCKED` (`API_ERROR_DEVICE_BLOCKED`) com status HTTP `403 Forbidden`
- Não há expiração automática para `is_blocked = true`: o registro é encontrado enquanto o aparelho usar o mesmo navegador e a mesma rede
- O bloqueio é por empresa: o mesmo aparelho em outra empresa tem outro registro
- Todo registro novo nasce com `is_blocked = false`

---

## Referência Técnica

- [Anti-Spam por Fingerprint → anti-spam-fingerprint.md](./anti-spam-fingerprint.md)
- [Coleta: QR Code, link e NFC → coleta-qrcode.md](./coleta-qrcode.md)
- [Regras de Negócio (RNE)](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
- [Endpoints Públicos](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
