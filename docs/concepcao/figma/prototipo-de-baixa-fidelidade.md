# Documentação de Design — Protótipo de Baixa Fidelidade

!!! note "Material de concepção (jun/2026)"
    Este documento registra o protótipo feito no Figma na fase de concepção e não foi atualizado com o produto. As telas, as rotas e os campos descritos aqui não refletem necessariamente a interface atual (por exemplo, o CPF/CNPJ mostrado no Perfil não existe mais no sistema). Nos protótipos a coleta é só por QR Code; hoje o produto também coleta por link e etiqueta NFC, pelo mesmo formulário. O que o sistema faz hoje está em [Requisitos e Funcionalidades](../requisitos-e-funcionalidades.md).

## Visão Geral

Este documento descreve o protótipo de baixa fidelidade do **Feedback Analytics**, focando na arquitetura de informação. Ele cobre as telas do sistema, fluxos de navegação básicos e os componentes estruturais esperados em cada interface para guiar a implementação front-end inicial.

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

---

### 2. Coleta de Feedbacks

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

---

## Usuário Logado

São telas acessadas pelos usuários da aplicação com autenticação válida, por autenticação via tela de login.

### 3. Dashboard

**Rota:** `/user/dashboard`  
**Objetivo:** Visão centralizada dos feedbacks coletados, com cards estruturais e espaço para os dados atualizados a cada carregamento.

#### Componentes da Tela

| Componente | Descrição |
|---|---|
| Header | Nome do usuário, e botões que facilitam o fluxo do usuário |
| Card — Total de Feedbacks | Número total de feedbacks recebidos |
| Card — Sentimentos | Média da satisfação geral dos clientes |
| Card — Feedbacks Positivos | Feedbacks positivos recebidos |
| Card — Feedbacks Críticos | Feedbacks negativos recebidos |
| Radar de satisfação | Lista com o total de feedbacks positivos, neutros ou negativos |

---

### 4. Perfil do Usuário

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

---

### 5. QR Code

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

---

### 6. Feedbacks (Listagem)

**Rota:** `/user/feedbacks/all`  
**Objetivo:** Visão de listagem dos feedbacks capturados para auditoria ou filtros manuais.

#### Componentes da Tela

| Componente |
|---|
| Pesquisa |
| Painel de filtros |
| Card de Feedback |
| Paginação |

---

### 7. Relatório IA

**Rota:** `/user/insights/reports`  
**Objetivo:** Geração e visualização de insights automáticos baseados nos feedbacks, utilizando inteligência artificial.

#### Conteúdo do Relatório

| Seção | Descrição |
|---|---|
| Resumo Executivo | Parágrafo gerado pela IA com os principais pontos |
| Sentimento geral | O clima pode ser positivo, neutro ou negativo |
| Visão geral | Uma visão geral resumida dos feedbacks coletados |
| Sugestões de Ação | Recomendações práticas geradas pela IA |
