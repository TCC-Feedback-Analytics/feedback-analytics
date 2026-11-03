# QR Codes por Escopo com Perguntas Dinâmicas

## O Que É

Cada empresa não tem apenas um QR Code — ela tem **um ponto de coleta por escopo**. A avaliação geral da empresa e cada produto, serviço ou departamento do catálogo têm o seu, com suas próprias perguntas e seus próprios canais (QR Code, link e etiqueta NFC).

O cliente que escaneia o QR do "Hambúrguer Artesanal" responde perguntas específicas sobre aquele item. Quem escaneia o QR do "Pós-Venda" responde perguntas sobre aquela experiência. Contextos diferentes, perguntas diferentes, análises diferentes.

---

## Por Que Existe

Um único QR Code para a empresa inteira diz que "os clientes estão insatisfeitos". Mas **não diz onde**.

Sem escopo, é impossível saber se o problema está no produto, no atendimento ou na entrega. O gestor termina com uma nota média que não orienta nenhuma decisão.

Com escopos, o feedback se torna **atribuível**:
- O Produto X está com nota 4.2, o Produto Y com 2.8 → o problema é específico
- O Departamento de Suporte está bem avaliado, mas o de Entrega está mal → a ação corretiva é cirúrgica

> Dados genéricos geram relatórios. Dados contextualizados geram decisões.

---

## Como Funciona

```
Empresa configura o catálogo (Produtos, Serviços ou Departamentos)
        ↓
Na página do item, o gestor configura as perguntas (opcional),
o campo de comentário e ativa a coleta → nasce o ponto de coleta do item
        ↓
O item ganha QR Code, link e etiqueta NFC próprios, todos para o mesmo ponto de coleta
        ↓
Se não houver perguntas no item, o formulário exibe só nota + comentário (sem fallback para outro escopo)
        ↓
Cliente escaneia → formulário carrega com as perguntas daquele escopo
        ↓
Feedback é armazenado vinculado ao item específico
        ↓
Análise de IA é segmentada por escopo → relatório separado por item
```

---

## Escopos Disponíveis

| Escopo | Quando usar | Exemplo de Uso |
|---|---|---|
| **Empresa** | Avaliação geral da experiência | "Como foi sua visita?" |
| **Produto** | Avaliação de item específico | "Como foi o Hambúrguer Artesanal?" |
| **Serviço** | Avaliação de serviço prestado | "Como foi o serviço de Entrega?" |
| **Departamento** | Avaliação de área interna | "Como foi o atendimento da Recepção?" |

---

## Perguntas Dinâmicas

Cada item pode ter **perguntas customizadas com subperguntas**:

- A empresa define a pergunta principal (ex: "Como foi a qualidade do produto?"), com 20 a 150 caracteres
- Cada pergunta pode ter até 3 subperguntas que detalham o aspecto avaliado
- Perguntas e subperguntas usam a mesma escala estruturada: `PESSIMO → RUIM → MEDIANA → BOA → OTIMA` (notas 1 a 5)
- Todas as subperguntas ativas aparecem logo abaixo da pergunta e precisam ser respondidas para o envio passar

O sistema usa uma **contagem variável de 0 a 3 perguntas ativas** por ponto de coleta. Se o item não tiver perguntas configuradas, o formulário exibe apenas nota + comentário — nunca faz fallback para as perguntas de outro escopo. O campo de comentário também é configurado por escopo (padrão, pergunta própria ou oculto).

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Granularidade** | Feedback atribuível a item específico, não só à empresa |
| **Análise de IA segmentada** | Cada escopo gera seu próprio relatório de insights |
| **Ação corretiva mais direcionada** | O gestor consegue identificar com mais clareza onde agir |
| **Flexibilidade** | Cada item tem perguntas relevantes ao seu contexto |
| **Controle por escopo** | Pausar a coleta de um item tira do ar todos os canais dele de uma vez |

---

## Detalhes Técnicos

- A ativação de escopos (Produtos, Serviços, Departamentos) é feita via flags no banco: `uses_company_products`, `uses_company_services`, `uses_company_departments`
- O formulário só abre e só aceita envio com o ponto de coleta do tipo QR Code em `ACTIVE`. Ativar a coleta de um item exige o item do catálogo ativo (RNE-009)
- O ponto de coleta do item é criado (ou reativado) quando o gestor ativa a coleta, e desativado quando ele a pausa. Itens que saem do catálogo viram `INACTIVE`, sem ser excluídos
- O sistema aceita uma contagem variável de 0 a 3 perguntas por ponto de coleta; sem fallback — as respostas precisam bater exatamente com as perguntas ativas do escopo (ou nenhuma)
- Esvaziar uma pergunta faz soft-delete (`is_active = false`): ela some do formulário, mas o histórico de respostas fica
- Cada feedback armazenado carrega o `collection_point_id`, permitindo filtrar e agrupar por escopo; o canal de chegada fica em `feedback.channel`

---

## Referência Técnica

- [Onboarding do Catálogo → onboarding-catalogo.md](./onboarding-catalogo.md)
- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [Análise dos comentários por escopo → painel-insights-ia.md](./painel-insights-ia.md)
- [Endpoints de QR Code](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
