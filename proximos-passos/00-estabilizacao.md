# 00 — Estabilização: parar o que está quebrando

> **Em uma frase:** antes de construir qualquer coisa nova, consertamos os quatro erros que apareceram na demonstração do TCC1 — com correções pequenas, rápidas e de baixo risco.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 1 |
| **Esforço** | Médio |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | Nada — é o ponto de partida do roadmap |
| **Camadas afetadas** | Backend · Banco · Infra (Supabase) |

## Para qualquer leitor

Imagine que o sistema é um carro que já anda, mas que, na hora de mostrar para a banca, engasga em quatro situações específicas: quando várias pessoas tentam se cadastrar ao mesmo tempo, quando a Inteligência Artificial é usada muitas vezes no mesmo dia, e quando uma análise demora demais e o sistema desiste no meio do caminho. Nada disso impede o carro de funcionar no dia a dia, mas são justamente as falhas que aparecem na pior hora — diante de quem está avaliando.

Esta etapa é o equivalente a **primeiros socorros**. Não vamos reconstruir o motor nem trocar a suspensão (isso vem nas etapas seguintes). Vamos identificar com precisão **por que** cada engasgo acontece e aplicar o remédio mais simples que resolve o sintoma sem efeitos colaterais. É a etapa menos vistosa do projeto, mas a mais importante: sem ela, qualquer demonstração corre o risco de travar.

São quatro problemas, e todos têm uma causa concreta já identificada no código: (1) o cadastro falha quando muita gente entra junto porque o serviço gratuito de e-mail tem um limite de envios; (2) e (3) a cota diária da Inteligência Artificial (o Google Gemini, no plano gratuito) estoura porque o sistema, quando algo dá errado, **tenta de novo várias vezes** e gasta o dobro ou o triplo, e porque o botão "gerar insights" **refaz toda a análise do zero a cada clique**, sem guardar o resultado; (4) a análise de muitos feedbacks demora mais do que o serviço de hospedagem gratuito permite e é cortada no meio.

O ponto honesto: aqui só **estancamos o sangramento**. A cura definitiva de dois desses problemas (a análise demorada e o custo da Inteligência Artificial) é estrutural e está planejada nas etapas [03 — Análise assíncrona](./03-analise-assincrona.md) e [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md). Esta etapa entrega estabilidade imediata e, de quebra, produz o **diagnóstico** que justifica aquelas mudanças maiores.

## O que muda para quem usa o sistema

- **Para o gestor (quem cria a conta):** o cadastro deixa de falhar de forma misteriosa quando há vários cadastros próximos no tempo. Se algo realmente der errado, a mensagem de erro passa a dizer **o que** aconteceu, em vez de uma falha genérica.
- **Para o gestor que analisa feedbacks:** o botão "gerar insights" para de "queimar" a cota da Inteligência Artificial repetindo o mesmo trabalho. Clicar duas vezes seguidas não gasta o dobro — o resultado já calculado é reaproveitado.
- **Para a banca / demonstração:** muito menos chance de o sistema travar na hora de mostrar, porque as três causas de falha mais prováveis foram tratadas na origem.
- **Para o cliente que dá o feedback:** nenhuma mudança visível — o formulário público continua igual. Esta etapa mexe só nos bastidores.

## Como vai funcionar

A etapa ataca cada um dos quatro erros de forma independente. Veja o "antes e depois" de cada um:

| Problema | Antes (TCC1) | Depois (esta etapa) |
|---|---|---|
| **Cadastro concorrente** | Falha silenciosa quando vários usuários se cadastram juntos; o erro é "engolido" e ninguém sabe a causa | E-mail próprio (sem o limite do plano gratuito), logs que mostram a causa real e o banco garantindo que documentos duplicados sejam barrados de forma confiável |
| **Retry da IA** | Em caso de erro, tenta até 4 vezes — e cada tentativa **consome cota** | Para de re-tentar quando o erro é justamente "cota esgotada" (re-tentar não adianta e só gasta mais) |
| **"Gerar insights"** | Reprocessa até 100 feedbacks **toda vez** que se clica, sem guardar nada | Respeita um limite e **reaproveita** o resultado já calculado, em vez de refazer tudo |
| **Timeout da análise** | A função é cortada antes de terminar, sem explicação clara | Diagnóstico confirma a causa (limite de tempo do plano gratuito) e justifica mover a análise para o modelo assíncrono na etapa 03 |

O fluxo do cadastro, em linguagem simples: hoje, quando alguém cria a conta, o Supabase (nosso serviço de banco e autenticação) precisa **enviar um e-mail de confirmação**. No plano gratuito, esse envio de e-mail tem um teto baixíssimo de mensagens por hora. Quando várias pessoas se cadastram em sequência, o teto é atingido e o cadastro falha. A solução é plugar um **servidor de e-mail próprio** (um serviço como o Resend, que tem camada gratuita generosa) — assim o limite some, porque quem envia os e-mails passa a ser o nosso provedor, não o cota interna do Supabase.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

### 1) Cadastro concorrente

Três frentes complementares:

**a) Configurar SMTP próprio no Supabase Auth.** Causa mais provável da falha sob carga: o **rate limit de envio de e-mail** do Supabase Auth no plano gratuito (poucos e-mails/hora). O código já reconhece o sintoma — `mapSupabaseRegisterError` em `backends/api-gateway/src/controllers/public/register.controller.ts` trata `'email rate limit exceeded'` e devolve `429`, e há inclusive um **bypass de teste** comentado (`email === 'gestor@empresateste.com'`) com a justificativa literal *"to avoid hitting Supabase Auth signup rate limits"*. Apontar o SMTP do projeto para um provedor externo (Resend, Brevo, AWS SES) move o limite de envio para fora da cota free do Auth. É configuração no painel do Supabase + variáveis de ambiente; **zero código de aplicação**.

**b) Parar de "engolir" erros para confirmar a causa.** No mesmo arquivo, o bloco que valida `phone_exists` / `document_exists` tem um `catch {}` **vazio** (linha ~178: *"Falha nas validações não deve impedir o fluxo."*). Isso mascara erros reais de RPC. Trocar por um `catch (err) { console.warn(...) }` estruturado dá observabilidade sem alterar o comportamento — confirma, nos logs do Vercel, se a falha vem do RPC, do `signUp` ou do trigger.

**c) Garantir unicidade no banco — pré-requisito do cadastro correto.** O trigger `public.create_enterprise_on_signup` (em `database/sql/functions/public/create_enterprise_on_signup__cd0cc999bf.sql`) usa **SELECT-depois-INSERT** para checar documento duplicado:

```sql
SELECT 1 INTO v_exists FROM public.enterprise e WHERE e.document = v_document LIMIT 1;
IF v_exists = 1 THEN RAISE EXCEPTION 'document_already_exists' ...
INSERT INTO public.enterprise (...) VALUES (...) ON CONFLICT (auth_user_id) DO NOTHING;
```

Dois problemas latentes:
- **Corrida (race condition):** entre o `SELECT` e o `INSERT`, dois cadastros simultâneos com o mesmo documento passam ambos na checagem. O DDL de `public.enterprise.sql` define **só** `PRIMARY KEY (id)` — **não há UNIQUE em `document`**. Falta `ALTER TABLE public.enterprise ADD CONSTRAINT enterprise_document_key UNIQUE (document);`.
- **Constraint não versionada:** o `ON CONFLICT (auth_user_id)` exige um índice/constraint UNIQUE em `auth_user_id` que **não existe** em `public.enterprise.sql`. Hoje funciona "por sorte" se a constraint foi criada manualmente no banco real; precisa ser versionada (`ADD CONSTRAINT enterprise_auth_user_id_key UNIQUE (auth_user_id)`), senão o `ON CONFLICT` quebra com erro de SQL.

Com os dois UNIQUE no lugar, o `SELECT`-prévio vira otimização (mensagem amigável) e o **banco** passa a ser a barreira real — atômica e à prova de corrida.

### 2) Retry da IA que multiplica consumo de cota

Em `services/ia-analyze/src/providers/gemini.provider.ts`, `MAX_ATTEMPTS = 4` e `RETRYABLE_STATUS` inclui **429** (rate limit / cota). Quando o erro é `429 RESOURCE_EXHAUSTED` da **cota diária**, re-tentar **não adianta** (a cota só reseta no dia seguinte) e cada tentativa **conta como mais uma requisição** — ou seja, o retry acelera o esgotamento. Correção cirúrgica: distinguir *rate limit de curto prazo* (vale esperar o `retryDelay` sugerido — já parseado por `parseSuggestedDelayMs`) de *cota diária esgotada* (não retentar; falhar rápido com erro claro). Na prática: inspecionar a mensagem do 429; se indicar limite **diário/por dia** (`PerDay`, `daily`), tratar como não-retryable. Mantém o retry útil para `503`/overload e elimina o desperdício.

### 3) "Gerar insights" sem limite e sem cache

O fluxo de regeneração busca feedbacks via `fetchAlreadyAnalyzedFeedbacks` (`backends/api-gateway/src/repositories/iaAnalyze.repository.ts`), com `limit = 100` por padrão, e **reprocessa a cada clique** — não há verificação de "já gerei isso recentemente". Há um `upsert` por escopo em `upsertFeedbackInsightsReports` (tabela `feedback_insights_report`, unicidade `enterprise_id,scope_type,catalog_item_id`), mas ele guarda o **resultado**, não evita o **reprocessamento**. Correção de baixo risco (cache de leitura): antes de chamar o LLM, ler `feedback_insights_report` para o escopo pedido; se houver relatório recente (ex.: `updated_at` dentro de uma janela curta, ou sem feedbacks novos desde então), **devolver o relatório salvo** em vez de reprocessar. Botão "forçar regeneração" continua disponível para o caso de querer recalcular de propósito. Isso transforma N cliques em **1 chamada ao Gemini** mais N leituras baratas no Postgres.

### 4) Timeout da análise — diagnóstico

Tanto `vercel.json` quanto `services/ia-analyze/vercel.json` pedem `maxDuration: 300` (e o gateway usa `DEFAULT_REMOTE_TIMEOUT_MS = 280_000`). Porém, no **plano Hobby (free) da Vercel**, o teto real de duração de função é **~60s** — o `maxDuration=300` é ignorado e a função é cortada bem antes. Como toda a análise roda **síncrona dentro da requisição HTTP** (encadeia 1 chamada ao Gemini por lote de ≤20 feedbacks por escopo), lotes grandes simplesmente não cabem em 60s. O entregável aqui é o **diagnóstico documentado** (medir o `elapsedMs` já logado por `logIaAnalyzeFailure` em `iaAnalyze.controller.ts` e correlacionar com o corte em ~60s), que **justifica formalmente** a [etapa 03 — Análise assíncrona](./03-analise-assincrona.md) (processar em segundo plano, fora do ciclo da requisição) e a [etapa 08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) (avaliar plano/host). Nesta etapa **não** reescrevemos a arquitetura — apenas confirmamos a causa e, opcionalmente, reduzimos o limite default de feedbacks por execução para caber na janela enquanto a 03 não chega. O diagnóstico completo (evidências de código + planilha de medição a preencher com os logs da Vercel) está em [00 — Diagnóstico do timeout](./00-diagnostico-timeout.md).

## Riscos e decisões em aberto

- **SMTP próprio é a causa *mais provável*, não 100% confirmada.** Por isso a frente (b) — melhorar os logs — vem junto: ela serve para **confirmar** o diagnóstico antes/depois da troca. Se mesmo com SMTP externo o cadastro falhar sob carga, os logs apontarão o próximo suspeito (o trigger, por exemplo).
- **Adicionar UNIQUE em tabela existente** pode falhar se já houver duplicatas no banco de produção. Antes do `ALTER TABLE`, rodar um `SELECT document, count(*) ... GROUP BY ... HAVING count(*) > 1` e limpar duplicatas.
- **Cache de insights** introduz a pergunta "quando o cache é considerado velho?". Decisão em aberto: invalidar por tempo (ex.: 1h) ou por "existe feedback novo desde a última geração?". A segunda é mais correta, mas exige uma query a mais.
- **Reduzir o limite de feedbacks por execução** é paliativo — mascara o problema de timeout em vez de resolvê-lo. É aceitável **somente** como ponte até a etapa 03.
- **Custo do provedor de e-mail:** o plano gratuito do Resend/Brevo cobre o TCC com folga, mas tem limite mensal. Não é problema na escala atual; fica registrado.

## Como vamos saber que deu certo

- [ ] 10 cadastros em sequência rápida (script ou teste E2E) concluem **sem** erro de rate limit de e-mail.
- [ ] Os e-mails de confirmação chegam pelo provedor SMTP externo configurado (verificável no painel do provedor).
- [ ] O `catch` vazio em `register.controller.ts` foi substituído por log estruturado; uma falha de RPC forçada aparece nos logs com causa identificável.
- [ ] Existe migração versionada em `database/sql/` adicionando `UNIQUE(document)` e `UNIQUE(auth_user_id)` em `public.enterprise`; tentar cadastrar documento duplicado retorna `409 document_already_exists` de forma consistente, inclusive sob concorrência.
- [ ] Um erro `429` de **cota diária** simulado **não** dispara as 4 tentativas — falha rápido e com mensagem clara; um `503` ainda é retentado normalmente (teste unitário no provider).
- [ ] Clicar "gerar insights" duas vezes seguidas no mesmo escopo resulta em **1** chamada ao Gemini (a segunda lê do cache) — verificável por log/contador.
- [ ] Documento de diagnóstico do timeout registra o tempo até o corte (~60s) e referencia explicitamente as etapas 03 e 08. → [00 — Diagnóstico do timeout](./00-diagnostico-timeout.md) criado (evidências de código prontas; falta colar a medição dos logs da Vercel).

## Etapas de entrega

1. **Diagnóstico e observabilidade (1–2 dias):** trocar o `catch {}` vazio por log estruturado no cadastro; medir e documentar o corte de ~60s no timeout da análise. Entrega: causas confirmadas, sem mexer em comportamento.
2. **E-mail próprio (0,5 dia):** configurar SMTP externo (Resend) no Supabase Auth; validar 10 cadastros em sequência. Entrega: cadastro concorrente estável.
3. **Unicidade no banco (0,5–1 dia):** migração versionada com os dois `UNIQUE`; limpeza prévia de duplicatas se houver. Entrega: integridade de documento/usuário garantida pelo banco.
4. **Retry consciente de cota (0,5 dia):** não retentar `429` de cota diária; manter retry para `503`/overload. Entrega: cota da IA para de ser desperdiçada por retries inúteis.
5. **Cache de insights (1 dia):** leitura prévia de `feedback_insights_report` antes de chamar o LLM; botão de regeneração forçada. Entrega: "gerar insights" para de reprocessar a cada clique.

## O que isso demonstra no TCC

- **Diagnóstico de problemas de produção:** identificar a causa-raiz de falhas intermitentes (rate limit, cota, timeout) a partir de sintomas — competência central de engenharia de software, não apenas "escrever código".
- **Observabilidade:** o valor de logs estruturados e métricas (tempo decorrido, código de erro tipado) para tornar falhas **investigáveis** em vez de misteriosas; mostra a diferença entre "engolir erro" e "registrar erro".
- **Resiliência a limites de serviços externos:** como projetar para conviver com cotas e rate limits de terceiros (Supabase Auth, Google Gemini, Vercel) — retry consciente, cache e escolha de plano — tema rico para o capítulo de arquitetura e confiabilidade.
- **Integridade de dados e concorrência:** o caso clássico SELECT-depois-INSERT versus constraint UNIQUE no banco ilustra atomicidade e condições de corrida de forma concreta e verificável.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [00 — Diagnóstico do timeout](./00-diagnostico-timeout.md) — evidências da causa-raiz (Parte F) que fundamentam as etapas 03 e 08
- [03 — Análise assíncrona](./03-analise-assincrona.md) — solução estrutural para o timeout e o custo da IA
- [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) — plano de hospedagem e teto de tempo de execução
