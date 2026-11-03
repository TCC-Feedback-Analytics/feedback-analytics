# Descrições dos objetos SQL

> **Legado.** Estas descrições acompanham os dumps desta pasta, da época do Supabase Auth, e não são mais a fonte do schema. A fonte única é o [`drizzle/schema/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle/schema) do gateway, com as migrations em [`drizzle/`](https://github.com/TCC-Feedback-Analytics/feedback-analytics-api-gateway/tree/main/drizzle). Vários objetos abaixo já não existem — `auth.users` como tabela de usuários do sistema, as funções de cadastro, de JWT, de telefone e de CPF/CNPJ, os triggers de `auth.users` e todas as policies listadas no fim (hoje cada tabela tem só a policy `feedback_app_all`). A descrição atual está em [Banco de Dados — Visão Geral](../../docs/referencia/banco-de-dados/visao-geral.md) e no [README desta pasta](README.md).

## Tabelas
- `auth.users`: tabela base de usuários de autenticação (credenciais, metadados e estado de conta).
- `public.enterprise`: cadastro da empresa vinculada ao usuário autenticado (`auth_user_id`).
- `public.collecting_data_enterprise`: dados estratégicos da empresa para contexto de análise (objetivo, resumo, listas de produtos/serviços e flags de uso de produtos, serviços e áreas/departamentos).
- `public.catalog_items`: catálogo estruturado de produtos, serviços e áreas/departamentos da empresa (nome, descrição, tipo e status).
- `public.collection_points`: pontos de coleta de feedback (ex.: QR Code), com status e identificação.
- `public.customer`: cadastro de clientes finais associados à empresa.
- `public.tracked_devices`: rastreio de dispositivos por fingerprint, bloqueio e contagem de feedbacks.
- `public.feedback`: feedback bruto enviado pelo cliente (mensagem, nota, vínculo com ponto/dispositivo/empresa).
- `public.questions_of_feedbacks`: perguntas configuráveis por contexto de feedback (empresa/produto/serviço/departamento).
- `public.feedback_question_subquestions`: subperguntas configuráveis (até 3) para cada pergunta dinâmica principal.
- `public.feedback_question_answers`: respostas das perguntas dinâmicas vinculadas a cada feedback enviado.
- `public.feedback_subquestion_answers`: respostas das subperguntas dinâmicas vinculadas a cada feedback enviado.
- `public.feedback_analysis`: resultado analítico do feedback (sentimento, categorias e palavras-chave).
- `public.feedback_insights_report`: relatório consolidado de insights e recomendações por empresa.

## Views
- `public.enterprise_public`: view pública (apenas `id` e `name`) que resolve o nome de exibição da empresa a partir de `auth.users.raw_user_meta_data->>'full_name'` (a tabela `public.enterprise` não tem coluna `name`). Caminho crítico do formulário público de coleta (QR Code), lido sem login pelo papel `anon`.

## Funções (public)
- `can_device_send_feedback`: valida se um dispositivo ainda pode enviar feedback no limite diário.
- `clean_user_metadata_before_change`: higieniza metadados do usuário antes de update e normaliza telefone.
- `create_enterprise_on_signup`: cria empresa no signup, valida documento/telefone e limpa metadados sensíveis.
- `document_exists`: consulta rápida para verificar se documento de empresa já existe.
- `enterprise_public_documents_fn`: lista documentos públicos distintos das empresas.
- `enterprise_public_ids_fn`: lista IDs/documentos/tipo de conta para uso público controlado.
- `generate_device_fingerprint`: gera fingerprint diário do dispositivo com user-agent + IP.
- `jwt_custom_claims`: monta claims extras do JWT (role e `enterprise_id`).
- `phone_exists`: consulta rápida para verificar se telefone já existe em `auth.users`.
- `register_device_feedback`: upsert de dispositivo rastreado e incremento de contagem de feedback.
- `update_updated_at_column`: trigger function genérica para manter campo `updated_at`.

## Triggers
- `auth.users.on_auth_user_created`: ao criar usuário, dispara criação/configuração inicial da empresa.
- `auth.users.on_auth_user_metadata_before_update`: antes de atualizar usuário, limpa metadados.
- `public.*.set_updated_at` (collecting_data_enterprise, catalog_items, collection_points, customer, enterprise, feedback, feedback_analysis, tracked_devices): atualiza `updated_at` automaticamente em updates.
- `storage.buckets.enforce_bucket_name_length_trigger` (INSERT/UPDATE): valida tamanho de nome de bucket no módulo de storage.
- `storage.buckets.protect_buckets_delete`: bloqueia deleções indevidas em buckets protegidos.
- `storage.objects.protect_objects_delete`: bloqueia deleções indevidas em objetos protegidos.
- `storage.objects.update_objects_updated_at`: mantém `updated_at` de objetos de storage.

## Permissões (Policies / RLS)
### public.collecting_data_enterprise
- `Auth gerencia dados de coleta`: só usuários autenticados da própria empresa podem ler/escrever dados de coleta.

### public.feedback_question_subquestions
- `Auth gerencia subperguntas de feedback`: usuários autenticados gerenciam subperguntas da própria empresa.
- `Anon pode ler subperguntas ativas`: permite leitura pública das subperguntas ativas no fluxo de QR Code.

### public.feedback_subquestion_answers
- `Auth gerencia respostas de subperguntas`: usuários autenticados gerenciam respostas da própria empresa.
- `Anon pode inserir respostas de subperguntas`: permite inserção pública no envio de feedback via QR Code.

### public.catalog_items
- `Usuários autenticados podem gerenciar catálogo`: gestão completa do catálogo restrita à empresa dona.
- `Anon pode ler catálogo ativo`: acesso público apenas para itens ativos.

### public.collection_points
- `Anon pode ler pontos QR_CODE ativos`: acesso público somente para leitura de pontos QR ativos, e quando houver item associado ele também deve estar ativo.
- `Usuários autenticados podem gerenciar pontos de coleta`: gestão completa apenas pela empresa dona.

### public.customer
- `Usuários autenticados podem gerenciar clientes`: gestão completa de clientes restrita à empresa dona.

### public.enterprise
- `Usuários autenticados podem criar sua empresa`: permite inserir empresa apenas com `auth_user_id` igual ao usuário logado.
- `Usuários autenticados veem apenas sua empresa`: leitura limitada à própria empresa.
- `Usuários podem atualizar sua própria empresa`: update limitado ao próprio registro de empresa.

### public.feedback
- `Anon pode inserir feedback via QR_CODE com checks`: permite feedback anônimo só com validações de ponto ativo e dispositivo válido/não bloqueado.
- `Usuários autenticados podem gerenciar feedbacks`: gestão completa de feedbacks restrita à empresa dona.

### public.feedback_analysis
- `Empresas gerenciam apenas suas próprias análises`: acesso às análises somente quando o feedback pertence à empresa logada.

### public.feedback_insights_report
- `feedback_insights_report_insert`: inserção de relatório apenas para a própria empresa.
- `feedback_insights_report_select`: leitura de relatório apenas da própria empresa.
- `feedback_insights_report_update`: atualização de relatório apenas da própria empresa.

### public.tracked_devices
- `Anon pode atualizar contagem do proprio device`: anônimo pode atualizar contagem apenas em device válido e não bloqueado.
- `Permitir criação anônima de dispositivo`: permite criar registro de device anônimo com dados mínimos obrigatórios.
- `Permitir verificação anônima de dispositivo`: permite consulta anônima de existência/estado do device.
- `Usuários autenticados podem gerenciar dispositivos`: gestão completa de dispositivos restrita à empresa dona.
