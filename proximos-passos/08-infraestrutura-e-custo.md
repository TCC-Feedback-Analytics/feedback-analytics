# 08 — Infraestrutura e custo (sair do free tier que quebra)

> **Em uma frase:** trocar a hospedagem atual — gratuita, mas que corta tarefas longas e derruba a IA — por um arranjo barato onde o "trabalhador pesado" roda numa máquina sempre ligada e o site continua numa CDN gratuita.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 5–6 |
| **Esforço** | Médio |
| **Prioridade** | 🟡 Importante |
| **Depende de** | [03 — Análise assíncrona](./03-analise-assincrona.md) (o worker precisa de um host "sempre ligado" para existir) |
| **Camadas afetadas** | Infra / DevOps |

## Para qualquer leitor

Hoje o sistema inteiro mora num serviço chamado **Vercel**, no plano gratuito. Esse plano é ótimo para coisas rápidas, mas tem um limite duro: ele **desliga qualquer tarefa que demore mais do que cerca de 1 minuto**. O problema é que a análise por inteligência artificial é exatamente uma tarefa demorada — então ela bate nesse teto e falha. É como contratar um entregador que só aceita corridas de até 1 minuto: para buscar pão na esquina serve, mas para uma mudança de casa ele te abandona no meio do caminho.

A saída óbvia seria pagar o plano profissional da Vercel, mas ele custa **US$ 20 por mês (por pessoa)** — caro demais para um projeto de TCC que ainda não tem clientes pagando. Então a proposta é diferente: separar o sistema em duas partes e colocar cada uma no lugar certo. O **site** (a tela que o gestor e o cliente veem) é leve e continua de graça numa CDN. O **trabalhador pesado** — a parte que conversa com a IA e pode levar 20, 30 segundos ou mais — vai para um **servidor sempre ligado**, que não tem essa regra de "1 minuto e desliga".

A melhor notícia é que **isso não é reescrever o sistema, é remontá-lo num lugar diferente**. O código já foi escrito de um jeito que ele sobe sozinho como um servidor comum quando não está na Vercel. Ou seja: a maior parte do trabalho aqui é de **configuração e mudança de endereço**, não de programação nova. É como uma loja que já está pronta — só precisamos mudar de ponto comercial para um aluguel mais barato e que não fecha às 18h.

Por fim, há uma escolha estratégica para a banca: podemos fazer o **mínimo necessário** (mover só o trabalhador pesado e manter o resto onde está) ou ir mais longe e **hospedar tudo numa máquina nossa**. A segunda opção dá mais trabalho, mas demonstra muito mais conhecimento de infraestrutura — e este documento explica honestamente os dois caminhos.

## O que muda para quem usa o sistema

- **Para o gestor (quem analisa os feedbacks):** a análise por IA deixa de "dar erro de tempo esgotado" nos lotes maiores. A funcionalidade que mais quebra hoje passa a terminar de forma confiável.
- **Velocidade do site continua igual ou melhor:** numa CDN gratuita as telas carregam de pontos espalhados pelo mundo, perto do usuário.
- **Custo mensal próximo de zero:** o objetivo é manter a conta em **R$ 0 a poucos reais por mês**, em vez dos ~US$ 20 do plano pago da Vercel.
- **Nada muda na aparência ou no jeito de usar.** Esta etapa é "por baixo do capô": o usuário final não percebe a troca de servidor — só percebe que parou de falhar.

## Como vai funcionar

A ideia central é entender a diferença entre dois jeitos de hospedar software:

| Conceito | Analogia do dia a dia | Bom para | Ruim para |
|---|---|---|---|
| **Serverless** (sob demanda) | Táxi: aparece quando você chama, some quando termina. Você não paga parado, mas a corrida tem tempo máximo. | Requisições curtas (abrir uma tela, salvar um formulário). | Trabalho longo — é onde a IA quebra hoje. |
| **Always-on** (sempre ligado) | Carro próprio na garagem: está sempre lá, pronto, sem relógio cortando a viagem. | O worker da IA, que precisa de tempo e paciência. | Coisas que ficam ociosas — você "paga" pela máquina mesmo parada (por isso buscamos free tier). |

**Antes (hoje):** tudo é "táxi" (serverless na Vercel). O site é táxi (tudo bem, ele é rápido) e a IA também é táxi (problema: estoura o tempo).

**Depois:** o site continua "táxi/CDN" gratuito; o **worker da IA vira "carro na garagem"** — uma máquina sempre ligada onde a análise pode levar o tempo que precisar, sem o relógio da Vercel cortando.

O caminho de uma análise fica assim: o gestor clica em "analisar" → o site envia o pedido → o pedido vai para uma fila (entregue pela [etapa 03](./03-analise-assincrona.md)) → o **worker sempre ligado** pega o trabalho, conversa com a IA com calma e grava o resultado → o gestor vê o resultado quando fica pronto. O ponto desta etapa 08 é garantir que esse worker tenha **onde morar** — uma casa que não o expulsa depois de 1 minuto.

### Onde hospedar (opções honestas)

| Opção (worker always-on) | Prós | Contras |
|---|---|---|
| **Oracle Cloud — Always Free** | VM ARM **gratuita para sempre** (não é trial de 30 dias), com folga de CPU/memória para rodar tudo em Docker. Melhor custo-benefício. | **Você administra a máquina** (atualizações, segurança, firewall). Cadastro inicial é chato e às vezes exige cartão para verificação. |
| **Fly.io** | Sobe container Docker fácil; bom para começar rápido. | Free tier mudou e tem ressalvas; pode haver cobrança ao escalar. |
| **Render** | Muito simples de configurar (conecta no GitHub e pronto). | O plano grátis **"dorme" após inatividade** — a primeira requisição depois do soninho demora a acordar (ruim para um worker que deveria estar pronto). |
| **Frontend → Cloudflare Pages** (ou Vercel free só para o site) | CDN global gratuita; o front já é **site estático**, então é portável **sem mudar uma linha de código**. | Praticamente nenhum para o nosso caso. |

**Recomendação para o TCC:** worker no **Oracle Cloud Always Free** (rende a melhor história de "deploy + containers + custo zero") e frontend no **Cloudflare Pages**. Render/Fly.io ficam como plano B caso o cadastro da Oracle trave.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

### Por que isso é configuração, não reescrita

Os dois serviços de backend **já detectam que não estão na Vercel e sobem como Express comum**:

- `feedback-analytics-ia-analyze/src/index.ts` (linhas 12–18): `if (process.env.VERCEL !== '1') { app.listen(port ?? 4100) }`.
- `feedback-analytics-api-gateway/src/index.ts` (linhas 269–272): mesmo padrão, `app.listen(port ?? 3000)`.

Ou seja, fora da Vercel o `export default app` continua sendo um app Express normal. **Não precisamos extrair o handler nem trocar de framework** — só empacotar e dar `start`.

### O que de fato muda

**1. Empacotamento (Dockerfile / script de start).** Hoje não há `Dockerfile` nos repos; o deploy é 100% Vercel. Criar um `Dockerfile` por serviço (ou um multi-stage com build do TypeScript) e um `docker-compose.yml` para a VM, levantando ao menos o **worker do ia-analyze** sempre ligado. Como cada serviço é um repositório próprio, o build de cada um respeita o seu `package.json` e consome o pacote de contratos (`@feedback/lib-shared`).

**2. Reescrever os deploys.** Hoje existem três workflows que publicam na Vercel:
- `.github/workflows/deploy-web.yml`
- `.github/workflows/deploy-api.yml`
- `.github/workflows/deploy-ia-analyze.yml`

E três `vercel.json` (um por serviço: `feedback-analytics-web`, `feedback-analytics-api-gateway`, `feedback-analytics-ia-analyze`), todos com `maxDuration: 300` — **valor que o plano free ignora e corta em ~60s** (causa provável do timeout). No destino: o worker passa a ser publicado via build/push de imagem Docker para a VM (ou `git pull` + `docker compose up -d` na VM); o front continua estático (`npm run build --prefix feedback-analytics-web` → publicar `dist/` no Cloudflare Pages). O `maxDuration` deixa de ser limitação porque o worker não roda mais como função serverless.

**3. Trocar a descoberta automática de URL/CORS por variáveis de ambiente explícitas.** Esse é o ponto mais delicado, porque há lógica **chumbada em domínios `.vercel.app`**:

- `feedback-analytics-api-gateway/src/index.ts` (linhas 45–157): `extractVercelProjectSuffix`, `isVercelProjectHostname`, `readVercelPairConfig`, `isAllowedByVercelProjectPair` — todo um mecanismo de **pareamento automático web/api por sufixo `.vercel.app`** e por `VERCEL_ENV=preview`. **Fora da Vercel isso vira código morto**: precisamos garantir que o CORS funcione apenas pela allowlist explícita.
- O caminho explícito **já existe e basta usar**: `readAllowedOrigins()` (linhas 98–117) lê `CORS_ALLOWED_ORIGINS` e `PUBLIC_SITE_URL`. Configurando essas vars com os domínios novos (ex.: o domínio do Cloudflare Pages e o do worker), o CORS funciona **sem depender de nada da Vercel**.
- `feedback-analytics-ia-analyze` é alcançado pela URL resolvida em `feedback-analytics-api-gateway/src/libs/iaAnalyze/resolvePrimaryBaseUrl.ts`: com `IA_ANALYZE_EXECUTION_MODE=remote` + `IA_ANALYZE_REMOTE_URL` apontando para o **novo host always-on**, o gateway fala com o worker certo. As vars já estão documentadas em `feedback-analytics-api-gateway/.env.example` (`IA_ANALYZE_REMOTE_URL`, `IA_ANALYZE_REMOTE_TOKEN`, `IA_ANALYZE_REMOTE_TIMEOUT_MS=280000`). Note que o timeout de 280s só faz sentido **quando o host destino aceita execuções longas** — exatamente o ganho desta etapa.
- Limpeza recomendada: marcar o pareamento `.vercel.app` como caminho legado (atrás de `CORS_ALLOW_VERCEL_PROJECT_PAIR`, que por padrão só liga em `VERCEL_ENV=preview`) e tratar a allowlist explícita como fonte da verdade no novo ambiente.

### Esboço de topologia alvo

```
Cliente/Gestor → Cloudflare Pages (frontend estático, grátis)
                      │  fetch /api → CORS por CORS_ALLOWED_ORIGINS
                      ▼
        API Gateway (Express)  ── pode ficar serverless (req. curtas) OU na VM
                      │ IA_ANALYZE_REMOTE_URL
                      ▼
        Worker ia-analyze (Docker, ALWAYS-ON)  ←  fila da etapa 03
                      │
                      ▼
        Supabase (Postgres + Auth + Storage)   ← inalterado na "Stack mínima"
```

## Riscos e decisões em aberto

- **Decisão (a) — "Stack mínima" vs "Self-host total":**
  - **Stack mínima (recomendada para o prazo):** mantém **Supabase** (Postgres, Auth, RLS, Storage) e move **apenas o worker** para a VM. Menos esforço, menos coisas para quebrar, e ainda assim demonstra Docker/deploy/portabilidade. Risco baixo.
  - **Self-host total:** subir Postgres próprio, autenticação própria e todos os serviços numa VM. **Mais esforço e mais superfície de risco** (backups, segurança, migrações de Auth), porém **muito mais material de TCC** (administração de banco, hardening, operação). Decisão honesta: só vale se sobrar tempo *depois* de a Stack mínima estar estável — não comece por aqui.
- **Decisão (b) — por que NÃO vamos separar os repositórios:** existe a tentação de quebrar o monorepo em 3 repos "para deixar o deploy independente". Não faremos, porque: (1) **as features são cross-cutting** — uma mudança de contrato toca `shared/interfaces`, gateway e front ao mesmo tempo; separar exigiria **PRs coordenados em 3 repositórios** para uma única mudança; (2) **o deploy já é independente hoje** (três workflows e quatro `vercel.json` separados) — separar repos **não compra** nada nesse ponto; (3) o custo (versionamento cruzado, sincronização de tipos) supera o ganho. Se a banca quiser fronteiras mais rígidas, reforçamos **dentro do monorepo** com Turborepo (build/cache por pacote) e regras de lint/import (impedir um pacote de importar internals de outro) — fronteira sem o custo de 3 repos.
- **Operação da VM:** uma máquina always-on é responsabilidade nossa (updates de SO, firewall, certificado TLS via Cloudflare/Caddy). Mitiga-se com uma imagem Docker reprodutível e um runbook curto.
- **"Soneca" no free tier:** se acabarmos em Render/Fly por algum motivo, o worker pode dormir e atrasar a primeira análise — aceitável para TCC, mas registrar como limitação.
- **Segredos e LGPD:** mover host implica mover variáveis sensíveis (chaves do Gemini, Supabase service role). Tratar junto da [etapa 07 — Segurança e LGPD](./07-seguranca-e-lgpd.md): segredos só por variável de ambiente do provedor, nunca no código.

## Como vamos saber que deu certo

- [ ] Uma análise de IA de um lote grande (≥ ~10–20 feedbacks) **termina sem erro de timeout** no ambiente novo.
- [ ] O frontend está publicado numa **CDN gratuita** (Cloudflare Pages) e carrega as telas normalmente.
- [ ] O worker `ia-analyze` roda como **container always-on** e responde no `/internal/health`.
- [ ] O CORS funciona **apenas pela allowlist explícita** (`CORS_ALLOWED_ORIGINS` / `PUBLIC_SITE_URL`), sem depender de nenhum mecanismo `.vercel.app`.
- [ ] O gateway encontra o worker por `IA_ANALYZE_REMOTE_URL` (sem fallback acidental para `localhost:4100`).
- [ ] **Custo mensal medido = R$ 0 a poucos reais**, documentado numa tabelinha de custo.
- [ ] Existe um **runbook de 1 página** ("como subir do zero noutro provedor") provando a portabilidade.

## Etapas de entrega

1. **Dockerizar o worker:** `Dockerfile` para o repositório `feedback-analytics-ia-analyze` + build funcionando localmente (`docker run` responde no `/internal/health`).
2. **Provisionar o host always-on:** criar a VM (Oracle Always Free), instalar Docker, subir o worker com `docker compose`, configurar firewall e TLS.
3. **Migrar o frontend para CDN:** publicar `feedback-analytics-web/dist` no Cloudflare Pages; ajustar a URL pública.
4. **Trocar descoberta por env explícito:** definir `CORS_ALLOWED_ORIGINS`, `PUBLIC_SITE_URL`, `IA_ANALYZE_EXECUTION_MODE=remote` e `IA_ANALYZE_REMOTE_URL`; validar CORS e a chamada gateway→worker fora da Vercel.
5. **Reescrever os deploys:** substituir/adaptar os workflows `deploy-*.yml` para publicar front na CDN e worker na VM (build+push de imagem ou `pull`+`compose up`).
6. **Documentar custo e portabilidade:** tabela de custo mensal + runbook curto de "como replicar noutro provedor".

## O que isso demonstra no TCC

- **Deploy e DevOps:** sair de um PaaS (Vercel) e operar a aplicação em mais de um provedor.
- **Containers:** empacotamento com Docker e execução reprodutível.
- **Portabilidade / "cloud-agnostic":** o mesmo código rodando em provedores diferentes graças a configuração por variáveis de ambiente (em vez de lógica chumbada a um host).
- **Análise de custo e arquitetura:** justificar serverless vs always-on, e a decisão consciente de monorepo vs multi-repo — argumentação de engenharia, não só código.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [03 — Análise assíncrona](./03-analise-assincrona.md) — cria o worker que esta etapa hospeda.
- [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md) — gestão de segredos e dados ao trocar de host.
