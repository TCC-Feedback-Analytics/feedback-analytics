# Stakeholders — Feedback Analytics

*Pessoas e grupos interessados e impactados pelo projeto.*

Este documento mapeia quem são os stakeholders do Feedback Analytics, o que cada um espera do sistema e como seus interesses moldam decisões de produto, arquitetura e experiência.

---

## Visão Geral

| Stakeholder | Tipo | Principal Interesse |
|---|---|---|
| Empresas / Clientes | Externo | Transformar feedbacks em decisões estratégicas |
| Usuários Finais | Externo | Avaliar com rapidez, com baixo atrito e sem identificação obrigatória |
| Equipe de Desenvolvimento | Interno | Arquitetura clara, manutenível e evolutiva |
| Fundador / Product Owner | Interno | Produto validado, sustentável e com crescimento de MRR |
| Autoridade Regulatória (LGPD) | Indireto | Conformidade com proteção de dados pessoais |

---

## Stakeholders Externos

### Empresas / Clientes

- **Descrição:** São as organizações — principalmente de pequeno e médio porte (PMEs) — que contratam o Feedback Analytics como SaaS para coletar e analisar os feedbacks de seus próprios clientes. São elas que pagam a assinatura mensal e usam o dashboard.
- **Perfis típicos:** restaurantes, salões, lojas de bairro e profissionais autônomos, sem equipe técnica própria.
- **Principal Interesse / Objetivo:** Transformar a "voz do cliente" em um ativo estratégico. Querem entender rapidamente o que seus clientes pensam por escopo (produto, serviço, departamento), identificar problemas, descobrir oportunidades e aumentar satisfação e fidelização — sem precisar de uma equipe de dados.
- **Impacto no Projeto:**
  - O requisito de **isolamento de dados (multi-tenancy)** é a principal demanda deste stakeholder: cada empresa só pode ver seus próprios dados.
  - A necessidade de **granularidade por escopo** (QR Code por produto/serviço/departamento) é o principal diferencial competitivo do produto.
  - A **clareza do dashboard** é crítica: o gestor não é analista de dados — os insights precisam chegar prontos.
  - A jornada de **onboarding e ativação** determina se a empresa chegará ao final do trial com valor percebido suficiente para converter em pagante.

---

### Usuários Finais

- **Descrição:** São os clientes das "Empresas/Clientes". São eles que efetivamente fornecem os feedbacks através dos canais disponibilizados — atualmente via QR Code. Não têm conta no sistema e não pagam pelo produto.
- **Principal Interesse / Objetivo:** Fornecer uma opinião de forma rápida, fácil e, preferencialmente, anônima. O processo não pode ter atritos — qualquer etapa desnecessária leva ao abandono.
- **Impacto no Projeto:**
  - A necessidade de uma **experiência de baixo atrito** guia a simplicidade do formulário público: sem login, sem cadastro, sem steps desnecessários.
  - A preocupação com **privacidade e anonimato** influencia decisões como não coletar nome ou e-mail por padrão.
  - O combate a **spam e abuso** sem prejudicar a experiência levou à criação do mecanismo `tracked_devices`, que evita múltiplos envios do mesmo dispositivo sem exigir login.
  - A experiência mobile-first é mandatória — o usuário final acessa pelo celular após escanear o QR Code.

---

## Stakeholders Internos

### Equipe de Desenvolvimento

- **Descrição:** Os engenheiros responsáveis por construir, manter e evoluir o sistema.
- **Principal Interesse / Objetivo:** Uma arquitetura clara, bem documentada, fácil de manter e que permita adicionar novas funcionalidades com segurança e agilidade.
- **Impacto no Projeto:**
  - A arquitetura **Serverless multi-repo** (`web`, `api-gateway`, `ia-analyze`) foi adotada para garantir autonomia entre serviços, deploys independentes e clareza de responsabilidades.
  - A documentação técnica (`/docs`) existe para reduzir o tempo de onboarding e evitar que o conhecimento fique concentrado em uma pessoa.
  - A **cobertura de testes** (unitários, integração, E2E) protege o time de regressões ao evoluir funcionalidades críticas.
  - O padrão de **variáveis de ambiente por domínio** e a separação de serviços reduzem o risco de mudanças em um serviço quebrarem outro.

---

### Fundador / Product Owner

- **Descrição:** A pessoa responsável pela visão estratégica, priorização e sustentabilidade do produto. Define o que entra no roadmap e quando, com base nas métricas de negócio.
- **Principal Interesse / Objetivo:** Lançar um produto validado pelo mercado que cresça de forma sustentável — medido pelo MRR, taxa de conversão trial → pago, churn e taxa de ativação.
- **Impacto no Projeto:**
  - O modelo de **trial de 4 meses com plano único** (sem feature flags por tier) simplifica o produto e direciona o esforço de desenvolvimento para o valor central, não para gestão de planos.
  - A decisão de focar em **PMEs** sem equipe técnica define o nível de complexidade aceitável na UX — simples acima de completo.
  - Os **diferenciais competitivos** (QR Code por escopo + painel de insights com IA) são as partes do sistema que nunca podem degradar — toda decisão de arquitetura existe, em alguma medida, para protegê-los.

---

## Stakeholder Indireto

### Autoridade Regulatória (LGPD)

- **Descrição:** A Lei Geral de Proteção de Dados Pessoais (Lei nº 13.709/2018) impõe obrigações sobre como dados pessoais são coletados, armazenados e tratados — mesmo que o stakeholder não interaja diretamente com o sistema.
- **Principal Interesse / Objetivo:** Garantir que dados pessoais dos usuários finais sejam tratados com transparência, finalidade definida e segurança.
- **Impacto no Projeto:**
  - O mecanismo de **higienização de JWT e dados pessoais** (`higienizacao-jwt-lgpd`) ajuda a evitar que tokens e dados sensíveis persistam além do necessário.
  - A política de **coleta mínima de dados** nos formulários públicos (sem e-mail ou nome obrigatórios) reduz a superfície de exposição.
  - O **isolamento por tenant** também serve como barreira de conformidade: dados de uma empresa jamais são visíveis para outra.

---

## Veja Também

- [Visão Geral do Sistema](../index.md)
- [Modelo de Negócio](./modelo-negocio.md)
- [Requisitos e Funcionalidades](./requisitos-e-funcionalidades.md)
- [Casos de Uso](./casos-de-uso/visao-geral.md)
