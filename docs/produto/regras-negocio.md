# Regras de Negócio

## API Gateway

### Autenticação e Isolamento de Dados

**Como funciona:** todo endpoint em `/protected/*` passa pelo middleware `requireAuth`, que valida a sessão do **Better Auth** a partir do cookie httpOnly, injeta `req.user` e resolve a empresa do usuário em `req.enterpriseId`.

**Regra de isolamento:** o `enterpriseId` resolvido a partir da sessão é usado em todas as queries. Nenhum endpoint retorna dados de outra empresa — o isolamento é garantido na **aplicação**, com filtro explícito por empresa nos repositórios. A **RLS (Row Level Security)** do Postgres está ligada em todas as tabelas, mas a policy deixa o papel do app (`feedback_app`, que só lê e escreve dados) ver todas as linhas; ela barra outros papéis do banco, não uma empresa da outra. Quem separa as empresas nos caminhos autenticados é o filtro da aplicação (veja [ORM × RLS](../arquitetura/orm-rls-decisao.md)).

> ⚠️ **Aviso:** Nunca passe `userId` ou `enterpriseId` como parâmetro de query string ou body em endpoints protegidos. O Gateway extrai o usuário e a empresa da sessão, não do payload da requisição.

---

### Proteção contra Enumeração de Usuários (RNE-014)

**Como funciona:** os fluxos públicos de autenticação retornam mensagens genéricas e padronizadas para tudo que envolva a existência de um **e-mail**, impedindo que atacantes descubram quais e-mails têm cadastro ativo.

| Fluxo | Endpoint | Comportamento |
|---|---|---|
| Login — credenciais inválidas | `POST /api/public/auth/login` | `401 invalid_credentials` com a mensagem "E-mail ou senha inválidos."; a Web mostra "E-mail ou senha incorretos." |
| Login — e-mail não confirmado | `POST /api/public/auth/login` | **Mesma** resposta `401 invalid_credentials`. O erro `EMAIL_NOT_VERIFIED` do Better Auth é remapeado por `mapLoginError` (`src/auth/errorMap.ts`) para não revelar que a conta existe porém está pendente. |
| Cadastro — e-mail já existente | `POST /api/public/auth/register` | `200 { ok: true, message: 'confirmation_required' }` — segue para a tela de sucesso sem indicar duplicidade. |
| Recuperação de senha | `POST /api/public/auth/forgot-password` | `200` com "Se este e-mail estiver cadastrado, você receberá as instruções em breve." — independente de o e-mail existir. |
| Recuperação de senha — link vencido ou já usado | `GET /api/public/auth/callback?type=recovery` | Com `error` ou sem token, o gateway redireciona para `/forgot-password?error=<código>` sem gravar o cookie `ba_reset`. A Web mostra "O link de redefinição expirou ou já foi usado. Peça um novo abaixo." Não revela se o e-mail existe. |

> **Escopo:** a regra cobre apenas o identificador **e-mail**. A validação de telefone no cadastro permanece explícita (`409 phone_taken`) por ser uma decisão de UX de cadastro fora do escopo desta regra. O documento (CPF/CNPJ) não é mais pedido no cadastro, então o antigo `409 document_taken` deixou de existir.

> **Recuperação com link vencido (correção de 16/11/2026, PR #108 do gateway e PR #150 da Web):** antes, o callback de recuperação com link vencido caía na tela "Conta verificada". Hoje `callback.controller.ts` manda o pedido de `type=recovery` com `error` (ou sem token) para `/forgot-password?error=<código>`, onde a pessoa pede um link novo; outro tipo com `error` vai para `/auth/link-expired`. Com o link válido, o token vai para o cookie httpOnly `ba_reset` (1 hora, restrito a `/api/protected/user/password`). Um token recusado em `PATCH /api/protected/user/password` responde `401 reset_password_invalid_token`.

> **Nota (frontend):** `formLogin.tsx` também não diferencia conta não confirmada — exibe a mesma mensagem genérica. Depois de um `401 invalid_credentials`, o diálogo "Problemas para entrar?" passa a mostrar um aviso neutro ("Se você acabou de se cadastrar e não recebeu o e-mail de confirmação, solicite um novo envio."), ao lado dos links "Redefinir senha" e "Reenviar e-mail de confirmação" (`/resend-confirmation`); fora do diálogo não há aviso, e nada revela se a conta existe. O reenvio também está disponível no pós-cadastro (`registerEmailPendingNotice.tsx`) e na página de link expirado (`/auth/link-expired`).

---

### Assinatura e Trial

#### Ciclo de Vida da Conta

Todo novo cadastro tem `subscription_status = 'TRIAL'` e `trial_ends_at = NOW() + 4 meses`, inicializados pelo Gateway em `enterpriseOnSignup.ts`, chamado pelo controller de cadastro logo após o Better Auth criar o usuário, ou na primeira entrada com o Google (substitui o antigo trigger `on_auth_user_created` do Supabase). Na mesma transação nascem as 3 perguntas padrão do escopo `COMPANY`. Com o contexto da empresa e a IA configurados, um job (`generate_company_questions`) troca essas perguntas padrão por 3 feitas para o negócio, desde que a empresa ainda esteja com as padrão.

| `subscription_status` | Significado |
|---|---|
| `TRIAL` | Conta em período de teste gratuito — acesso completo |
| `ACTIVE` | Assinatura paga ativa |
| `EXPIRED` | Período de trial encerrado sem conversão |
| `CANCELED` | Assinatura cancelada pelo gestor |

Hoje só `TRIAL` é gravado (no cadastro). Os outros valores existem no CHECK e nos rótulos da Web, mas nenhum código muda o status: não há passagem automática para `EXPIRED` nem bloqueio ao fim do trial (RNE-013).

O campo `trial_ends_at` é uma timestamp com fuso horário (`timestamptz`). O cálculo de dias restantes é feito no cliente para evitar chamadas extras.

#### Confirmação de E-mail

Após o cadastro, o Better Auth envia um e-mail com link de confirmação (`emailVerification.sendOnSignUp`). O link expira em **1 hora** (padrão do Better Auth). O login só é liberado depois da confirmação (`requireEmailVerification`).

Se o link estiver expirado ou inválido, o Better Auth redireciona para `/auth/success?error=<código>` (`TOKEN_EXPIRED`, `INVALID_TOKEN`, `USER_NOT_FOUND` ou `INVALID_USER`), e a página `AuthSuccess` encaminha o usuário para `/auth/link-expired` em vez de exibir a confirmação. Para pedir um novo link, essa página usa o endpoint `POST /api/public/auth/resend-confirmation`, que chama `sendVerificationEmail` do Better Auth. A resposta é sempre genérica (RNE-014) e o reenvio tem limites: 60 s entre envios para o mesmo e-mail, 20 pedidos por IP a cada 15 min e 5 por e-mail por hora, com as chaves em HMAC-SHA256 (`src/libs/resendRateLimit.ts`). Ao estourar o limite, responde `429 rate_limited` com o cabeçalho `Retry-After`. Se o controle de reenvio estiver indisponível, responde `503 service_unavailable`. O endpoint nativo `POST /api/auth/send-verification-email` também passa por esse controller.

#### Constraint de `account_type`

A coluna `account_type` aceitava só `'CPF'` ou `'CNPJ'` (constraint `enterprise_account_type_check`). A migration `0009` do gateway removeu essa coluna, a coluna `document` e as duas constraints: o sistema não pede nem guarda mais CPF/CNPJ, porque nada o usava (LGPD, necessidade).

---

### Orquestração de Análise IA

O Gateway é responsável por validar, filtrar e agrupar os dados antes de chamar o IA Analyze, e por persistir os resultados retornados. As regras internas do serviço (sentimentos, keywords, normalização) estão na seção [IA Analyze](#ia-analyze) abaixo.

Todo trabalho de IA é **assíncrono**: `POST /ia-analyze/analyze-raw` e `/regenerate-insights` só enfileiram um job e respondem `202`. Um worker processa a fila em passos (um lote por vez) e grava o progresso; a Web acompanha por `GET /ia-analyze/jobs/:id`. Erros de validação e da IA chegam no `errorCode` do job, não como resposta do POST. Os erros tratados como temporários (`failed_remote_ia_analyze_request`, `ia_provider_unavailable`, `ia_provider_rate_limited` e `ia_provider_error`) voltam para a fila com espera; os demais terminam o job como `failed`. Cada job tenta no máximo 3 vezes; a espera é `min(60, 5·2^falhas)` segundos. Com `IA_RPM_LIMIT`/`IA_RPD_LIMIT` definidos, o job fica em `waiting_budget` até a janela virar.

#### Requisitos para Executar

A análise só é executada se a empresa tiver dados de contexto preenchidos em `collecting_data_enterprise`. A função `hasRequiredEnterpriseInfoForAnalysis` valida isso antes de qualquer chamada ao IA Analyze.

**Campos exigidos (os três):**
- `company_objective`
- `analytics_goal`
- `business_summary`

**Se não atender:** o job falha com `collecting_data_required_for_analysis` (no diagnóstico do escopo, que valida no POST, a resposta é `422`).

A empresa também precisa da **própria chave de IA** (OpenRouter, em Configuração de IA). Sem ela, o job falha com `ia_config_required`.

> **Nota:** `main_products_or_services` **não** é verificado por essa função. O campo é preenchido separadamente via catálogo e não bloqueia a análise.

---

#### Deduplicação de Feedbacks

Só entram na análise os feedbacks **com comentário** (o comentário é opcional) e fora do "Testar o formulário" (canal `TEST`). A busca já pega só os que não têm linha em `feedback_analysis`, do mais antigo para o mais novo, e antes de enviar ao IA Analyze o Gateway confere de novo os `feedback_id` já presentes em `feedback_analysis`. Feedbacks já analisados são **removidos do batch** para evitar reprocessamento.

---

#### Limite por Execução

```
limit = options.limit > 0 ? Math.min(options.limit, 100) : sem limite
```

- **Padrão:** sem limite — entram todos os pendentes do escopo. A Web não envia `limit`
- **Máximo explícito:** 100 feedbacks por execução, quando o `limit` vem no pedido
- **Mínimo obrigatório:** `MIN_FEEDBACKS_FOR_RELEVANT_ANALYSIS = 10`, contado sobre os feedbacks com comentário do escopo (não só os pendentes)

Se o escopo tiver menos de 10: o job falha com `insufficient_feedbacks_for_analysis`. Sem nenhum pendente, o job conclui com zero, sem chamar a IA. Na regeneração, o mínimo é de 10 feedbacks já analisados no escopo.

---

#### Batching por Escopo

Os feedbacks são agrupados pela função `buildAnalysisBatches`:

- Um batch para escopo `COMPANY` (sem `catalog_item_id`)
- Um batch por par `(scope_type, catalog_item_id)` para itens de catálogo

Cada batch é enviado **separadamente** ao provedor LLM externo para manter o contexto coerente por escopo.

##### Sub-batching por Tamanho

Após agrupar por `(scope_type, catalog_item_id)`, `buildAnalysisBatches` chama `chunkBatchesBySize`, que **fatia cada lote** em sub-lotes de no máximo `IA_MAX_FEEDBACKS_PER_BATCH` feedbacks (**default 20**).

- **Por quê:** o modelo emite um objeto JSON por feedback, então lotes grandes estouram o teto de tokens de **saída** do modelo e truncam o JSON (→ `truncated_ai_response`). Sub-lotes menores mantêm a saída pequena e previsível.
- **Exemplo:** um escopo com 100 feedbacks vira 5 chamadas de 20 — cada sub-lote preserva o `scope_type`/`catalog_item_id` do lote original.

---

#### Janela por Escopo

A busca de feedbacks para análise (`analyze-raw`) e para regeneração de insights é **restrita ao escopo** via `resolveScopeCollectionPointIds`.

- O escopo pedido (`scope_type`/`catalog_item_id`) é resolvido para os `collection_point_id` correspondentes — `COMPANY` cobre os pontos com `catalog_item_id = null` — e a query filtra os feedbacks por esses ids (`fetchFeedbacksForAnalysis` e `fetchAlreadyAnalyzedFeedbacks`).
- Os pendentes vêm do mais antigo para o mais novo (`order created_at asc`), sem limite quando o pedido não traz `limit`.
- A regeneração lê todos os feedbacks já analisados do escopo (`all: true`).
- Escopo válido porém **sem nenhum ponto de coleta** → a busca retorna lista vazia (nada a analisar).

---

#### Persistência de Resultados

| O que persiste | Tabela | Operação |
|---|---|---|
| Análise por feedback | `feedback_analysis` | `INSERT … ON CONFLICT (feedback_id) DO NOTHING` (idempotente em retomadas) |
| Insights globais por escopo | `feedback_insights_report` | `UPSERT` (`onConflict: enterprise_id,scope_type,catalog_item_id`) |

O `UPSERT` de insights usa **exclusivamente** a unicidade composta `(enterprise_id, scope_type, catalog_item_id)`. Não há mais o fallback legado por `enterprise_id`-only (1 relatório por empresa), incompatível com relatórios por escopo.

`upsertFeedbackInsightsReports` retorna os **contextos efetivamente persistidos** (só os que tinham conteúdo relevante viraram linha salva). O POST de regeneração responde só `202 { jobId, status }`. Se algum relatório não for salvo, o job termina `failed` com `insights_not_generated`, o que evita o **"falso sucesso"**; a Web só considera o relatório gerado quando o job conclui.

#### Regeneração de insights em etapas

1. Com `analyze_pending: true`, o job analisa primeiro os pendentes do escopo.
2. Sem `force`, se cada lote já tem relatório mais novo que a última análise, o job conclui sem chamar a IA (cache). A tela manda `force` quando o resumo já está atualizado.
3. **"generating":** um lote por passo, com até `IA_MAX_FEEDBACKS_PER_BATCH` feedbacks; cada lote devolve insights parciais.
4. **"synthesizing":** uma síntese por relatório, em `/internal/ia-analyze/synthesize-insights`, junta os insights parciais.
5. Upsert dos relatórios. O total do job é N lotes + 1 síntese por relatório.

---

### Catálogo

#### Validação de Perguntas

```
20 ≤ comprimento da pergunta ≤ 150 caracteres
```

Vale para perguntas e subperguntas. A Web confere antes de enviar, e o Gateway rejeita o que vier fora do intervalo: nas perguntas da empresa, com `400 upsert_failed`; nas de um item do catálogo, com `400 invalid_payload` e o motivo em `reason` (`question_length_invalid` / `subquestion_length_invalid`).

#### Estrutura de Perguntas por Escopo

```
TOTAL_ITEM_QUESTIONS = 3
TOTAL_SUBQUESTIONS_PER_QUESTION = 3
```

- Não há mais exigência de "exatamente 3 perguntas ativas". Cada slot (`question_order`) é tratado individualmente:
    - **Empresa (`COMPANY`):** o gateway exige sempre os 3 slots com texto válido (senão `400 upsert_failed`). Pela Web são de 1 a 3 perguntas efetivas: os slots removidos vão com texto de placeholder e `is_active: false`.
    - **Item do catálogo (PRODUCT, SERVICE, DEPARTMENT):** 0 a 3 — os 3 slots vazios desativam todas as perguntas do item, e o formulário dele fica só com nota e comentário.
- Cada pergunta aceita no máximo **3 subperguntas**; as que passarem da 3ª são descartadas em silêncio (`slice(0, 3)`).
- No item do catálogo, **esvaziar um slot** (pergunta sem texto válido) faz **soft-delete**: a linha em `questions_of_feedbacks` é marcada `is_active = false` (e suas subperguntas em `feedback_question_subquestions` também), em vez de ser excluída. A linha e o **histórico de respostas** são preservados — a FK é `ON DELETE CASCADE`, então apagar perderia o histórico.
- O **editor lê apenas** perguntas/subperguntas com `is_active = true`; por isso um slot desativado volta vazio na interface, mas continua existindo no banco para fins de histórico.
- No item do catálogo, o payload chega sempre com 3 slots ordenados (`question_order`); um array que não tenha 3 itens resulta em `400 invalid_payload` (`questions_must_have_3_slots`).

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

Desativar uma flag **não exclui** os itens cadastrados, mas põe todos os itens `ACTIVE` daquele tipo em `INACTIVE`: os formulários deles param de aceitar respostas (`404 collection_point_not_found`) (RF-037, RNE-009).

Exceção: desativar `uses_company_products` (`false`) **zera automaticamente** o campo `main_products_or_services = null` no mesmo request, pois a lista de produtos deixa de ser relevante para o contexto de IA.

---

### Coleta pelo Formulário Público (QR Code, Link e NFC)

#### Fingerprint Anti-Spam

O fingerprint de dispositivo é gerado no backend como:

```
MD5(userAgent + "|" + clientIP)
```

O dia fica fora do hash: o mesmo navegador na mesma rede é o mesmo aparelho em qualquer dia. A tabela `tracked_devices` registra o aparelho e a busca é por `(enterprise_id, device_fingerprint)`, sem constraint de unicidade na tabela; o limite é conferido na tabela `feedback`, por `tracked_device_id` + `collection_point_id` desde a meia-noite de Brasília. Isso garante que o limite seja por **dia corrido** (não janela de 24 horas).

- Um dispositivo que enviou feedback para o mesmo ponto de coleta no mesmo dia recebe **`409 Conflict`** (`DEVICE_ALREADY_SUBMITTED`).
- Um registro de aparelho com `is_blocked = true` recebe **`403`** (`DEVICE_BLOCKED`), conferido antes do limite diário.
- Como o dia fica fora do hash, o mesmo aparelho é o mesmo registro em qualquer dia: o bloqueio e o `feedback_count` acumulam entre dias (ver [Anti-spam por fingerprint](anti-spam-fingerprint.md)).
- Empresa inexistente → **`404 enterprise_not_found`**.
- Sem ponto de coleta `ACTIVE` no escopo, ou com o item ou o tipo inativo → **`404 collection_point_not_found`**.

#### Canal e Campo de Comentário

- O envio leva o canal da marca `canal` da URL: `QR`, `LINK`, `NFC` ou `TEST` ("Testar o formulário"), gravado em `feedback.channel`. Valor ausente, desconhecido ou o antigo `QRCODE` grava `null`, sem recusar a resposta. Os feedbacks `TEST` ficam fora de todas as métricas, do mínimo de feedbacks e da análise da IA.
- O campo de comentário segue a configuração do escopo: `DEFAULT` (convite padrão), `CUSTOM` (pergunta própria, de 10 a 150 caracteres, guardada com o comentário em `feedback.comment_prompt`) ou `HIDDEN` (o texto que vier é descartado). O comentário aceita até 5000 caracteres.

#### Contagem Variável de Questões por Escopo

O backend retorna **exatamente as perguntas ativas configuradas para o escopo resolvido (0 a 3)** — **não há fallback para o escopo COMPANY**. Um item de catálogo (PRODUCT/SERVICE/DEPARTMENT) sem perguntas ativas resulta em um formulário só com nota + mensagem (`questions` vazio). Tanto `enterprise.controller.ts` (coleta pública) quanto `qrcode.controller.ts` documentam explicitamente "sem fallback para Geral".

#### Validação das Respostas

O payload de coleta deve incluir **um número de respostas igual ao número de perguntas ativas do escopo** (`answers[]`, 0 a 3) — sem duplicatas de `question_id` e sem `question_id` que não esteja no conjunto das perguntas ativas buscadas. Qualquer desvio resulta em `400 invalid_payload`.

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

Valores não reconhecidos produzem `answer_score = 0`. Um score 0 em qualquer resposta ou subresposta rejeita toda a submissão com `400 invalid_payload`.

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

O upsert usa **somente** a chave composta `(enterprise_id, scope_type, catalog_item_id)` (constraint `uq_feedback_insights_context` `UNIQUE NULLS NOT DISTINCT`, criada pela migration `0014`; antes, o índice da `0000` tratava o NULL como distinto e o escopo COMPANY gravava uma linha nova a cada geração). A unique legada `UNIQUE(enterprise_id)` — que limitava a 1 relatório por empresa — foi removida, pois é incompatível com relatórios por escopo.

---

### Troubleshooting — API Gateway

| Erro | Regra Violada | Como Resolver |
|---|---|---|
| `collecting_data_required_for_analysis` (no job; `422` no diagnóstico) | Empresa sem contexto de negócio | Preencha os três campos: objetivo, meta analítica e resumo |
| `insufficient_feedbacks_for_analysis` (no job; `422` no diagnóstico) | Menos de 10 feedbacks com comentário no escopo (na regeneração, menos de 10 já analisados; no diagnóstico, menos de 10 avaliações no período) | Colete mais feedbacks ou escolha outro escopo/período |
| `ia_config_required` (no job; `409` no diagnóstico) | Empresa sem chave e modelo de IA | Configure a chave OpenRouter em Configuração de IA |
| `400 invalid_payload` / `400 upsert_failed` no catálogo ou nas perguntas da empresa | Pergunta com texto inválido | Ajuste o texto para entre 20 e 150 caracteres |
| `409` na coleta pública | Dispositivo já enviou feedback para este ponto hoje | Aguarde até a meia-noite de Brasília ou use outro ponto de coleta |
| `403` na coleta pública | Registro do aparelho marcado com `is_blocked` | Só se resolve no banco, tirando a marca do registro |
| `404 collection_point_not_found` na coleta pública | Sem ponto de coleta ativo no escopo, ou item/tipo inativo | Ative a coleta do escopo, reative o item ou o tipo, ou compartilhe outro QR Code ou link |
| `insights_not_generated` (no job) | Nenhum relatório foi gerado ou salvo na regeneração | Gere de novo; se repetir, confira os logs do worker e do IA Analyze |
| `missing_ia_analyze_remote_url` (no job) | URL do IA Analyze remoto ausente em runtime serverless (modo `remote` ou `VERCEL=1`) | Defina `IA_ANALYZE_REMOTE_URL` (e `IA_ANALYZE_EXECUTION_MODE=remote`). Em serverless não há fallback para `localhost` — `resolvePrimaryBaseUrl` falha alto em vez de mascarar como conexão recusada |

> **Timeout da chamada remota:** `DEFAULT_REMOTE_TIMEOUT_MS` é **280s** (`280_000`), alinhado ao `maxDuration` de 300s do `vercel.json`. Análises de muitos feedbacks são fatiadas por sub-batching (ver [Sub-batching por Tamanho](#sub-batching-por-tamanho)) e o worker chama um lote por vez; ainda assim, se o IA Analyze não responder dentro da janela, o `AbortController` cancela o fetch e o lote falha com `failed_remote_ia_analyze_request`, que volta para a fila como erro temporário.

---

## IA Analyze

### Autenticação Interna

**O quê:** com `IA_ANALYZE_INTERNAL_TOKEN` configurado, toda requisição deve incluir `x-ia-analyze-token` com o valor exato dele.

**Por quê:** o serviço não tem autenticação de usuário. O token garante que apenas o API Gateway — e não agentes externos — pode acionar análises.

**Como é validado:** `utils/isInternalRequestAuthorized.ts` compara o header com a variável de ambiente. Se inválido, retorna `401 unauthorized_internal_request` imediatamente, antes de qualquer processamento. Sem a variável configurada, as rotas só aceitam a requisição fora da Vercel e fora de `NODE_ENV=production` (uso em desenvolvimento local); lá, todas as rotas de trabalho (analyze, synthesize-insights, diagnose-scope e generate-company-questions) respondem `503 internal_auth_not_configured`; as de health não passam pela checagem.

**Credencial do LLM:** o Gateway envia o provedor, a chave e o modelo da empresa nos headers internos `x-llm-*`; o serviço não guarda chave de nenhuma empresa.

---

### Processamento de Batches

#### Batches Vazios São Ignorados

Se um batch tiver `feedbacks = []` ou `feedbacks` não for um array, ele é **pulado silenciosamente**. O serviço não lança erro — apenas continua para o próximo batch.

#### Idempotência por Feedback ID

Os resultados são acumulados em um `Map<string, Analysis>`. Se o mesmo `feedback_id` aparecer em dois batches diferentes (situação anômala), apenas a última análise prevalece.

#### Sem Sucesso Parcial

Os lotes rodam com concorrência limitada (`IA_LLM_CONCURRENCY`, padrão 3). Se um lote falhar, o serviço para de agendar os próximos e responde `502` com o código do erro (`incomplete_ai_response` quando outros lotes já tinham concluído) — nunca devolve parte dos resultados.

---

### Validação de Sentimentos

Só três valores são aceitos:

```
'positive' | 'neutral' | 'negative'
```

A resposta de cada lote é validada **inteira** antes do processamento (`validations/iaBatchResponse.validation.ts`). O lote falha com `invalid_ai_response_schema` se algum item:
- não tiver `feedback_id` em string, de um feedback do lote, sem repetir
- tiver `sentiment` fora dos três valores válidos
- não trouxer `categories` e `keywords` como listas de texto
- tiver `sentiment_score` fora de [-1, 1], `confidence` fora de [0, 1] ou aspecto malformado

Também falha sem `global_insights` com resumo não vazio e lista de recomendações. Se faltar o resultado de algum feedback enviado, o erro é `incomplete_ai_response`. Resumo e recomendações fora do pt-BR ganham uma única nova tentativa com reforço de idioma; uma segunda resposta inválida falha com `invalid_ai_response_language`.

> 📝 **Nota:** antes, um item com sentimento inválido era descartado em silêncio e o resto do lote seguia. Hoje o lote inteiro é recusado; o filtro por item (`canProcessAnalyzedItem`) continua no processamento como segunda barreira.

---

### Extração de Keywords

#### Regras de Sanitização

Cada keyword sugerida pelo modelo passa por `sanitizeTermList`:

1. Deve ser uma string não-vazia após trim
2. Não pode estar no conjunto de **termos proibidos**
3. Deve estar **ancorada** na mensagem normalizada do feedback (`isGroundedInMessage`, ver [Normalização de Texto](#normalização-de-texto))
4. Não pode ser duplicata

**Limite:** máximo de **6 keywords**.

#### Fallback

Se nenhuma keyword passar na sanitização, `tokenizeRelevantWords` extrai palavras diretamente da mensagem (sem stop words e sem os rótulos de `STRUCTURED_ANSWER_LABELS`, mínimo **4 caracteres**). Retorna até **4 tokens**. Esse fallback não aplica os enunciados das perguntas.

---

### Extração de Categorias

#### Regras de Sanitização

Mesmas regras de keywords, com:

**Limite:** máximo de **4 categorias**.

#### Fallback

Se nenhuma categoria for válida, retorna as **2 primeiras keywords** como fallback.

Depois, as categorias (saneadas ou do fallback) são mapeadas para a **taxonomia fixa do escopo** (`canonicalizeCategories`): o termo que bate com um rótulo canônico ou um sinônimo vira o canônico; o que não bate fica como emergente (ver [Motor de IA](filtro-semantico-ia.md)).

---

### Termos Proibidos

`buildForbiddenTerms` constrói um `Set<string>` com termos que nunca devem aparecer no resultado:

- **`STRUCTURED_ANSWER_LABELS`** — rótulos genéricos de respostas estruturadas fixos no código: `pessimo`, `ruim`, `mediana`, `boa`, `otima`
- **Respostas das perguntas dinâmicas** (`dynamic_answers[].answer_value`) — os valores que o cliente selecionou nas perguntas do formulário
- **Enunciados das perguntas dinâmicas** (`dynamic_answers[].question_text_snapshot`) — o texto das próprias perguntas (filtro anti-poluição)
- **Respostas das subperguntas** (`dynamic_subanswers[].answer_value`)
- **Enunciados das subperguntas** (`dynamic_subanswers[].subquestion_text_snapshot`)

**Por quê:** evita que as respostas estruturadas do formulário (ex: "boa", "ótima") e os enunciados das próprias perguntas (ex: "Como foi o atendimento?") apareçam como keywords ou categorias — garantindo que o resultado reflita apenas a voz espontânea do cliente na mensagem livre.

> 📝 **Nota:** cada enunciado entra no conjunto **inteiro** (normalizado), e a comparação é por igualdade. Uma palavra solta do enunciado (como "atendimento") não é proibida: ela só passa se estiver ancorada na mensagem do cliente. O prompt também instrui o modelo a não copiar o texto das perguntas nem a pergunta própria do campo de comentário (`message_question`).

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

> 📝 **Nota:** `analyzedCount` reflete o total de feedbacks **enviados** no batch. Como a validação exige um resultado válido para cada feedback enviado, esse total coincide com as análises do lote.

> 📝 **Regeneração:** na regeneração de insights, os `globalInsights` de cada lote são parciais. O relatório final vem da síntese (`POST /internal/ia-analyze/synthesize-insights`, validada em `validations/insightsSynthesis.validation.ts`), que junta os insights parciais de todos os lotes do escopo.

---

### Tratamento de Erros do Provedor LLM

A falha do provedor sai como `IaAnalyzeServiceError` com um código, em geral com status `502` (sem provedor válido, a IA responde antes `409 ia_config_required`; sem a chave nos headers, `500 missing_openrouter_api_key` ou `missing_gemini_api_key`):

| Cenário | Código Retornado |
|---|---|
| Falha ao chamar o provedor (rede, timeout, credencial no Gemini), depois de esgotar as tentativas com backoff | `failed_ia_request` |
| Erro HTTP do provedor (cota, limite de requisições, indisponível) | `ia_provider_*` (ex.: `ia_provider_rate_limited`, `ia_provider_unavailable`, `ia_provider_error`) |
| O provedor recusou a chave (HTTP 401) | `ia_provider_auth_error` |
| A conta do provedor ficou sem créditos (HTTP 402 no OpenRouter) | `ia_provider_credits_exhausted` |
| Resposta do provedor sem o formato da API | `invalid_provider_response` |
| Resposta vazia | `empty_ai_response` |
| O modelo recusou responder (filtro de conteúdo ou recusa) | `ai_response_refused` |
| Resposta não parseável como JSON | `invalid_ai_response` |
| Saída cortada pelo limite de tokens, nos dois provedores | `truncated_ai_response` |
| Resposta fora da estrutura esperada | `invalid_ai_response_schema` |
| Faltou o resultado de algum feedback, ou um lote falhou depois de outros concluírem | `incomplete_ai_response` |
| Resumo ou recomendações fora do pt-BR depois da nova tentativa | `invalid_ai_response_language` |

O controller captura e retorna o status e o código ao API Gateway, que os grava no `errorCode` do job; a Web lê o job e mostra a mensagem.

---

### Troubleshooting — IA Analyze

| Sintoma | Regra Violada | Diagnóstico |
|---|---|---|
| `502 invalid_ai_response_schema` ou `incomplete_ai_response` | O modelo devolveu sentimento inválido, ids errados ou faltou feedback | Verifique se o prompt está retornando `positive`, `neutral` ou `negative` exatamente e um item por feedback; troque de modelo se for recorrente |
| Keywords e categorias sempre vazias | Termos não encontrados na mensagem | Verifique se `message` está sendo enviada corretamente no payload |
| `analyses` vazio com `200` | `batches` veio vazio ou só com lotes sem feedbacks | Confira o fatiamento de lotes no Gateway |
| `502 invalid_ai_response` frequente | Resposta do provedor LLM não parseável | Verifique `extractJsonFromText.ts`; pode ser mudança no formato de saída do modelo |
