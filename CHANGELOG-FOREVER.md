# Carbonite-Forever

O Carbonite-Forever é a edição não oficial do Carbonite para o World of Warcraft: Forever. Veja o [README](https://github.com/Alexsir-Wolf/Carbonite-Forever#readme) para saber o que o addon faz e como instalar.

## v1.0.0

Primeira versão com a numeração própria da edição. Base: Carbonite All in One v12.1.0-00023, de IrcDirk.

### Tema Blizzard (agora o padrão)
- Janelas com a moldura metálica do jogo, faixa de título e faixa de ferramentas; o minimapa integrado usa a versão compacta.
- Fonte original do jogo (Friz Quadrata) em todo o addon, inclusive no Monitor de missões.
- Menus e pop-ups com a moldura e a fonte do tooltip do jogo.
- Barra de rolagem fina do jogo em todas as listas e textos, e abas com o brilho dourado de botão selecionado.
- Diário de missões no layout do diário original, com o pergaminho nos detalhes.
- Monitor de missões alinhado; minimizar só esconde as missões, sem encolher a janela.
- Opções dentro do painel de configurações do jogo e botão do Carbonite pelo LibDBIcon, aceito pelos coletores de botões.

### Novidades
- **Rota até o lugar indicado pelo guarda:** o Carbonite marca no mapa o NPC que o guarda da cidade indica e traça a rota até ele.
- **Planta da masmorra com M:** rota pelos chefes, retratos, minimapa ao vivo e as quests do registro para aquela masmorra.
- **Jornada do personagem:** níveis, quests, zonas, mortes e masmorras de cada personagem (`/carb jornada`).
- **Fila de destinos:** vários destinos em sequência e a janela Destinos para ordenar, ir agora, remover e inverter (`/carb destinos`).
- **Rotas mais espertas:** começo pela pedra de regresso ou por teleporte de mago (desligado por padrão) e rota a pé contornando o terreno com o GatherLite.
- **Navios, zepelins e bonde** em movimento no mapa, com o horário no píer.
- Assistente de primeira execução e modo básico de opções.
- Aviso no jogo quando sair uma versão nova da edição.
- Pedras de encontro no Guia e curandeiro espiritual mais próximo destacado.

### Correções
- Minimapa integrado: a máscara redonda antiga não existe no cliente e deixava o minimapa nativo sem desenhar nada.
- Transparência do minimapa acoplado aplicada de verdade.
- Mapa grande abre na zona do jogador e mantém o desenho em `/carb map show`, `hide` e `toggle`.
- Diário de quests: rolagem até as recompensas, objetivos sem repetição e XP lida do cliente e do Questie.
- Janelas de informação atualizadas periodicamente e com dica quando vazias.
- Muitos textos traduzidos para o português, com datas, duração e moeda no formato do cliente.

### Conhecido
- Os pontos de coleta (Localizar Ervas e Minérios) ainda não aparecem por cima do mapa no minimapa integrado; no modo acoplado aparecem ([#214](https://github.com/Alexsir-Wolf/Carbonite-Forever/issues/214)).

## v12.1.0-00023-forever.1

Base: Carbonite All in One v12.1.0-00023, de IrcDirk.

### Novidades
- **Quests do Forever a partir do QuestieDB:** com o QuestieDB ativo, o Carbonite passa a mostrar quem dá, onde entregar e os objetivos das cerca de 1.300 quests do Forever que não estavam na base dele. As quests que ele já tinha não mudam.
- **Narração do Spoken na lista de quests:** botão ▶ ao lado do ícone das quests que o Spoken narra.
- **Minimapa ao vivo em masmorras:** a janela do mapa mostra o minimapa da Blizzard com o nome da masmorra, em vez de um mapa em branco ou errado.

### Distribuição
- Os `.toc` não trazem mais os ids da CurseForge e do WoWInterface. Assim, os gerenciadores de addons não trocam a edição pela versão oficial.
- As releases são publicadas a partir das tags `v*-forever*`.
