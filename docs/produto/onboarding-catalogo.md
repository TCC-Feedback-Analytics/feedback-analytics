# Onboarding Automático do Catálogo

## O Que É

No momento em que uma empresa conclui o cadastro, um **trigger no banco de dados** cria automaticamente 3 perguntas institucionais base:

1. **Atendimento** — Como foi sua experiência em relação ao atendimento?
2. **Qualidade** — O que você achou da qualidade do produto/serviço?
3. **Custo-Benefício** — Como você avalia a relação entre o valor pago e a qualidade do produto/serviço?

Essas perguntas ficam vinculadas ao QR Code geral da empresa e permitem que o gestor comece a coletar feedbacks **imediatamente após o cadastro**, sem precisar configurar nada antes.

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

1. Empresa se cadastra
2. Entra no dashboard → 3 perguntas já configuradas
3. QR Code já disponível para uso imediato
4. Pode começar a coletar no mesmo minuto

> A diferença entre "preciso configurar tudo antes de começar" e "já posso usar agora" pode determinar se o usuário fica ou vai embora.

---

## Como Funciona

```
Empresa finaliza o cadastro (Supabase auth.signUp)
        ↓
Trigger no banco dispara automaticamente
        ↓
Função cria 3 perguntas base vinculadas à empresa:
  - "Como foi sua experiência em relação ao atendimento?"
  - "O que você achou da qualidade do produto/serviço?"
  - "Como você avalia a relação entre o valor pago e a qualidade do produto/serviço?"
        ↓
Perguntas ficam associadas ao QR Code geral da empresa
        ↓
Gestor acessa o dashboard e já encontra tudo pronto para uso
```

Tudo isso acontece **de forma invisível**, sem nenhuma intervenção manual do gestor ou da equipe de suporte.

---

## Importância e Impacto

| Aspecto | Impacto |
|---|---|
| **Experiência de primeiro uso** | Dashboard nunca inicia vazio — o gestor encontra algo funcional imediatamente |
| **Redução de atrito no onboarding** | Não é necessário ler documentação ou passar por um wizard de configuração |
| **Coleta imediata** | A empresa pode compartilhar o QR Code e coletar feedbacks no mesmo dia do cadastro |
| **Perguntas abrangentes** | Atendimento, Qualidade e Custo-Benefício costumam ser relevantes para a maioria dos negócios |
| **Customização posterior** | O gestor pode editar, substituir ou complementar as perguntas a qualquer momento |

---

## Detalhes Técnicos

- O trigger é executado no banco de dados (PostgreSQL/Supabase) logo após a inserção do registro da empresa
- As 3 perguntas são criadas com status `ACTIVE` e vinculadas ao `enterprise_id` recém-criado
- As perguntas base não são fixas ou imutáveis — o gestor pode editá-las, desativá-las ou adicionar novas
- O sistema aceita uma contagem variável de 0 a 3 perguntas ativas por ponto de coleta; as 3 perguntas do onboarding já deixam o escopo COMPANY pronto para uso de imediato
- Itens de catálogo criados posteriormente não herdam as perguntas da empresa: a contagem é variável (0 a 3) e, sem perguntas próprias, o formulário daquele item exibe apenas nota + mensagem

---

## Referência Técnica

- [QR Codes por Escopo → qrcode-escopo-dinamico.md](./qrcode-escopo-dinamico.md)
- [Coleta via QR Code → coleta-qrcode.md](./coleta-qrcode.md)
- [Regras de Negócio — RNE-010](../concepcao/requisitos-e-funcionalidades.md#regras-de-negócio-rne)
