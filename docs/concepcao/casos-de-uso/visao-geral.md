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
> - **UC-03 fica fora do runbook do Web** (depende de e-mail real) — permanece coberto por unidade/manual pontual.
> - **UC-05, UC-06, UC-07 e UC-10** têm apenas **smoke de carregamento de página** no runbook — os fluxos de ação documentados não são exercitados nesses cenários.

---

## Índice

| UC | Nome | Ator | Objetivo |
|---|---|---|---|
| [UC-01](uc-01-cadastro-conta.md) | Cadastro de Conta Empresarial | Empresa | Criar conta e ativá-la via e-mail (ou com o Google) |
| [UC-02](uc-02-login.md) | Login da Empresa | Gestor | Autenticar (e-mail e senha ou Google) e acessar o dashboard |
| [UC-03](uc-03-recuperacao-senha.md) | Recuperação de Senha | Gestor | Redefinir senha via link no e-mail |
| [UC-04](uc-04-envio-feedback-qrcode.md) | Envio de Feedback (QR Code, link ou NFC) | Cliente do estabelecimento | Enviar avaliação pelo QR Code, link ou etiqueta NFC |
| [UC-05](uc-05-geracao-qrcode.md) | Canais de Coleta (QR Code, link e NFC) | Gestor | Controlar a coleta e distribuir os canais (QR Code, link e NFC) |
| [UC-06](uc-06-ativacao-tipos-feedback.md) | Ativação de Tipos de Feedback | Gestor | Definir quais categorias a empresa coleta |
| [UC-07](uc-07-configuracao-catalogo.md) | Configuração do Catálogo | Gestor | Cadastrar itens e configurar perguntas, comentário e canais por item |
| [UC-08](uc-08-configuracao-coleta-ia.md) | Configuração de Dados de Coleta (IA) | Gestor | Preencher o contexto do negócio e conectar a IA |
| [UC-09](uc-09-dashboard.md) | Visualização do Dashboard | Gestor | Visão geral dos feedbacks por escopo e período, com o diagnóstico da IA |
| [UC-10](uc-10-listagem-feedbacks.md) | Listagem e Filtragem de Feedbacks | Gestor | Navegar, filtrar e detalhar feedbacks |
| [UC-11](uc-11-insights-ia.md) | Análise dos comentários com IA | Gestor | Analisar os comentários com IA e ver o tom, os assuntos, o resumo e a lista |
| [UC-12](uc-12-gestao-perfil.md) | Gestão de Perfil | Gestor | Atualizar dados pessoais e de contato e excluir a conta |

---

## Atores

| Ator | UCs | Papel |
|---|---|---|
| **Empresa** (novo cliente) | UC-01 | Realiza o cadastro inicial e ativa a conta |
| **Gestor** | UC-02 a UC-12 (exceto UC-04) | Opera o dashboard, configura a coleta e analisa resultados |
| **Cliente do estabelecimento** | UC-04 | Escaneia o QR Code, abre o link ou encosta na etiqueta NFC e envia o feedback |

---

## Agrupamento por Domínio

### Onboarding e Autenticação
> Fluxos de entrada na plataforma. Precisam funcionar antes de qualquer outra coisa.

| UC | Descrição |
|---|---|
| UC-01 | Empresa cria a conta e confirma o e-mail de ativação (ou cria com o Google e completa o cadastro) |
| UC-02 | Gestor faz login com e-mail e senha ou com o Google |
| UC-03 | Gestor redefine a senha quando perde o acesso |

---

### Coleta de Feedback
> O núcleo do produto — como os feedbacks chegam e como o gestor os controla.

| UC | Descrição |
|---|---|
| UC-04 | Cliente abre o formulário pelo QR Code, link ou etiqueta NFC e submete a avaliação |
| UC-05 | Gestor ativa ou pausa a coleta e distribui os canais (baixar o QR Code, copiar ou compartilhar o link, gravar a etiqueta NFC) |

---

### Configuração
> Personalização da coleta. Cada UC aqui afeta diretamente o que o cliente vê no formulário.

| UC | Descrição |
|---|---|
| UC-06 | Gestor decide quais tipos de feedback a empresa coleta (Produtos, Serviços, Departamentos) |
| UC-07 | Gestor cadastra itens do catálogo e configura, por item, perguntas, campo de comentário e canais de coleta |
| UC-08 | Gestor preenche o contexto do negócio e conecta a IA; com os dois, a IA cria as 3 perguntas do formulário geral |
| UC-12 | Gestor atualiza nome e telefone (a troca de e-mail hoje falha), consulta os dados da empresa e pode excluir a conta |

---

### Análise e Insights
> O que o gestor lê depois que os feedbacks chegam.

| UC | Descrição |
|---|---|
| UC-09 | Dashboard com métricas por escopo e período, "Por onde chegaram", perguntas do formulário, análise dos comentários e diagnóstico do escopo com IA |
| UC-10 | Listagem paginada com busca, filtros por escopo e nota, marca "Teste" e modal de detalhes completo por feedback |
| UC-11 | Análise dos comentários com IA por escopo: tom dos comentários, assuntos que mais impactam, resumo e recomendações e lista de comentários com filtros |

---

## Mapa de Dependências

Dependências que impactam diretamente o funcionamento de um UC — não apenas boas práticas, mas bloqueios reais.

```
UC-01 (Cadastro)
  └── UC-02 (Login) — conta precisa existir e estar ativa
        └── Todos os demais UCs do Gestor — sessão precisa estar autenticada

UC-06 (Ativar tipos)
  └── UC-07 (Catálogo) — o link "Configurar catálogo" só aparece com o tipo salvo como ativo
  └── UC-05 (Canais por item) — desativar o tipo inativa todos os itens dele

UC-07 (Catálogo)
  └── UC-05 (Canais por item) — os canais do item precisam do item cadastrado
  └── UC-04 (Feedback por item) — a coleta do item precisa estar ativa para o formulário carregar

UC-05 (Canais de coleta)
  └── UC-04 (Envio de feedback) — a coleta precisa estar ativa para aceitar envios

UC-08 (Contexto e IA)
  └── UC-11 (Análise dos comentários) — os 3 campos de contexto (resumo, objetivo, objetivo analítico) preenchidos e a IA configurada
  └── UC-09 (Diagnóstico do escopo) — mesmas condições do UC-11

UC-04 (Coleta de feedback)
  └── UC-09 (Dashboard) — dados úteis dependem de feedbacks coletados
  └── UC-10 (Listagem) — não há o que listar sem feedbacks
  └── UC-11 (Insights) — mínimo de 10 feedbacks para disparar análise (e só os que têm comentário vão para a IA)
```

---

## Relação com Testes E2E

A suíte de testes E2E do Playwright (`feedback-analytics-web/e2e/`) foi **removida**; os cenários de cada UC passaram a ser executados **manualmente**, pelo [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). A coluna **Cobertura** abaixo reflete a profundidade dos cenários hoje reproduzidos manualmente (equivalente ao que a suíte automatizada exercitava antes da remoção):

| Arquivo de UC | Cobertura manual (runbook) |
|---|---|
| [uc-01-cadastro-conta.md](uc-01-cadastro-conta.md) | ✅ E-mail duplicado (o cenário de documento duplicado ficou obsoleto: o cadastro não pede mais CPF/CNPJ) |
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

A seção "Base para Teste E2E" de cada UC lista, cenário a cenário, o que é reproduzido manualmente, o que é apenas smoke e o que está apenas planejado. Os cenários marcados ⛔ *Obsoleto* descrevem um comportamento que o sistema não tem mais e ficam só como registro. As coberturas detalhadas (incluindo testes de unidade, de integração e cenários planejados) estão mapeadas no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).
