---
hide:
  - navigation
  - toc
---

<div class="hero" markdown>

# Feedback Analytics

A voz dos seus clientes ajudando a decidir — com apoio de IA. Colete por QR Code, link ou NFC, deixe a IA analisar e receba insights no painel, sem precisar de equipe de dados.

[Ver a arquitetura :material-arrow-right-thin:](arquitetura/visao-geral.md){ .md-button .md-button--primary }
[Ver no GitHub :material-github:](https://github.com/TCC-Feedback-Analytics/feedback-analytics){ .md-button }

</div>

O **Feedback Analytics** transforma a opinião dos seus clientes em decisões estratégicas — de forma automatizada e sem exigir equipe de dados. Muitas empresas, especialmente as de pequeno e médio porte, não têm um canal estruturado para ouvir o cliente: os feedbacks ficam espalhados entre várias plataformas (redes sociais, sites de avaliação, mensagens), e o gestor acaba decidindo por intuição, não por evidência. Nós resolvemos isso reunindo coleta, análise e decisão em um único fluxo: o cliente avalia pelo QR Code, por um link ou por uma etiqueta NFC, uma inteligência artificial lê os comentários e o gestor recebe um painel com métricas e recomendações prontas. Você deixa de adivinhar o que está dando errado e ganha mais clareza sobre onde agir.

## Como funciona

<div class="grid cards" markdown>

- :material-qrcode-scan: __1. Colete__

    ---

    A empresa ativa a coleta geral ou a de cada produto, serviço ou departamento, por QR Code, link ou etiqueta NFC, e escolhe o campo de comentário de cada escopo; o cliente avalia em menos de um minuto e vai embora, sem criar conta nem instalar app.

- :material-brain: __2. Analise__

    ---

    A IA, com a conta OpenRouter da própria empresa, roda em segundo plano: classifica o sentimento dos comentários, extrai temas, palavras-chave e aspectos, diagnostica o escopo e gera as perguntas do formulário.

- :material-chart-box: __3. Decida__

    ---

    O dashboard mostra as métricas por escopo e período, compara itens do catálogo e traz a análise dos comentários, com o tom, os assuntos que mais impactam e recomendações acionáveis para transformar a voz do cliente em ação.

</div>

## Para quem é

O Feedback Analytics é feito para quem atende o cliente **presencialmente** e quer ouvi-lo ali, no ponto de atendimento: **pequenas e médias empresas**, **profissionais autônomos** e o **pequeno comerciante** — restaurantes, salões, lojas de bairro e prestadores de serviço. A coleta acontece por QR Code ou etiqueta NFC no balcão, na mesa ou na recepção, ou por um link, logo após o atendimento, enquanto a experiência ainda está fresca. É para quem precisa de informação estruturada para decidir melhor, mas não tem orçamento para ferramentas complexas, nem equipe de dados, nem tempo de ler feedback por feedback.

## Estrutura do sistema

A plataforma é **serverless** (Vercel Functions + CDN) e distribuída em **repositórios independentes**, com um banco PostgreSQL (hospedado no Supabase) acessado só pelo API Gateway:

- **feedback-analytics-web** — frontend React: formulário público de coleta e dashboard protegido da empresa.
- **feedback-analytics-api-gateway** — API REST e ponto único de entrada: centraliza a autenticação (Better Auth, com sessão em cookie httpOnly), as regras de negócio, as métricas e o acesso ao banco (Drizzle), e põe todo trabalho de IA numa fila processada em segundo plano.
- **feedback-analytics-ia-analyze** — serviço isolado de IA, sem banco: chama o LLM da empresa (OpenRouter) para analisar comentários, diagnosticar o escopo e gerar as perguntas do formulário; só o Gateway o acessa.
- **feedback-analytics-contracts** — pacote `@feedback/lib-shared` com os tipos e contratos compartilhados entre os serviços.

[Ver como os serviços se conectam → Arquitetura](arquitetura/visao-geral.md)

## Explore a documentação

<div class="grid cards" markdown>

- :material-clipboard-list: __Requisitos & Casos de uso__

    ---

    O que o sistema faz — requisitos funcionais, regras de negócio e os fluxos de uso.

    [:octicons-arrow-right-24: Ver requisitos](concepcao/requisitos-e-funcionalidades.md)

- :material-chart-line: __Métricas e estatísticas__

    ---

    Quais métricas extraímos dos feedbacks e como lê-las com honestidade estatística.

    [:octicons-arrow-right-24: Ver métricas](produto/metricas-e-estatisticas.md)

- :material-lightbulb-on: __Análise dos comentários__

    ---

    Como a IA lê centenas de comentários e mostra o tom, os assuntos que mais impactam e um resumo com recomendações.

    [:octicons-arrow-right-24: Ver a análise](produto/painel-insights-ia.md)

- :material-qrcode-scan: __Coleta por QR Code, link e NFC__

    ---

    Os canais de coleta de baixo atrito que alimentam todo o sistema.

    [:octicons-arrow-right-24: Como funciona](produto/coleta-qrcode.md)

- :material-sitemap: __Arquitetura__

    ---

    Como os serviços se conectam: frontend, API Gateway e análise de IA.

    [:octicons-arrow-right-24: Ver arquitetura](arquitetura/visao-geral.md)

- :material-download: __Instalação__

    ---

    Suba o ambiente local e comece a rodar o projeto.

    [:octicons-arrow-right-24: Instalar](guias/guia-instalacao.md)

</div>

---

A documentação está organizada em **Produto**, **Concepção & Requisitos**, **Arquitetura**, **Segurança e LGPD**, **Referência Técnica** e **Guias**.
