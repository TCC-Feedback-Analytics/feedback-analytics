# UC-04: Envio de Feedback via QR Code

| Campo | Valor |
|---|---|
| **Ator** | Cliente do estabelecimento |
| **Objetivo** | Enviar uma avaliação sobre a experiência com a empresa, produto, serviço ou departamento |
| **Gatilho** | Cliente escaneia o QR Code disponibilizado pela empresa |

---

## Fluxo Principal (Caminho Feliz)

1. O cliente escaneia o QR Code e o navegador abre a URL do formulário.
2. O sistema lê os parâmetros da URL: identificador da empresa, ponto de coleta e item do catálogo (quando aplicável).
3. O sistema valida se a empresa existe e está ativa via API.
4. O formulário é carregado com as perguntas configuradas pela empresa.
5. O cliente preenche os campos obrigatórios:
   - Respostas às perguntas de avaliação configuradas pela empresa, cada uma com escala Likert: **Péssimo / Ruim / Mediana / Boa / Ótima**
   - Comentário escrito
   - Respostas às subperguntas (quando presentes)
6. Opcionalmente, o cliente informa seus dados pessoais: nome, e-mail e gênero.
7. O cliente clica em "Enviar".
8. O sistema valida todos os campos obrigatórios antes de enviar.
9. O sistema registra o feedback e exibe a tela de agradecimento.

---

## Exceções

| Situação | O que o sistema faz |
|---|---|
| Identificador da empresa ausente na URL | Exibe tela de erro fatal — o formulário não é carregado |
| Empresa não encontrada, inativa ou item do catálogo inativo | Exibe tela de erro fatal — o formulário não é carregado |
| Perguntas dinâmicas não configuradas para este QR Code | Bloqueia o envio e exibe mensagem no formulário orientando o cliente |
| Perguntas de avaliação não respondidas | Bloqueia o envio e exibe mensagem "Responda as X perguntas antes de enviar" |
| Comentário não preenchido | Bloqueia o envio e exibe mensagem "Por favor, escreva seu feedback" |
| Subperguntas não respondidas | Bloqueia o envio e exibe mensagem solicitando que todas as subperguntas sejam respondidas |
| Dispositivo já enviou feedback para este ponto de coleta hoje | O sistema aceita o envio mas retorna o estado de "já enviado" — exibe tela informando que o feedback já foi registrado e agradece |
| Falha de rede ou erro do servidor ao enviar | Exibe toast de erro e mensagem inline no formulário — o cliente pode corrigir e tentar novamente |

---

## Base para Teste E2E

> Os testes E2E já estão implementados no Playwright ([uc-04-envio-feedback-qrcode.spec.ts](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/blob/main/e2e/uc-04-envio-feedback-qrcode.spec.ts)).
> Cada cenário abaixo possui a sua respectiva classificação e estratégia de execução mapeada no [Plano de Teste Estratégico](../../guias/testes/plano-estrategico.md).

**Cenários a cobrir:**

- **[CT-UC04-01]** ✅ *Coberto E2E (skip condicional)* - Caminho feliz: empresa ativa; QR Code ativo; perguntas dinâmicas configuradas; dispositivo sem envio anterior no dia. Acessa a URL, seleciona nota Likert, adiciona comentário, responde perguntas e envia. O teste contém `test.skip(!TEST_ENTERPRISE_ID, ...)` — é **pulado** quando a variável `E2E_TEST_ENTERPRISE_ID` não está configurada. (Spec: `[CT-UC04-01] Envio válido exibe confirmação de feedback recebido`.)
- **[CT-UC04-02]** 📝 *Planejado / não implementado* - Dispositivo duplicado (Exceção): tentar enviar feedback a partir do mesmo dispositivo no mesmo dia deve exibir tela de "feedback já registrado". Não há teste E2E com este ID no spec.
- **[CT-UC04-03]** ✅ *Coberto E2E* - Empresa inválida (Exceção): acessar a URL com identifier de empresa inexistente deve exibir tela de empresa não encontrada / erro, sem renderizar o formulário. (Spec: `[CT-UC04-03] Acesso com enterprise_id inválido exibe empresa não encontrada`.)
- **[CT-UC04-04]** 🔵 *Unidade já atende* - Nota não selecionada (Exceção): tentar enviar o formulário sem selecionar a avaliação Likert deve bloquear a submissão.
- **[CT-UC04-05]** 🔵 *Unidade já atende* - Comentário vazio (Exceção): tentar enviar sem preencher a mensagem escrita de comentário deve bloquear a submissão.
- **[CT-UC04-06]** 🔵 *Unidade já atende* - Perguntas não respondidas (Exceção): deixar ao menos uma pergunta dinâmica sem resposta deve bloquear a submissão do formulário.
