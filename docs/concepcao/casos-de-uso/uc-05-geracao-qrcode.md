# UC-05: Geração e Compartilhamento de QR Code

| Campo | Valor |
|---|---|
| **Ator** | Gestor |
| **Objetivo** | Controlar o status de coleta e distribuir o QR Code para os clientes finais |
| **Gatilho** | Gestor acessa a área de QR Code no dashboard (empresa, produto, serviço ou departamento) |

---

## Fluxo Principal (Caminho Feliz)

1. O gestor acessa a página de QR Code do escopo desejado.
2. O sistema carrega e exibe o status atual do QR Code (ativo ou inativo) e o código gerado.
3. O gestor pode ativar ou desativar o QR Code usando o botão de controle — com confirmação imediata via toast e atualização do estado na tela.
4. Para distribuir o QR Code, o gestor escolhe uma das três opções:
   - **Download:** salva o QR Code como imagem `.png` no dispositivo, com o nome da empresa no arquivo.
   - **Copiar link:** copia o link do formulário de feedback para a área de transferência. Um indicador visual confirma a cópia por 2 segundos.
   - **Compartilhar:** abre a API nativa de compartilhamento do dispositivo com o título, descrição e link de coleta.
5. O QR Code ou link é distribuído para os clientes finais (impresso, enviado por mensagem, etc.).

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Erro ao carregar o status do QR Code | Exibe mensagem de erro no painel, mas a página permanece acessível |
| Erro ao ativar ou desativar o QR Code | Exibe toast de erro e mensagem na tela — o estado não é alterado |
| Erro no download da imagem do QR Code | Exibe toast de erro "Não foi possível baixar o QR Code" |
| API de compartilhamento não suportada pelo navegador | O sistema copia o link automaticamente para a área de transferência, sem exibir mensagem alternativa |
| QR Code desativado | O formulário público bloqueia envios — clientes que tentam acessar o link veem tela de erro |

---

## Base para Teste E2E

> **O E2E atual deste UC é apenas um smoke test de carregamento de página** ([uc-05-geracao-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-05-geracao-qrcode.spec.ts)): verifica que a página `/user/qrcode/enterprise` carrega e exibe o QR Code ou o botão de controle. Os fluxos de **ação** (ativar/desativar, download, copiar link, compartilhar) **não estão cobertos por E2E**. Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC05-01]** ✅ *Coberto E2E (smoke)* - Carregamento: a página do QR Code carrega com os dados da empresa, exibindo o QR Code (canvas/img/svg) ou o botão de ativar/desativar. (Spec: `[CT-UC05-01] Página do QR Code carrega com dados da empresa`.) **Não** cobre o clique de ativar/desativar.
- **[CT-UC05-02]** 📝 *Planejado / não implementado* - Caminho feliz — ativar/desativar: gestor clica no botão de controle, deve exibir toast de confirmação e o estado visual do QR Code deve refletir a mudança imediatamente.
- **[CT-UC05-03]** 🚫 *Não é possível testar com Playwright* - Caminho feliz — download: gestor clica em "Download", deve disparar o download de um arquivo `.png` com o nome da empresa no título.
- **[CT-UC05-04]** 📝 *Planejado / não implementado* - Caminho feliz — copiar link: gestor clica em "Copiar link", deve copiar a URL correta para a área de transferência e exibir o indicador visual de cópia por 2 segundos.
- **[CT-UC05-05]** 🚫 *Não é possível testar com Playwright* - Caminho feliz — compartilhar: em ambiente com `navigator.share` disponível, clicar em "Compartilhar" deve invocar a API nativa com os dados corretos.
- **[CT-UC05-06]** 📝 *Planejado / não implementado* - Exceção — share API indisponível: em ambiente sem `navigator.share`, clicar em "Compartilhar" deve copiar o link para a área de transferência automaticamente.
- **[CT-UC05-07]** 📝 *Planejado / não implementado* - Exceção — QR desativado: acessar o link de formulário de uma empresa com QR Code desativado deve exibir tela de erro no formulário público.
