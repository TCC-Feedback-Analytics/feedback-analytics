# Testes de Usabilidade e Campo (UAT)

### Este documento descreve o plano de execução para os **Testes de Campo / Testes de Aceitação do Usuário (UAT)** do Feedback Analytics. Esses testes serão conduzidos em um cenário de uso real com usuários finais (Pequenas e Médias Empresas — PMEs e profissionais autônomos).
---
## 1. Informações Gerais
* **Objetivo:** Validar a usabilidade prática do sistema, a estabilidade da arquitetura técnica (API Gateway/BFF e Supabase) e a eficácia/assertividade da inteligência artificial (Gemini) em um ambiente real e cotidiano de operação.
* **Duração:** _[Data de Início]_ a _[Data de Término]_ (a definir).
* **Empresas Participantes:** _[Inserir nomes das empresas participantes]_ (a definir).
* **Responsáveis:** Cada membro da equipe é responsável direto pelo suporte técnico, monitoramento e comunicação constante com os gestores das empresas que trouxe para o projeto de teste.
---
## 2. Fase Pré-Teste
Ações que devem ser obrigatoriamente concluídas **antes** de disponibilizar o sistema para uso comercial das empresas parceiras:
* **Limpeza e Higienização de Dados:** Zerar completamente as tabelas de dados de operação (`feedback` e `feedback_analysis`) no Supabase no ambiente que será disponibilizado (homologação/produção) para garantir que métricas antigas ou testes de desenvolvimento não poluam os relatórios reais das empresas.
* **Auditoria de Variáveis de Ambiente:** Confirmar se as variáveis cruciais (como a chave da API do Gemini e credenciais de acesso ao Supabase) estão seguras, ativas e configuradas no servidor Express (API Gateway).
* **Termo de Consentimento (Aspectos Éticos):** Obter o aceite formal ou a assinatura dos gestores parceiros no Termo de Consentimento Livre e Esclarecido (TCLE) que regulamenta a participação no teste de usabilidade.
* **Kit de Coleta (SUS):** Garantir que o link do formulário (Google Forms) contendo o questionário estruturado da escala SUS (*System Usability Scale*) esteja pronto, revisado e operacional.
---
## 3. Fase de Execução (Monitoramento Diário)
Acompanhamento passivo e técnico para identificar anomalias sem interferir na experiência direta do cliente e do gestor:
* **Saúde do Banco de Dados (Diário):** Verificar ao final de cada dia no painel do Supabase se novas linhas de feedbacks estão sendo inseridas na tabela `feedback` com integridade relacional.
* **Monitoramento Anti-Spam (Diário):** Analisar a tabela `tracked_devices` para medir a eficiência do bloqueio por fingerprint de dispositivos. É importante registrar a quantidade de tentativas abusivas bloqueadas diariamente.
* **Auditoria das Análises de IA (A cada 2 dias):** Sempre que os gestores rodarem novas análises consolidadas de IA em lote, consultar a tabela `feedback_analysis` para assegurar que a API do Gemini gerou o JSON estruturado adequadamente (com chaves corretas de `Sentimento`, `Categorias` e `Palavras-chave`) e verificar se não houve retornos nulos ou erros de alucinação.
---
## 4. Fase de Encerramento (Coleta de Dados)
Ações consolidadas no último dia do período de testes em campo:
* **Suspensão da Coleta:** Desativar a recepção de novos feedbacks ou instruir as empresas parceiras a retirarem temporariamente os QR Codes do ponto de atendimento.
* **Extração de Dados Operacionais:** Exportar e realizar o backup das tabelas `feedback`, `feedback_analysis` e `tracked_devices` do Supabase para formato de planilha (.csv ou .xlsx) para posterior tabulação estatística.
* **Aplicação do Questionário SUS:** Disparar o link do questionário SUS (Google Forms) para os gestores que operaram o painel/dashboard.
* **Entrevistas Qualitativas Rápidas:** Agendar uma chamada de voz/vídeo de aproximadamente 10 minutos (ou enviar 3 perguntas abertas por meio de aplicativo de mensagem instantânea) para capturar a percepção subjetiva e qualitativa do gestor sobre o valor gerou o dashboard e o nível de concordância técnica com os insights gerados pela inteligência artificial.
