# Documentação de Produto — Branding & Design Tokens

!!! note "Material de concepção (jun/2026)"
    Este documento registra as diretrizes de marca definidas no Figma na fase de concepção e não foi atualizado com o produto. A interface atual não segue necessariamente estes valores.

Esta seção detalha as diretrizes da marca **Feedback Analytics** e o sistema de Design Tokens que fundamenta toda a interface visual (UI) da plataforma. O uso consistente de tipografia, paleta de cores e aplicações de marca busca proporcionar uma experiência mais sólida, coesa e profissional para os usuários corporativos e finais.

---

## 1. Identidade Visual (Logo)

O logotipo do Feedback Analytics transmite confiança, inteligência de dados e fluidez na comunicação entre empresa e cliente.

### Variações e Aplicações
* **Logotipo Principal:** Deve ser utilizado prioritariamente sobre fundos claros ou brancos. Combina o ícone geométrico representativo com a tipografia da marca em tom escuro.
* **Logotipo Negativo (Branco):** Reservado para aplicações sobre fundos escuros, fotografias escurecidas ou fundos com a cor primária da marca.
* **Símbolo Isolado (Isotipo):** Utilizado em avatares, favicons, loading states e em contextos onde o espaço horizontal é restrito.

---

## 2. Paleta de Cores (Color Palette)

A paleta de cores do Feedback Analytics é dividida em três pilares: Cores da Marca (Brand), Cores Semânticas (Feedback visual) e Tons Neutros (Estrutura e tipografia).

### Cores Primárias (Brand Colors)
Utilizadas para guiar as ações do usuário (CTAs), links ativos e destaque de componentes importantes. Transmitem modernidade e foco analítico.
* **Primary / Brand Base:** A cor institucional central da aplicação.
* **Primary Hover / Focus:** Variação ligeiramente mais escura (Darken) para interações de mouse.
* **Primary Light:** Utilizada para fundos suaves ou micro-alertas relacionados à marca.

### Cores Semânticas (Feedback Emocional & Alertas)
Extremamente importantes em um produto de analytics, pois categorizam o tom dos feedbacks dos clientes (NPS / Sentimento).
* **Positivo / Sucesso (Verde):** Avaliações 4-5 estrelas, submissões com sucesso, badges de crescimento. *(Ex: Verde Esmeralda/Mint)*
* **Neutro / Aviso (Amarelo/Âmbar):** Avaliações 3 estrelas, alertas não destrutivos, espera. *(Ex: Âmbar/Laranja)*
* **Negativo / Erro (Vermelho):** Avaliações 1-2 estrelas, falhas de sistema, zonas de alerta gerencial crônico. *(Ex: Vermelho Coral/Rose)*
* **Informativo (Azul):** Tooltips, relatórios de IA e guias contextuais. *(Ex: Azul Sky)*

### Cores Neutras (Grayscale / Slate)
Base arquitetônica da interface corporativa. Proporcionam contraste e conforto visual em longas jornadas de uso do dashboard.
* **Surface / Background:** Fundo geral da aplicação e dos *cards* de métrica (Branco e off-white).
* **Bordas e Divisores:** Tons cinzas super claros (Gray 100/200).
* **Textos Secundários / Legendas:** Tons médios com menor contraste visual (Gray 400/500).
* **Textos Principais / Títulos:** Tons escuros para melhor legibilidade e conformidade de acessibilidade (Gray 800/900).

---

## 3. Tipografia (Typography)

A leitura de dados complexos requer uma tipografia limpa, geométrica e altamente legível em diversos tamanhos de tela.

### Família Tipográfica Primária
* **Nome da Fonte:** *Sans-serif* (Padrões sugeridos: Inter, Roboto, ou SF Pro para ecossistemas modernos).
* A fonte principal é aplicada em 100% do sistema, variando apenas em peso (Weight) e tamanho.

### Escala de Pesos (Font Weights)
* **Regular (400):** Textos corridos, depoimentos em feedbacks, descrições secundárias.
* **Medium (500):** Títulos de botões primários, subtítulos em *cards* gerenciais e tabs.
* **SemiBold (600) / Bold (700):** Cabeçalhos H1/H2, números de destaque em métricas e KPIs importantes, logotipos.

### Escala de Tamanhos Sugerida (Base 16px)
* **Heading 1 (H1):** Telas vazias, destaque de Relatórios IA.
* **Heading 2 (H2):** Títulos de seções no Dashboard.
* **Heading 3 (H3):** Títulos de painéis modais e popups.
* **Body Base:** Textos de leitura comum (14px a 16px).
* **Micro / Detail:** Badges, timestamps e contadores (12px).

---