# Visão Geral dos Casos de Uso

## O que é esta pasta

Cada arquivo desta pasta documenta um caso de uso do sistema — uma intenção de um ator que resulta em um valor concreto. A premissa de organização é:

> **Caso de Uso ↔ arquivo de teste E2E (quando existe)**
>
> Os cenários da seção "Base para Teste E2E" de cada UC são a referência de comportamento esperado; cada arquivo de UC com cobertura aponta para o seu `uc-XX-*.spec.ts` correspondente. O mapeamento **não é 1:1 com todos os cenários**: nem todo cenário documentado tem um teste E2E implementado, e parte dos UCs tem apenas smoke test de carregamento. A cobertura real de cada cenário (✅ E2E, smoke, skip, planejado, unidade/integração) está indicada caso a caso na seção de testes de cada UC.
>
> **Estado atual da cobertura E2E:**
> - **11 UCs** possuem arquivo de spec em `feedback-analytics-web/e2e/` (UC-01, 02, 04, 05, 06, 07, 08, 09, 10, 11, 12).
> - **UC-03 não possui cobertura E2E** (depende de e-mail real / rate limit do Supabase).
> - **UC-05, UC-06, UC-07 e UC-10** têm apenas **smoke test de carregamento de página** — os fluxos de ação documentados não são exercitados por E2E.
> - São **27** chamadas `test()` no total, incluindo **7** `test.skip()` (condicionais) em UC-04, UC-08, UC-11 e UC-12. O `auth.setup.ts` é fixture de login, não um teste de UC.

---

## Índice

| UC | Nome | Ator | Objetivo |
|---|---|---|---|
| [UC-01](uc-01-cadastro-conta.md) | Cadastro de Conta Empresarial | Empresa | Criar conta e ativá-la via e-mail |
| [UC-02](uc-02-login.md) | Login da Empresa | Gestor | Autenticar e acessar o dashboard |
| [UC-03](uc-03-recuperacao-senha.md) | Recuperação de Senha | Gestor | Redefinir senha via link no e-mail |
| [UC-04](uc-04-envio-feedback-qrcode.md) | Envio de Feedback via QR Code | Cliente do estabelecimento | Enviar avaliação escaneando o QR Code |
| [UC-05](uc-05-geracao-qrcode.md) | Geração e Compartilhamento de QR Code | Gestor | Controlar e distribuir o QR Code |
| [UC-06](uc-06-ativacao-tipos-feedback.md) | Ativação de Tipos de Feedback | Gestor | Definir quais categorias a empresa coleta |
| [UC-07](uc-07-configuracao-catalogo.md) | Configuração do Catálogo | Gestor | Cadastrar itens e configurar QR Code por item |
| [UC-08](uc-08-configuracao-coleta-ia.md) | Configuração de Dados de Coleta (IA) | Gestor | Preencher contexto do negócio para a IA |
| [UC-09](uc-09-dashboard.md) | Visualização do Dashboard | Gestor | Visão geral e atualizada dos feedbacks |
| [UC-10](uc-10-listagem-feedbacks.md) | Listagem e Filtragem de Feedbacks | Gestor | Navegar, filtrar e detalhar feedbacks |
| [UC-11](uc-11-insights-ia.md) | Disparo e Visualização de Insights IA | Gestor | Gerar análise com IA e visualizar relatório |
| [UC-12](uc-12-gestao-perfil.md) | Gestão de Perfil | Gestor | Atualizar dados pessoais e de contato |

---

## Atores

| Ator | UCs | Papel |
|---|---|---|
| **Empresa** (novo cliente) | UC-01 | Realiza o cadastro inicial e ativa a conta |
| **Gestor** | UC-02 a UC-12 (exceto UC-04) | Opera o dashboard, configura a coleta e analisa resultados |
| **Cliente do estabelecimento** | UC-04 | Escaneia o QR Code e envia o feedback |

---

## Agrupamento por Domínio

### Onboarding e Autenticação
> Fluxos de entrada na plataforma. Precisam funcionar antes de qualquer outra coisa.

| UC | Descrição |
|---|---|
| UC-01 | Empresa cria a conta e confirma o e-mail de ativação |
| UC-02 | Gestor faz login com e-mail e senha |
| UC-03 | Gestor redefine a senha quando perde o acesso |

---

### Coleta de Feedback
> O núcleo do produto — como os feedbacks chegam e como o gestor os controla.

| UC | Descrição |
|---|---|
| UC-04 | Cliente escaneia o QR Code e submete a avaliação |
| UC-05 | Gestor ativa, desativa e distribui o QR Code (download, copiar link, compartilhar) |

---

### Configuração
> Personalização da coleta. Cada UC aqui afeta diretamente o que o cliente vê no formulário.

| UC | Descrição |
|---|---|
| UC-06 | Gestor decide quais tipos de feedback a empresa coleta (Produtos, Serviços, Departamentos) |
| UC-07 | Gestor cadastra itens do catálogo, configura perguntas por item e controla o QR Code por item |
| UC-08 | Gestor preenche o contexto do negócio que orienta a IA na geração de insights |
| UC-12 | Gestor atualiza nome, e-mail, telefone e as perguntas dinâmicas gerais da empresa |

---

### Análise e Insights
> O que o gestor lê depois que os feedbacks chegam.

| UC | Descrição |
|---|---|
| UC-09 | Dashboard com métricas, gráficos, estratégia de coleta e últimos 5 feedbacks |
| UC-10 | Listagem paginada com 4 filtros e modal de detalhes completo por feedback |
| UC-11 | Disparo de análise de IA por escopo, visualização de relatório, análise emocional e estatísticas |

---

## Mapa de Dependências

Dependências que impactam diretamente o funcionamento de um UC — não apenas boas práticas, mas bloqueios reais.

```
UC-01 (Cadastro)
  └── UC-02 (Login) — conta precisa existir e estar ativa
        └── Todos os demais UCs do Gestor — sessão precisa estar autenticada

UC-06 (Ativar tipos)
  └── UC-07 (Catálogo) — tipo deve estar ativo para acessar a rota de catálogo
  └── UC-05 (QR Code por item) — tipo deve estar ativo para o QR de catálogo funcionar

UC-07 (Catálogo)
  └── UC-04 (Feedback por item) — item deve estar ACTIVE para o formulário carregar
  └── UC-05 (QR Code por item) — QR de item precisa do item cadastrado

UC-05 (QR Code)
  └── UC-04 (Envio de feedback) — QR Code precisa estar ativo para aceitar envios

UC-08 (Contexto IA)
  └── UC-11 (Insights) — os 3 campos de contexto (objetivo, objetivo analítico, resumo) devem estar preenchidos

UC-04 (Coleta de feedback)
  └── UC-09 (Dashboard) — dados úteis dependem de feedbacks coletados
  └── UC-10 (Listagem) — não há o que listar sem feedbacks
  └── UC-11 (Insights) — mínimo de 10 feedbacks para disparar análise
```

---

## Relação com Testes E2E

A maioria dos UCs possui um arquivo de teste E2E do Playwright em `feedback-analytics-web/e2e/`. O **Status** abaixo reflete a profundidade real da cobertura, não apenas a existência do arquivo:

| Arquivo de UC | Arquivo de teste E2E | Status |
|---|---|---|
| [uc-01-cadastro-conta.md](uc-01-cadastro-conta.md) | [uc-01-cadastro-conta.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-01-cadastro-conta.spec.ts) | ✅ Implementado (2 testes: e-mail e documento duplicados) |
| [uc-02-login.md](uc-02-login.md) | [uc-02-login.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-02-login.spec.ts) | ✅ Implementado (2 testes) |
| [uc-03-recuperacao-senha.md](uc-03-recuperacao-senha.md) | *Sem spec* | ❌ Sem cobertura E2E (unidade / manual) |
| [uc-04-envio-feedback-qrcode.md](uc-04-envio-feedback-qrcode.md) | [uc-04-envio-feedback-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-04-envio-feedback-qrcode.spec.ts) | ✅ Implementado (2 testes; envio válido com skip condicional) |
| [uc-05-geracao-qrcode.md](uc-05-geracao-qrcode.md) | [uc-05-geracao-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-05-geracao-qrcode.spec.ts) | 🔎 Apenas smoke (carregamento da página) |
| [uc-06-ativacao-tipos-feedback.md](uc-06-ativacao-tipos-feedback.md) | [uc-06-ativacao-tipos-feedback.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-06-ativacao-tipos-feedback.spec.ts) | 🔎 Apenas smoke (carregamento da página) |
| [uc-07-configuracao-catalogo.md](uc-07-configuracao-catalogo.md) | [uc-07-configuracao-catalogo.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-07-configuracao-catalogo.spec.ts) | 🔎 Apenas smoke (carregamento da página) |
| [uc-08-configuracao-coleta-ia.md](uc-08-configuracao-coleta-ia.md) | [uc-08-configuracao-coleta-ia.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-08-configuracao-coleta-ia.spec.ts) | ✅ Implementado (smoke + 2 saves com skip condicional) |
| [uc-09-dashboard.md](uc-09-dashboard.md) | [uc-09-dashboard.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-09-dashboard.spec.ts) | ✅ Implementado (5 testes) |
| [uc-10-listagem-feedbacks.md](uc-10-listagem-feedbacks.md) | [uc-10-listagem-feedbacks.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-10-listagem-feedbacks.spec.ts) | 🔎 Apenas smoke (carregamento da página) |
| [uc-11-insights-ia.md](uc-11-insights-ia.md) | [uc-11-insights-ia.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-11-insights-ia.spec.ts) | ✅ Implementado (2 smokes + regenerar com skip condicional) |
| [uc-12-gestao-perfil.md](uc-12-gestao-perfil.md) | [uc-12-gestao-perfil.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-12-gestao-perfil.spec.ts) | ✅ Implementado (6 testes; 2 com skip condicional) |

**Legenda de Status:** ✅ Implementado = há ao menos um fluxo de ação coberto · 🔎 Apenas smoke = o spec só verifica que a página carrega, sem exercitar os fluxos de ação documentados · ❌ Sem cobertura E2E = não há arquivo de spec.

A seção "Base para Teste E2E" de cada UC lista, cenário a cenário, o que está coberto por E2E, o que é apenas smoke, o que está skipped e o que está apenas planejado. As coberturas detalhadas (incluindo testes de unidade, de integração e cenários skipped) estão mapeadas no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).
