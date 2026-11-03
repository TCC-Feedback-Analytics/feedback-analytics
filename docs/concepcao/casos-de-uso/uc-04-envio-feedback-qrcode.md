# UC-04: Envio de Feedback via QR Code

| Campo | Valor |
|---|---|
| **Ator** | Cliente do estabelecimento |
| **Objetivo** | Enviar uma avaliação sobre a experiência com a empresa, produto, serviço ou departamento |
| **Gatilho** | Cliente escaneia o QR Code, abre o link compartilhado ou encosta o celular na etiqueta NFC da empresa |

---

## Fluxo Principal (Caminho Feliz)

1. O cliente escaneia o QR Code (ou abre o link, ou encosta o celular na etiqueta NFC) e o navegador abre o formulário público (`/feedback/qrcode`). Os três canais abrem o mesmo endereço; o que muda é a marca `canal` na URL (`qr`, `link` ou `nfc`), que o formulário repassa no envio e o gateway grava no feedback.
2. O sistema lê os parâmetros da URL: identificador da empresa (`enterprise`), ponto de coleta (`collection_point`) e item do catálogo (`item`), quando aplicável.
3. O sistema busca na API a empresa e o ponto de coleta QR **ativo** do escopo (avaliação da empresa ou item do catálogo).
4. O formulário é carregado com o nome da empresa (e do item, quando houver), as perguntas ativas do escopo (de 0 a 3) e o campo de comentário configurado para o escopo.
5. O cliente preenche:
   - A nota de 1 a 5 estrelas (obrigatória)
   - As respostas às perguntas do escopo, cada uma na escala **Péssimo / Ruim / Mediana / Boa / Ótima** (obrigatórias quando existem)
   - As respostas às subperguntas, quando presentes (obrigatórias)
   - O comentário escrito, opcional. O texto acima do campo depende do escopo: o convite padrão ("Conte-nos mais sobre sua experiência"), uma pergunta própria do escopo ou nenhum campo, quando a empresa o ocultou
6. Opcionalmente, o cliente abre os dados pessoais e informa nome, e-mail e gênero.
7. O cliente clica em "Enviar Feedback".
8. O sistema valida a nota, as perguntas e as subperguntas antes de enviar.
9. O sistema registra o feedback e exibe a tela "Feedback enviado".

> **Formulário de teste.** O "Testar o formulário" do Dashboard abre o mesmo formulário numa janela, com `canal=teste`. A resposta é gravada, aparece na lista com a marca "Teste" e não entra nas métricas nem na análise da IA.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Identificador da empresa ausente na URL | Exibe a tela de erro "Não foi possível continuar" com "ID da empresa não encontrado na URL. Verifique o QR Code." — o formulário não é carregado |
| Empresa não encontrada | Exibe a tela de erro com "Empresa não encontrada. Verifique se o QR Code é válido." — o formulário não é carregado |
| Sem ponto de coleta QR ativo para o escopo (coleta pausada na empresa ou no item) | Exibe a tela de erro com "QR Code indisponível: não há ponto de coleta ativo para este código. Verifique o QR Code ou contate a empresa." — o formulário não é carregado |
| Escopo sem perguntas ativas | O formulário mostra só a nota e o comentário (quando o campo não está oculto) e aceita o envio |
| Nota não selecionada | Bloqueia o envio e exibe "Por favor, selecione uma avaliação." |
| Perguntas não respondidas | Bloqueia o envio e exibe "Responda todas as perguntas antes de enviar." |
| Subperguntas não respondidas | Bloqueia o envio e exibe "Responda todas as subperguntas antes de enviar." |
| Comentário em branco | Aceita o envio: o feedback fica só com as estrelas e as respostas, não vai para a IA e não conta como "aguardando análise". Com o campo oculto no escopo, nenhum texto é enviado |
| Aparelho já enviou feedback para este ponto de coleta hoje (anti-spam diário) | O gateway recusa com `409 DEVICE_ALREADY_SUBMITTED` e a Web mostra "Obrigado por participar": "Este dispositivo já enviou uma resposta para esta empresa hoje. Você poderá compartilhar uma nova opinião amanhã." O aparelho é identificado no backend por um fingerprint de user agent, IP e dia |
| Aparelho bloqueado | O gateway recusa com `403 DEVICE_BLOCKED` e o formulário mostra "Seu dispositivo está temporariamente bloqueado para novos envios." |
| Falha de rede ou erro do servidor ao enviar | Exibe o toast "Erro ao enviar feedback" e a mensagem inline no formulário — o cliente pode corrigir e tentar novamente |

---

## Base para Teste E2E

> Os cenários deste UC eram cobertos por testes Playwright (e2e), agora **removidos**; passaram a ser executados manualmente — veja o [runbook de testes manuais do Web](../../guias/testes/manuais-web.md).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC04-01]** ✅ *Coberto E2E (skip condicional)* - Caminho feliz: empresa ativa; QR Code ativo; perguntas dinâmicas configuradas; dispositivo sem envio anterior no dia. Acessa a URL, seleciona nota Likert, adiciona comentário, responde perguntas e envia. O teste contém `test.skip(!TEST_ENTERPRISE_ID, ...)` — é **pulado** quando a variável `E2E_TEST_ENTERPRISE_ID` não está configurada. (Spec: `[CT-UC04-01] Envio válido exibe confirmação de feedback recebido`.)
- **[CT-UC04-02]** 📝 *Planejado / não implementado* - Dispositivo duplicado (Exceção): tentar enviar feedback a partir do mesmo dispositivo no mesmo dia deve exibir tela de "feedback já registrado". Não há teste E2E com este ID no spec.
- **[CT-UC04-03]** ✅ *Coberto E2E* - Empresa inválida (Exceção): acessar a URL com identifier de empresa inexistente deve exibir tela de empresa não encontrada / erro, sem renderizar o formulário. (Spec: `[CT-UC04-03] Acesso com enterprise_id inválido exibe empresa não encontrada`.)
- **[CT-UC04-04]** 🔵 *Unidade já atende* - Nota não selecionada (Exceção): tentar enviar o formulário sem selecionar a nota em estrelas deve bloquear a submissão.
- **[CT-UC04-05]** 🔵 *Unidade já atende* - Comentário vazio: enviar sem preencher o comentário deve ser **aceito** — o comentário é opcional desde a configuração do campo de comentário por escopo.
- **[CT-UC04-06]** 🔵 *Unidade já atende* - Perguntas não respondidas (Exceção): deixar ao menos uma pergunta dinâmica sem resposta deve bloquear a submissão do formulário.
