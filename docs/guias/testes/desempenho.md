# Testes de Desempenho

Esta página guarda as medições de desempenho do site e da API em produção, o método usado e como repeti-las. Os números são os mesmos da seção 24 do documento de especificação do PFC (Gráfico 7).

---

## 1. Ferramentas e método

| Item | Como foi feito |
| --- | --- |
| **Site** | [PageSpeed Insights](https://pagespeed.web.dev/), do Google, que roda o Lighthouse 13.6.0 em um celular emulado (Moto G Power, 4G lento) e em um computador. Cada análise dá notas de 0 a 100 para desempenho, acessibilidade, práticas recomendadas e SEO. |
| **Páginas** | Página inicial (`/`), login (`/login`), cadastro (`/register`) e Política de Privacidade (`/privacidade`), em `https://feedback-analytics-web.vercel.app`. |
| **Repetições** | Antes da otimização, três análises por página, com a mediana de cada valor. Depois, uma análise por página (duas no login). |
| **Dados de usuários reais** | O PageSpeed mostra "Nenhum dado" nessa parte, porque o Google só publica dados de campo (CrUX) de sites com muito acesso. Valem os dados de laboratório. |
| **API** | 30 requisições `GET /api/health` ao API Gateway em produção, com 2 s de intervalo, medindo o tempo total de cada uma com `curl`. |

O Speed Insights da Vercel não foi usado porque só coleta dados no plano pago, e os logs de requisição do plano gratuito ficam guardados por pouco tempo.

### Métricas

| Sigla | Nome | O que mede |
| --- | --- | --- |
| FCP | First Contentful Paint | Quando aparece o primeiro texto ou imagem. |
| LCP | Largest Contentful Paint | Quando aparece o maior elemento visível. É a métrica que mais pesa na nota. |
| TBT | Total Blocking Time | Quanto tempo a página fica travada por JavaScript. |
| CLS | Cumulative Layout Shift | Quanto a tela "pula" enquanto carrega (0 é o ideal). |
| SI | Speed Index | Quão rápido o conteúdo visível vai sendo preenchido. |

---

## 2. Antes da otimização (18/11/2026)

Mediana de três análises.

| Página | Aparelho | Desempenho | FCP | LCP | TBT | CLS | SI |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Inicial | Celular | **77** | 1,2 s | 6,5 s | 30 ms | 0 | 1,8 s |
| Inicial | Computador | 98 | 0,3 s | 1,1 s | 10 ms | 0 | 0,5 s |
| Login | Celular | 100 | 1,2 s | 1,2 s | 0 ms | 0 | 1,2 s |
| Login | Computador | 100 | 0,3 s | 0,3 s | 0 ms | 0 | 0,4 s |
| Cadastro | Celular | 100 | 1,2 s | 1,2 s | 50 ms | 0,043 | 1,2 s |
| Cadastro | Computador | 100 | 0,3 s | 0,3 s | 10 ms | 0 | 0,4 s |
| Privacidade | Celular | 100 | 1,2 s | 1,2 s | 20 ms | 0,001 | 1,2 s |
| Privacidade | Computador | 100 | 0,3 s | 0,3 s | 10 ms | 0,033 | 0,4 s |

Nas demais categorias, todas as páginas tiveram acessibilidade de 95 a 100, práticas recomendadas 100 e SEO de 82 a 83.

O relatório da página inicial no celular apontou dois motivos para a nota 77:

- a foto do topo (`hero.png`) tinha 506 KiB, e o PageSpeed estimava 425 KiB de economia com um formato moderno de imagem.
- o JavaScript principal tinha 352 KiB transferidos, dos quais cerca de 280 KiB não eram usados na página inicial, porque o site baixava de uma vez o código de todas as telas.

---

## 3. O que foi mudado

As mudanças estão nas PRs [#158](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/pull/158) (para a `developer`) e [#159](https://github.com/TCC-Feedback-Analytics/feedback-analytics-web/pull/159) (para a `main`) do `feedback-analytics-web`, publicadas em 18/11/2026. Os detalhes técnicos estão em `docs/interface-performance.md` daquele repositório.

| Mudança | Antes | Depois |
| --- | --- | --- |
| Foto do topo da página inicial em WebP | 518 KB (PNG) | 39 KB |
| Logos reduzidos a 640 px de largura (o dobro do exibido), em WebP | 43 KB cada | cerca de 10 KB cada |
| Área logada (`/user`) carregada sob demanda, com o `lazy` do React Router | JavaScript principal de 362 KB (gzip) | 237 KB (gzip) |
| Fontes estáticas só com os alfabetos latin e latin-ext, sem fonte em base64 no CSS | CSS principal de 80 KB (gzip) | 38 KB (gzip) |

As páginas públicas continuam no pacote principal. Um teste com elas também carregadas sob demanda baixou o login e a privacidade de 100 para cerca de 90 no Lighthouse, porque o navegador só descobria o código da tela depois de baixar o pacote principal.

---

## 4. Depois da otimização (18/11/2026, site publicado)

| Página | Aparelho | Desempenho | FCP | LCP | TBT | CLS | SI |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Inicial | Celular | **91** | 0,9 s | 3,5 s | 70 ms | 0 | 1,4 s |
| Inicial | Computador | **100** | 0,2 s | 0,6 s | 0 ms | 0,001 | 0,7 s |
| Login | Celular | 100 | 0,9 s | 0,9 s | 0 ms | 0 | 0,9 s |
| Login | Computador | 100 | 0,2 s | 0,2 s | 0 ms | 0 | 0,5 s |
| Cadastro | Celular | 100 | 0,9 s | 0,9 s | 0 ms | 0,043 | 0,9 s |
| Cadastro | Computador | 100 | 0,2 s | 0,2 s | 10 ms | 0 | 0,4 s |
| Privacidade | Celular | 95 | 2,1 s | 2,1 s | 80 ms | 0 | 4,0 s |
| Privacidade | Computador | 100 | 0,2 s | 0,2 s | 10 ms | 0,03 | 0,4 s |

A primeira análise do login no celular deu 97, com FCP de 2,1 s, e a segunda deu 100, com 0,9 s. A análise da privacidade no celular teve o mesmo atraso de 2,1 s no primeiro conteúdo. As duas páginas carregam do mesmo jeito, então a diferença vem da rede da própria análise. Acessibilidade, práticas recomendadas e SEO não mudaram.

---

## 5. Tempo de resposta da API (18/11/2026)

30 requisições `GET /api/health` a `https://feedback-analytics-api-gateway.vercel.app`, entre 20h49 e 20h50 (horário de Brasília), todas com status 200.

| Medida | Tempo total |
| --- | --- |
| Primeira requisição | 1,05 s |
| Mediana das 29 seguintes | 0,099 s |
| Mínimo | 0,091 s |
| 90% das requisições até | 0,140 s |
| Máximo | 0,903 s |
| Abaixo de 0,15 s | 28 de 29 |

A primeira requisição é mais lenta porque a Vercel inicia a função serverless que estava parada (*cold start*). Depois disso, o serviço responde em cerca de 0,1 s. A rota `/api/health` não consulta o banco, então a medida mostra o tempo do próprio Gateway e da rede, sem o tempo das consultas.

---

## 6. Como repetir

1. Abra `https://pagespeed.web.dev/`, cole o endereço da página e clique em **Analisar**. A mesma análise traz as abas **Celular** e **Computador**.
2. Faça três análises por página e use a mediana.
3. Para a área logada, que o PageSpeed não alcança, use o Lighthouse do Chrome: abra a página logado, aperte F12, vá na aba **Lighthouse** e analise. Faça isso numa janela anônima, porque extensões do navegador (bloqueador de anúncios, por exemplo) entram na medição. O painel consulta a API a cada 2,5 s para acompanhar os pedidos de IA, então o Lighthouse pode avisar que o carregamento "não terminou" no computador. Nesse caso, o resultado fica incompleto.
4. Para a API, no PowerShell:

```powershell
1..30 | ForEach-Object { curl.exe -s -o NUL -w "%{http_code} %{time_total}`n" https://feedback-analytics-api-gateway.vercel.app/api/health; Start-Sleep -Seconds 2 }
```

---

## Veja também

- [Visão geral dos testes](./visao-geral.md)
- [Plano de Teste Estratégico](./plano-estrategico.md)
- [Frontend — `feedback-analytics-web`](./web.md)
