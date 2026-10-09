# Regras de Negócio

## API Gateway

### Autenticação e Isolamento de Dados

**Como funciona:** todo endpoint em `/protected/*` passa pelo middleware `requireAuth`, que valida a sessão do **Better Auth** a partir do cookie httpOnly, injeta `req.user` e resolve a empresa do usuário em `req.enterpriseId`.

**Regra de isolamento:** o `enterpriseId` resolvido a partir da sessão é usado em todas as queries. Nenhum endpoint retorna dados de outra empresa — o isolamento é garantido na **aplicação**, com filtro explícito por empresa nos repositórios. A **RLS (Row Level Security)** do Postgres continua ligada como defesa em profundidade, mas a conexão do Drizzle usa uma role que a ignora; quem barra o acesso nos caminhos autenticados é o filtro da aplicação (veja [ORM × RLS](../arquitetura/orm-rls-decisao.md)).

> ⚠️ **Aviso:** Nunca passe `userId` ou `enterpriseId` como parâmetro de query string ou body em endpoints protegidos. O Gateway extrai o usuário e a empresa da sessão, não do payload da requisição.

---

### Proteção contra Enumeração de Usuários (RNE-014)

**Como funciona:** os fluxos públicos de autenticação retornam mensagens genéricas e padronizadas para tudo que envolva a existência de um **e-mail**, impedindo que atacantes descubram quais e-mails têm cadastro ativo.

| Fluxo | Endpoint | Comportamento |
|---|---|---|
| Login — credenciais inválidas | `POST /public/auth/login` | `401 invalid_credentials` — "E-mail ou senha incorretos." |
| Login — e-mail não confirmado | `POST /public/auth/login` | **Mesma** resposta `401 invalid_credentials`. O erro `EMAIL_NOT_VERIFIED` do Better Auth é remapeado por `mapLoginError` (`auth/errorMap.ts`) para não revelar que a conta existe porém está pendente. |
| Cadastro — e-mail já existente | `POST /public/auth/register` | `200 { ok: true, message: 'confirmation_required' }` — segue para a tela de sucesso sem indicar duplicidade. |
| Recuperação de senha | `POST /public/auth/forgot-password` | `200` com "Se este e-mail estiver cadastrado, você receberá as instruções em breve." — independente de o e-mail existir. |

> **Escopo:** a regra cobre apenas o identificador **e-mail**. As validações de telefone e documento no cadastro permanecem explícitas (`409 phone_taken` / `409 document_taken`) por serem decisões de UX de cadastro fora do escopo desta regra.

> **Nota (frontend):** `formLogin.tsx` também não diferencia conta não confirmada — exibe a mesma mensagem genérica. Depois de um `401 invalid_credentials`, mostra um aviso neutro ("se você acabou de se cadastrar e não recebeu o e-mail…") com link para `/resend-confirmation`, e o diálogo "Problemas para entrar?" oferece o mesmo caminho; nenhum dos dois revela se a conta existe. O reenvio também está disponível no pós-cadastro (`registerEmailPendingNotice.tsx`) e na página de link expirado (`/auth/link-expired`).

---

### Assinatura e Trial

#### Ciclo de Vida da Conta

Todo novo cadastro tem `subscription_status = 'TRIAL'` e `trial_ends_at = NOW() + 4 meses`, inicializados pelo Gateway em `enterpriseOnSignup.ts`, chamado pelo controller de cadastro logo após o Better Auth criar o usuário (substitui o antigo trigger `on_auth_user_created` do Supabase).

| `subscription_status` | Significado |
|---|---|
| `TRIAL` | Conta em período de teste gratuito — acesso completo |
| `ACTIVE` | Assinatura paga ativa |
| `EXPIRED` | Período de trial encerrado sem conversão |
| `CANCELED` | Assinatura cancelada pelo gestor |

O campo `trial_ends_at` é uma timestamp com fuso horário (`timestamptz`). O cálculo de dias restantes é feito no cliente para evitar chamadas extras.

#### Confirmação de E-mail

Após o cadastro, o Better Auth envia um e-mail com link de confirmação (`emailVerification.sendOnSignUp`). O link expira em **1 hora** (padrão do Better Auth). O login só é liberado depois da confirmação (`requireEmailVerification`).

Se o link estiver expirado ou inválido, o Better Auth redireciona para `/auth/success?error=<código>` (ex.: `TOKEN_EXPIRED`, `INVALID_TOKEN`), e a página `AuthSuccess` encaminha o usuário para `/auth/link-expired` em vez de exibir a confirmação. Para pedir um novo link, essa página usa o endpoint `POST /api/public/auth/resend-confirmation`, que chama `sendVerificationEmail` do Better Auth. A resposta é sempre genérica (RNE-014) e o reenvio é limitado por IP e por hash do e-mail, com intervalo mínimo entre envios; ao estourar o limite, responde `429 rate_limited` com o cabeçalho `Retry-After`.

#### Constraint de `account_type`

A coluna `account_type` só aceita os valores `'CPF'` ou `'CNPJ'` (constraint `enterprise_account_type_check`). Tentativas de inserir outro valor resultam em erro de violação de constraint no banco.

---

### Orquestração de Análise IA

O Gateway é responsável por validar, filtrar e agrupar os dados antes de chamar o IA Analyze, e por persistir os resultados retornados. As regras internas do serviço (sentimentos, keywords, normalização) estão na seção [IA Analyze](#ia-analyze) abaixo.

#### Requisitos para Executar

A análise só é executada se a empresa tiver dados de contexto preenchidos em `collecting_data_enterprise`. A função `hasRequiredEnterpriseInfoForAnalysis` valida isso antes de qualquer chamada ao IA Analyze.

**Campos considerados:**
- `company_objective`
- `analytics_goal`
- `business_summary`

**Se não atender:** erro `422 collecting_data_required_for_analysis`.

> **Nota:** `main_products_or_services` **não** é verificado por essa função. O campo é preenchido separadamente via catálogo e não bloqueia a análise.

---

#### Deduplicação de Feedbacks

Antes de enviar ao IA Analyze, o Gateway busca todos os `feedback_id` já presentes em `feedback_analysis`. Feedbacks já analisados são **removidos do batch** para evitar reprocessamento.

---

#### Limite por Execução

```
limit = Math.min(options.limit ?? 50, 100)
```

- **Padrão:** 50 feedbacks por execução
- **Máximo:** 100 feedbacks por execução
- **Mínimo obrigatório:** `MIN_FEEDBACKS_FOR_RELEVANT_ANALYSIS = 10`

Se após filtragem o total ficar abaixo de 10: erro `422 insufficient_feedbacks_for_analysis`.

---

#### Batching por Escopo

Os feedbacks são agrupados pela função `buildAnalysisBatches`:

- Um batch para escopo `COMPANY` (sem `catalog_item_id`)
- Um batch por par `(scope_type, catalog_item_id)` para itens de catálogo

Cada batch é enviado **separadamente** ao provedor LLM externo para manter o contexto coerente por escopo.

##### Sub-batching por Tamanho

Após agrupar por `(scope_type, catalog_item_id)`, `buildAnalysisBatches` chama `chunkBatchesBySize`, que **fatia cada lote** em sub-lotes de no máximo `IA_MAX_FEEDBACKS_PER_BATCH` feedbacks (**default 20**).

- **Por quê:** o modelo emite um objeto JSON por feedback, então lotes grandes estouram o teto de tokens de **saída** do modelo e truncam o JSON (→ erro de parse → `502`). Sub-lotes menores mantêm a saída pequena e previsível.
- **Exemplo:** um escopo com 100 feedbacks vira 5 chamadas de 20 — cada sub-lote preserva o `scope_type`/`catalog_item_id` do lote original.

---

#### Janela por Escopo

A busca de feedbacks para análise (`analyze-raw`) e para regeneração de insights é **restrita ao escopo** via `resolveScopeCollectionPointIds` **antes** de aplicar o `limit`.

- O escopo pedido (`scope_type`/`catalog_item_id`) é resolvido para os `collection_point_id` correspondentes — `COMPANY` cobre os pontos com `catalog_item_id = null` — e a query filtra os feedbacks por esses ids (`fetchFeedbacksForAnalysis` e `fetchAlreadyAnalyzedFeedbacks`).
- A janela das **N linhas mais recentes** (`order created_at desc` + `limit`) passa a valer **DENTRO do escopo**, e não nas linhas mais recentes da empresa inteira.
- **Por que importa:** corrige escopos específicos que ficavam sem análise/relatório por caírem fora das ~100 linhas mais recentes da empresa.
- Escopo válido porém **sem nenhum ponto de coleta** → a busca retorna lista vazia (nada a analisar).

---

#### Persistência de Resultados

| O que persiste | Tabela | Operação |
|---|---|---|
| Análise por feedback | `feedback_analysis` | `INSERT` |
| Insights globais por escopo | `feedback_insights_report` | `UPSERT` (`onConflict: enterprise_id,scope_type,catalog_item_id`) |

O `UPSERT` de insights usa **exclusivamente** a unicidade composta `(enterprise_id, scope_type, catalog_item_id)`. Não há mais o fallback legado por `enterprise_id`-only (1 relatório por empresa), incompatível com relatórios por escopo.

`upsertFeedbackInsightsReports` retorna os **contextos efetivamente persistidos** (só os que tinham conteúdo relevante viraram linha salva). A partir disso, a resposta de regeneração inclui **`reportGenerated: boolean`**:

- Com escopo pedido (`scope_type`/`catalog_item_id`): `true` só quando há um relatório salvo para **aquele** `scope_type` + item.
- Sem escopo: `true` quando ao menos um relatório foi persistido.

Isso permite ao frontend detectar o **"falso sucesso"** — quando a chamada retorna `200` mas nada relevante foi gerado/salvo para o escopo.

---

### Catálogo

#### Validação de Perguntas

```
20 ≤ comprimento da pergunta ≤ 150 caracteres
```

Perguntas fora desse intervalo são rejeitadas pela action `actionFeedbackSettings`.

#### Estrutura de Perguntas por Escopo

```
TOTAL_ITEM_QUESTIONS = 3
TOTAL_SUBQUESTIONS_PER_QUESTION = 3
```

- Cada escopo (COMPANY, PRODUCT, SERVICE, DEPARTMENT) aceita **1 a 3 perguntas efetivas** — não há mais exigência de "exatamente 3 perguntas ativas". Cada slot (`question_order`) é tratado individualmente; o gestor pode configurar 1, 2 ou 3.
- Cada pergunta aceita no máximo **3 subperguntas**.
- **Esvaziar um slot** (pergunta sem texto válido) faz **soft-delete**: a linha em `questions_of_feedbacks` é marcada `is_active = false` (e suas subperguntas em `feedback_question_subquestions` também), em vez de ser excluída. A linha e o **histórico de respostas** são preservados — a FK é `ON DELETE CASCADE`, então apagar perderia o histórico.
- O **editor lê apenas** perguntas/subperguntas com `is_active = true`; por isso um slot desativado volta vazio na interface, mas continua existindo no banco para fins de histórico.
- O payload de configuração ainda chega com 3 slots ordenados (`question_order`); enviar uma contagem de slots diferente de 3 resulta em `400 INVALID_PAYLOAD` (`ordered_questions_not_3`).

#### Itens de Catálogo

Itens são enviados como **JSON serializado** no campo do formulário (`FormData`). A action deserializa, valida a estrutura e repassa ao serviço.

#### Soft-Delete de Itens

Ao atualizar o catálogo via PATCH/UPSERT, itens que existem no banco mas **não estão presentes** na lista enviada são automaticamente definidos como `status = 'INACTIVE'` — não são excluídos. Isso preserva o histórico de feedbacks associados.

#### Flags de Tipo

| Flag | Tipo Habilitado |
|---|---|
| `uses_company_products` | Produtos |
| `uses_company_services` | Serviços |
| `uses_company_departments` | Departamentos |

Desativar uma flag **não exclui** os itens cadastrados — apenas oculta o tipo da interface.

Exceção: desativar `uses_company_products` (`false`) **zera automaticamente** o campo `main_products_or_services = null` no mesmo request, pois a lista de produtos deixa de ser relevante para o contexto de IA.

---

### Coleta via QR Code

#### Fingerprint Anti-Spam

O fingerprint de dispositivo é gerado no backend como:

```
MD5(userAgent + "|" + clientIP + "|" + dayEpoch)
```

Onde `dayEpoch` é o timestamp UNIX do início do dia corrente (`00:00:00`). Isso garante que o bloqueio seja por **dia corrido** (não janela de 24 horas). A tabela `tracked_devices` registra envios por `(device_fingerprint, collection_point_id)`.

Um dispositivo que enviou feedback para o mesmo ponto de coleta no mesmo dia recebe **`409 Conflict`**.

#### Contagem Variável de Questões por Escopo

O backend retorna **exatamente as perguntas ativas configuradas para o escopo resolvido (0 a 3)** — **não há fallback para o escopo COMPANY**. Um item de catálogo (PRODUCT/SERVICE/DEPARTMENT) sem perguntas ativas resulta em um formulário só com nota + mensagem (`questions` vazio). Tanto `enterprise.controller.ts` (coleta pública) quanto `qrcode.controller.ts` documentam explicitamente "sem fallback para Geral".

#### Validação das Respostas

O payload de coleta deve incluir **um número de respostas igual ao número de perguntas ativas do escopo** (`answers[]`, 0 a 3) — sem duplicatas de `question_id` e sem `question_id` que não esteja no conjunto das perguntas ativas buscadas. Qualquer desvio resulta em `400 INVALID_PAYLOAD`.

Da mesma forma, o campo `subanswers[]` deve conter **exatamente o mesmo número de subperguntas ativas** combinadas das perguntas ativas do escopo, sem duplicatas de `subquestion_id`. Nenhum subanswer a mais ou a menos é aceito.

#### Score de Respostas

Cada `answer_value` é mapeado para um `answer_score` numérico pelo backend:

| `answer_value` | `answer_score` |
|---|---|
| `PESSIMO` | 1 |
| `RUIM` | 2 |
| `MEDIANA` | 3 |
| `BOA` | 4 |
| `OTIMA` | 5 |

Valores não reconhecidos produzem `answer_score = 0`. Um score 0 em qualquer resposta ou subresposta rejeita toda a submissão com `400 INVALID_PAYLOAD`.

#### Perguntas Dinâmicas — Snapshot

O campo `question_text_snapshot` salva o texto da pergunta **no momento da coleta**. Isso preserva o histórico mesmo que a pergunta seja editada ou excluída depois.

```typescript
interface IaAnalyzeDynamicAnswer {
  question_id: string;
  question_text_snapshot: string;  // texto imutável no histórico
  answer_value: 'PESSIMO' | 'RUIM' | 'MEDIANA' | 'BOA' | 'OTIMA';
  answer_score: number;
}
```

---

### Escopo de Insights

A coluna `scope_type` em `feedback_insights_report` aceita:

```
'COMPANY' | 'PRODUCT' | 'SERVICE' | 'DEPARTMENT'
```

- `COMPANY` + `catalog_item_id = null` → insight geral da empresa
- Qualquer outro + `catalog_item_id` → insight por item específico

O upsert usa **somente** a chave composta `(enterprise_id, scope_type, catalog_item_id)` (índice único `uq_feedback_insights_context`, `NULLS NOT DISTINCT`). A unique legada `UNIQUE(enterprise_id)` — que limitava a 1 relatório por empresa — foi removida, pois é incompatível com relatórios por escopo.

---

### Troubleshooting — API Gateway

| Erro | Regra Violada | Como Resolver |
|---|---|---|
| `422 collecting_data_required_for_analysis` | Empresa sem contexto de negócio | Preencha ao menos um dos campos: objetivo, meta analítica ou resumo |
| `422 insufficient_feedbacks_for_analysis` | Menos de 10 feedbacks após filtragem | Colete mais feedbacks ou remova filtros de escopo/item |
| `422` no catálogo | Pergunta com texto inválido | Ajuste o texto para entre 20 e 150 caracteres |
| `409` na coleta pública | Dispositivo já enviou feedback para este ponto hoje | Aguarde até o próximo dia ou use outro ponto de coleta |
| `500 missing_ia_analyze_remote_url` | URL do IA Analyze remoto ausente em runtime serverless (modo `remote` ou `VERCEL=1`) | Defina `IA_ANALYZE_REMOTE_URL` (e `IA_ANALYZE_EXECUTION_MODE=remote`). Em serverless não há fallback para `localhost` — `resolvePrimaryBaseUrl` falha alto em vez de mascarar como `502` de conexão recusada |

> **Timeout da chamada remota:** `DEFAULT_REMOTE_TIMEOUT_MS` é **280s** (`280_000`), alinhado ao `maxDuration` de 300s do `vercel.json`. Análises de muitos feedbacks são fatiadas por sub-batching (ver [Sub-batching por Tamanho](#sub-batching-por-tamanho)); ainda assim, se o IA Analyze não responder dentro da janela, o `AbortController` cancela o fetch e a chamada falha com `502 failed_remote_ia_analyze_request`.

---

## IA Analyze

### Autenticação Interna

**O quê:** toda requisição deve incluir `x-ia-analyze-token` com o valor exato de `IA_ANALYZE_INTERNAL_TOKEN`.

**Por quê:** o serviço não tem autenticação de usuário. O token garante que apenas o API Gateway — e não agentes externos — pode acionar análises.

**Como é validado:** `utils/isInternalRequestAuthorized.ts` compara o header com a variável de ambiente. Se inválido, retorna `401` imediatamente, antes de qualquer processamento.

---

### Processamento de Batches

#### Batches Vazios São Ignorados

Se um batch tiver `feedbacks = []` ou `feedbacks` não for um array, ele é **pulado silenciosamente**. O serviço não lança erro — apenas continua para o próximo batch.

#### Idempotência por Feedback ID

Os resultados são acumulados em um `Map<string, Analysis>`. Se o mesmo `feedback_id` aparecer em dois batches diferentes (situação anômala), apenas a última análise prevalece.

---

### Validação de Sentimentos

Só três valores são aceitos:

```
'positive' | 'neutral' | 'negative'
```

Um item analisado pelo LLM é **descartado silenciosamente** se:
- `feedback_id` não for uma string
- `sentiment` não estiver nos três valores válidos
- `feedback_id` não existir no mapa de feedbacks do batch atual

> 📝 **Nota:** O descarte é silencioso por design — um sentimento inválido não deve interromper a análise dos demais feedbacks do batch.

---

### Extração de Keywords

#### Regras de Sanitização

Cada keyword sugerida pelo modelo passa por `sanitizeTermList`:

1. Deve ser uma string não-vazia após trim
2. Sua forma normalizada deve estar **contida** na mensagem normalizada do feedback
3. Não pode estar no conjunto de **termos proibidos**
4. Não pode ser duplicata

**Limite:** máximo de **6 keywords**.

#### Fallback

Se nenhuma keyword passar na sanitização, `tokenizeRelevantWords` extrai palavras diretamente da mensagem (sem stop words, mínimo **4 caracteres**). Retorna até **4 tokens**.

---

### Extração de Categorias

#### Regras de Sanitização

Mesmas regras de keywords, com:

**Limite:** máximo de **4 categorias**.

#### Fallback

Se nenhuma categoria for válida, retorna as **2 primeiras keywords** como fallback.

---

### Termos Proibidos

`buildForbiddenTerms` constrói um `Set<string>` com termos que nunca devem aparecer no resultado:

- **`STRUCTURED_ANSWER_LABELS`** — rótulos genéricos de respostas estruturadas fixos no código: `pessimo`, `ruim`, `mediana`, `boa`, `otima`
- **Respostas das perguntas dinâmicas** (`dynamic_answers[].answer_value`) — os valores que o cliente selecionou nas perguntas do formulário
- **Enunciados das perguntas dinâmicas** (`dynamic_answers[].question_text_snapshot`) — o texto das próprias perguntas (filtro anti-poluição)
- **Respostas das subperguntas** (`dynamic_subanswers[].answer_value`)
- **Enunciados das subperguntas** (`dynamic_subanswers[].subquestion_text_snapshot`)

**Por quê:** evita que as respostas estruturadas do formulário (ex: "boa", "ótima") e os enunciados das próprias perguntas (ex: "Como foi o atendimento?") apareçam como keywords ou categorias — garantindo que o resultado reflita apenas a voz espontânea do cliente na mensagem livre.

---

### Normalização de Texto

Antes de qualquer comparação, textos passam por `normalizeForComparison`:

1. Converte para minúsculas
2. Remove acentos (NFD + regex)
3. Remove pontuação e caracteres especiais
4. Colapsa espaços múltiplos

A comparação usa `isGroundedInMessage`, que opera em dois níveis:
1. Verifica se o termo normalizado está contido diretamente na mensagem normalizada (`includes()`)
2. Se não estiver, tokeniza tanto o termo quanto a mensagem e verifica se **pelo menos um token** do termo aparece na mensagem — tolerando categorias multipalavra parcialmente presentes no texto

Isso garante que termos como "tempo de espera" sejam aceitos mesmo que a mensagem diga "demorou muito", desde que "espera" ou outro token relevante esteja presente.

---

### Contexto de Batch (Global Insights)

`buildBatchContext` monta `IaAnalyzeContext` para cada batch:

```typescript
{
  scope_type: batch.scope_type,
  catalog_item_id: batch.catalog_item_id,
  catalog_item_name: batch.catalog_item_name,
  analyzedCount: batch.feedbacks.length,  // total de entrada, não de saída válida
  globalInsights: parsed.global_insights ?? null
}
```

> 📝 **Nota:** `analyzedCount` reflete o total de feedbacks **enviados** no batch — não o número de análises válidas retornadas. Um feedback com sentimento inválido é contado aqui, mas descartado no `analyses[]`.

---

### Tratamento de Erros do Provedor LLM

| Cenário | Tipo de Erro | Código Retornado |
|---|---|---|
| Falha HTTP (`IaApiClientError` com código `failed_ia_request`) | `IaAnalyzeServiceError` 502 | `failed_ia_request` |
| Qualquer outro erro (JSON inválido, timeout, etc.) | `IaAnalyzeServiceError` 502 | `invalid_ai_response` |

O controller captura e retorna o status e código ao API Gateway, que repassa ao frontend.

---

### Troubleshooting — IA Analyze

| Sintoma | Regra Violada | Diagnóstico |
|---|---|---|
| `analyses` retorna vazio para todos os feedbacks | Todos com sentimento inválido | Verifique se o prompt está retornando `positive`, `neutral` ou `negative` exatamente |
| Keywords e categorias sempre vazias | Termos não encontrados na mensagem | Verifique se `message` está sendo enviada corretamente no payload |
| `globalInsights` é sempre `null` | Provedor LLM não retornou insights | Pode ser batch muito pequeno; experimente com mais feedbacks |
| `502 invalid_ai_response` frequente | Resposta do provedor LLM não parseável | Verifique `extractJsonFromText.ts`; pode ser mudança no formato de saída do modelo |
