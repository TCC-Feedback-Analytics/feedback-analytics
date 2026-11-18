# Plano de Teste Estratégico

!!! warning "Atualização (2026-08-08): E2E/integração agora são manuais; deploy main-only"
    A **automação E2E (Playwright)** do web, os testes de **integração dependentes de banco** do API Gateway e o gate `e2e-main.yml` foram **removidos** do CI; o **ambiente de homologação** foi descontinuado (o deploy é **main-only**, direto para produção). A execução ponta a ponta e os cenários dependentes de banco/ambiente passaram a ser **manuais**, nos runbooks **[Testes manuais — Web](./manuais-web.md)** e **[Testes manuais — API Gateway](./manuais-api-gateway.md)**.

    Este plano continua válido: a **Fase 1** (estratégia/riscos) é permanente e a **Fase 2** (CTs com passos e dados) virou o **roteiro da execução manual**. Onde o texto abaixo cita "Playwright", "homologação" ou "automação no CI", entenda como a execução **manual** descrita nos runbooks. No CI seguem apenas **unidade + integração mockada** (Vitest) e o **smoke de migrations** do API Gateway (`schema-migrations.yml`).

    Em 03/11/2026, a stack, os riscos e a massa de dados foram revistos contra o código (Better Auth no lugar do Supabase Auth, Mailpit e `npm run db:reset` no ambiente local). Em 16/11/2026, os selos dos CTs da Fase 2 passaram a seguir os casos de uso e o runbook da Web.

## Para que serve este documento?
### Está tabela serve para mostrar do por que o plano de teste estratégico é útil e como ele trabalha com os casos de uso.
Os casos de uso e o plano estratégico dividem responsabilidades sem repetir conteúdo, cada um tem um papel único.

- **Os casos de uso definem a regra:** Cada UC descreve o que o sistema precisa fazer: o fluxo, as exceções e os cenários a cobrir em linguagem de produto. É onde está a decisão de negócio — "o sistema nunca revela se um e-mail já existe", "dispositivo duplicado não gera erro mas exibe tela diferente".

- **O plano transforma a regra em execução:** A Fase 1 pega os UCs e responde: quais são críticos, em que ordem testar, o que pode dar errado e o que precisa existir antes de começar. A Fase 2 pega cada cenário do UC e traduz em passos concretos: URL exata, dados de teste, resultado esperado.

- **O elo entre eles são os CT-IDs:** Cada cenário no UC tem um ID ([CT-UC04-02]) que aponta para a linha correspondente na tabela da Fase 2. O UC diz o quê ("dispositivo duplicado deve exibir tela de feedback já registrado"), o plano diz como executar ("acessar URL com mesmo fingerprint, preencher e submeter").

**Na prática o fluxo é assim:**
```
UC define o cenário
    → Fase 1 prioriza e documenta riscos
        → Fase 2 detalha os passos
            → Um testador executa os passos manualmente (runbook)
                → Resultado validado contra o UC
```
Se uma regra mudar no UC (ex: mínimo de feedbacks para análise mudar de 10 para 5), você atualiza o UC e o CT correspondente na Fase 2 — um só lugar para cada tipo de informação. Sem o CT-ID ligando os dois, cada mudança precisaria ser rastreada manualmente nos dois documentos.


| Dimensão | Casos de Uso | Fase 1 — Estratégia | Fase 2 — Execução |
|---|---|---|---|
| **O que o sistema deve fazer** | ✅ Fluxo principal + exceções | — | — |
| **Cenários a testar (linguagem natural)** | ✅ Seção "Base para Teste E2E" | — | ✅ Formaliza com CT-IDs |
| **Passos de execução passo a passo** | ✗ | — | ✅ "1. Acesse URL. 2. Preencha X..." |
| **Dados de teste concretos** | ✗ | — | ✅ E-mails, identificadores, notas específicas |
| **Pré-condições por caso** | Parcial | — | ✅ Por CT ("dispositivo sem envio anterior") |
| **Por que esses fluxos são prioritários** | ✗ | ✅ Mapa de criticidade e bloqueadores entre UCs | — |
| **Riscos documentados** | ✗ | ✅ Anti-spam, e-mail inacessível em CI, estado sujo | — |
| **Ambiente e ferramentas necessárias** | ✗ | ✅ Produção/local, execução manual, reset de fingerprint | — |
| **Critérios de entrada e saída dos testes** | ✗ | ✅ O que precisa existir antes de começar | — |
| **Decisões de "por que testamos assim"** | ✗ | ✅ Permanente, não muda com o código | — |
| **Valor sem roteiro de execução (Fase 2)** | ✅ Alto | ✅ Alto | ⚠️ Baixo — redundante com os UCs |
| **Valor com execução manual (runbook)** | ✅ Alto | ✅ Alto | ✅ Alto — é o roteiro de execução |

---

## Fase 1: Plano de Teste Estratégico (Teórico)

---

### 1. Introdução e Escopo

#### 1.1. Introdução

O feedback-analytics é um SaaS destinado a negócios — de profissionais autônomos a pequenas e médias empresas — que precisam coletar e interpretar avaliações de clientes de forma estruturada. O sistema resolve dois problemas centrais: **como coletar feedback com granularidade** (por empresa, produto, serviço ou departamento, pelo mesmo formulário aberto por QR Code, link compartilhado ou etiqueta NFC) e **como transformar esse volume em decisões** sem que o gestor precise ler cada avaliação individualmente (via análise de IA).

A plataforma possui três atores distintos:

- **Empresa** (novo cliente) — realiza o cadastro e ativa a conta.
- **Gestor** — configura a coleta, distribui os canais (QR Code, link e etiqueta NFC) e analisa os resultados no dashboard.
- **Cliente do estabelecimento** — escaneia o QR Code, abre o link ou encosta o celular na etiqueta NFC e submete a avaliação pelo formulário público.

Stack técnica: React 19 SPA com React Router v7, API Gateway Node.js (Express, com autenticação Better Auth e acesso ao Postgres via Drizzle; o Postgres de produção é hospedado no Supabase) e Serviço Serverless de IA em Node.js, que chama o LLM configurado por cada empresa (OpenRouter).

#### 1.2. Escopo do Teste

**EM ESCOPO:**

- Fluxo de cadastro, ativação de conta e autenticação (UC-01, UC-02, UC-03)
- Configuração da coleta: tipos de feedback, catálogo de itens, perguntas dinâmicas e contexto de IA (UC-06, UC-07, UC-08)
- Envio de feedback pelo formulário público, aberto por QR Code, link ou etiqueta NFC (UC-04)
- Canais de coleta: ativar/pausar a coleta, baixar o QR Code, copiar e compartilhar o link, gravar a etiqueta NFC e testar o formulário (UC-05)
- Dashboard com métricas, canais de chegada, gráficos e diagnóstico do escopo pela IA (UC-09)
- Listagem de feedbacks com filtros combinados e modal de detalhes (UC-10)
- Disparo da análise dos comentários com IA e visualização do tom, dos assuntos e do resumo com recomendações (UC-11)
- Gestão de perfil: nome, e-mail, telefone, contexto e LLM da empresa e exclusão da conta (UC-12)
- Mecanismo anti-spam por fingerprint de dispositivo (bloqueio de envios duplicados no mesmo ponto de coleta e no mesmo dia)

**FORA DO ESCOPO:**

- Testes de carga e estresse (muitos envios simultâneos do formulário público em pico)
- Testes de acessibilidade visual detalhados (WCAG)
- Testes end-to-end do fluxo de e-mail (confirmação de conta, link de reset) — requerem acesso a caixa de e-mail real em tempo de execução
- Testes de integração direta com provedores externos de IA (OpenRouter, Gemini) — nos testes automatizados as chamadas ao LLM são mockadas
- Testes de gateway de pagamento

---

### 2. Estratégia de Teste

#### 2.1. Níveis de Teste

- **Teste de Unidade:** Foco nas funções puras de validação (força da senha, telefone, comprimento de perguntas 20–150 chars), funções de transformação (formatação de data, truncamento de texto) e lógica das route actions (parsing de FormData, retorno de erros). Responsável: Desenvolvedores. Ferramenta: **Vitest** (já em uso no projeto).

- **Teste de Integração:** Verificação de que as camadas loader → service → API Gateway retornam dados com o contrato esperado; que as actions processam FormData e acionam os serviços corretos; e que o fluxo de autenticação Better Auth + cookie httpOnly funciona de ponta a ponta. Responsável: Engenharia/QA.

- **Teste de Sistema (E2E):** Navegação pelos casos de uso documentados, simulando o comportamento real dos três atores. A cobertura E2E abrange os 12 UCs. O UC-03 (recuperação de senha) entrou no roteiro em 16/11/2026: no ambiente local, o e-mail com o link chega no Mailpit, e o link vencido segue conferido por testes de unidade. Responsável: QA. Execução: **manual**, seguindo o runbook [Testes manuais — Web](./manuais-web.md) (a antiga automação Playwright foi removida).

- **Teste de Aceitação (UAT):** Realizado por gestores reais em **produção** (não há mais ambiente de homologação — deploy main-only), validando se os fluxos de configuração → coleta → análise refletem as necessidades reais do negócio.

#### 2.2. Abordagens de Teste

- **Caixa-Branca:** Aplicada nos testes de unidade com cobertura via `@vitest/coverage-v8`. Objetivo: garantir que cada branch das funções de validação e das route actions seja exercitado, evitando comportamentos silenciosos em casos de borda.

- **Caixa-Cinza:** Aplicada nos testes de integração entre as camadas do frontend (loader/action) e a API. Conhecemos o contrato da API e os tipos esperados, mas testamos o comportamento observável — não o código interno do backend.

- **Caixa-Preta:** Aplicada nos testes E2E, simulando exatamente o que cada ator faz na interface: Empresa realiza cadastro, Gestor configura e analisa, Cliente submete feedback. Nenhum conhecimento do código interno é usado — apenas entradas e saídas visíveis.

---

### 3. Recursos e Ambiente

**Ferramentas:**

| Finalidade | Ferramenta | Status |
|---|---|---|
| Testes de unidade e componentes | Vitest + @vitest/coverage-v8 | Em uso |
| Execução E2E de interface | Manual pela UI (runbook [Web](./manuais-web.md)) | Em uso — automação Playwright removida |
| Mock de API em testes de integração | MSW (Mock Service Worker) | A implementar |
| Gerenciamento de casos de teste | Casos de Uso em `docs/concepcao/casos-de-uso/` | Em uso |

**Ambiente de Teste:**

A execução manual do E2E aponta preferencialmente para **produção** (URL deployada) ou, alternativamente, para o ambiente **local** (`http://localhost:5173`). Não há mais ambiente de homologação. O ambiente escolhido deve conter:

- Uma empresa de teste criada, conta ativada e com gestor autenticado.
- Tipos de feedback ativados (Produtos, Serviços e Departamentos).
- Coleta da empresa ativa e catálogo com ao menos 1 item ativo por tipo, com a coleta do item ativa.
- Contexto de IA preenchido (os 3 campos obrigatórios: objetivo, objetivo analítico, resumo).
- Mínimo de 10 feedbacks coletados para viabilizar os testes de insights.

---

### 4. Critérios de Qualidade

**Critérios de Entrada:**

- Ambiente de produção (ou local) estável e acessível.
- Massa de dados configurada conforme descrito na seção de Ambiente.
- Deploy da versão a ser testada concluído sem erros de build.

**Critérios de Saída:**

- 100% dos cenários de caminho feliz dos 12 UCs executados manualmente com sucesso (o do UC-03 no ambiente local, com o Mailpit).
- Zero bugs de bloqueio nos fluxos de autenticação e coleta de feedback (UC-01, UC-02, UC-04, UC-05).
- Cobertura de código ≥ 80% nas funções de validação (testes de unidade).
- Todos os bugs críticos identificados registrados e com responsável atribuído.

---

### 5. Gestão de Riscos

| Risco | Probabilidade | Impacto | Ação de Mitigação |
|---|---|---|---|
| **Anti-spam bloqueando testes E2E** — o fingerprint do dispositivo de teste é reconhecido após o primeiro envio do dia, impedindo novos envios ao mesmo ponto de coleta no mesmo ciclo de testes | Alta | Alto | O fingerprint é calculado no servidor (MD5 de navegador e IP), então não dá para trocá-lo pelo cliente: use outro navegador, outra rede ou outro ponto de coleta, ou limpe a tabela `tracked_devices` no banco do ambiente de teste antes de cada rodada (no local, `npm run db:reset`) |
| **Fluxo de e-mail inacessível em automação** — confirmação de conta e reset de senha exigem acesso à caixa de e-mail em tempo real, inviável em pipelines automatizados | Média | Alto | No ambiente local, o Mailpit do docker-compose do API Gateway captura os e-mails (UI em `http://localhost:8025`) e permite clicar no link; em produção, testar as telas de sucesso/erro do fluxo sem clicar no link real |
| **Instabilidade do provedor de IA externo** — indisponibilidade bloqueia completamente os testes de UC-11 | Baixa | Alto | Criar mocks das respostas de IA para testes unitários e de integração; pular o cenário de UC-11 na execução manual quando o provedor estiver indisponível |
| **Estado sujo entre execuções de teste** — empresa de teste acumula catálogos, tipos e feedbacks de execuções anteriores, causando resultados inconsistentes | Alta | Médio | No ambiente local, rodar `npm run db:reset` no API Gateway antes de cada rodada: recria o banco com o seed determinístico e o usuário de teste. O script só roda contra banco local; em produção a limpeza continua manual |

---

## Fase 2: Casos de Teste por Funcionalidade

> Cada CT mapeia 1:1 para um cenário da seção "Base para Teste E2E" do UC correspondente. O UC define **O QUÊ** testar (regra de negócio, fluxo, exceções); esta fase define **COMO EXECUTAR** (passos, dados, resultado esperado).

### Legenda de cobertura

> Os selos seguem a seção "Base para Teste E2E" de cada caso de uso. A suíte Playwright saiu em 08/08/2026, e os fluxos de ponta a ponta são reproduzidos à mão pelo [runbook da Web](./manuais-web.md).

*   **✅ Coberto manual (runbook):** o runbook reproduz o fluxo de ponta a ponta.
*   **✅ Coberto manual (smoke):** o runbook só confere que a página carrega (ou o estado vazio). **Não** exercita cliques, salvamentos nem filtros.
*   **✅ Coberto manual (runbook, condicional):** o runbook cobre o fluxo, mas ele só se aplica com uma pré-condição (o Google ligado, um ponto de coleta ativo, uma conta nova ou o botão habilitado).
*   **📝 Planejado / não implementado:** cenário do caso de uso que ainda não está no runbook nem num teste automatizado.
*   **🚫 Não dá para automatizar no navegador:** depende do aparelho ou do sistema operacional (download do arquivo, `navigator.share`). Dá para conferir à mão num aparelho real.
*   **❌ Cenário não coberto:** sem teste automatizado e fora do runbook.
*   **🔵 Unidade já atende:** a regra é conferida por teste de unidade (Vitest).
*   **🟠 Integração já atende:** a regra é conferida por teste de integração mockada (actions e loaders da Web ou rotas do Gateway).
*   **⛔ Obsoleto:** o sistema não tem mais esse comportamento; o CT fica só como registro.

---

### Grupo 1: Onboarding e Autenticação

#### [UC-01] Cadastro de Conta Empresarial → [uc-01-cadastro-conta.md](../../concepcao/casos-de-uso/uc-01-cadastro-conta.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC01-01`<br>📝 *Planejado / não implementado* | Caminho feliz | E-mail ainda não cadastrado | 1. Acessar tela de cadastro. 2. Preencher nome, e-mail, senha forte, telefone BR, aceitar termos. 3. Clicar "Criar Conta". | e-mail: `novo@teste.com` | Tela de sucesso com orientação para confirmar o e-mail. *Sem teste E2E no spec — depende de recebimento de e-mail real.* |
| `CT-UC01-02`<br>✅ *Coberto manual (runbook)* | E-mail duplicado — prevenção de enumeração (Exceção) | E-mail já cadastrado | 1. Acessar tela de cadastro. 2. Preencher com e-mail já existente e dados válidos. 3. Clicar "Criar conta". | e-mail: `gestor@empresateste.com` (já existente) | **Segue para a tela de sucesso** normalmente — sem revelar que o e-mail já existe |
| `CT-UC01-03`<br>⛔ *Obsoleto* (o cadastro não pede mais CPF/CNPJ) | Documento já cadastrado (Exceção) | CPF/CNPJ já existente na base | 1. Acessar tela de cadastro. 2. Preencher com um documento já existente e demais dados válidos. 3. Clicar "Criar conta". | CPF: documento já cadastrado na base | Envio bloqueado; mensagem de erro de documento duplicado exibida |
| `CT-UC01-04`<br>⛔ *Obsoleto* (o cadastro não pede mais CPF/CNPJ) | Documento inválido (Exceção) | Nenhuma | 1. Acessar tela de cadastro. 2. Preencher todos os campos com CPF inválido. 3. Clicar "Criar conta". | CPF: `111.111.111-11` (não passa na validação matemática) | Envio bloqueado; mensagem indicando que o documento é inválido |
| `CT-UC01-05`<br>📝 *Planejado / não implementado* | Telefone inválido (Exceção) | Nenhuma | 1. Acessar tela de cadastro. 2. Preencher telefone fora do padrão BR. 3. Clicar "Criar conta". | Telefone: `12345` | Envio bloqueado; campo destacado com mensagem de formato inválido |
| `CT-UC01-06`<br>📝 *Planejado / não implementado* | Termos não aceitos (Exceção) | Nenhuma | 1. Acessar tela de cadastro. 2. Preencher todos os campos válidos sem marcar os termos. 3. Clicar "Criar conta". | Checkbox de termos: desmarcado | Envio bloqueado; formulário não submetido |
| `CT-UC01-07`<br>✅ *Coberto manual (runbook)* | Reenvio de e-mail (Exceção) | Conta criada, e-mail não confirmado | 1. Na tela de sucesso ou login, solicitar reenvio do e-mail de confirmação. | — | Resposta genérica de envio e o botão desabilitado com "Solicitar novamente em mm:ss" |
| `CT-UC01-08`<br>✅ *Coberto manual (runbook)* | Celular já cadastrado (Exceção) | Celular já usado por outra conta | 1. Acessar tela de cadastro. 2. Preencher com e-mail novo, o celular de outra conta e dados válidos. 3. Clicar "Criar Conta". | celular: o da conta de teste | Aviso "Telefone já cadastrado."; formulário continua na tela |

#### [UC-02] Login da Empresa → [uc-02-login.md](../../concepcao/casos-de-uso/uc-02-login.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC02-01`<br>✅ *Coberto manual (runbook)* | Caminho feliz | Conta ativa com e-mail confirmado | 1. Acessar tela de login. 2. Preencher e-mail e senha corretos. 3. Clicar "Entrar". | e-mail: `gestor@empresateste.com`; senha correta | Sessão criada; redirecionamento para o dashboard |
| `CT-UC02-02`<br>✅ *Coberto manual (runbook)* | Credenciais inválidas (Exceção) | Conta ativa | 1. Acessar tela de login. 2. Preencher e-mail válido e senha errada. 3. Clicar "Entrar". | e-mail: `gestor@empresateste.com`; senha: `senhaerrada123` | Mensagem de erro sem revelar qual campo está incorreto; sem redirecionamento |
| `CT-UC02-03`<br>🔵 *Unidade já atende* | Rate limit (Exceção) | Conta ativa | 1. Acessar tela de login. 2. Errar a senha da mesma conta 11 vezes seguidas, em menos de 15 minutos. | e-mail válido; senha errada (repetir) | Da 1ª à 10ª, "E-mail ou senha incorretos.". Na 11ª, "Muitas tentativas de login." com "Aguarde alguns instantes antes de tentar novamente.". A senha certa também é recusada até a janela acabar. Coberto por `src/tests/authRateLimit.test.ts` (Gateway) |
| `CT-UC02-04`<br>📝 *Planejado / não implementado* | Campos vazios (Exceção) | Nenhuma | 1. Acessar tela de login. 2. Clicar "Entrar" sem preencher nenhum campo. | e-mail: `""`; senha: `""` | Campos destacados como obrigatórios; envio bloqueado antes de chamar a API |
| `CT-UC02-05`<br>✅ *Coberto manual (runbook, condicional)* | Entrar com o Google (Fluxo alternativo) | Google ligado na Web e no gateway; conta Google que nunca entrou | 1. Em `/login`, clicar "Continuar com Google". 2. Entrar e autorizar. 3. Em "Complete seu cadastro", informar um celular livre, aceitar os termos e clicar "Concluir cadastro". | conta Google nova | Passa por `/auth/complete-signup` e vai para `/user/dashboard`. *Sem o Google ligado, não se aplica.* |

#### [UC-03] Recuperação de Senha → [uc-03-recuperacao-senha.md](../../concepcao/casos-de-uso/uc-03-recuperacao-senha.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC03-01`<br>✅ *Coberto manual (runbook)* | Caminho feliz | Conta ativa com e-mail válido | 1. Acessar tela de recuperação. 2. Informar e-mail cadastrado. 3. Clicar "Enviar instruções". 4. Abrir o e-mail (no local, no Mailpit) e clicar no link. 5. Definir nova senha e confirmar. | e-mail: o de uma conta descartável; nova senha: forte | Volta para `/login?reset=success` com "Senha alterada."; o login com a nova senha funciona e a antiga deixa de funcionar |
| `CT-UC03-02`<br>✅ *Coberto manual (runbook)* | E-mail inexistente (Exceção) | Nenhuma | 1. Acessar tela de recuperação. 2. Informar e-mail não cadastrado. 3. Clicar "Enviar instruções". | e-mail: `naoexiste@xyz.com` | Mesmo aviso "E-mail enviado!" — sem revelar que o e-mail não existe; nenhum e-mail sai |
| `CT-UC03-03`<br>🔵 *Unidade já atende* | Link expirado (Exceção) | Link de redefinição expirado | 1. Acessar a URL do link de redefinição já expirado. | URL expirada | Volta para `/forgot-password?error=INVALID_TOKEN` com o aviso "O link de redefinição expirou ou já foi usado. Peça um novo abaixo." Coberto por `src/tests/authCallback.test.ts` (Gateway) e `pages/tests/forgotPassword.test.tsx` (Web) |
| `CT-UC03-04`<br>✅ *Coberto manual (runbook)* | Senhas divergentes (Exceção) | Link de redefinição ativo | 1. Acessar URL de redefinição válida. 2. Digitar senhas diferentes nos dois campos. 3. Clicar "Redefinir senha". | senha: `Nova123!`; confirmação: `Diferente456!` | Envio bloqueado com "As senhas não coincidem" abaixo da confirmação |

---

### Grupo 2: Coleta de Feedback

#### [UC-04] Envio de Feedback (QR Code, link ou NFC) → [uc-04-envio-feedback-qrcode.md](../../concepcao/casos-de-uso/uc-04-envio-feedback-qrcode.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC04-01`<br>✅ *Coberto manual (runbook, condicional)* | Caminho feliz | Empresa ativa; coleta ativa; perguntas dinâmicas configuradas; dispositivo sem envio anterior no dia | 1. Acessar URL do formulário com identifier válido. 2. Clicar na 5ª estrela. 3. Preencher comentário. 4. Responder todas as perguntas dinâmicas. 5. Clicar em "Enviar". | identifier: `empresa-teste`; comentário: "Ótimo atendimento". Requer o `enterprise_id` da conta de teste e um ponto de coleta ativo | Tela "Feedback enviado" exibida; feedback registrado no banco. *Só se aplica com um ponto de coleta ativo.* |
| `CT-UC04-02`<br>✅ *Coberto manual (runbook)* | Dispositivo duplicado (Exceção) | Dispositivo já enviou feedback para o mesmo ponto de coleta hoje | 1. Acessar URL do formulário. 2. Preencher e submeter o formulário normalmente. | Mesmo fingerprint do envio anterior | O envio é recusado (HTTP 409) e o formulário mostra a tela "Obrigado por participar", avisando que o dispositivo já respondeu hoje. |
| `CT-UC04-03`<br>✅ *Coberto manual (runbook)* | Empresa inválida (Exceção) | Nenhuma empresa com o identifier informado | 1. Acessar URL com `enterprise_id` inexistente. | identifier: `empresa-inexistente-xyz` | Tela de "empresa não encontrada" / erro exibida; formulário não renderizado |
| `CT-UC04-04`<br>🔵 *Unidade já atende* | Nota não selecionada (Exceção) | Empresa com a coleta ativa | 1. Acessar URL válida. 2. Preencher comentário. 3. Responder perguntas. 4. Clicar "Enviar" sem selecionar nota. | Sem nota selecionada | Envio bloqueado; mensagem "Por favor, selecione uma avaliação" exibida |
| `CT-UC04-05`<br>🔵 *Unidade já atende* | Comentário vazio | Empresa com a coleta ativa | 1. Acessar URL válida. 2. Selecionar nota. 3. Responder perguntas. 4. Clicar "Enviar" sem preencher comentário. | Comentário: `""` | Envio **aceito**: o comentário é opcional desde a configuração do campo de comentário por escopo |
| `CT-UC04-06`<br>🔵 *Unidade já atende* | Perguntas não respondidas (Exceção) | Empresa com perguntas dinâmicas; coleta ativa | 1. Acessar URL válida. 2. Selecionar nota. 3. Preencher comentário. 4. Deixar ao menos uma pergunta sem resposta. 5. Clicar "Enviar". | 1 pergunta sem resposta | Envio bloqueado; mensagem solicitando que todas as perguntas sejam respondidas |

#### [UC-05] Canais de coleta (QR Code, link e NFC) → [uc-05-geracao-qrcode.md](../../concepcao/casos-de-uso/uc-05-geracao-qrcode.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC05-01`<br>✅ *Coberto manual (smoke)* | Carregamento da página | Gestor autenticado | 1. Acessar `/user/edit/feedback-general` (o antigo `/user/qrcode/enterprise` redireciona para lá). 2. Verificar que a seção **Canais de coleta** carrega, exibindo o QR Code ou o botão de ativar a coleta. | — | Página carrega e exibe o QR Code ou o botão de controle. *Smoke — **não** exercita o clique de ativar/pausar.* |
| `CT-UC05-02`<br>✅ *Coberto manual (runbook)* | Ativar/pausar a coleta (Caminho Feliz) | Gestor autenticado; seção Canais de coleta carregada | 1. Clicar em "Ativar coleta" ou "Pausar coleta". | — | Toast de confirmação exibido; estado visual atualizado imediatamente; o interruptor vale para os três canais |
| `CT-UC05-03`<br>🚫 *Não dá para automatizar no navegador* | Download (Caminho Feliz) | Gestor autenticado | 1. Clicar em "Baixar QR Code" no cartão QR Code. | — | Download de arquivo `.png` disparado com o nome da empresa no título |
| `CT-UC05-04`<br>✅ *Coberto manual (runbook)* | Copiar link (Caminho Feliz) | Gestor autenticado | 1. Clicar em "Copiar link" no cartão Link. | — | URL copiada para a área de transferência, com `canal=link`; indicador visual de cópia por 2 segundos |
| `CT-UC05-05`<br>🚫 *Não dá para automatizar no navegador* | Compartilhar (Caminho Feliz) | Ambiente com `navigator.share` disponível | 1. Clicar em "Compartilhar". | — | API nativa de compartilhamento invocada com título, descrição e link corretos |
| `CT-UC05-06`<br>📝 *Planejado / não implementado* | Share API indisponível (Exceção) | Ambiente sem `navigator.share` | 1. Clicar em "Compartilhar". | — | Link copiado automaticamente para a área de transferência (sem mensagem de erro) |
| `CT-UC05-07`<br>✅ *Coberto manual (runbook, dentro do CT-UC05-02)* | Coleta pausada — formulário bloqueado (Exceção) | Coleta da empresa pausada | 1. Acessar o formulário público da empresa (pelo QR Code, pelo link ou pela etiqueta NFC) com a coleta pausada. | identifier: `empresa-teste` (coleta pausada) | O formulário público mostra "Este formulário está desativado ou o endereço é inválido. Peça um novo QR Code ou link ao estabelecimento."; envio bloqueado |
| `CT-UC05-08`<br>✅ *Coberto manual (runbook)* | Campo de comentário do escopo | Gestor autenticado; coleta ativa | 1. Em `/user/edit/feedback-general`, no cartão "Campo de comentário", escolher "Pergunta própria", escrever e salvar. 2. Abrir o link da empresa numa janela anônima. 3. Repetir com "Ocultar o campo" e "Convite padrão". | pergunta: `O que faltou para ser nota 5?` | O formulário público mostra a pergunta própria, nenhum campo ou o convite padrão, conforme o que foi salvo |

---

### Grupo 3: Configuração e Perfil

#### [UC-06] Ativação de Tipos de Feedback → [uc-06-ativacao-tipos-feedback.md](../../concepcao/casos-de-uso/uc-06-ativacao-tipos-feedback.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC06-01`<br>✅ *Coberto manual (smoke)* | Carregamento da página | Gestor autenticado | 1. Acessar `/user/edit/types-feedback`. 2. Verificar que a página carrega e lista as opções disponíveis (Produtos/Serviços/Departamentos). | — | Página carrega exibindo as opções disponíveis. *Smoke — **não** cobre ativar/salvar nem o badge.* |
| `CT-UC06-02`<br>📝 *Planejado / não implementado* | Ativar tipo (Caminho Feliz) | Gestor autenticado; tipo "Produtos" inativo | 1. Acessar tela de tipos de feedback. 2. Ativar o toggle "Produtos". 3. Clicar "Salvar seleção". | — | Toast de sucesso; badge "Ativo" e link "Configurar catálogo de produtos" aparecem no card |
| `CT-UC06-03`<br>📝 *Planejado / não implementado* | Desativar tipo (Caminho Feliz) | Gestor autenticado; tipo "Produtos" ativo | 1. Acessar tela de tipos de feedback. 2. Desativar o toggle "Produtos". 3. Clicar "Salvar seleção". | — | Toast de sucesso; badge e link de catálogo desaparecem do card |
| `CT-UC06-04`<br>❌ *Cenário não coberto* | Toggle sem salvar (Comportamento) | Gestor autenticado | 1. Ativar toggle de um tipo. 2. NÃO clicar em "Salvar". | — | Aviso "Suas alterações ainda não foram salvas" e "Salve para liberar o catálogo."; selo "Ativo" e link "Configurar catálogo" NÃO aparecem |
| `CT-UC06-05`<br>❌ *Cenário não coberto* | Erro ao salvar (Exceção) | Gestor autenticado; rede instável | 1. Ativar toggle de um tipo. 2. Clicar "Salvar seleção" com falha de rede simulada. | — | Toast de erro exibido; estado salvo dos tipos não alterado |

#### [UC-07] Configuração do Catálogo → [uc-07-configuracao-catalogo.md](../../concepcao/casos-de-uso/uc-07-configuracao-catalogo.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC07-01`<br>✅ *Coberto manual (smoke)* | Carregamento da página | Gestor autenticado | 1. Acessar `/user/edit/feedback-products`. 2. Verificar que a página carrega — exibindo o conteúdo principal ou a mensagem de tipo não ativado. | — | Página carrega corretamente. *Smoke — **não** cobre adicionar/editar item nem salvar perguntas.* |
| `CT-UC07-02`<br>📝 *Planejado / não implementado* | Adicionar item (Caminho Feliz) | Gestor autenticado; tipo "Produtos" ativo | 1. Acessar catálogo de produtos. 2. Preencher nome do novo produto. 3. Clicar "Salvar". | nome: `Produto Teste A` | Toast de sucesso; item aparece na lista com status ativo |
| `CT-UC07-03`<br>📝 *Planejado / não implementado* | Editar item (Caminho Feliz) | Item existente no catálogo | 1. Acessar catálogo e clicar em "Configurar" num item. 2. Editar o nome em "Dados do item". 3. Clicar "Salvar dados do item". | nome editado: `Produto Atualizado` | Toast de sucesso; nome atualizado na lista |
| `CT-UC07-04`<br>📝 *Planejado / não implementado* | Salvar perguntas (Caminho Feliz) | Item existente no catálogo | 1. Abrir a tela do item ("Configurar"). 2. Em "Configurar perguntas", escrever pergunta dinâmica válida (20–150 chars). 3. Clicar "Salvar perguntas". | texto: `Como você avaliaria a qualidade?` (31 chars) | Toast de sucesso para aquele item; pergunta salva |
| `CT-UC07-05`<br>✅ *Coberto manual (runbook)* | Coleta por item (Caminho Feliz) | Item existente no catálogo | 1. Abrir a tela do item ("Configurar"). 2. Em "Canais de coleta", ativar ou pausar a coleta do item. | — | Aviso "Coleta ativada!" ("Item disponível para coleta de feedback."); o estado muda sem salvar os outros blocos; vale para o QR Code, o link e a etiqueta NFC do item |
| `CT-UC07-06`<br>🔵 *Unidade já atende* | Pergunta inválida — curta (Exceção) | Item existente no catálogo | 1. Abrir a tela do item. 2. Inserir pergunta com menos de 20 caracteres. 3. Clicar "Salvar perguntas". | texto: `Curta` (5 chars) | Envio bloqueado; campo destacado com erro de comprimento mínimo |
| `CT-UC07-07`<br>📝 *Planejado / não implementado* | Pergunta inválida — longa (Exceção) | Item existente no catálogo | 1. Abrir a tela do item. 2. Inserir pergunta com mais de 150 caracteres. 3. Clicar "Salvar perguntas". | texto: 151 caracteres | Envio bloqueado; campo destacado com erro de comprimento máximo |
| `CT-UC07-08`<br>❌ *Cenário não coberto* | Item removido (Exceção) | Item com a coleta ativa | 1. Remover o item da lista do catálogo. 2. Acessar a URL do formulário público daquele item. | — | O envio é recusado como QR pausado (`404 collection_point_not_found`; ver a exceção "Gestor remove um item da lista" no UC-07) |
| `CT-UC07-09`<br>❌ *Cenário não coberto* | Coleta do item pausada (Exceção) | Item ativo com a coleta pausada | 1. Pausar a coleta do item em "Canais de coleta". 2. Acessar a URL do formulário público daquele item. | — | Tela de erro no formulário público; envio bloqueado |

#### [UC-08] Configuração de Dados de Coleta (Contexto IA) → [uc-08-configuracao-coleta-ia.md](../../concepcao/casos-de-uso/uc-08-configuracao-coleta-ia.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC08-01`<br>✅ *Coberto manual (smoke)* | Carregamento da página | Gestor autenticado | 1. Acessar a tela de configuração de coleta. 2. Verificar que o formulário está visível. | — | Página carrega com o formulário de contexto visível. *Smoke — não salva dados.* |
| `CT-UC08-02`<br>✅ *Coberto manual (runbook, condicional)* | Salvar objetivo (Caminho Feliz) | Gestor autenticado; campo de objetivo visível | 1. Em `/user/profile`, clicar "Editar contexto e LLM". 2. No passo "Sua meta", preencher o objetivo da empresa. 3. Avançar até "Modelo LLM" e salvar. | objetivo: `Aumentar retenção` | Toast "Contexto salvo!"; objetivo persistido. *Só salva com os outros dois campos do contexto preenchidos.* |
| `CT-UC08-03`<br>⛔ *Obsoleto na interface* (a janela não deixa salvar com campo vazio) | Campos em branco (Exceção) | Gestor autenticado | 1. Em `/user/profile`, clicar "Editar contexto e LLM". 2. Limpar algum dos três campos do contexto. 3. Tentar salvar. | Um dos campos: `""` | Salvamento barrado com "Complete os campos obrigatórios". O gateway ainda aceita os campos nulos no `PATCH /collecting_data` |
| `CT-UC08-04`<br>✅ *Coberto manual (runbook, condicional)* | Salvar resumo do negócio (Caminho Feliz) | Gestor autenticado; campo de resumo visível | 1. Em `/user/profile`, clicar "Editar contexto e LLM". 2. No passo "Seu negócio", preencher o resumo do negócio. 3. Avançar até "Modelo LLM" e salvar. | resumo: `Restaurante de culinária japonesa` | Toast "Contexto salvo!"; resumo persistido. *Só salva com os outros dois campos do contexto preenchidos.* |
| `CT-UC08-05`<br>🟠 *Integração já atende* | Atualização parcial (Caminho Feliz) | Gestor com dados já preenchidos | 1. Em `/user/profile`, clicar "Editar contexto e LLM". 2. Editar apenas o resumo do negócio. 3. Avançar até "4. Modelo LLM" e salvar. | Resumo atualizado; demais campos mantidos | Toast de sucesso; apenas o resumo alterado — os demais campos permanecem inalterados |
| `CT-UC08-06`<br>❌ *Cenário não coberto* | Erro ao salvar (Exceção) | Gestor autenticado; rede instável | 1. Preencher os campos. 2. Salvar com falha de rede simulada. | — | Toast de erro; dados do formulário permanecem para nova tentativa |
| `CT-UC08-07`<br>✅ *Coberto manual (runbook, condicional)* | Geração automática das perguntas (Caminho Feliz) | Conta nova (perguntas ainda padrão); chave OpenRouter de teste | 1. No onboarding, preencher o contexto e configurar a IA no passo "4. Modelo LLM"; clicar "Configurar IA e salvar". 2. Acompanhar "Preparando sua conta". 3. Abrir `/user/edit/feedback-general`. | — | "Sua conta está pronta" e as 3 perguntas novas no formulário geral. Na falha, o aviso "As perguntas personalizadas não foram criadas" com "Tentar de novo", "Trocar modelo" e "Manter perguntas padrão". *Consome a cota da IA; com as perguntas já editadas, não se aplica.* |

#### [UC-12] Gestão de Perfil → [uc-12-gestao-perfil.md](../../concepcao/casos-de-uso/uc-12-gestao-perfil.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC12-01`<br>✅ *Coberto manual (runbook)* | Carregamento do perfil | Gestor autenticado | 1. Acessar a tela de perfil. 2. Verificar que os dados da empresa (perfil/empresa/nome/e-mail) são exibidos. | — | Página de perfil carrega com os dados da empresa |
| `CT-UC12-02`<br>✅ *Coberto manual (runbook)* | E-mail exibido | Gestor autenticado | 1. Acessar a tela de perfil. 2. Localizar o e-mail do usuário autenticado. | e-mail da sessão | E-mail do usuário autenticado exibido no perfil |
| `CT-UC12-03`<br>✅ *Coberto manual (runbook)* | Endereço antigo do QR Code | Gestor autenticado | 1. Acessar diretamente `/user/qrcode/enterprise` (o perfil não tem mais link de QR Code). | — | Redireciona para `/user/edit/feedback-general`, com a seção Canais de coleta |
| `CT-UC12-04`<br>✅ *Coberto manual (runbook)* | Catálogo acessível | Gestor autenticado | 1. Acessar diretamente `/user/edit/types-feedback` (o catálogo fica no menu Configuração da coleta, não no perfil). | — | A tela responde na rota com o conteúdo principal visível |
| `CT-UC12-06`<br>✅ *Coberto manual (runbook)* | Logout | Gestor autenticado | 1. Abrir o menu de conta (nome da empresa no cabeçalho). 2. Clicar em "Sair". | — | Logout redireciona para a página de login |
| `CT-UC12-07`<br>✅ *Coberto manual (runbook)* | Rota protegida | Usuário não autenticado | 1. Acessar uma rota protegida sem sessão. | — | Redirecionamento automático para o login |
| `CT-UC12-08`<br>📝 *Planejado / não implementado* | Atualizar nome (Caminho Feliz) | Gestor autenticado | 1. Acessar tela de perfil. 2. Editar o campo de nome. 3. Salvar. | nome: `Gestor Atualizado` | Novo nome aparece no perfil após salvar |
| `CT-UC12-09`<br>✅ *Coberto manual (runbook)* | Atualizar e-mail (Caminho Feliz) | Gestor autenticado | 1. Acessar tela de perfil. 2. Informar novo e-mail válido. 3. Confirmar. | e-mail: `novo@email.com` | Toast "Confirme no novo e-mail!" e link "Confirme seu novo e-mail" no endereço novo; o e-mail da conta só muda depois do clique (ver o CT-UC12-09 do [runbook da Web](./manuais-web.md)) |
| `CT-UC12-10`<br>✅ *Coberto manual (runbook)* | Atualizar telefone (Caminho Feliz) | Gestor autenticado | 1. Acessar tela de perfil. 2. Clicar no campo de telefone (modo edição). 3. Informar novo número e clicar "Salvar". | número: `+55 11 99999-0001` | Toast "Telefone atualizado!", telefone atualizado na conta e tela de volta ao modo de visualização. Sem provedor de SMS, não há passo de código |
| `CT-UC12-11`<br>📝 *Planejado / não implementado* | Cancelar atualização de telefone (Caminho Alternativo) | Gestor no modo de edição de telefone | 1. Clicar em "Cancelar" no modo de edição do telefone. | — | Tela retorna ao modo de visualização sem alterar o número atual |
| `CT-UC12-12`<br>📝 *Planejado / não implementado* | Nome vazio (Exceção) | Gestor autenticado | 1. Acessar tela de perfil. 2. Apagar o conteúdo do campo de nome. 3. Tentar salvar. | nome: `""` | Envio bloqueado; campo de nome destacado como obrigatório |
| `CT-UC12-13`<br>📝 *Planejado / não implementado* | Telefone inválido (Exceção) | Gestor no modo edição de telefone | 1. Informar número fora do padrão `+55 DDD NÚMERO`. 2. Clicar "Salvar". | número: `12345` | Formulário bloqueado antes de chamar a API; mensagem de formato inválido |
| `CT-UC12-14`<br>⛔ *Obsoleto* (sem provedor de SMS, a tela não tem passo de código) | Código de verificação inválido (Exceção) | — | — | — | Não se aplica: a tela salva o telefone direto, sem pedir código. Volta a valer se o projeto ganhar um provedor de SMS |
| `CT-UC12-15`<br>✅ *Coberto manual (runbook)* | Excluir minha conta | Conta descartável com senha | 1. No fim de `/user/profile`, clicar "Excluir minha conta". 2. Digitar a senha errada e `EXCLUIR` e clicar "Excluir para sempre". 3. Corrigir a senha e confirmar. | palavra: `EXCLUIR` | Senha errada: "Senha incorreta. Confira e tente de novo." e nada é apagado. Senha certa: "Sua conta foi excluída." e o login responde "E-mail ou senha incorretos." *Nunca na conta de teste do time.* |
| `CT-UC12-16`<br>✅ *Coberto manual (runbook)* | Rotas antigas redirecionam | Gestor autenticado | 1. Abrir cada endereço antigo da tabela do runbook. | ex.: `/user/insights/reports` | Cada endereço cai no destino novo (ex.: `/user/insights/overview`), conforme o CT-UC12-16 do [runbook da Web](./manuais-web.md) |

---

### Grupo 4: Análise e Insights

#### [UC-09] Visualização do Dashboard → [uc-09-dashboard.md](../../concepcao/casos-de-uso/uc-09-dashboard.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC09-01`<br>✅ *Coberto manual (runbook)* | Carregamento (Caminho Feliz) | Gestor autenticado | 1. Acessar `/user/dashboard`. 2. Verificar o menu e a barra de escopo e período. | — | Item "Visão geral" destacado no menu e barra de escopo e período com os botões "QR Code" (leva à tela de canais do escopo) e "Analisar comentários com IA". O Dashboard não tem título nem breadcrumb próprios |
| `CT-UC09-02`<br>✅ *Coberto manual (runbook)* | Avaliação por estrelas | Gestor autenticado; empresa com feedbacks | 1. Acessar o dashboard. 2. Localizar a seção "Avaliação por estrelas". | — | Card "Média" com nota /5, rótulo e número de avaliações (o card de total saiu em 16/10/2026) |
| `CT-UC09-03`<br>✅ *Coberto manual (runbook)* | Positivas, neutras e críticas | Gestor autenticado | 1. Acessar o dashboard. 2. Localizar os cards de positivas, neutras e críticas. | — | Cards "Positivas (4–5★)", "Neutras (3★)" e "Críticas (1–2★)" com contagem e %; "Ver a nota completa" leva a `/user/ratings` |
| `CT-UC09-04`<br>✅ *Coberto manual (runbook)* | Análise dos comentários | Gestor autenticado | 1. Acessar o dashboard. 2. Localizar a seção "Análise dos comentários ✨ IA". | — | Tom dos comentários e "Resumo dos comentários e recomendações" exibidos (ou os estados vazios) |
| `CT-UC09-05`<br>✅ *Coberto manual (runbook)* | Navegação para listagem | Gestor autenticado | 1. Acessar o dashboard. 2. Abrir o sino do cabeçalho e clicar em "Ver todos os feedbacks". | — | Navega para a listagem completa (`/user/feedbacks/all`) |
| `CT-UC09-06`<br>📝 *Planejado / não implementado* | Toast de login (Caminho Alternativo) | Gestor que acabou de fazer login | 1. Acessar o dashboard com `?login=success` na URL. | URL: `?login=success` | Toast "Login realizado com sucesso." exibido; parâmetro `?login=success` removido da URL |
| `CT-UC09-07`<br>❌ *Cenário não coberto* | Erro de carregamento (Exceção) | API de estatísticas indisponível | 1. Acessar o dashboard com API de estatísticas simulando falha. | — | Mensagem de erro inline no topo; página permanece acessível sem redirecionamento |
| `CT-UC09-08`<br>📝 *Planejado / não implementado* | Sessão expirada (Exceção) | Sessão do gestor inválida | 1. Tentar acessar o dashboard com sessão inválida. | — | Redirecionamento automático para `/login`. *Coberto de forma análoga em UC-12 via rota protegida.* |
| `CT-UC09-09`<br>✅ *Coberto manual (runbook)* | Por onde chegaram | Feedbacks recebidos por ao menos um canal marcado | 1. No dashboard, localizar a seção "Por onde chegaram". | — | Com um canal só, "Todas as avaliações marcadas ... vieram pelo QR Code" (ou link, ou NFC); com mais de um, uma linha por canal com contagem, % e média. Os envios do "Testar o formulário" não entram |
| `CT-UC09-10`<br>✅ *Coberto manual (runbook)* | Diagnóstico do escopo e histórico | IA configurada; contexto completo; 10 ou mais avaliações no recorte | 1. No dashboard, clicar "Gerar diagnóstico". 2. Aguardar. 3. Clicar "Ver o histórico de diagnósticos". | — | Diagnóstico com "O que fazer, em ordem", "O que vai bem", "O que preocupa" e "O que mudou"; `/user/diagnosis` lista os diagnósticos do escopo. Com menos de 10 avaliações, o botão fica desabilitado. Consome a cota da IA |
| `CT-UC09-11`<br>✅ *Coberto manual (runbook)* | Nota completa | Empresa com feedbacks | 1. No dashboard, clicar "Ver a nota completa". | — | `/user/ratings` com "Avaliação por estrelas" (com "Neutras (3★)"), "Distribuição das avaliações" e "Movimento das avaliações" |
| `CT-UC09-12`<br>✅ *Coberto manual (runbook)* | Comparar dois itens | Dois itens do mesmo tipo no catálogo | 1. Abrir "Comparar itens" (`/user/compare`). 2. Escolher o tipo, os dois itens e o período. | — | Tabela com Nº de avaliações, Média, Positivas, Neutras, Críticas, Tom dos comentários, Escreveram comentário e Precisão da média, e a coluna "Quem está melhor". Sem dois itens, o passo a passo para chegar lá |
| `CT-UC09-13`<br>✅ *Coberto manual (runbook)* | Primeiros passos e "Testar o formulário" | Coleta da empresa pausada; aparelho sem resposta no dia | 1. No cartão "Primeiros passos", clicar "Ativar QR Code". 2. Clicar "Testar o formulário", responder e enviar. 3. Abrir `/user/feedbacks/all`. | — | "Coleta ativada", "Pronto! Seu teste chegou." e "Tudo pronto ✓"; o feedback aparece com a marca "Teste", fora das métricas |
| `CT-UC09-14`<br>📝 *Planejado / não implementado* | Página Nota (Caminho Feliz) | Gestor autenticado | 1. Clicar "Ver a nota completa" ou "Nota" no menu. 2. Trocar o escopo na barra. | — | `/user/ratings` com Média, Positivas, Neutras e Críticas, distribuição e movimento, no escopo e no período da barra. Com falha na API, "Não foi possível carregar as avaliações agora. Tente novamente em instantes." |
| `CT-UC09-15`<br>📝 *Planejado / não implementado* | Página Clientes e canais (Caminho Feliz) | Gestor autenticado | 1. Clicar "Ver horários de pico e clientes que voltam" ou "Clientes e canais" no menu. | — | `/user/customers` com "Por onde chegaram", "Dias e horários de pico" e "Clientes que voltam". Com falha na API das estatísticas, "Não foi possível carregar os canais agora. Tente novamente em instantes." e as outras seções seguem carregando |

#### [UC-10] Listagem e Filtragem de Feedbacks → [uc-10-listagem-feedbacks.md](../../concepcao/casos-de-uso/uc-10-listagem-feedbacks.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC10-01`<br>✅ *Coberto manual (smoke)* | Carregamento da listagem | Gestor autenticado | 1. Acessar `/user/feedbacks/all`. 2. Verificar que a lista de feedbacks carrega ou que o estado vazio é exibido. | — | Listagem carrega os feedbacks paginados ou exibe o estado vazio. *Smoke — **não** cobre abrir o modal de detalhes nem aplicar filtros.* |
| `CT-UC10-02`<br>📝 *Planejado / não implementado* | Modal de detalhes (Caminho Feliz) | Gestor autenticado; empresa com feedbacks | 1. Acessar listagem de feedbacks. 2. Clicar em um feedback. | — | Modal de detalhes com cabeçalho, mensagem completa, ponto de coleta, perguntas, dispositivo e cliente |
| `CT-UC10-03`<br>📝 *Planejado / não implementado* | Filtro por nota (Caminho Feliz) | Empresa com feedbacks de notas variadas | 1. Acessar listagem. 2. Selecionar nota 5 no filtro de avaliação. | nota: 5 | Apenas feedbacks com nota 5 exibidos |
| `CT-UC10-04`<br>📝 *Planejado / não implementado* | Filtro por categoria (Caminho Feliz) | Empresa com feedbacks de múltiplas categorias | 1. Abrir a listagem com `?category=PRODUCT` na URL (a tela não tem mais o controle de categoria). | categoria: `PRODUCT` | Apenas feedbacks de pontos de coleta do tipo Produto exibidos |
| `CT-UC10-05`<br>📝 *Planejado / não implementado* | Busca textual (Caminho Feliz) | Empresa com feedbacks | 1. Acessar listagem. 2. Digitar um termo no campo de busca e aguardar ~450ms. | busca: `atendimento` | Feedbacks que contêm o termo na mensagem exibidos após o debounce |
| `CT-UC10-06`<br>📝 *Planejado / não implementado* | Filtro por escopo (Caminho Feliz) | Empresa com feedbacks de múltiplos itens | 1. Acessar listagem. 2. Escolher um item na lista "Escopo". | item: `Produto A` | Feedbacks daquele item exibidos |
| `CT-UC10-07`<br>📝 *Planejado / não implementado* | Paginação (Caminho Feliz) | Empresa com mais de 10 feedbacks | 1. Acessar listagem (padrão 10 itens/página). 2. Navegar para a segunda página. | — | Segunda página carregada; filtros ativos mantidos |
| `CT-UC10-08`<br>📝 *Planejado / não implementado* | Filtro sem resultado (Exceção) | Empresa com feedbacks | 1. Aplicar filtro que não corresponde a nenhum feedback. | nota: 1 (sem feedbacks com essa nota) | Empty state com mensagem de "ajuste os filtros" exibido |
| `CT-UC10-09`<br>📝 *Planejado / não implementado* | Sem feedbacks (Exceção) | Empresa sem nenhum feedback coletado | 1. Acessar listagem. | — | Empty state com mensagem de "nenhum feedback recebido" exibido (o smoke CT-UC10-01 já aceita este estado como válido) |

#### [UC-11] Análise dos comentários com IA → [uc-11-insights-ia.md](../../concepcao/casos-de-uso/uc-11-insights-ia.md)

| ID | Título | Pré-condições | Passos de Execução | Dados de Teste | Resultado Esperado |
|---|---|---|---|---|---|
| `CT-UC11-01`<br>✅ *Coberto manual (smoke)* | Carregamento do Resumo | Gestor autenticado | 1. Acessar `/user/insights/overview` (antes `/user/insights/reports`). 2. Verificar que a página carrega exibindo o tom, os assuntos e o resumo da IA, ou os estados vazios. | — | O Resumo carrega com a análise ou os estados vazios. *Smoke — **não** dispara a análise.* |
| `CT-UC11-02`<br>✅ *Coberto manual (smoke)* | Tom e assuntos | Gestor autenticado | 1. Acessar a Visão geral. 2. Verificar o tom dos comentários e os assuntos que mais impactam (ou o estado vazio). | — | Visão geral exibe o tom e os assuntos (ou estado vazio); palavras-chave não aparecem mais. *Smoke.* |
| `CT-UC11-05`<br>✅ *Coberto manual (runbook, condicional)* | Gerar o resumo de novo (Caminho Feliz) | Botão "Apenas gerar o resumo" habilitado | 1. Acessar o Resumo. 2. Clicar em "Analisar comentários com IA" e em "Apenas gerar o resumo" (dispara a análise real). | — | Nova análise solicitada; feedback de processamento exibido. *Só se aplica com o botão habilitado. Consome a cota da chave OpenRouter.* |
| `CT-UC11-03`<br>📝 *Planejado / não implementado* | Analisar feedbacks (Caminho Feliz) | Contexto de IA preenchido (os 3 campos); mínimo de 10 feedbacks | 1. Acessar a Visão geral. 2. Clicar em "Analisar comentários com IA" e em "Apenas Analisar". | — | Processamento concluído; tom dos comentários atualizado na tela |
| `CT-UC11-04`<br>📝 *Planejado / não implementado* | Gerar o resumo (Caminho Feliz) | Feedbacks já analisados; contexto preenchido | 1. Clicar em "Analisar comentários com IA" e em "Apenas gerar o resumo". | — | "Resumo dos comentários e recomendações" atualizado |
| `CT-UC11-06`<br>📝 *Planejado / não implementado* | Escopo por produto (Caminho Feliz) | Catálogo com item de produto ativo; contexto preenchido; feedbacks suficientes | 1. Selecionar escopo "Produto". 2. Escolher item de catálogo. 3. Clicar em "Processar e analisar comentários com IA". | escopo: PRODUCT; item: `Produto A` | Tom, assuntos e resumo refletem apenas aquele item; a etiqueta de escopo mostra "Produto · Produto A" |
| `CT-UC11-07`<br>🔵 *Unidade já atende* | Lista e filtros de comentários (Caminho Feliz) | Comentários já analisados | 1. Acessar a aba "Comentários". 2. Escolher o filtro "Nota e texto não combinam". 3. Abrir `/user/feedbacks/analytics/negative`. | — | A lista mostra só os comentários do filtro e guarda `?filtro=` no endereço; o endereço antigo cai na lista filtrada por negativos |
| `CT-UC11-08`<br>📝 *Planejado / não implementado* | Contexto incompleto (Exceção) | Algum dos 3 campos de contexto em branco | 1. Acessar a Análise dos comentários sem contexto completo. | Um ou mais campos de UC-08 em branco | Botões de análise desabilitados; mensagem com link para tela de configuração |
| `CT-UC11-09`<br>📝 *Planejado / não implementado* | Item não selecionado (Exceção) | Gestor autenticado | 1. Selecionar escopo "Produto". 2. NÃO escolher item de catálogo. | escopo: PRODUCT; item: não selecionado | Botões permanecem desabilitados |
| `CT-UC11-10`<br>📝 *Planejado / não implementado* | Volume insuficiente (Exceção) | Contexto preenchido; menos de 10 feedbacks | 1. Acessar a Visão geral. 2. Clicar em "Analisar comentários com IA". | feedbacks disponíveis: < 10 | Mensagem "É necessário no mínimo 10 feedbacks" retornada; ação bloqueada |

---

### Relatório de Execução / Artefatos Complementares

**Massa de Dados:**

- A empresa de teste deve ser criada manualmente em produção antes da primeira execução, com conta ativa, gestor autenticado e todos os tipos de feedback ativados. No ambiente local, o `npm run db:reset` do API Gateway já entrega duas empresas semeadas e o usuário de teste (`E2E_TEST_EMAIL`/`E2E_TEST_PASSWORD`) vinculado a uma delas — ver o [Guia de Instalação](../guia-instalacao.md).
- O fingerprint de dispositivo deve ser resetado (via script de limpeza no banco; no local, o próprio `npm run db:reset`) antes de cada execução dos testes de UC-04 para evitar bloqueio por anti-spam.
- Os feedbacks necessários para UC-11 (mínimo 10) devem ser inseridos diretamente no banco do ambiente de teste caso o volume ainda não tenha sido atingido via envio manual. No local, o `node scripts/seed-raw-feedbacks.mjs --apply` do API Gateway insere um lote sintético de 100 feedbacks na empresa A do seed.
- Para os testes de UC-07 e UC-08, ao menos um item de catálogo deve estar cadastrado e ativo no ambiente de teste.

**Critérios de Sucesso:**

O conjunto de testes é considerado aprovado quando todos os 101 casos de teste desta fase (CT-UC01 a CT-UC12) executam com o resultado esperado, sem nenhum comportamento divergente nos fluxos de Caminho Feliz, e com todos os bloqueios de exceção ocorrendo exatamente na etapa documentada.

Desses 101 cenários, **48 estão no runbook** [Testes manuais — Web](./manuais-web.md): 34 de ponta a ponta, 7 *smoke* (só o carregamento da página), 6 condicionais e 1 dentro de outro caso (o CT-UC05-07, no CT-UC05-02). Os testes automatizados do CI atendem mais 8: 7 por testes de unidade e 1 por teste de integração de rota. Seguem 33 planejados, 6 sem cobertura, 2 que não dá para automatizar no navegador (CT-UC05-03 e CT-UC05-05) e 4 obsoletos. Os números saem dos selos da seção "Base para Teste E2E" de cada caso de uso, conferidos em 16/11/2026.
