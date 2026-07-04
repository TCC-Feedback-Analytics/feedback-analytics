# 01 — Camada de dados e ORM (Drizzle)

> **Em uma frase:** dar ao projeto uma "ponte" tipada entre o código e o banco de dados (um ORM chamado Drizzle), com histórico versionado de mudanças do banco — respondendo de frente à crítica da banca sobre conhecimento de banco de dados, sem abrir mão das proteções que o banco já tem.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 1–2 |
| **Esforço** | Médio |
| **Prioridade** | 🔴 Essencial |
| **Depende de** | Nada (é a fundação para a [Etapa 02 — Métricas por período](./02-metricas-por-periodo-e-comparacao.md)) |
| **Camadas afetadas** | Banco · Backend |

## Para qualquer leitor

Todo sistema precisa guardar informações em algum lugar: os feedbacks que os clientes deixam, o cadastro das empresas, as notas, as análises da IA. Esse "lugar" é o **banco de dados** — pense nele como um armário de arquivos extremamente organizado, com gavetas (as *tabelas*), fichas (as *linhas*) e regras de quem pode abrir cada gaveta. O nosso banco é o **PostgreSQL**, um dos bancos profissionais mais respeitados do mercado.

Durante a apresentação, surgiu uma crítica: *"usar Supabase não exercita conhecimento de banco de dados; migrem para um ORM"*. Um **ORM** (sigla em inglês para "Mapeamento Objeto-Relacional") é uma camada de software que **traduz comandos escritos em código de programação para a linguagem do banco** (o SQL). É como ter um intérprete: o programador "fala" na linguagem do app e o ORM "fala" com o banco por baixo dos panos. Isso ajuda na produtividade e reduz erros de digitação.

Aqui está o ponto importante, e ele precisa ser dito com honestidade à banca: **a crítica parte de um equívoco**. O Supabase é apenas uma hospedagem do PostgreSQL — quem programa o banco continua sendo a equipe. E o nosso banco **já usa recursos avançados**, escritos à mão, que vão muito além do que um ORM faria automaticamente: regras de segurança que garantem que cada empresa só enxergue os próprios dados (chamadas de *RLS*), funções internas que validam cadastros, gatilhos automáticos e índices para deixar as buscas rápidas. Curiosamente, **os ORMs mais "mágicos" (como o Prisma) escondem o SQL** — ou seja, mostrariam *menos* domínio de banco, não mais. O que temos hoje é mais profundo do que um ORM padrão entrega.

Então por que mexer? Porque há um ganho real e *demonstrável* em adotar um ORM do tipo certo. Vamos adotar o **Drizzle**, um ORM moderno que é "SQL-first" (ele não esconde o SQL, anda lado a lado com ele) e que traz duas coisas que valem ouro num TCC: **tipagem** (o código avisa o erro antes de rodar, como um corretor ortográfico para dados) e **migrations versionadas** — um histórico, passo a passo, de toda mudança feita na estrutura do banco, igual ao histórico de versões de um documento. Resultado: respondemos à banca *e* melhoramos o projeto de verdade, sem jogar fora o trabalho de banco que já existe.

## O que muda para quem usa o sistema

- **Para o gestor (dono da empresa que coleta feedback):** nada muda de imediato na tela — esta é uma melhoria "de bastidores". O benefício chega indireto: menos bugs de dados, mudanças futuras mais seguras, e a fundação pronta para as novas telas de métricas por período (Etapa 02).
- **Para o cliente que dá o feedback:** nenhum impacto visível. O formulário público continua igual.
- **Para a banca e o orientador:** passa a existir uma narrativa clara e checável de "como modelamos e evoluímos o banco", com diagrama, migrations e tipos — exatamente o que a crítica pedia.

## Como vai funcionar

**Antes (hoje):** o backend conversa com o banco principalmente pelo cliente do Supabase, e a estrutura do banco está versionada como arquivos SQL em `database/sql/` (tabelas, funções, gatilhos, políticas). Funciona, mas a "fonte da verdade" do esquema e o código que o consome vivem separados, sem tipagem ponta-a-ponta nem um sistema formal de migrations.

**Depois (com Drizzle):** descrevemos as tabelas uma vez, em um arquivo de *schema* do Drizzle. A partir dele ganhamos: (1) **tipos automáticos** — se uma coluna mudar de nome, o código que a usa acusa erro na hora; (2) **migrations versionadas** — cada alteração de estrutura vira um arquivo numerado, aplicável e reversível, com histórico; (3) **consultas tipadas** nos caminhos internos e autenticados do backend (por exemplo, as agregações de métricas da Etapa 02).

O que **não** muda: continua sendo o **mesmo PostgreSQL**, e as **regras de segurança do banco (RLS) permanecem ligadas** como uma segunda camada de proteção. O Drizzle entra nos caminhos *autenticados/internos* (onde o backend já sabe de qual empresa é a requisição); o fluxo público anônimo do QR Code segue protegido pelas políticas do banco como está hoje.

Há um detalhe técnico que vale explicar em linguagem simples, porque é uma decisão honesta de engenharia: **a tensão entre ORM e RLS**. Hoje, quando o usuário acessa logado, o próprio banco confere "essa linha é da empresa dele?" usando a identidade do usuário (`auth.uid()`). Um ORM normalmente se conecta ao banco com um **"usuário administrador" que ignora essas regras** (para poder fazer seu trabalho com performance). Ou seja: ao usar o Drizzle, a checagem de "cada empresa só vê o seu" precisa passar a ser **feita também no código** — toda consulta filtra explicitamente pelo `enterprise_id` da requisição. A RLS continua ligada como rede de segurança, mas a responsabilidade primária migra para a aplicação nesses caminhos. Reconhecer e tratar isso bem é, por si só, um ótimo ponto de discussão acadêmica.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

**Esquema atual (fonte de verdade hoje):** `database/sql/` — 14 arquivos de tabela em `tables/`, funções PL/pgSQL em `functions/public/`, gatilhos em `triggers/all_triggers.sql`, políticas em `policies/all_policies.sql`, a view `views/public.enterprise_public.sql`, e o catálogo legível em `database/sql/DESCRICOES.md`. Esses arquivos provam o nível do banco e devem ser citados na defesa.

**Riqueza já existente (use como evidência contra "Supabase não exercita banco"):**
- **RLS multi-tenant** em todas as tabelas. Ex.: em `tables/public.enterprise.sql`, a policy de `SELECT` usa `auth.uid() = auth_user_id`; em `tables/public.feedback.sql`, a policy `authenticated` usa `enterprise_id IN (SELECT id FROM enterprise WHERE auth_user_id = auth.uid())` e a policy `anon` de INSERT exige ponto `cp.type='QR_CODE'` e `status='ACTIVE'` + dispositivo não bloqueado.
- **Funções PL/pgSQL com `SECURITY DEFINER`** e tratamento de concorrência/erros: `functions/public/register_device_feedback__*.sql` usa `pg_advisory_xact_lock(...)`; `functions/public/create_enterprise_on_signup__*.sql` lança erros com `SQLSTATE` customizado (`RAISE EXCEPTION ... USING ERRCODE = '23505'`).
- **Índices avançados:** índice **PARCIAL** com `WHERE` (`idx_feedback_question_subquestions_active`), **UNIQUE com `NULLS NOT DISTINCT`** (`uq_feedback_insights_context` em `tables/public.feedback_insights_report.sql`, sobre `enterprise_id, scope_type, catalog_item_id`), UNIQUEs compostos (`uq_questions_company_order`, `uq_questions_item_order`).
- **View cruzando schemas:** `enterprise_public` resolve o nome da empresa a partir de `auth.users.raw_user_meta_data` para o fluxo anônimo do QR Code.

**Plano de adoção do Drizzle (incremental, não-destrutivo):**
1. Adicionar `drizzle-orm` + `drizzle-kit` e uma conexão Postgres (ex.: `postgres`/`pg`) no `feedback-analytics-api-gateway`, lendo a connection string do Postgres do Supabase.
2. **Introspecção:** rodar `drizzle-kit pull`/`introspect` sobre o banco existente para *gerar* o schema TypeScript a partir do que já existe — assim o `database/sql/` continua sendo a verdade e o Drizzle reflete fielmente as tabelas (`feedback`, `enterprise`, `feedback_analysis`, `catalog_items`, etc.).
3. Reconciliar o schema do Drizzle com os contratos TypeScript já existentes em `shared/interfaces/domain/feedback.domain.ts` (ex.: `Feedback`, `FeedbackStats`, `CollectionPoint`) — os tipos inferidos do Drizzle devem casar com esses contratos de domínio para não duplicar verdade.
4. Migrar **um caminho de leitura autenticado** primeiro (candidato natural: as agregações de stats que hoje somam em JavaScript — base da Etapa 02), repassando o `enterprise_id` da sessão como filtro explícito em toda query.
5. Estabelecer o fluxo de **migrations versionadas** (`drizzle-kit generate` → arquivos numerados em `drizzle/`), definindo a convenção: mudanças estruturais novas nascem como migration; o `database/sql/` permanece como dump/documentação de referência durante a transição.

**Decisão sobre RLS + Drizzle:** conectar com role que respeita RLS é possível propagando o JWT/claims, mas é frágil e lento via pool. Decisão recomendada: **Drizzle nos caminhos autenticados com filtro explícito por `enterprise_id` na aplicação**, mantendo a RLS ligada como defesa em profundidade. Documentar essa escolha (e o trade-off) é parte da entrega.

**O que NÃO faremos (e por quê):**
- **NÃO Prisma** — esconde o SQL e a modelagem real; demonstraria menos domínio de banco, justamente o oposto do que a banca pediu.
- **NÃO migração total** para o ORM de uma vez — o fluxo público anônimo (QR Code) é mais seguro sob RLS; migrá-lo traria risco sem ganho.
- **NÃO trocar Express por NestJS** — NestJS é framework de aplicação, não de banco; não melhora a demonstração de modelagem de dados e adicionaria reescrita sem valor para esta crítica.

## Riscos e decisões em aberto

- **RLS vs. ORM:** ao operar com role administrativa, perde-se a checagem automática do banco; um filtro de `enterprise_id` esquecido vira vazamento entre empresas. Mitigação: helper único de query que *sempre* injeta o `enterprise_id`, revisão de código e testes de isolamento.
- **Duas fontes de verdade na transição:** durante a migração coexistem `database/sql/` e o schema do Drizzle. Risco de divergência. Mitigação: introspecção a partir do banco real e CI que checa drift.
- **Escopo do TCC:** migrar tudo pode estourar o cronograma. Decisão: migrar caminhos de leitura autenticados (começando pelas métricas) e deixar o resto como trabalho futuro, declarado.
- **Em aberto:** adotar `drizzle-kit migrate` como mecanismo oficial de migration *ou* manter os dumps SQL como verdade e usar Drizzle só para consulta tipada? (Recomendação: migrations oficiais para mudanças novas.)

## Como vamos saber que deu certo

- [ ] Schema do Drizzle gerado por introspecção do banco real e versionado no repositório.
- [ ] Tipos inferidos do Drizzle conferem com `shared/interfaces/domain/feedback.domain.ts` (sem duplicar/divergir).
- [ ] Pelo menos um endpoint autenticado de leitura (agregação de stats) servido via Drizzle, com filtro explícito por `enterprise_id`.
- [ ] Pasta de **migrations versionadas** funcionando: gerar e aplicar uma migration de exemplo de ponta a ponta.
- [ ] **Teste de isolamento multi-tenant:** uma requisição da empresa A nunca retorna linha da empresa B pelo caminho via Drizzle (RLS continua ligada como rede).
- [ ] **Diagrama ER** do banco produzido e versionado (entregável de apresentação), com decisões de modelagem documentadas.
- [ ] Documento curto "ORM × RLS: nossa decisão" no repositório, explicando o trade-off.

## Etapas de entrega

1. **Inventário e diagrama (resposta à banca):** gerar o diagrama ER a partir de `database/sql/`, escrever 1 página de decisões de modelagem (RLS, funções, índices parciais/condicionais) — já entrega o material de defesa, mesmo antes de uma linha de código.
2. **Drizzle "read-only" tipado:** instalar Drizzle, introspectar o banco, reconciliar com os contratos de domínio. Sem trocar nenhum caminho ainda. Entrega: tipagem ponta-a-ponta disponível.
3. **Primeiro caminho migrado:** mover a agregação de stats (fundação da Etapa 02) para Drizzle com filtro explícito de `enterprise_id` + teste de isolamento.
4. **Migrations oficiais:** estabelecer `drizzle-kit generate`, aplicar uma migration de exemplo, documentar a convenção e o trade-off ORM × RLS.

## O que isso demonstra no TCC

- **Modelagem de dados relacional:** entidades, relacionamentos, chaves, integridade referencial (`ON DELETE CASCADE`), constraints de domínio (`CHECK`).
- **ORM e tipagem ponta-a-ponta:** uso consciente de um ORM SQL-first e seus limites.
- **Migrations e versionamento de esquema:** evolução controlada do banco, com histórico.
- **Isolamento multi-tenant e segurança:** RLS por `auth.uid()`, defesa em profundidade, e a discussão (rara em TCCs) do trade-off entre ORM e segurança no nível do banco.
- **Resposta argumentada à banca:** transformar uma crítica em um capítulo sobre decisões de arquitetura de dados.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [02 — Métricas por período e comparação](./02-metricas-por-periodo-e-comparacao.md) (esta etapa é a fundação dela)
- [00 — Estabilização](./00-estabilizacao.md)
- [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md) (RLS e isolamento de dados)
