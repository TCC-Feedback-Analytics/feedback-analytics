# UC-05: Geração e Compartilhamento de QR Code

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Controlar o status de coleta e distribuir o formulário aos clientes finais pelos canais de coleta: QR Code, link e etiqueta NFC |
| **Gatilho** | Gestor acessa a seção "Canais de coleta" da Avaliação da empresa (menu "Configuração da coleta" → "Avaliação da empresa", `/user/edit/feedback-general`) ou da tela de um item do catálogo (UC-07) |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a tela da avaliação desejada: a **Avaliação da empresa** (`/user/edit/feedback-general`) ou a tela de um item do catálogo (`/user/edit/feedback/:kind/:itemId`). A antiga rota `/user/qrcode/enterprise` redireciona para a Avaliação da empresa.
2. Na seção **"Canais de coleta"** ("Por onde seus clientes respondem"), o sistema exibe o estado da coleta ("Recebendo respostas" ou "Pausado") e, com ela ativa, o QR Code gerado. Na mesma tela ficam as seções **Perguntas** e **Campo de comentário** daquela avaliação.
3. O gestor liga ou pausa a coleta pelo botão "Ativar coleta" / "Pausar coleta". O interruptor vale para todos os canais de uma vez; o sistema confirma com o toast "QR Code ativado!" ou "QR Code desativado!" e atualiza o estado na tela.
4. Para distribuir o formulário, o gestor usa um dos canais. Cada canal leva a sua marca `canal` na URL, para as métricas por canal (UC-09):
   - **QR Code — "Baixar QR Code":** salva o QR Code como imagem `.png`, com o nome da empresa (ou do item) no arquivo. A tela traz os passos e dicas de impressão.
   - **Link — "Copiar link":** copia o link do formulário para a área de transferência; o botão mostra "Link copiado!" por 2 segundos.
   - **Link — "Compartilhar":** abre a API nativa de compartilhamento do dispositivo com o título, o texto e o link de coleta.
   - **Etiqueta NFC:** no Chrome do Android, "Gravar etiqueta" grava o endereço numa etiqueta NFC encostada no celular (Web NFC). Fora dele, "Copiar endereço da etiqueta" copia o endereço, e a tela ensina a gravar por um app (como no iPhone). A etiqueta abre o mesmo formulário, sem câmera e sem app, no iPhone e no Android.
5. O QR Code, o link ou a etiqueta chegam aos clientes finais (impresso, enviado por mensagem, colado no balcão etc.).

> **No Dashboard.** A conta nova vê os "Primeiros passos", com "Ativar QR Code" (o QR geral da Avaliação da empresa) e "Testar o formulário (opcional)", que abre o formulário numa janela com `canal=teste`. Depois disso, o cartão de compartilhamento do Dashboard aponta para a tela de canais do escopo selecionado.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Erro ao carregar o status da coleta | Exibe mensagem de erro na seção, mas a página permanece acessível |
| Erro ao ativar ou pausar a coleta | Exibe o toast "Erro na operação" — o estado não é alterado |
| Erro no download da imagem do QR Code | Exibe o toast "Erro no download" com "Não foi possível baixar o QR Code" |
| API de compartilhamento não suportada pelo navegador | O sistema copia o link automaticamente para a área de transferência, sem exibir mensagem alternativa |
| Coleta pausada | Os três canais param juntos: o formulário público mostra a tela de erro "QR Code indisponível" (UC-04). O card da etiqueta avisa que ela usa a mesma coleta do QR Code |
| Falha ao gravar a etiqueta NFC | Mostra o motivo: permissão negada, celular sem gravação pelo navegador, NFC desligado ou etiqueta afastada antes do fim / sem espaço (recomenda NTAG215) |

---

## Base para Teste E2E

> A suíte Playwright (e2e) deste UC foi **removida**; ela cobria apenas um **smoke test de carregamento de página** (verificava que a página `/user/qrcode/enterprise` carregava e exibia o QR Code ou o botão de controle), e os fluxos de **ação** (ativar/desativar, download, copiar link, compartilhar) nunca tiveram E2E. Os cenários agora são executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md). Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC05-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página do QR Code carrega com os dados da empresa, exibindo o QR Code (canvas/img/svg) ou o botão de ativar/desativar. (Spec: `[CT-UC05-01] Página do QR Code carrega com dados da empresa`.) **Não** cobre o clique de ativar/desativar.
- **[CT-UC05-02]** 📝 *Planejado / não implementado* - Caminho feliz — ativar/desativar: gestor clica no botão de controle, deve exibir toast de confirmação e o estado visual do QR Code deve refletir a mudança imediatamente.
- **[CT-UC05-03]** 🚫 *Não é possível testar com Playwright* - Caminho feliz — download: gestor clica em "Download", deve disparar o download de um arquivo `.png` com o nome da empresa no título.
- **[CT-UC05-04]** 📝 *Planejado / não implementado* - Caminho feliz — copiar link: gestor clica em "Copiar link", deve copiar a URL correta para a área de transferência e exibir o indicador visual de cópia por 2 segundos.
- **[CT-UC05-05]** 🚫 *Não é possível testar com Playwright* - Caminho feliz — compartilhar: em ambiente com `navigator.share` disponível, clicar em "Compartilhar" deve invocar a API nativa com os dados corretos.
- **[CT-UC05-06]** 📝 *Planejado / não implementado* - Exceção — share API indisponível: em ambiente sem `navigator.share`, clicar em "Compartilhar" deve copiar o link para a área de transferência automaticamente.
- **[CT-UC05-07]** 📝 *Planejado / não implementado* - Exceção — coleta pausada: acessar o link de formulário de uma empresa com a coleta pausada deve exibir tela de erro no formulário público.
