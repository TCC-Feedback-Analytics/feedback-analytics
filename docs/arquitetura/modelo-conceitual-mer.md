# Modelo Conceitual (MER)

> Modelo de Entidade e Relacionamento **conceitual** (notação de Chen): a visão de alto nível das entidades do domínio e de como elas se relacionam, antes do mapeamento para tabelas.
>
> Para o modelo **lógico** (tabelas, FKs e cardinalidades em crow's-foot) veja a [Modelagem de Dados (DER)](modelagem-de-dados.md); para o detalhe **físico** (colunas, tipos, RLS, índices, triggers e funções) veja a [Visão Geral do Banco de Dados](../referencia/banco-de-dados/visao-geral.md).

---

## Diagrama

> **Diagrama em atualização.** A imagem anterior saiu por estar desatualizada; enquanto a nova não chega, a tabela abaixo descreve os relacionamentos e as cardinalidades.

---

## Relacionamentos e Cardinalidades

| Entidade A | Card. | Entidade B | Descrição |
| --- | --- | --- | --- |
| `user` | 1 - 1 | `enterprise` | Cada usuário autenticado (Better Auth) possui exatamente uma empresa vinculada (`auth_user_id`), criada no cadastro ou na primeira entrada com o Google. |
| `user` | 1 - N | `session` | Um usuário pode ter várias sessões ativas (Better Auth). |
| `user` | 1 - N | `account` | Um usuário entra por um ou mais provedores (senha, Google). |
| `user` | 1 - N | `user_onboarding` | Um usuário conclui ou pula cada versão do guia do sistema. |
| `enterprise` | 1 - 0..1 | `collecting_data_enterprise` | Uma empresa tem no máximo um registro de dados estratégicos de contexto, criado quando ela preenche o contexto. |
| `enterprise` | 1 - 0..1 | `enterprise_ia_config` | Uma empresa possui opcionalmente configurações próprias de provedor e chave de IA (BYO-key). |
| `enterprise` | 1 - N | `ia_analysis_job` | Uma empresa enfileira múltiplas operações de análise e síntese assíncrona. |
| `enterprise` | 1 - N | `catalog_items` | Uma empresa cadastra múltiplos itens de catálogo (produtos, serviços, departamentos). |
| `enterprise` | 1 - N | `collection_points` | Uma empresa possui múltiplos pontos de coleta de feedback. |
| `enterprise` | 1 - N | `customer` | Uma empresa atende múltiplos clientes. |
| `enterprise` | 1 - N | `tracked_devices` | Uma empresa rastreia múltiplos dispositivos. |
| `enterprise` | 1 - N | `feedback` | Uma empresa recebe múltiplos feedbacks. |
| `enterprise` | 1 - N | `questions_of_feedbacks` | Uma empresa define múltiplas perguntas dinâmicas por escopo/contexto. |
| `enterprise` | 1 - N | `feedback_insights_report` | Uma empresa possui múltiplos relatórios de insights consolidados (um por escopo/item). |
| `enterprise` | 1 - N | `scope_diagnosis` | Uma empresa acumula o histórico de diagnósticos do escopo gerados pela IA. |
| `enterprise` | 1 - N | `feedback_comment_field` | Uma empresa configura o campo de comentário do formulário por escopo (sem registro = convite padrão). |
| `catalog_items` | 0..1 - N | `collection_points` | Um ponto de coleta pode estar vinculado a um item do catálogo (opcional). |
| `catalog_items` | 0..1 - N | `questions_of_feedbacks` | Uma pergunta pode ser contextualizada por um item do catálogo (null = escopo COMPANY). |
| `catalog_items` | 0..1 - N | `feedback_insights_report` | Um relatório pode ser contextualizado por um item do catálogo (null = escopo COMPANY). |
| `catalog_items` | 0..1 - N | `ia_analysis_job` | Um job assíncrono pode ser delimitado para processar um item de catálogo específico. |
| `catalog_items` | 0..1 - N | `scope_diagnosis` | Um diagnóstico pode ser de um item do catálogo (null = escopo COMPANY). |
| `catalog_items` | 0..1 - 0..1 | `feedback_comment_field` | Cada item do catálogo tem no máximo uma configuração própria do campo de comentário. |
| `collection_points` | 1 - N | `feedback` | Cada ponto de coleta recebe múltiplos feedbacks. |
| `tracked_devices` | 0..1 - N | `feedback` | Um feedback pode estar associado a um dispositivo rastreado (opcional). |
| `customer` | 0..1 - N | `tracked_devices` | Um dispositivo pode ser atribuído a um cliente (opcional). |
| `feedback` | 1 - 0..1 | `feedback_analysis` | Cada feedback gera no máximo uma análise semântica (relação 1:1, `feedback_id` único). |
| `feedback` | 1 - N | `feedback_question_answers` | Cada feedback armazena respostas para as perguntas dinâmicas do formulário. |
| `feedback` | 1 - N | `feedback_subquestion_answers` | Cada feedback armazena respostas para as subperguntas ativas. |
| `questions_of_feedbacks` | 1 - N | `feedback_question_subquestions` | Cada pergunta pode ter até 3 subperguntas de detalhamento. |
| `questions_of_feedbacks` | 1 - N | `feedback_question_answers` | Cada pergunta pode receber múltiplas respostas (uma por feedback). |
| `feedback_question_subquestions` | 1 - N | `feedback_subquestion_answers` | Cada subpergunta pode receber múltiplas respostas (uma por feedback). |
| `user` (via `blocked_by`) | 0..1 - N | `tracked_devices` | Um dispositivo pode ser marcado como bloqueado por um usuário (opcional). Hoje não há tela nem rota que faça isso: o bloqueio só é gravado direto no banco. |

> A entidade raiz de autorização é `enterprise`: os dados de negócio carregam `enterprise_id`, e o gateway filtra cada query por ele (o isolamento multi-tenant fica na aplicação; a RLS barra os papéis que não são o do app). As tabelas filhas (`feedback_question_subquestions`, `feedback_question_answers`, `feedback_subquestion_answers` e `feedback_analysis`) chegam à empresa pela entidade-pai. Algumas relações desta tabela são só lógicas, sem FK no banco (como `feedback` → `collection_points` e `tracked_devices` → `customer`); a [Modelagem de Dados (DER)](modelagem-de-dados.md) marca quais.
>
> Ficam fora da tabela, por não se relacionarem com outras entidades: `verification` (tokens do Better Auth), `auth_rate_limit` (limite de reenvio de e-mail) e `ia_rate_budget` (orçamento de chamadas à IA por empresa, guardado por chave de texto).

---

## Veja Também

- [Modelagem de Dados (DER)](modelagem-de-dados.md) — modelo lógico (crow's-foot) com os campos de cada entidade e as enumerações.
- [Visão Geral do Banco de Dados](../referencia/banco-de-dados/visao-geral.md) — referência física completa (colunas, RLS, índices, triggers, funções e a view `enterprise_public`).
