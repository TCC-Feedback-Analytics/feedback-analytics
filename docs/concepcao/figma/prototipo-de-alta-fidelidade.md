# Design de Alta Fidelidade — Feedback Analytics

!!! note "Material de concepção (jun/2026)"
    Este documento registra o protótipo feito no Figma na fase de concepção e não foi atualizado com o produto. As telas, as rotas e os campos descritos aqui não refletem necessariamente a interface atual (por exemplo, o CPF/CNPJ mostrado no Perfil não existe mais no sistema). Nos protótipos a coleta é só por QR Code; hoje o produto também coleta por link e etiqueta NFC, pelo mesmo formulário. O que o sistema faz hoje está em [Requisitos e Funcionalidades](../requisitos-e-funcionalidades.md).

## Visão Geral

Este documento descreve o protótipo de alta fidelidade do **Feedback Analytics**, cobrindo todas as telas do sistema, fluxos de navegação, estados de UI e comportamentos esperados para guiar a implementação front-end.

O protótipo contempla transições animadas entre telas, simulando ao máximo o produto final. As seções estão organizadas por contexto de autenticação: **Usuário Deslogado**, **Usuário Logado** e **Assets de Componentes**.

---

## Usuário Deslogado

São telas acessadas pelos usuários da aplicação sem autenticação válida, seja acessados por links ou leituras de qrcode.

---

### 1. Home

**Rota:** `/`  
**Objetivo:** Primeira impressão do produto. Tela de apresentação comercial, atrativa e orientada à conversão.

#### Seções da Página

| Seção | Descrição |
|---|---|
| Hero | Título principal, subtítulo de valor, CTA primário |
| Como funciona | Explicação visual em etapas do fluxo do produto |
| Benefícios | Cards destacando os diferenciais da plataforma |
| CTA Final | Chamada para cadastro/conversão ao final da página |
| Footer | Links institucionais, contato e redes sociais |

#### Comportamentos

- Botões de CTA redirecionam para `/login`

---

### 2. Login / Cadastro

**Rota:** `/login`  
**Objetivo:** Autenticação segura do usuário.

#### Estados da Tela

| Estado | Campos |
|---|---|
| Login | E-mail, Senha, Botão "Login", Link "Esqueceu a senha?"|

#### Comportamentos
- Alternância entre Login e Cadastro sem navegação de página (toggle/tab)
- Validação de campos em tempo real (inline errors)
- Loading state no botão de submit durante a requisição
- Redirecionamento para `/user/dashboard` após autenticação bem-sucedida
- Exibição de mensagem de erro em caso de credenciais inválidas

---

### 3. Coleta de Feedbacks

**Rota:** `/feedback/qrcode?enterprise=:id`  
**Objetivo:** Página pública onde o cliente final deposita seu feedback após escanear o QR Code.

> Esta rota é **pública**, mas só deve ser acessada via QR Code gerado por um usuário logado. Acessos diretos sem um `id` válido devem retornar erro ou página de QR Code inválido.

#### Campos do Formulário

| Campo | Tipo | Obrigatório |
|---|---|---|
| Avaliação geral | Estrelas (1–5) — "Como você avalia sua experiência?" (Muito insatisfeito → Muito satisfeito) | Sim |
| Perguntas dinâmicas (3 por escopo) | Escala Péssimo / Ruim / Mediana / Boa / Ótima, cada pergunta com até 3 subperguntas opcionais na mesma escala | Sim |
| Comentário livre | Textarea | Sim |
| Informações pessoais | Nome, e-mail e gênero (opcionais) | Não |

#### Comportamentos
- Não requer autenticação

---

## Usuário Logado

Telas acessíveis apenas com autenticação. Usuários não autenticados devem ser redirecionados para `/login`.

---

### 4. Dashboard

**Rota:** `/user/dashboard`  
**Objetivo:** Visão centralizada dos feedbacks coletados, com cards interativos e dados atualizados a cada carregamento.

#### Componentes da Tela

| Componente | Descrição |
|---|---|
| Header | Nome do usuário, e botões que facilitam o fluxo do usuário |
| Card — Total de Feedbacks | Número total de feedbacks recebidos |
| Card — Sentimentos | Média da satisfação geral dos clientes |
| Card — Feedbacks Positivos | Feedbacks positivos recebidos |
| Card — Feedbacks Críticos | Feedbacks negativos recebidos |
| Card — Avaliação Média | Nota média das avaliações (estrelas) |
| Feedbacks Recentes | Lista com os últimos feedbacks recebidos |
| Estratégia de Coleta |  Informações da empresa para melhorar a análise feita pela IA|
| Radar de satisfação | Lista com o total de feedbacks positivos, neutros ou negativos |


#### Comportamentos

- Cards clicáveis que redirecionam para as seções correspondentes

---

### 5. Perfil do Usuário

**Rota:** `/user/profile`  
**Objetivo:** Visualização e edição das informações pessoais do usuário.

#### Informações Exibidas

| Campo | Editável |
|---|---|
| Avatar / Foto de perfil | Sim |
| Nome completo | Sim |
| E-mail | Sim |
| Senha | Sim (campo separado) |
| Data de cadastro | Não |
| CPF/CNPJ | Não |

#### Comportamentos

- Transições e hovers de botões

---

### 6. QR Code

**Rota:** `/user/qrcode/enterprise`  
**Objetivo:** Gerenciamento dos QR Codes gerados pelo usuário para coleta de feedbacks.

#### Ações Disponíveis por QR Code

| Ação | Descrição |
|---|---|
| Habilitar | Habilita o QR Code para receber feedbacks |
| Desabilitar | Desabilita o QR Code (feedbacks não são aceitos) |
| Compartilhar | Copia o link do QR Code |
| Copiar link | Copia a URL do QR Code para a área de transferência |
| Download | Baixar o QR Code para a impressão |

#### Comportamentos

- Toggle de ativo/inativo com confirmação rápida

---

### 7. Feedbacks

**Rota:** `/user/feedbacks/all`  
**Objetivo:** Listagem completa de todos os feedbacks recebidos, com filtros e pesquisa.

#### Filtros Disponíveis

| Filtro | Opções |
|---|---|
| Estrelas | 1, 2, 3, 4 e 5 |
| Categoria | Múltipla escolha |
| Quantidade | Paginação de feedbacks |
| Pesquisa | Busca por texto livre no conteúdo dos feedbacks |

#### Componentes da Tela

| Componente | Descrição |
|---|---|
| Pesquisa | Busca por texto livre no conteúdo dos feedbacks |
| Painel de filtros | Sidebar ou dropdown com todos os filtros disponíveis |
| Card de Feedback | Sentimento, avaliação, categoria, comentário, data e QR Code de origem |
| Paginação | Carregamento progressivo dos itens |

---

### 8. Visão Geral dos Feedbacks

**Rota:** `/user/feedbacks/analytics/all`  
**Objetivo:** Painel analítico com dados agregados dos feedbacks, sem listagem individual.

> Esta visão tem três recortes implementados como telas próprias: todos (`/user/feedbacks/analytics/all`), positivos (`/user/feedbacks/analytics/positive`) e negativos (`/user/feedbacks/analytics/negative`).

#### Métricas Exibidas

| Métrica | Visualização |
|---|---|
| Total de feedbacks | Número grande em destaque |
| Distribuição de sentimentos | Positivos, neutros e ruins |
| Principais categorias | Categorias definidas pelo usuário logado |

---

### 9. Relatório IA

**Rota:** `/user/insights/reports` (abas: `/user/insights/reports`, `/user/insights/emotional`, `/user/insights/statistics`)  
**Objetivo:** Geração e visualização de insights automáticos baseados nos feedbacks, utilizando inteligência artificial.

#### Fluxo de Geração

1. Usuário acessa a tela
2. Caso não haja relatório gerado, exibe botão "Gerar Relatório"
3. Durante a geração, exibe loading
4. Relatório gerado é exibido com os insights

#### Conteúdo do Relatório

| Seção | Descrição |
|---|---|
| Resumo Executivo | Parágrafo gerado pela IA com os principais pontos |
| Sentimento geral | O clima pode ser positivo, neutro ou negativo |
| Visão geral | Uma visão geral resumida dos feedbacks coletados |
| Sugestões de Ação | Recomendações práticas geradas pela IA |

---

## Assets e Componentes

Componentes reutilizáveis disponíveis no Figma como base para implementação.

### Menu Principal

O menu lateral contém as animações e transições de navegação entre as seções do sistema.

| Item |
|---|
| Perfil |
| Feedbacks |
| QR Code |
| Visão Geral |
| Relatório IA |
| Perfil |

---
