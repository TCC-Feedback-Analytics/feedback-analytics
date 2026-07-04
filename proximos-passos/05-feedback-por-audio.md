# 05 — Feedback por áudio

> **Em uma frase:** deixar o cliente **falar** sua opinião gravando um áudio, em vez de digitar — e o gestor decide se o formulário pede texto, áudio ou deixa o cliente escolher.

| Campo | Valor |
|---|---|
| **Status** | 🔵 Planejado |
| **Quando** | Mês 3-4 |
| **Esforço** | Alto |
| **Prioridade** | 🟡 Importante (Fase 1 é essencial; a transcrição por IA da Fase 2 é "se sobrar tempo") |
| **Depende de** | Implementar o **Supabase Storage** (armazenamento de arquivos, ainda não existe) · [03 — Análise assíncrona](./03-analise-assincrona.md) (a fila/worker que processa coisas demoradas em segundo plano) · [04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md) (a "porta" de troca de IA) |
| **Camadas afetadas** | Frontend público · Backend · Banco · Storage (arquivos) · Serviço de IA |

## Para qualquer leitor

Hoje, para deixar um comentário, o cliente precisa **digitar** no celular. Isso afasta muita gente: quem está com pressa na fila, quem tem dificuldade para escrever, quem é mais velho, ou simplesmente quem acha chato teclar num formulário. O resultado é que muitos avaliam só com a nota (as estrelinhas) e não contam *o porquê* — e é justamente o "porquê" que tem valor para o gestor.

A ideia desta etapa é simples: oferecer um **botão de gravar áudio**, do mesmo jeito que num aplicativo de mensagens. O cliente aperta, fala o que sentiu, ouve para conferir e envia. Falar é mais rápido e mais natural do que escrever — e tende a trazer comentários mais ricos e espontâneos.

Quem manda nessa escolha é o **gestor**. Numa tela de configuração ele define como quer receber as respostas abertas: **só texto**, **só áudio**, ou **"o cliente escolhe"** (mostra os dois e cada pessoa usa o que preferir). Assim, um restaurante movimentado pode preferir áudio (mais rápido na correria), enquanto um consultório pode preferir texto.

Há um detalhe importante de honestidade: guardar e ouvir o áudio é a parte mais fácil. **Entender o que foi dito** (transcrever a fala em texto para a IA analisar sentimento e temas) é a parte cara e demorada. Por isso vamos entregar em duas fases: primeiro o "gravar, guardar e ouvir" funcionando de ponta a ponta; depois, se o tempo permitir, a transcrição automática.

## O que muda para quem usa o sistema

**Para o cliente que dá o feedback:**
- Pode **falar** em vez de digitar — aperta gravar, fala, ouve, regrava se quiser e envia.
- Menos esforço, especialmente no celular e em ambientes de pressa (fila, balcão, mesa do restaurante).
- Se o celular dele não suportar gravação, o formulário **volta automaticamente para o campo de texto** — ninguém fica sem conseguir responder.

**Para o gestor:**
- Escolhe na configuração se o formulário pede **texto**, **áudio** ou **deixa o cliente decidir**.
- No painel, consegue **ouvir** o áudio de cada feedback (player simples).
- Na Fase 2, vê também a **transcrição** (o texto do que foi falado) e os mesmos insights de sentimento/temas que já existem hoje — agora alimentados pela fala.

## Como vai funcionar

**Antes (hoje):** o formulário público tem sempre um campo de texto obrigatório ("Conte-nos mais sobre sua experiência"). Quem não quer digitar, deixa em branco a parte mais valiosa.

**Depois:**

1. O gestor configura o modo de resposta aberta (texto / áudio / cliente escolhe).
2. No celular do cliente, conforme essa configuração, aparece o **gravador** em vez (ou além) do campo de texto.
3. O cliente grava, ouve para conferir e envia junto com a nota.
4. O áudio é guardado num **cofre de arquivos** (o Storage), e o feedback fica registrado apontando para esse arquivo.
5. **Fase 1 termina aqui:** o gestor já consegue ouvir tudo no painel.
6. **Fase 2 (depois):** em segundo plano, sem travar o cliente, o áudio é **transcrito** em texto e entra no mesmo pipeline de análise que já existe — sentimento, temas, palavras-chave.

O ponto-chave da Fase 2 é *onde* a transcrição acontece. Transcrever um minuto de áudio é uma tarefa demorada — não pode rodar "na hora", enquanto o cliente espera a tela carregar. Por isso ela vai para a **fila/worker** que criamos na [etapa 03](./03-analise-assincrona.md): o cliente envia e segue a vida; a transcrição roda atrás das cortinas e o resultado aparece quando estiver pronto.

## Por dentro — detalhes técnicos

> Esta seção é para a equipe de desenvolvimento; quem não é da área pode pular.

### Por que esta etapa "amarra" 03 e 04

Esta funcionalidade é a demonstração prática de duas etapas anteriores juntas:

- **Worker/fila (etapa 03):** transcrição de áudio é o caso de uso perfeito de processamento assíncrono. Não dá para transcrever dentro da requisição HTTP do formulário (mesma armadilha de timeout serverless da análise síncrona). Ela vira um **job** enfileirado e processado pelo worker.
- **Porta de provedor de LLM (etapa 04):** o `gemini-2.5-flash` que já usamos (`feedback-analytics-ia-analyze/src/providers/gemini.provider.ts`, modelo hardcoded na linha 134) é **multimodal** — o SDK `@google/genai` aceita áudio via partes `inlineData`/`fileData`. Ou seja, dá para transcrever (e até analisar direto) reusando a interface `IaApiClient` (`feedback-analytics-ia-analyze/types/iaApiClient.types.ts`), sem fornecedor novo. A transcrição passa a ser mais uma operação por trás da mesma "porta".

### Pré-requisito: Supabase Storage (infra nova)

Hoje **não há Storage** no projeto — não existe bucket em `database/sql/` nem chamada `.storage` no código. Precisamos:

- Criar um bucket (ex.: `feedback-audio`), **privado**.
- Definir limites: tamanho máximo (ex.: ~5 MB ≈ 1 min de fala), formatos aceitos (`audio/webm`, `audio/mp4`/`m4a` para iOS), retenção.
- O cliente **não está logado** (papel `anon`). Em vez de liberar insert anônimo direto no bucket, o Gateway gera uma **URL assinada de upload** (signed upload URL) com validade curta, e o navegador faz o PUT nela. Isso limita abuso e mantém o controle no backend.
- Para o gestor ouvir no painel, o Gateway gera **URL assinada de leitura** sob demanda (o bucket nunca fica público).
- Bônus que justifica o investimento: o mesmo Storage serve para **upload de logo da empresa** e outros anexos — não é custo exclusivo do áudio.

### Banco — tabela `feedback` (`database/sql/tables/public.feedback.sql`)

Hoje a coluna `message` é `text NOT NULL` (linha 8). Mudanças:

| Coluna | Tipo | Para quê |
|---|---|---|
| `message_type` | `text` (`'TEXT'` \| `'AUDIO'`) | distingue o canal da resposta aberta |
| `audio_path` | `text` (nullable) | caminho do arquivo no bucket |
| `audio_duration_seconds` | `int` (nullable) | duração, para validação e UI |
| `transcription` | `text` (nullable) | texto transcrito (preenchido na Fase 2) |

- Tornar `message` **anulável** (`message_type='AUDIO'` ⇒ `message` pode ser `NULL`). Alternativa: gravar a transcrição na própria `message` para o pipeline não mudar — decisão em aberto (ver riscos).
- Recomendado um `CHECK` de coerência: `message_type='TEXT'` exige `message NOT NULL`; `message_type='AUDIO'` exige `audio_path NOT NULL`. (O banco já usa triggers de validação de coerência em outras tabelas — segue o padrão.)
- **RLS:** a policy de insert anônimo `"Anon pode inserir feedback via QR_CODE com checks"` (linha 39) valida `cp.type='QR_CODE'`, dispositivo não bloqueado etc. Ela precisa aceitar o novo formato (linha com `audio_path` em vez de `message`) **sem afrouxar** os checks de segurança existentes.
- Onde o gestor configura o modo: avaliar uma coluna em `collecting_data_enterprise` (modo global) e/ou granularidade por item de catálogo (`catalog_items`), conforme o nível desejado.

### Contrato e validação (`shared/schemas/public/feedbackSchema.ts`)

Hoje `feedbackBaseSchema` exige `message: z.string().min(3).max(5000)`. Tornar a resposta aberta um **campo discriminado**:

- `message_type: z.enum(['TEXT','AUDIO'])`.
- Quando `'TEXT'`: `message` obrigatória (regra atual).
- Quando `'AUDIO'`: `message` opcional + `audio_path` (ou referência ao upload assinado) obrigatório, com `audio_duration_seconds` dentro dos limites.
- Atenção: mexer neste schema é **breaking change** para o formulário público — versionar com cuidado, manter `'TEXT'` como default para não quebrar quem já consome.

### Frontend público

- Novo campo `fieldAudioMessage.tsx` em `feedback-analytics-web/components/public/forms/fields/fieldsQRCode/`: gravar / regravar / ouvir antes de enviar, usando a **API MediaRecorder** do navegador.
- O `formQRCodeFeedback.tsx` passa a renderizar `FieldMessage` **ou** `FieldAudioMessage` (ou ambos, no modo "cliente escolhe") conforme a config recebida.
- **Fallback obrigatório:** se `MediaRecorder` não estiver disponível ou o usuário negar o microfone, cair de volta para o textarea — ninguém pode ficar travado.
- Ajustar o controller `feedback-analytics-web/pages/public/qrcode/useQrCodeFeedbackController.ts`: pedir a URL assinada ao Gateway, fazer o upload do blob, então enviar o feedback com `audio_path`.

### Backend (`feedback-analytics-api-gateway/src/controllers/public/qrcode.controller.ts`)

- Novo endpoint para emitir a **URL assinada de upload** (valida que o ponto de coleta é válido/ativo antes de assinar).
- No insert do feedback: validar `message_type`, tamanho/duração e a existência do `audio_path`; gravar as novas colunas.
- Fase 2: ao gravar um feedback de áudio, **enfileirar um job de transcrição** na fila da etapa 03 (não transcrever inline).

### Serviço de IA — transcrição (Fase 2)

Duas opções, **decisão em aberto**:

- **Opção A — reusar o Gemini multimodal.** Estender o provider para enviar o áudio (parte `inlineData`/`fileData`) e pedir a transcrição (e, opcionalmente, a análise direto do áudio). Sem fornecedor novo; reusa a porta da etapa 04. Atenção a custo (tokens de áudio) e latência.
- **Opção B — STT dedicado** (Whisper/Deepgram/Google Speech-to-Text): transcreve antes, e o pipeline de análise atual segue intacto. Mais peças, custo separado.
- Em ambos: definir **fallback** se a transcrição falhar (guardar o áudio sem análise e marcar para retry, em vez de descartar).

## Riscos e decisões em aberto

- **Storage é pré-requisito duro:** nada disso anda antes do bucket + URLs assinadas + policies existirem. É o maior gargalo da etapa.
- **Custo recorrente:** transcrição (Gemini multimodal ou STT dedicado) adiciona custo por minuto de áudio. Estimar por volume esperado — conecta com [08 — Infraestrutura e custo](./08-infraestrutura-e-custo.md).
- **Qualidade da transcrição:** coleta é **presencial** → ruído de ambiente, sotaques regionais e português-BR podem degradar o resultado. Precisamos medir antes de prometer.
- **LGPD — áudio é PII mais sensível que texto:** a voz é dado pessoal e pode conter terceiros mencionados. Consentimento explícito, retenção definida e acesso restrito são obrigatórios — tratado em [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md).
- **Compatibilidade do `MediaRecorder`:** comportamento e formatos variam por navegador; o iOS/Safari tem particularidades de codec (tende a `mp4`/`m4a`). O fallback para texto é inegociável.
- **`message` anulável vs. transcrição em `message`:** decidir se a transcrição vira a `message` (pipeline não muda) ou fica numa coluna própria `transcription` (mais limpo, mas exige ajustar o builder de prompt).
- **Versionamento do contrato:** mudar o `feedbackSchema` afeta o formulário público em produção — rollout cuidadoso, com `'TEXT'` como default.

## Como vamos saber que deu certo

**Fase 1 (essencial):**
- [ ] Bucket privado existe, com upload via URL assinada e leitura via URL assinada (nunca público).
- [ ] No modo áudio, o cliente grava, ouve, regrava e envia pelo celular (Android e iOS).
- [ ] Em navegador sem suporte, o formulário cai para texto automaticamente.
- [ ] O áudio fica salvo e o gestor consegue **ouvi-lo** no painel.
- [ ] O gestor escolhe texto / áudio / "cliente escolhe" na configuração e isso reflete no formulário público.
- [ ] As RLS de insert anônimo continuam barrando dispositivos bloqueados e pontos de coleta inativos.

**Fase 2 (stretch):**
- [ ] A transcrição roda no **worker** (etapa 03), fora da requisição HTTP, sem timeout.
- [ ] O texto transcrito entra no pipeline e gera sentimento/temas como um feedback de texto.
- [ ] Falha de transcrição não perde o áudio (retry/marcação), e há uma métrica de taxa de falha.

## Etapas de entrega

1. **Storage (pré-requisito):** bucket privado + URL assinada de upload/leitura + policies + limites de tamanho/formato. Já habilita também o upload de logo.
2. **Fase 1 — captura e guarda (sem IA):** gravador no formulário (com fallback), colunas novas no `feedback`, ajuste de RLS e schema, flag de configuração do gestor e player no painel. **Entrega valor completa por si só.**
3. **Fase 2 — transcrição + análise (stretch):** job de transcrição na fila (etapa 03), provider multimodal/STT (etapa 04), plug no pipeline existente.
4. **Polimento:** limites finos, retry, métrica de falha de transcrição, modo "cliente escolhe" refinado e consentimento LGPD no formulário.

## O que isso demonstra no TCC

- **Armazenamento de mídia em nuvem:** bucket privado, URLs assinadas e controle de acesso a arquivos sensíveis.
- **IA multimodal:** uso de um modelo que entende áudio, não só texto — e como uma boa abstração (a porta `IaApiClient`) permite essa extensão sem reescrever o motor.
- **Pipeline de processamento de mídia assíncrono:** captura → armazenamento → fila → transcrição → análise, sem travar o usuário, evidenciando arquitetura orientada a tarefas.
- **Engenharia honesta de escopo:** decompor uma feature cara em Fase 1 entregável + Fase 2 stretch, com riscos (custo, LGPD, compatibilidade) declarados.

## Relacionado

- [⟵ Roadmap geral](./README.md)
- [03 — Análise assíncrona](./03-analise-assincrona.md) — a fila/worker que processa a transcrição em segundo plano
- [04 — Provedor de LLM configurável](./04-provedor-de-llm-configuravel.md) — a porta reusada para o Gemini multimodal
- [07 — Segurança e LGPD](./07-seguranca-e-lgpd.md) — tratamento do áudio como dado pessoal sensível
