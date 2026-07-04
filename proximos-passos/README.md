# Roadmap — Próximos Passos (TCC2)

> **Em uma frase:** o plano dos próximos **6 meses** para o *feedback-analytics*: primeiro estabilizar o que quebra em produção, depois entregar 4 funcionalidades novas — cada uma apoiada em uma melhoria de arquitetura que rende capítulo de TCC.

Este documento é o **ponto de entrada**. Ele foi escrito para ser entendido por **qualquer pessoa** (não só por quem programa). Cada etapa tem um documento próprio, mais detalhado, linkado na tabela abaixo. No fim há um **glossário** que explica os termos técnicos em linguagem simples.

---

## O projeto em uma página

O *feedback-analytics* é um sistema onde uma **empresa** coleta a opinião dos seus clientes por **QR Code** e recebe, de volta, uma **análise feita por inteligência artificial** (sentimento, temas, pontos fortes e fracos). O cliente escaneia o código, responde um formulário curto (nota + perguntas + um comentário), e o gestor vê tudo organizado num painel, com relatórios e estatísticas.

O sistema é dividido em três partes: o **site** que as pessoas usam (frontend), o **servidor** que recebe e organiza os dados (API), e o **serviço de IA** que analisa os textos. Tudo guardado num **banco de dados**.

## Por que este roadmap existe

Na entrega anterior (TCC1), surgiram dois tipos de questão:

**1. Erros de produção** (a aplicação quebrava em uso real, por causa dos limites dos planos gratuitos que usamos):
- O **cadastro** falhava quando várias pessoas se cadastravam ao mesmo tempo.
- A **análise da IA** estourava o tempo limite (timeout).
- A análise às vezes falhava por mandar **contexto grande demais** para a IA.
- A análise estourava o **limite diário de uso** da IA (Gemini gratuito).

**2. Sugestões da banca** (pontos de evolução acadêmica):
- "Usar Supabase não exercita o conhecimento de banco de dados" → sugeriram um **ORM**.
- "A autenticação está no Supabase; e se houver um **vazamento de dados**, como vocês lidariam com as consequências?"

E, além disso, **4 funcionalidades novas** que decidimos entregar no TCC2:
1. Métricas por período personalizável.
2. Comparar métricas entre períodos.
3. Feedback por áudio.
4. Novo canal de coleta por aproximação (**NFC**).

## A estratégia: features apoiadas em engenharia

O risco de um TCC parecer "duas listas soltas" (refatorações + funcionalidades) se resolve assim: **cada funcionalidade nova é construída em cima de uma melhoria de arquitetura.** Você entrega algo visível *e* demonstra profundidade técnica na mesma frente.

| Funcionalidade (o que se vê) | Apoiada em (a profundidade) |
|---|---|
| Métricas por período + comparação | Camada de dados com **ORM** + consultas otimizadas |
| Feedback por áudio | **Armazenamento de arquivos** + **processamento assíncrono** (a transcrição é uma tarefa longa) + **IA multimodal** |
| Novo canal **NFC** | Modelo de coleta **multicanal** |
| (a análise de IA atual) | **Processamento assíncrono** + **controle de ritmo** (resolve os erros de produção) |

> Repare: a **feature de áudio sozinha** já justifica armazenamento, processamento assíncrono e IA configurável. A infraestrutura não é um item "à parte" — ela é pré-requisito de coisas que a banca pediu.

---

## Roadmap de 6 meses

| Mês | Etapa | O que o usuário ganha | Profundidade (capítulo) | Prioridade |
|---|---|---|---|---|
| 1 | [00 — Estabilização](./00-estabilizacao.md) | Sistema para de quebrar | Diagnóstico, observabilidade, resiliência a limites | 🔴 Essencial |
| 1–2 | [01 — Camada de dados e ORM](./01-camada-de-dados-e-orm.md) | (base para o resto) | Modelagem, ORM, migrations, multi-tenant | 🔴 Essencial |
| 2 | [02 — Métricas por período + comparação](./02-metricas-por-periodo-e-comparacao.md) | Filtra e compara períodos no painel | Agregação em SQL, índices, UX de comparação | 🔴 Essencial |
| 2–3 | [03 — Análise assíncrona (worker + fila)](./03-analise-assincrona.md) | IA deixa de dar timeout/estourar cota | Arquitetura assíncrona, filas, rate limiting, idempotência | 🔴 Essencial |
| 3 | [04 — Provedor de IA configurável](./04-provedor-de-llm-configuravel.md) | IA mais barata e resiliente | Padrões de projeto (Strategy/Adapter), avaliação empírica de modelos | 🔴 Essencial |
| 3–4 | [05 — Feedback por áudio](./05-feedback-por-audio.md) | Cliente grava áudio em vez de digitar | Armazenamento de mídia, IA multimodal, pipeline assíncrono | 🟡 Fase 1 essencial · Fase 2 stretch |
| 4–5 | [06 — Coleta por NFC](./06-coleta-por-nfc.md) | Coleta por aproximação do celular | Arquitetura omnichannel, Web NFC/NDEF | 🔴 Essencial |
| 5 | [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md) | Confiança e conformidade | Análise de risco, LGPD, responsabilidade compartilhada | 🟡 Importante |
| 5–6 | [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) | Roda estável e barato/grátis | Deploy, containers, portabilidade entre provedores | 🟡 Importante |

**Legenda de prioridade:** 🔴 Essencial · 🟡 Importante · ⚪ Se sobrar tempo
**Legenda de status (em cada etapa):** 🔵 Planejado · 🟢 Em andamento · ✅ Entregue · ⏸️ Pausado

---

## Mapa de leitura (resumo de cada etapa)

- **[00 — Estabilização](./00-estabilizacao.md):** primeiros socorros — corrige os 4 erros de produção (cadastro, retry da IA que gasta cota, "gerar insights" sem cache, diagnóstico do timeout) com mudanças pequenas e de baixo risco.
- **[01 — Camada de dados e ORM](./01-camada-de-dados-e-orm.md):** adota o **Drizzle** (ORM que mantém o SQL à vista) sobre o mesmo banco, respondendo à crítica sobre conhecimento de banco sem esconder o SQL — e mostrando o que o projeto já tem de avançado (segurança por empresa, funções, índices).
- **[02 — Métricas por período + comparação](./02-metricas-por-periodo-e-comparacao.md):** filtra o painel por intervalo de tempo e compara dois períodos (atual × referência) com variação clara (seta e cor).
- **[03 — Análise assíncrona](./03-analise-assincrona.md):** **a peça central.** Tira a análise de IA de dentro da requisição e a coloca numa **fila** processada por um **worker** no ritmo certo — resolve timeout e cota na raiz.
- **[04 — Provedor de IA configurável](./04-provedor-de-llm-configuravel.md):** permite trocar o modelo de IA por configuração (Gemini + OpenRouter, com opção gratuita padrão) e, depois, cada empresa usar a própria chave.
- **[05 — Feedback por áudio](./05-feedback-por-audio.md):** o cliente grava um áudio em vez de digitar; entregue em duas fases (guardar/ouvir primeiro; transcrever e analisar depois).
- **[06 — Coleta por NFC](./06-coleta-por-nfc.md):** novo canal por aproximação (a etiqueta guarda a mesma URL do QR), com comparação QR × NFC nas métricas.
- **[07 — Segurança e LGPD](./07-seguranca-e-lgpd.md):** trata a preocupação de vazamento como **gestão de risco** (modelagem de ameaças + plano de resposta), em vez de reescrever a autenticação.
- **[08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md):** move o que precisa ficar "sempre ligado" para um servidor barato/gratuito e mantém o site numa CDN.

---

## Decisões em aberto (precisam de definição da equipe/orientador)

| Decisão | Opções | Onde discutir |
|---|---|---|
| **Autenticação própria?** | Manter Supabase Auth (recomendado, menor risco) **ou** biblioteca de auth self-hosted (só se formos para servidor próprio total) | [07](./07-seguranca-e-lgpd.md) e [08](./08-infraestrutura-e-custo.md) |
| **Self-host total?** | "Mínimo" (fica no Supabase, move só o worker) **ou** "tudo num servidor próprio" (mais esforço, mais demonstração) | [08](./08-infraestrutura-e-custo.md) |
| **Separar os repositórios?** | ✅ **Decidido (jul/2026): separado em multi-repo.** Motivação **organizacional e técnica**: isolar acesso por repositório para novos contribuidores; e, como o **ORM (Drizzle) bypassa a RLS** (a segurança passa a depender de filtro explícito por `enterprise_id` na aplicação), concentrar o código sensível de acesso ao banco no repo do gateway para revisão mais atenta. A sincronização de contratos passou a um pacote versionado (`@feedback/lib-shared`). Ver [decisão de arquitetura](../docs/arquitetura/historico-de-decisoes/decisao-monorepo-vs-monolito.md#evolução-de-monorepo-para-multi-repo) e [ORM × RLS](../docs/arquitetura/orm-rls-decisao.md). | [08](./08-infraestrutura-e-custo.md) |

## Alerta honesto de escopo

Isto é **ambicioso** para 6 meses. Cabe com **2+ pessoas** se mantivermos o ORM **parcial** (Drizzle só nos caminhos novos, sem migração total) e a autenticação no Supabase. Se o tempo apertar, os **cortes seguros**, nesta ordem, são:
1. **Áudio Fase 2** (transcrição) — entrega só a Fase 1 (gravar/guardar/ouvir).
2. **Self-host** — o worker pode continuar onde estiver se necessário.
3. **Comparação de modelos de IA** — mantém um provedor só.

**Não cortar:** a etapa 03 (worker + fila) — é o que conserta os erros de produção.

---

## Glossário (termos técnicos em linguagem simples)

| Termo | O que significa |
|---|---|
| **Serverless / função** | Código que roda só quando é chamado, por pouco tempo, gerenciado pela plataforma (Vercel). Ótimo para respostas rápidas, ruim para tarefas longas. |
| **Always-on / worker** | Um programa **sempre ligado** numa máquina, que faz trabalho em segundo plano (ex.: analisar feedbacks sem o usuário esperar). |
| **Fila (queue)** | Uma "lista de tarefas" durável: o sistema **anota** o pedido e responde na hora; alguém processa depois, no ritmo certo. |
| **Cota / rate limit** | Limite de quantas vezes se pode usar um serviço externo (ex.: a IA) por minuto ou por dia. |
| **Retry / backoff** | Tentar de novo após uma falha, esperando um pouco mais a cada tentativa. |
| **LLM** | O modelo de inteligência artificial que lê e escreve texto (ex.: Gemini). |
| **Lote (batch)** | Grupo de feedbacks enviados juntos para a IA numa única chamada. |
| **ORM** | Uma camada que traduz código em comandos de banco de dados (ex.: Drizzle), com tipagem e histórico de mudanças. |
| **Migration** | Um arquivo versionado que descreve uma mudança na estrutura do banco. |
| **RLS (segurança por linha)** | Regra **dentro do banco** que garante que cada empresa só enxerga os próprios dados. |
| **Multi-tenant** | Vários clientes (empresas) no mesmo sistema, isolados uns dos outros. |
| **Storage / bucket** | Espaço para guardar **arquivos** (áudios, logos). |
| **URL assinada** | Um link temporário e seguro para enviar ou baixar um arquivo. |
| **NFC / NDEF** | Tecnologia de **aproximação** (a mesma do pagamento por aproximação); NDEF é o formato do dado (uma URL) gravado na etiqueta. |
| **CDN** | Rede que entrega o site estático rápido e barato no mundo todo. |
| **Polling** | O aplicativo pergunta de tempos em tempos: "já terminou?". |
| **Idempotência** | Rodar a mesma tarefa duas vezes não causa efeito duplicado. |
| **Threat model** | Análise de "o que pode dar errado em segurança e como nos protegemos". |
| **Controlador / Operador (LGPD)** | Quem decide sobre os dados (nós) e quem processa a nosso serviço (o Supabase). |
| **Escopo** | O recorte da análise: empresa, produto, serviço ou departamento. |
| **Monorepo** | Um único repositório com vários módulos (site, API, IA) que evoluem juntos. |

---

## Como usar e manter esta pasta

- Cada frente de trabalho tem **um arquivo** (`NN-titulo.md`). Atualize o **Status** no topo conforme avança (🔵 → 🟢 → ✅).
- Quando uma etapa for entregue, marque ✅ aqui na tabela e registre as decisões tomadas no próprio arquivo.
- Esta pasta **consolida e substitui** as anotações iniciais da antiga pasta `proxPassos/` (já removida; o histórico permanece no Git). As frentes de reorganização das telas de configuração e de preview do formulário daquelas anotações **já foram implementadas** — ver `docs/changelog_documentacao.md` (v4.2).
- A documentação técnica do **estado atual** do sistema vive em [`docs/`](../docs/).
