# Escolha das Ferramentas de Teste: Vitest & Playwright

Este documento explica de forma simples e direta por que escolhemos o **Vitest** e o **Playwright** como as ferramentas oficiais de teste para o ecossistema do projeto **Feedback Analytics**.

---

## ⚡ Vitest (Testes Unitários e de Integração)

O **Vitest** é utilizado para testar a lógica isolada da aplicação (funções, hooks, utilitários, componentes React) e as rotas de API do backend, garantindo que cada pequena parte do código funcione corretamente por conta própria.

### Por que escolhemos o Vitest?

1. **Integração Nativa com o Vite:**
   Como nosso frontend utiliza o **Vite**, o Vitest utiliza a mesma configuração de compilação. Isso elimina a necessidade de configurar ferramentas adicionais (como Babel ou ts-jest) apenas para rodar os testes.
   
2. **Alta performance:**
   O Vitest é rápido porque aproveita o ecossistema do Vite e o carregamento sob demanda. A inicialização é veloz e ele reexecuta apenas os testes afetados pelas suas alterações (Watch Mode).

3. **Compatibilidade com Jest:**
   A sintaxe do Vitest (`describe`, `test`, `expect`, `vi`) é praticamente idêntica à do Jest. Isso significa que desenvolvedores com experiência prévia em Jest tendem a se adaptar rapidamente, com uma curva de aprendizado reduzida.

4. **Mesma Ferramenta no Frontend e Backend:**
   Utilizamos o Vitest tanto na aplicação web (`feedback-analytics-web`) quanto nos serviços backend (`feedback-analytics-api-gateway` e `feedback-analytics-ia-analyze`). Isso mantém o padrão de escrita e a execução de testes unificados em todos os serviços.

---

## 🎭 Playwright (Testes de Fim a Fim - E2E)

O **Playwright** é utilizado para realizar testes **End-to-End (E2E)** no frontend. Ele abre navegadores reais, simula interações reais de usuários (como cliques, preenchimento de formulários e navegação) e valida se os fluxos completos da aplicação (da tela até o banco de dados) funcionam sem erros.

### Por que escolhemos o Playwright?

1. **Multinavegador Nativo:**
   O Playwright suporta nativamente três grandes motores de renderização: **Chromium** (Chrome, Edge), **Firefox** e **WebKit** (Safari), o que permite ampliar a cobertura entre navegadores quando necessário. Atualmente, porém, o projeto está configurado (`feedback-analytics-web/playwright.config.ts`) para executar a suíte E2E apenas em **Chromium** (Desktop Chrome).

2. **Redução de Testes Intermitentes (Flaky Tests):**
   Um dos maiores problemas em testes E2E é a instabilidade (testes que passam uma hora e falham na outra por lentidão na rede). O Playwright resolve isso com **Auto-Waiting** (espera automática): ele aguarda os elementos estarem visíveis, clicáveis e estáveis antes de interagir com eles.

3. **Ferramentas de Desenvolvimento Incríveis (DX):**
   * **Codegen (Gerador de Código):** Permite gravar interações no navegador e gerar o código de teste automaticamente.
   * **UI Mode:** Uma interface gráfica interativa onde você pode ver o passo a passo da execução do teste, inspecionar o DOM, visualizar a linha do tempo e debugar facilmente.
   * **Trace Viewer:** Grava capturas de tela, chamadas de rede e logs de console durante a execução. Se um teste falhar no servidor de CI (integração contínua), podemos abrir o trace e ver exatamente o que aconteceu no segundo exato do erro.

4. **Gerenciamento Inteligente de Autenticação:**
   Em sistemas normais, os testes E2E precisam fazer login em cada teste, o que torna a execução lenta. Com o Playwright, criamos um fluxo de `setup` que faz o login uma única vez no início, salva o estado de autenticação (cookies e localStorage) e compartilha com todos os outros testes instantaneamente.

---

## 📌 Resumo Comparativo: Qual usar e quando?

| Cenário de Teste | Ferramenta Recomendada | Como Executar |
| :--- | :---: | :--- |
| Testar funções puras, cálculos de IA, validações de schemas (Zod). | **Vitest** | `npm run test` |
| Testar se um componente React renderiza corretamente isolado na tela. | **Vitest** | `npm run test` |
| Testar se as rotas da API Express respondem com os status HTTP corretos. | **Vitest** | `npm run test` |
| Testar o fluxo completo de cadastro, login ou geração de QR Codes no navegador. | **Playwright** | `npm run test:e2e` |
