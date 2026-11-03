# Onboarding Automático do Catálogo

## O Que É

No momento em que a empresa é criada, o **API Gateway** grava automaticamente 3 perguntas institucionais base no formulário geral (escopo `COMPANY`):

1. **Atendimento** — Como foi sua experiência em relação ao atendimento?
2. **Qualidade** — O que você achou da qualidade do produto/serviço?
3. **Custo-Benefício** — Como você avalia a relação entre o valor pago e a qualidade do produto/serviço?

Essas perguntas garantem que o formulário geral nunca comece vazio. Depois, na primeira entrada no painel, o gestor passa pela configuração inicial: conta o contexto da empresa e, se quiser, configura a IA. Com a IA configurada, ela **troca as 3 perguntas padrão por 3 perguntas feitas para aquele negócio**. Para começar a coletar, falta só ativar o QR Code da empresa, primeiro dos "Primeiros passos" do Dashboard.

> Antes, as perguntas eram criadas por um trigger do Supabase no cadastro. Hoje a criação fica no gateway (`provisionEnterpriseForUser`), com os mesmos textos.

---

## Por Que Existe

O momento mais crítico para qualquer produto SaaS é o **primeiro acesso**. Se o usuário chega ao dashboard e encontra tudo vazio — sem dados, sem configuração, sem nenhum ponto de partida — a chance de abandono é muito alta.

Sem o onboarding automático, o fluxo seria:

1. Empresa se cadastra
2. Entra no dashboard → vazio
3. Precisa descobrir como configurar o catálogo
4. Precisa criar as perguntas manualmente
5. Só então consegue gerar o QR Code
6. Só então começa a coletar

Com o onboarding automático:

1. Empresa se cadastra → 3 perguntas já configuradas
2. Conta o contexto da empresa; com a IA configurada, recebe perguntas sob medida
3. Ativa o QR Code nos "Primeiros passos" do Dashboard
4. Pode começar a coletar no mesmo minuto

> A diferença entre "preciso configurar tudo antes de começar" e "já posso usar agora" pode determinar se o usuário fica ou vai embora.

---

## Como Funciona

```
Empresa finaliza o cadastro (e-mail e senha, ou primeira entrada com o Google)
        ↓
Gateway cria a empresa e as 3 perguntas padrão do escopo COMPANY
        ↓
Primeira entrada no painel: configuração inicial
  - 3 passos de contexto da empresa (obrigatórios)
  - 1 passo de IA: chave OpenRouter e modelo (opcional)
        ↓
  ┌── Sem IA → segue com as perguntas padrão
  │
  └── Com IA e contexto completo → Gateway enfileira a geração
      das 3 perguntas; a tela "Preparando sua conta" espera
        ↓
      Worker gera as perguntas e só as grava se as da empresa
      ainda forem as padrão
        ↓
Dashboard: "Primeiros passos" (ativar o QR Code e, se quiser,
testar o formulário) e o convite para o guia do sistema
```

O gestor não precisa da equipe de suporte em nenhum passo.

---

## Geração Automática das Perguntas

- **Quando dispara:** assim que a empresa tem os 3 campos de contexto (objetivo, meta de análise e resumo do negócio) e a IA configurada (chave e modelo). O gateway tenta ao salvar a chave, conectar com o OpenRouter, trocar o modelo ou salvar o contexto.
- **Quando não mexe:** se o gestor já editou as perguntas da empresa, a IA não interfere. Uma geração concluída não se repete.
- **Na configuração inicial:** a tela "Preparando sua conta" espera o resultado. Depois de 40 segundos mostra "A IA está demorando", com a troca rápida de modelo. Na falha, mostra o motivo, "Tentar de novo" e a troca de modelo. "Continuar com as perguntas padrão" aparece na falha ou depois de 3 minutos.
- **Se falhar:** as perguntas padrão continuam. Um aviso fica no topo do painel, mesmo em outro aparelho, até o gestor tentar de novo ou escolher "Manter perguntas padrão".
- **Limites:** um pedido novo só depois de 60 segundos do anterior e no máximo 5 por dia. Quando o provedor responde "muitas requisições" (429), o pedido tenta de novo sozinho algumas vezes antes de falhar.

---

## Guia do Sistema por Convite

O guia interativo (16 passos pelo painel) **não abre sozinho**. O Dashboard convida o gestor:

- quando chega o **primeiro feedback** da conta; ou
- sem feedback, numa **próxima sessão** do navegador, nunca logo depois do cadastro.

"Depois" adia o convite para outra sessão; depois de 2 adiamentos o painel para de perguntar. O guia continua disponível no menu da conta, no cabeçalho.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Experiência de primeiro uso** | O formulário geral nunca nasce vazio — o gestor encontra algo funcional imediatamente |
| **Perguntas do negócio** | Com a IA, as perguntas já saem ajustadas ao contexto que o gestor descreveu |
| **IA opcional** | Sem chave de IA, a conta funciona com as perguntas padrão |
| **Coleta imediata** | Ativado o QR Code, a empresa pode coletar feedbacks no mesmo dia do cadastro |
| **Customização posterior** | O gestor pode editar, substituir ou desativar as perguntas a qualquer momento |

---

## Detalhes Técnicos

- A empresa e as perguntas são criadas por `provisionEnterpriseForUser` (`src/auth/enterpriseOnSignup.ts` do gateway), numa transação, logo depois de o Better Auth criar o usuário. É idempotente: rodar de novo não duplica nada
- As 3 perguntas são criadas com `is_active = true` no escopo `COMPANY` (`catalog_item_id` nulo) e vinculadas ao `enterprise_id` recém-criado. Os textos ficam em `src/config/defaultCompanyQuestions.ts`
- O cadastro **não** ativa o QR Code: o ponto de coleta da empresa é criado quando o gestor ativa a coleta
- A geração usa o job `generate_company_questions` da fila de IA; o resultado só é aplicado se as perguntas ainda forem as padrão
- As perguntas base não são fixas ou imutáveis — o gestor pode editá-las, desativá-las ou adicionar subperguntas
- Itens de catálogo criados depois não herdam as perguntas da empresa: a contagem é variável (0 a 3) e, sem perguntas próprias, o formulário daquele item exibe apenas nota + comentário

---

## Referência Técnica

- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [Regras de Negócio — RNE-010](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
- [Geração automática das perguntas na Web](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/docs/configuracao-ia.md)
