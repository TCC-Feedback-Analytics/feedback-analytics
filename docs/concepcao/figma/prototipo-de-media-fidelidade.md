# Documentação de Design — Protótipo de Média Fidelidade

!!! note "Material de concepção (jun/2026)"
    Este documento registra o protótipo feito no Figma na fase de concepção e não foi atualizado com o produto. As telas, os campos e os fluxos descritos aqui não refletem necessariamente a interface atual (por exemplo, o CPF/CNPJ mostrado no Perfil não existe mais no sistema e o comentário do formulário é opcional). Nos protótipos a coleta é só por QR Code; hoje o produto também coleta por link e etiqueta NFC, pelo mesmo formulário. O que o sistema faz hoje está em [Requisitos e Funcionalidades](../requisitos-e-funcionalidades.md).

## Visão Geral

O protótipo de média fidelidade detalha os componentes estáticos, as tabelas de dados, a hierarquia tipográfica e os campos de formulário presentes em cada tela mapeada na arquitetura (baixa fidelidade). 

O foco desta etapa é validar o **conteúdo real**, a **disposição do grid** e a **estrutura de dados** de forma estática, sem focar nas interações complexas e animações (que pertencem à alta fidelidade).

---

## 1. Formulários e Coleta de Dados

### 1.1. Coleta de Feedbacks
Define a estrutura de dados que será preenchida pelo cliente final.

| Campo | Tipo | Obrigatório |
| :--- | :--- | :---: |
| Avaliação geral | Estrelas (1–5) — "Como você avalia sua experiência?" (Muito insatisfeito → Muito satisfeito) | Sim |
| Perguntas dinâmicas (3 por escopo) | Escala Péssimo / Ruim / Mediana / Boa / Ótima, cada pergunta com até 3 subperguntas opcionais na mesma escala | Sim |
| Comentário livre | Textarea | Sim |
| Informações pessoais | Nome, e-mail e gênero (opcionais) | Não |

### 1.2. Perfil do Usuário
Define quais informações da conta e da empresa são exibidas e quais permitem edição.

| Informação Exibida | Editável no sistema |
| :--- | :---: |
| Avatar / Foto de perfil | Sim |
| Nome completo | Sim |
| E-mail | Sim |
| Senha | Sim (campo separado) |
| Data de cadastro | Não |
| CPF/CNPJ | Não |

---

## 2. Componentes de Listagem e Gerenciamento

### 2.1. Gerenciamento de QR Code
Define o escopo de ações estáticas disponíveis para cada ponto de coleta (QR Code) criado pelo usuário.

| Ação Disponível | Descrição do escopo |
| :--- | :--- |
| **Habilitar** | Habilita o QR Code para receber feedbacks |
| **Desabilitar** | Desabilita o QR Code (feedbacks não são aceitos) |
| **Compartilhar** | Copia o link do QR Code via modal |
| **Copiar link** | Copia a URL do QR Code para a área de transferência |
| **Download** | Baixar o arquivo de imagem do QR Code para impressão |

### 2.2. Listagem de Feedbacks
Define os elementos visuais estáticos necessários para a triagem de milhares de avaliações.

* **Filtros Disponíveis:** * Estrelas (1 a 5)
  * Categoria (Múltipla escolha)
  * Pesquisa (Texto livre)
* **Componentes da Tela:** * Barra de Pesquisa
  * Painel de filtros (Sidebar ou Dropdown)
  * Paginação (Controles de carregamento progressivo)
  * Card de Feedback (Deve exibir estaticamente: sentimento, avaliação, categoria, comentário truncado, data e QR Code de origem)

---

## 3. Componentes Analíticos e Dashboards

### 3.1. Dashboard Central
Define a grade de cartões de métricas (KPIs) e os dados numéricos que devem ser renderizados na tela principal.

| Componente | Métrica / Informação Exibida |
| :--- | :--- |
| **Card — Total de Feedbacks** | Número total absoluto de feedbacks recebidos |
| **Card — Avaliação Média** | Nota média das avaliações (estrelas de 1.0 a 5.0) |
| **Card — Sentimentos** | Média da satisfação geral dos clientes |
| **Card — Feedbacks Positivos** | Volume de feedbacks com notas altas |
| **Card — Feedbacks Críticos** | Volume de feedbacks com notas baixas (Alerta) |
| **Estratégia de Coleta** | Informações da empresa utilizadas para melhorar a análise da IA |
| **Radar de satisfação** | Gráfico/Lista estática com a proporção de feedbacks (Positivo/Neutro/Negativo) |
| **Feedbacks Recentes** | Tabela resumida com os últimos 5 registros recebidos |

### 3.2. Visão Geral dos Feedbacks
Painel puramente analítico com dados agregados, desprovido da listagem individual.

* **Total de feedbacks:** Número em destaque tipográfico (H1).
* **Distribuição de sentimentos:** Representação percentual (Positivos, neutros e ruins).
* **Principais categorias:** Temáticas recorrentes definidas pelo usuário logado.

### 3.3. Relatório IA
Estrutura de leitura de insights gerados automaticamente, focada em escaneabilidade textual.

| Seção do Relatório | Descrição |
| :--- | :--- |
| **Resumo Executivo** | Parágrafo gerado pela IA sintetizando os principais pontos do período |
| **Sentimento geral** | O clima geral extraído (Pode ser: Positivo, Neutro ou Negativo) |
| **Visão geral** | Uma análise em tópicos resumindo os feedbacks coletados |
| **Sugestões de Ação** | Recomendações práticas e estruturadas em lista geradas pela IA |