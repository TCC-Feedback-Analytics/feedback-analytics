# Visão Geral dos Casos de Uso

## O que é esta pasta

Cada arquivo desta pasta documenta um caso de uso do sistema — uma intenção de um ator que resulta em um valor concreto. A premissa de organização é:

> **Caso de Uso ↔ cenários de teste**
>
> Os cenários da seção "Base para Teste E2E" de cada UC são a referência de comportamento esperado. Eles eram cobertos por uma suíte **Playwright (e2e)**, agora **removida**; passaram a ser executados **manualmente**, seguindo o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). O mapeamento **não é 1:1 com todos os cenários**: nem todo cenário documentado vira um passo do runbook, e parte dos UCs tem apenas smoke de carregamento. A cobertura real de cada cenário (✅ manual, smoke, planejado, unidade/integração) está indicada caso a caso na seção de testes de cada UC.
>
> **Estado atual da cobertura:**
> - A suíte **Playwright (e2e)** foi **removida** — a pasta `feedback-analytics-web/e2e/` não existe mais.
> - O [runbook de testes manuais do Web](../../guias/testes/manuais-web.md) reproduz manualmente os cenários de **11 dos 12 UCs** (UC-01, 02, 04, 05, 06, 07, 08, 09, 10, 11, 12).
> - **UC-03 fica fora do runbook do Web** (depende de e-mail real / rate limit do Supabase) — permanece coberto por unidade/manual pontual.
> - **UC-05, UC-06, UC-07 e UC-10** têm apenas **smoke de carregamento de página** no runbook — os fluxos de ação documentados não são exercitados nesses cenários.

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

A suíte de testes E2E do Playwright (`feedback-analytics-web/e2e/`) foi **removida**; os cenários de cada UC passaram a ser executados **manualmente**, pelo [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). A coluna **Cobertura** abaixo reflete a profundidade dos cenários hoje reproduzidos manualmente (equivalente ao que a suíte automatizada exercitava antes da remoção):

| Arquivo de UC | Cobertura manual (runbook) |
|---|---|
| [uc-01-cadastro-conta.md](uc-01-cadastro-conta.md) | ✅ 2 cenários (e-mail e documento duplicados) |
| [uc-02-login.md](uc-02-login.md) | ✅ 2 cenários |
| [uc-03-recuperacao-senha.md](uc-03-recuperacao-senha.md) | ❌ Fora do runbook do Web (unidade / manual pontual) |
| [uc-04-envio-feedback-qrcode.md](uc-04-envio-feedback-qrcode.md) | ✅ 2 cenários (envio válido é condicional) |
| [uc-05-geracao-qrcode.md](uc-05-geracao-qrcode.md) | 🔎 Apenas smoke (carregamento da página) |
| [uc-06-ativacao-tipos-feedback.md](uc-06-ativacao-tipos-feedback.md) | 🔎 Apenas smoke (carregamento da página) |
| [uc-07-configuracao-catalogo.md](uc-07-configuracao-catalogo.md) | 🔎 Apenas smoke (carregamento da página) |
| [uc-08-configuracao-coleta-ia.md](uc-08-configuracao-coleta-ia.md) | ✅ Smoke + 2 salvamentos condicionais |
| [uc-09-dashboard.md](uc-09-dashboard.md) | ✅ 5 cenários |
| [uc-10-listagem-feedbacks.md](uc-10-listagem-feedbacks.md) | 🔎 Apenas smoke (carregamento da página) |
| [uc-11-insights-ia.md](uc-11-insights-ia.md) | ✅ 2 smokes + regenerar (condicional) |
| [uc-12-gestao-perfil.md](uc-12-gestao-perfil.md) | ✅ 6 cenários (2 condicionais) |

**Legenda de Cobertura:** ✅ = há ao menos um fluxo de ação reproduzido manualmente · 🔎 Apenas smoke = o cenário verifica apenas que a página carrega, sem exercitar os fluxos de ação documentados · ❌ = fica fora do runbook de testes manuais do Web.

A seção "Base para Teste E2E" de cada UC lista, cenário a cenário, o que é reproduzido manualmente, o que é apenas smoke e o que está apenas planejado. As coberturas detalhadas (incluindo testes de unidade, de integração e cenários planejados) estão mapeadas no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).
