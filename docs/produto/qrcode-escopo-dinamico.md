# QR Codes por Escopo com Perguntas Dinâmicas

## O Que É

Cada empresa não tem apenas um QR Code — ela tem **um QR por ponto de coleta**. Cada produto, serviço ou departamento cadastrado recebe seu próprio QR Code com suas próprias perguntas configuradas.

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
Cada item cadastrado recebe um QR Code único automaticamente
        ↓
A empresa configura perguntas customizadas por item (opcional)
        ↓
Se não houver perguntas no item, o formulário exibe só nota + mensagem (sem fallback para outro escopo)
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

Cada item pode ter **perguntas customizadas com subperguntas hierárquicas**:

- A empresa define a pergunta principal (ex: "Como foi a qualidade do produto?")
- Cada pergunta pode ter subperguntas que detalham o aspecto avaliado
- As subperguntas usam uma escala estruturada: `PESSIMO → RUIM → MEDIANA → BOA → OTIMA`
- A visibilidade das subperguntas pode depender da resposta selecionada na pergunta pai

O sistema usa uma **contagem variável de 0 a 3 perguntas ativas** por ponto de coleta. Se o item não tiver perguntas configuradas, o formulário exibe apenas nota + mensagem — nunca faz fallback para as perguntas de outro escopo.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Granularidade** | Feedback atribuível a item específico, não só à empresa |
| **Análise de IA segmentada** | Cada escopo gera seu próprio relatório de insights |
| **Ação corretiva mais direcionada** | O gestor consegue identificar com mais clareza onde agir |
| **Flexibilidade** | Cada item tem perguntas relevantes ao seu contexto |
| **Hierarquia de ativação** | Desativar um item bloqueia automaticamente o formulário daquele QR |

---

## Detalhes Técnicos

- A ativação de escopos (Produtos, Serviços, Departamentos) é feita via flags no banco: `uses_company_products`, `uses_company_services`, `uses_company_departments`
- Um QR Code só aceita submissões se **tanto o QR quanto o item do catálogo** estiverem `ACTIVE` (RNE-009)
- O sistema aceita uma contagem variável de 0 a 3 perguntas por ponto de coleta; sem fallback — as respostas precisam bater exatamente com as perguntas ativas do escopo (ou nenhuma)
- Cada feedback armazenado carrega o `collection_point_id`, permitindo filtrar e agrupar por escopo

---

## Referência Técnica

- [Onboarding do Catálogo → onboarding-catalogo.md](./onboarding-catalogo.md)
- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [Painel de Insights por Escopo → painel-insights-ia.md](./painel-insights-ia.md)
- [Endpoints de QR Code](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/blob/main/docs/endpoints.md)
