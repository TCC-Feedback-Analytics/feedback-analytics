# Documentação de Assets e Componentes (Design System)

!!! note "Material de concepção (jun/2026)"
    Este documento registra a biblioteca de componentes feita no Figma na fase de concepção e não foi atualizado com o produto. Os componentes da interface atual não seguem necessariamente estes padrões.

Esta seção documenta exclusivamente a biblioteca de componentes visuais reutilizáveis (Assets) desenvolvidos no Figma para o projeto **Feedback Analytics**. Esses elementos promovem a consistência visual da aplicação e centralizam os padrões de interação, estados e animações.

---

## 1. Filtros (Filters)

Os componentes de filtragem ajudam telas densas como a listagem de feedbacks e painéis analíticos a manter a consistência na triagem de dados.

| Componente | Descrição | Comportamento / Estados |
| :--- | :--- | :--- |
| **Filtro de Datas** | Seleção de período (data inicial e final) para refinar métricas e listas. | **Default:** Borda cinza neutra, fundo branco.**Hover:** Borda muda para a cor primária de foco.**Active:** Calendário flutuante (dropdown) com sombra projetada. |
| **Filtro de Categorias** | Dropdown ou seleção múltipla (tags) para filtrar feedbacks por temas específicos (ex: Produto, Suporte). | **Expansível:** Suporte a scroll interno se exceder 6 itens.**Seleção:** Tags internas colapsáveis (badges) para indicar os filtros ativos. |
| **Listagem (Paginação)** | Seletor de quantidade de itens por página (ex: exibir 10, 20, 50). | Dropdown simples acionado no clique para controle da densidade da lista. |

---

## 2. Links de Navegação (Links)

Elementos de navegação sutil focados em fluxos secundários, mensagens de rodapé ou alternância rápida de telas.

| Tipo de Link | Contexto de Uso | Comportamento / Estados |
| :--- | :--- | :--- |
| **Links de Autenticação** | Utilizados nas telas de Login/Cadastro. | **Hover:** Microinteração animada com uma linha horizontal inferior (underline) que surge suavemente do centro ou da esquerda, acompanhada de um leve aumento de saturação na cor. |
| **Links de Texto Embutido** | Links dentro de textos de ajuda ou descrições no sistema. | **Hover/Focus:** Destaque na cor primária com underline persistente. |

---

## 3. Botões e Chamadas de Ação (CTA)

Os botões da aplicação seguem uma hierarquia rígida de importância visual para guiar o usuário de forma intuitiva pelas ações principais e secundárias do sistema.

| Hierarquia / Estilo | Aplicação | Comportamento / Estados |
| :--- | :--- | :--- |
| **Primário** | Ações principais e conclusivas. | **Default:** Fundo sólido na cor da marca, texto branco, bordas arredondadas.**Hover:** Escurecimento e leve sombra.**Disabled:** Fundo cinza opaco, cursor não-permitido.**Loading:** Texto oculto, exibindo spinner circular animado. |
| **Secundário** | Ações alternativas ou de cancelamento. | **Default:** Contorno na cor da marca, fundo transparente.**Hover:** Preenchimento de fundo com 5-10% de opacidade da cor principal.**Disabled:** Borda desbotada, interações bloqueadas. |
| **Ghost / Ícones** | Ações secundárias em cards ou tabelas. | **Default:** Sem contorno ou fundo, apenas ícone/texto.**Hover:** Fundo sutil indicando área de clique. |

---

## 4. Cards e Carrosséis (Cards)

Os cartões funcionam como os blocos fundamentais de construção das interfaces internas da aplicação, agrupando informações correlacionadas de forma modular.

| Componente | Descrição | Comportamento / Estados |
| :--- | :--- | :--- |

| **Carrosséis** | Utilizados para agrupar múltiplos cards ocupando menos espaço vertical. | **Navegação:** Setas de navegação lateral que surgem no *hover* da área do carrossel.**Paginação:** Indicadores em pontos (dots) na base informando a página atual. |
