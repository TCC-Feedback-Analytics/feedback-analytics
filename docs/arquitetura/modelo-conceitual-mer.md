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
| `user` | 1 - 1 | `enterprise` | Cada usuário autenticado (Better Auth) possui exatamente uma empresa vinculada (`auth_user_id`), criada no cadastro. |
| `enterprise` | 1 - 1 | `collecting_data_enterprise` | Uma empresa tem exatamente um registro de dados estratégicos de contexto. |
| `enterprise` | 1 - 0..1 | `enterprise_ia_config` | Uma empresa possui opcionalmente configurações próprias de provedor e chave de IA (BYO-key). |
| `enterprise` | 1 - N | `ia_analysis_job` | Uma empresa enfileira múltiplas operações de análise e síntese assíncrona. |
| `enterprise` | 1 - N | `catalog_items` | Uma empresa cadastra múltiplos itens de catálogo (produtos, serviços, departamentos). |
| `enterprise` | 1 - N | `collection_points` | Uma empresa possui múltiplos pontos de coleta de feedback. |
| `enterprise` | 1 - N | `customer` | Uma empresa atende múltiplos clientes. |
| `enterprise` | 1 - N | `tracked_devices` | Uma empresa rastreia múltiplos dispositivos. |
| `enterprise` | 1 - N | `feedback` | Uma empresa recebe múltiplos feedbacks. |
| `enterprise` | 1 - N | `questions_of_feedbacks` | Uma empresa define múltiplas perguntas dinâmicas por escopo/contexto. |
| `enterprise` | 1 - N | `feedback_insights_report` | Uma empresa possui múltiplos relatórios de insights consolidados (um por escopo/item). |
| `catalog_items` | 0..1 - N | `collection_points` | Um ponto de coleta pode estar vinculado a um item do catálogo (opcional). |
| `catalog_items` | 0..1 - N | `questions_of_feedbacks` | Uma pergunta pode ser contextualizada por um item do catálogo (null = escopo COMPANY). |
| `catalog_items` | 0..1 - N | `feedback_insights_report` | Um relatório pode ser contextualizado por um item do catálogo (null = escopo COMPANY). |
| `catalog_items` | 0..1 - N | `ia_analysis_job` | Um job assíncrono pode ser delimitado para processar um item de catálogo específico. |
| `collection_points` | 1 - N | `feedback` | Cada ponto de coleta recebe múltiplos feedbacks. |
| `tracked_devices` | 0..1 - N | `feedback` | Um feedback pode estar associado a um dispositivo rastreado (opcional). |
| `customer` | 0..1 - N | `tracked_devices` | Um dispositivo pode ser atribuído a um cliente (opcional). |
| `feedback` | 1 - 0..1 | `feedback_analysis` | Cada feedback gera no máximo uma análise semântica (relação 1:1, `feedback_id` único). |
| `feedback` | 1 - N | `feedback_question_answers` | Cada feedback armazena respostas para as perguntas dinâmicas do formulário. |
| `feedback` | 1 - N | `feedback_subquestion_answers` | Cada feedback armazena respostas para as subperguntas ativas. |
| `questions_of_feedbacks` | 1 - N | `feedback_question_subquestions` | Cada pergunta pode ter até 3 subperguntas de detalhamento. |
| `questions_of_feedbacks` | 1 - N | `feedback_question_answers` | Cada pergunta pode receber múltiplas respostas (uma por feedback). |
| `feedback_question_subquestions` | 1 - N | `feedback_subquestion_answers` | Cada subpergunta pode receber múltiplas respostas (uma por feedback). |
| `user` (via `blocked_by`) | 0..1 - N | `tracked_devices` | Um dispositivo pode ser bloqueado manualmente por um usuário gestor (opcional). |

> A entidade raiz de autorização é `enterprise`: quase todas as tabelas carregam `enterprise_id` para o isolamento multi-tenant (RLS). As exceções (`feedback_question_subquestions`, `feedback_question_answers`, `feedback_subquestion_answers` e `feedback_analysis`) herdam o isolamento por cascata da entidade-pai.

---

## Veja Também

- [Modelagem de Dados (DER)](modelagem-de-dados.md) — modelo lógico (crow's-foot) com os campos de cada entidade e as enumerações.
- [Visão Geral do Banco de Dados](../referencia/banco-de-dados/visao-geral.md) — referência física completa (colunas, RLS, índices, triggers, funções e a view `enterprise_public`).
