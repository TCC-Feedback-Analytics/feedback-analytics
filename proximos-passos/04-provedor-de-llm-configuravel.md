# 04 — Provedor de IA (LLM) configurável

> **Em uma frase:** deixar de depender de um único "cérebro de IA" preso no código e com uma única chave compartilhada, passando a poder trocar de provedor (Gemini, OpenRouter e outros) por configuração — e, num segundo momento, deixar cada empresa usar a própria chave.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 3 |
| **Esforço** | Médio |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | Idealmente da [03 — Análise assíncrona](./03-analise-assincrona.md) (para que a troca de provedor já rode fora da requisição HTTP) |
| **Camadas afetadas** | Serviço de IA · Backend |

## Para qualquer leitor

Toda análise de feedback deste sistema é feita por uma "inteligência artificial" — um serviço externo que lê os comentários dos clientes e devolve o sentimento (positivo, neutro, negativo), as categorias e as palavras-chave. Hoje esse serviço é **um só**: o **Google Gemini**. E ele está "soldado" no código: o nome do modelo está escrito à mão e existe **uma única chave de acesso** compartilhada por todas as empresas do sistema.

Pense numa cafeteria com **uma única tomada** para todos os clientes carregarem o celular. Enquanto há pouca gente, funciona. Mas conforme mais pessoas chegam, a fila na tomada cresce e, em algum momento, ela "desarma" — é exatamente o que acontece com a cota gratuita do Gemini: todas as empresas dividem o mesmo limite diário, e quando ele acaba, acaba para todo mundo.

A solução desta etapa tem duas partes. A **primeira** é tornar o provedor de IA **trocável por configuração**: além do Gemini, passar a aceitar o **OpenRouter** — um "balcão único" que dá acesso a vários modelos de IA de diferentes empresas (incluindo opções gratuitas) usando um mesmo padrão de comunicação. Com isso, escolher qual IA usar vira uma decisão de configuração, não uma reescrita de código. A **segunda parte**, mais ambiciosa, é permitir que **cada empresa traga a própria chave** (o chamado "BYO-key", do inglês *bring your own key*) — voltando à analogia, é como cada cliente trazer seu próprio carregador e tomada: o limite deixa de ser compartilhado e a fila simplesmente some.

A boa notícia é que o sistema **já foi construído pensando nisso**. Existe um "encaixe padrão" no código onde qualquer provedor de IA pode ser plugado — só falta fabricar o segundo plugue.

## O que muda para quem usa o sistema

- **Para o gestor (dono da empresa):** as análises param de falhar por "cota esgotada", porque o sistema deixa de depender de um único limite compartilhado. Na fase BYO-key, o gestor poderá conectar a própria conta de IA e ter um limite só seu.
- **Para o gestor, na prática:** mais estabilidade nos botões "Analisar feedbacks" e "Gerar insights" — eles deixam de competir com todas as outras empresas pelo mesmo balde de cota.
- **Para o cliente que dá o feedback:** nada muda na tela dele — é uma mudança "embaixo do capô". O benefício chega indireto: o gestor consegue analisar mais feedbacks com mais frequência.
- **Para o projeto/TCC:** abre a porta para uma comparação honesta entre diferentes modelos de IA (qual acerta mais o sentimento?), usando uma ferramenta de medição que **já existe** no código.

## Como vai funcionar

Hoje o caminho é fixo: o serviço de IA sempre instancia o cliente do **Gemini**, com o modelo `gemini-2.5-flash` escrito à mão e uma única chave global (`GEMINI_API_KEY`).

**Antes (hoje):**

```
Análise → [SEMPRE Gemini, modelo fixo, chave única global]
```

**Depois (esta etapa):**

```
Análise → escolhe o provedor por configuração:
            ├─ Gemini       (continua funcionando)
            └─ OpenRouter   (vários modelos, opções gratuitas)
          ... e, na fase 2, usa a CHAVE DA PRÓPRIA EMPRESA quando ela tiver uma.
```

O segredo é que o "motor" de análise não precisa saber **qual** provedor está atrás dele. Ele conversa com um **encaixe padrão** (um contrato): "me dê este lote de feedbacks analisado neste formato". Quem responde — Gemini ou OpenRouter — é detalhe de implementação. Trocar de provedor passa a ser como trocar a marca da lâmpada: o soquete é o mesmo.

A escolha do provedor e do modelo será feita por **variáveis de configuração** (`LLM_PROVIDER` e `LLM_MODEL`), sem mexer no código a cada troca. O **padrão recomendado** será um modelo gratuito do OpenRouter, com o Gemini disponível como alternativa.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

### O encaixe já existe (padrão Strategy/Adapter)

O ponto-chave: a **porta** (interface) já está definida e o motor **só depende dela**, não da implementação concreta.

- Contrato: `feedback-analytics-ia-analyze/types/iaApiClient.types.ts` define o tipo `IaApiClient` — basicamente `analyzeBatch(params) => Promise<ParsedIaResponse>`. Também define o shape **neutro** de saída (`ParsedIaResponse` com `feedbacks[]` + `global_insights`) e os códigos de erro padronizados (`'failed_ia_request' | 'invalid_ai_response'`).
- Implementação atual: `feedback-analytics-ia-analyze/src/providers/gemini.provider.ts` — a função `createIaApiClient(apiKey)` devolve um objeto que **implementa** `IaApiClient`. É o único provedor existente.
- Consumo: `feedback-analytics-ia-analyze/src/services/iaAnalyze.service.ts` importa `createIaApiClient` **diretamente do arquivo do Gemini** (linha 1) e o instancia na linha 118 com `process.env.GEMINI_API_KEY`. Esse import fixo é o único acoplamento concreto que sobra.

Ou seja: a "estratégia" (Strategy) já está abstraída; falta apenas **fabricar um segundo adaptador** (Adapter) para o OpenRouter e **inverter a escolha** do provedor para uma fábrica configurável.

### Tarefas concretas

1. **Criar `feedback-analytics-ia-analyze/src/providers/openrouter.provider.ts`** implementando `IaApiClient`. O OpenRouter expõe uma API **compatível com o formato OpenAI** (`/chat/completions`), então o adaptador:
   - **Reusa o builder de prompt** `buildIaPromptByScope` (`feedback-analytics-ia-analyze/src/lib/iaAnalyzePromptBuilders.ts`) — ele já devolve uma `string` neutra (cabeçalho + instruções de escopo + esquema esperado + payload JSON), sem nada específico do Gemini.
   - **Reusa o parser** `extractJsonFromText` (`feedback-analytics-ia-analyze/src/utils/extractJsonFromText.ts`) + `JSON.parse` — também já é genérico (tolera cercas markdown e texto ao redor do JSON).
   - **Embrulha o prompt em `messages[]`:** onde o Gemini envia `contents: prompt`, o OpenRouter envia `messages: [{ role: 'user', content: prompt }]` (ou um `system` curto + `user`). Pode-se pedir `response_format: { type: 'json_object' }` nos modelos que suportam, reforçando a saída em JSON.
   - **Trava de saída:** equivalente ao `MAX_OUTPUT_TOKENS` (16.384) via `max_tokens`, e detecção de truncamento via `finish_reason === 'length'` (espelhando o tratamento de `finishReason === 'MAX_TOKENS'` do Gemini → lançar `IaApiClientError('...', 'invalid_ai_response')`).

2. **Mapear erros para o contrato já existente.** O `gemini.provider.ts` já tem uma boa base reaproveitável: `getErrorStatus`, `isRetryableError`, `RETRYABLE_STATUS` (429/500/502/503/504), backoff com jitter e `parseSuggestedDelayMs`. Para o OpenRouter, ler o header **`Retry-After`** (HTTP padrão) em vez do `retryDelay` embutido na mensagem do Gemini. **Sugestão de refatoração:** extrair essas funções de retry/erro para um módulo compartilhado (`providers/shared/retry.ts`) para os dois adaptadores usarem.

3. **Seletor de provedor por env (inverter o import fixo).** Criar uma fábrica — por exemplo `feedback-analytics-ia-analyze/src/providers/createProvider.ts` — que lê `LLM_PROVIDER` (`'gemini' | 'openrouter'`) e devolve o `IaApiClient` certo. Em `iaAnalyze.service.ts`, trocar o import direto de `createIaApiClient` por essa fábrica. Documentar as novas variáveis em `feedback-analytics-ia-analyze/.env.example`:
   - `LLM_PROVIDER=openrouter` (default sugerido)
   - `LLM_MODEL=<id-do-modelo>` (ex.: um modelo `:free` do OpenRouter)
   - `OPENROUTER_API_KEY=...` (ao lado da `GEMINI_API_KEY` já existente)

4. **Extrair o modelo hardcoded.** Em `gemini.provider.ts` o `model: 'gemini-2.5-flash'` está fixo na chamada (`ai.models.generateContent`). Passar a ler de `LLM_MODEL` (com fallback para o valor atual), para que o modelo também seja configurável — pré-requisito para a comparação empírica descrita abaixo.

### BYO-key (chave por empresa) — sub-fase POSTERIOR e cara

Permitir que cada empresa traga a própria chave é o item que **resolve a cota na raiz** (distribui o limite), mas é caro e fica para uma sub-fase separada porque exige:

- **Armazenamento criptografado** da chave por empresa (nunca em texto puro): nova coluna/tabela com segredo cifrado em repouso, idealmente via *secret* gerenciado, não direto na tabela.
- **RLS** garantindo que uma empresa só leia/escreva a própria chave (alinhado às 26 policies multi-tenant já existentes em `database/sql/`).
- **Propagação nos contratos:** a chave deixa de vir só de `process.env` e passa a ser resolvida **por requisição/escopo** — muda a assinatura de `createProvider`/`createIaApiClient` (que hoje recebe uma `apiKey` global) e o caminho do `iaAnalyze.service.ts`.
- **UI** para a empresa cadastrar/testar a chave, e fallback para a chave global quando ela não tiver uma.

A primeira fase (OpenRouter + seletor por env) é estimada em **~1–2 dias**; BYO-key é um épico à parte.

### O ângulo acadêmico forte: comparar modelos com a ferramenta de avaliação que já existe

O projeto **já tem** um avaliador de classificador pronto para isso:

- `feedback-analytics-api-gateway/src/libs/eval/classifierEval.ts` — funções **puras** que calculam **Cohen's kappa** (concordância além do acaso, com faixas de Landis & Koch), **matriz de confusão** e **precision/recall/F1 por classe + macro-F1**.
- `feedback-analytics-api-gateway/scripts/eval-classifier.ts` — script de linha de comando que recebe um *gold set* (pares `{ human, model }`) e imprime kappa, acurácia, macro-F1 e a matriz de confusão. O próprio cabeçalho recomenda ≥150–300 itens rotulados (≥50 por classe) e **meta de kappa ≥ 0,6**.

Com o modelo agora configurável (`LLM_MODEL`) e múltiplos provedores, dá para rodar o **mesmo gold set** contra Gemini e contra dois ou três modelos do OpenRouter e **medir, com número, qual classifica melhor o sentimento** — em vez de "achismo". Isso transforma a escolha do provedor numa **decisão baseada em evidência** e rende um capítulo inteiro de avaliação experimental no TCC.

## Riscos e decisões em aberto

- **Modelos "free" do OpenRouter têm limites próprios** (RPM/RPD), **qualidade variável** e podem ser **descontinuados** sem aviso. → Mitigação: definir uma **cadeia de fallback** (provedor/modelo A → B → C) e tratar o esgotamento como um erro retentável já mapeado.
- **Confiabilidade da saída em JSON varia por modelo.** Modelos menores às vezes "conversam" em vez de devolver só o JSON. → O parser já tolera texto ao redor (`extractJsonFromText`), mas convém preferir modelos com `response_format: json_object` e medir a taxa de respostas inválidas por modelo.
- **Risco de fragmentar o tratamento de erro/retry** entre dois provedores. → Extrair a lógica comum para um módulo compartilhado, em vez de duplicar.
- **Sem a etapa 03 (assíncrono), a troca de provedor ainda roda dentro do timeout serverless.** Trocar o modelo não conserta sozinho o timeout; idealmente fazer depois (ou junto) do processamento assíncrono.
- **Decisão em aberto:** qual modelo gratuito do OpenRouter vira o **default**? Definir só **depois** de medir com o `eval-classifier`, não por intuição.
- **Decisão em aberto:** na fase BYO-key, onde guardar o segredo (coluna cifrada vs. *secret manager* do provedor de infra) — ver [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md).

## Como vamos saber que deu certo

- [ ] Existe `openrouter.provider.ts` implementando `IaApiClient`, reusando `buildIaPromptByScope` e `extractJsonFromText`.
- [ ] Definindo `LLM_PROVIDER=openrouter` e `LLM_MODEL=<modelo>`, uma análise real roda **de ponta a ponta** e grava sentimento/categorias/keywords/aspectos corretamente.
- [ ] Definindo `LLM_PROVIDER=gemini`, o comportamento atual continua **idêntico** (sem regressão).
- [ ] O modelo do Gemini **não está mais hardcoded**: vem de `LLM_MODEL` (com fallback).
- [ ] Erros do OpenRouter são mapeados para os mesmos códigos do contrato (`failed_ia_request` / `invalid_ai_response`) e o `Retry-After` é respeitado.
- [ ] `.env.example` documenta `LLM_PROVIDER`, `LLM_MODEL` e `OPENROUTER_API_KEY`.
- [ ] Existe ao menos **uma comparação medida** (kappa + macro-F1) entre Gemini e um modelo do OpenRouter sobre o mesmo gold set, via `eval-classifier`.
- [ ] (BYO-key, se entrar) uma empresa cadastra a própria chave, ela é cifrada em repouso, protegida por RLS, e a análise passa a usá-la em vez da global.

## Etapas de entrega

1. **Fábrica + seletor por env (sem novo provedor ainda):** extrair o import fixo do `iaAnalyze.service.ts` para uma fábrica `createProvider(LLM_PROVIDER)` que, por ora, só conhece o Gemini. Extrair o modelo hardcoded para `LLM_MODEL`. Entrega valor: comportamento idêntico, mas já configurável e testável.
2. **Adaptador OpenRouter:** criar `openrouter.provider.ts` (messages[], `max_tokens`, `response_format`, mapeamento de erro/`Retry-After`), reaproveitando o builder e o parser. Plugar na fábrica. Entrega valor: provedor alternativo funcionando, fora da cota do Gemini.
3. **Cadeia de fallback + default gratuito:** ordenar provedores/modelos para tentar o próximo quando o atual esgota/recusa. Entrega valor: robustez contra limites dos modelos "free".
4. **Comparação empírica:** montar um gold set, rodar `eval-classifier` contra ≥2 modelos, registrar kappa/macro-F1 e **escolher o default por evidência**. Entrega valor: decisão fundamentada + material de TCC.
5. **(Posterior) BYO-key por empresa:** storage cifrado + RLS + propagação de chave por escopo + UI. Entrega valor: resolve a cota na raiz, distribuindo o limite por empresa.

## Plano de execução detalhado — sub-fase BYO-key por empresa (decidido em ago/2026)

> Este plano detalha a **etapa 5** ("BYO-key por empresa") acima, com as decisões já travadas com a equipe. Foi validado contra o código real dos 4 repositórios em ago/2026. Enquanto não implementado, o Status geral desta etapa segue 🔵 Planejado.

### Decisões travadas

1. **Estratégia (alinhada a este doc):** primeiro a **fábrica `createProvider`** (Strategy) + modelo configurável + adaptador OpenRouter reusando prompt/parser, **mantendo o Gemini selecionável**; depois o **BYO-key por empresa** por cima, **com fallback a uma chave global** para empresas que ainda não configuraram a sua.
2. **Transporte da chave gateway → ia-analyze: por header HTTP** (à la `x-ia-analyze-token`). **Zero mudança** no pacote `@feedback/lib-shared` (sem bump de versão/tag, sem tocar os 3 consumidores). A chave fica fora do corpo JSON e dos logs de payload.
3. **Storage:** tabela dedicada `enterprise_ia_config` (1:1 com `enterprise`), chave cifrada com **AES-256-GCM** (`node:crypto`), segredo em `IA_CONFIG_ENCRYPTION_KEY`.
4. **Modelo:** lista curada no frontend (`google/gemini-2.5-flash`, `anthropic/claude-3.5-sonnet`, `openai/gpt-4o-mini`, `deepseek/deepseek-chat`, `openrouter/auto`) **+ opção "modelo personalizado"**.
5. **Validação da chave:** `GET https://openrouter.ai/api/v1/auth/key` no momento de salvar.

### Arquitetura alvo

```
[Config]  Web (perfil) → Gateway: PUT /api/protected/user/ia-config
            → valida no OpenRouter (/auth/key) → cifra AES-256-GCM → enterprise_ia_config

[Análise] Web → Gateway (busca+decifra config do tenant)
            → ia-analyze  [headers: x-ia-analyze-token, x-llm-api-key, x-llm-model, x-llm-provider]
            → createProvider(headers ?? env)  → OpenRouter (ou Gemini)
```

Empresa sem chave configurada ⇒ o gateway não envia os headers de credencial ⇒ o ia-analyze usa a **chave global do env** (fallback). A flag `REQUIRE_USER_IA_KEY=true` desliga o fallback quando a migração terminar.

### Camadas de implementação

**Camada 1 — Fundação (repo `feedback-analytics-ia-analyze`)** — é a etapa 1–2 deste doc:
- `[NEW] src/providers/shared/retry.ts` — extrair de `gemini.provider.ts` as funções genéricas de retry/erro (`getErrorStatus`, `isRetryableError`, `RETRYABLE_STATUS`, backoff com jitter). Para OpenRouter, ler o header `Retry-After`.
- `[NEW] src/providers/openrouter.provider.ts` — implementa `IaApiClient`; POST `/chat/completions` com `messages[]`, `max_tokens`, `response_format:{type:'json_object'}`; trunca via `finish_reason==='length'`; **402/401 não-retentáveis**. Reusa `buildIaPromptByScope` e `extractJsonFromText` sem alteração.
- `[NEW] src/providers/createProvider.ts` — fábrica `{ provider, apiKey, model }` → `IaApiClient`.
- `[MODIFY] src/providers/gemini.provider.ts` — remover o `model:'gemini-2.5-flash'` hardcoded (receber `model`); usar `shared/retry.ts`.
- `[MODIFY] src/services/iaAnalyze.service.ts` — trocar o import fixo `createIaApiClient(process.env.GEMINI_API_KEY)` pela fábrica, com creds vindos dos headers (Camada 2) **ou** do env como fallback.
- `[MODIFY] .env.example` — `LLM_PROVIDER`, `LLM_MODEL`, `OPENROUTER_API_KEY`.

**Camada 2 — Transporte por header (repos `ia-analyze` + `gateway`):**
- `ia-analyze [MODIFY] src/controllers/iaAnalyze.controller.ts` — após o `IA_ANALYZE_INTERNAL_TOKEN`, ler `x-llm-provider/x-llm-api-key/x-llm-model`; ausentes ⇒ cai no env. **Nunca logar esses headers.**
- `gateway [MODIFY] src/providers/iaAnalyze.provider.ts` — estender `runIaAnalyzeAnalysis(payload, creds?)` e injetar os headers `x-llm-*` junto do `x-ia-analyze-token`.

**Camada 3 — Storage + endpoints (repo `feedback-analytics-api-gateway`):**
- `[MODIFY] drizzle/schema/enterprise.ts` — tabela `enterpriseIaConfig` espelhando `collectingDataEnterprise` (1:1): `enterpriseId` unique + FK cascade; `provider`, `model`, `apiKeyCiphertext`, `apiKeyIv`, `apiKeyAuthTag`, timestamps. Re-exportar no barrel `drizzle/schema.ts`.
- **Migration:** `db:generate` (gera `0002_*.sql`) → `db:migrate` → `db:check` (fluxo schema-first do ADR-0001; não usar `db:pull` cego).
- `[NEW] src/utils/crypto.ts` — AES-256-GCM (`node:crypto`), chave em `IA_CONFIG_ENCRYPTION_KEY`.
- `[NEW] src/repositories/iaConfig.repository.ts` — get/upsert/delete filtrando por `enterprise_id` (`scopedByEnterprise`).
- `[NEW] src/libs/iaConfig/validateOpenRouterKey.ts` — valida a chave no `/auth/key`.
- `[NEW] src/controllers/protected/iaConfig.controller.ts` + `src/routes/protected/iaConfig.routes.ts` — GET/PUT/DELETE `/protected/user/ia-config` (molde `enterprise.controller.ts`). **GET nunca retorna a chave** (só `{ has_key, provider, model, masked_key }`). Registrar em `src/index.ts`.
- `[MODIFY] src/config/errors.ts` — `ia_config_not_found`, `ia_config_invalid_key`, `ia_config_required`.

**Camada 4 — Injeção no fluxo (repo `gateway`):**
- `[MODIFY] src/services/iaAnalyze.service.ts` — antes de `runIaAnalyzeAnalysis`: buscar+decifrar a config do `enterpriseId`; se existe, passar creds; se não e `REQUIRE_USER_IA_KEY!=='true'`, chamar sem creds (fallback global); se exigido, lançar `ia_config_required`.
- `[MODIFY] .env.example` — `IA_CONFIG_ENCRYPTION_KEY`, `REQUIRE_USER_IA_KEY=false`.
- *(Opcional)* rate-limit por `enterprise_id` nos endpoints de análise.

**Camada 5 — UI (repo `feedback-analytics-web`):**
- `[NEW] src/services/serviceIaConfig.ts` (molde `serviceEnterprise.ts`, usa os helpers de `src/lib/utils/http.ts`).
- `[NEW] pages/user/edit/editIaSettings.tsx` (wrapper fino) + `[NEW] components/user/pages/profile/editIaSettings/formIaSettings.tsx` (rhf + `zodResolver` + `useFetcher`/`useToast`); API key mascarada (reaproveitar o toggle de `components/public/forms/fields/*/fieldPassword.tsx`), select de modelo curado + custom, badge de status, link para `https://openrouter.ai/keys`.
- `[NEW] src/routes/actions/actionIaSettings.ts` + `[MODIFY] src/routes/user.tsx` (nova rota) + `[MODIFY] src/lib/mock/menu.ts` (item "Configuração de IA").

### Segurança

| Risco | Mitigação |
|---|---|
| Vazar a key no GET | GET retorna só `{ has_key, provider, model, masked_key }` |
| Key em texto no DB | AES-256-GCM (`src/utils/crypto.ts`); segredo em `IA_CONFIG_ENCRYPTION_KEY` (env, nunca no repo) |
| Key em logs | Não logar headers `x-llm-*`; revisar `describeError` do ia-analyze |
| Endpoint interno aberto | `IA_ANALYZE_INTERNAL_TOKEN` segue obrigatório |
| Gasto de créditos em loop | Rate-limit por `enterprise_id` (opcional) |
| Perda da `IA_CONFIG_ENCRYPTION_KEY` | Rotacioná-la exige re-cadastro de todas as chaves (ficam indecifráveis) |

### Verificação

- **Unit:** roundtrip do `crypto.ts`; OpenRouter provider mockado (sucesso, JSON com texto ao redor, `finish_reason:'length'`, 401, 402, 429+`Retry-After`); repo `iaConfig` (upsert/get/delete por `enterprise_id`); regressão `LLM_PROVIDER=gemini` idêntica.
- **Manual:** cadastrar chave válida/ inválida na UI; rodar análise e confirmar consumo da chave do tenant no dashboard do OpenRouter; trocar modelo; deletar chave e verificar `ia_config_required` (com flag) ou fallback (sem flag).
- **TCC:** com o modelo configurável, usar `gateway/src/libs/eval/classifierEval.ts` + `scripts/eval-classifier.ts` para comparar Gemini vs. modelos OpenRouter (kappa + macro-F1) e escolher o default por evidência.

### Esforço estimado

| Camada | Esforço |
|---|---|
| 1 — Fábrica + OpenRouter + modelo (ia-analyze) | ~6–8h |
| 2 — Headers (ia-analyze + gateway) | ~2h |
| 3 — Crypto + tabela + endpoints (gateway) | ~5–6h |
| 4 — Injeção no fluxo + flag | ~2h |
| 5 — UI (web) | ~4–5h |
| 6 — Docs + testes | ~4h |
| **Total** | **~23–27h** |

## O que isso demonstra no TCC

- **Padrões de projeto:** **Strategy** (provedor de IA intercambiável) e **Adapter** (envolver a API do OpenRouter no contrato neutro do sistema), com um caso real de **porta/adaptador** já presente no código.
- **Inversão de dependência (princípio SOLID "D"):** o motor de análise depende de uma **abstração** (`IaApiClient`), não de uma implementação concreta — e esta etapa mostra o ganho prático disso ao plugar um segundo provedor sem tocar no motor.
- **Avaliação empírica de modelos de IA:** uso de **Cohen's kappa** e **macro-F1** sobre um gold set rotulado para comparar modelos objetivamente, transformando uma escolha de engenharia em **experimento mensurável** (capítulo de metodologia + resultados).

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [03 — Análise assíncrona](./03-analise-assincrona.md) — pré-requisito ideal: roda a análise fora do timeout antes de trocar o provedor.
- [05 — Feedback por áudio](./05-feedback-por-audio.md) — outro ponto que se beneficia de um provedor de IA configurável (transcrição/multimodal).
- [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md) — onde guardar segredos (chaves por empresa) com segurança.
