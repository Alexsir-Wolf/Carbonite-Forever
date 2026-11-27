# Carbonite-Forever

O Carbonite-Forever é a edição não oficial do Carbonite para o World of Warcraft: Forever. Veja o [README](https://github.com/Alexsir-Wolf/Carbonite-Forever#readme) para saber o que o addon faz e como instalar.

## v1.5.4

### Correções
- **Rastreamento de caçador no minimapa:** com Rastrear Feras, Humanoides, Mortos-vivos e os demais rastreamentos de caçador ligados, os pontos voltam a aparecer no minimapa integrado ao mapa, como os de ervas e minérios. Vale também para Rastrear Humanoides do druida, Sentir Mortos-vivos do paladino e Sentir Demônios do bruxo. As opções de transparência, escala dos ícones e terreno passam a valer para esses rastreamentos.

## v1.5.3

### Correções
- **Tooltip dos pontos de erva e minério no minimapa:** com Encontrar Ervas ou Encontrar Minérios ligado, passar o mouse num ponto amarelo do jogo ou num ícone do GatherLite mostra o nome do nó e a perícia. O jogo não dá tooltip aos próprios pontos; o nome vem do nó do GatherLite mais perto.

## v1.5.2

### Correções
- **Desmarcar missão no Monitor:** clicar de novo no "..." do título de uma missão rastreada volta a desmarcá-la, e a rota sai do minimapa. Com a seta do jogo escondida, o segundo clique não chegava a desmarcar.

## v1.5.1

### Correções
- **Tooltip dos pontos de coleta:** com Encontrar Ervas ou Encontrar Minérios ligado, passar o mouse num ponto de erva ou minério do Carbonite no mapa volta a mostrar o nome e a perícia. O minimapa integrado ficava por cima dos pontos e pegava o mouse.

### Conhecido
- Ainda não testado no jogo.

## v1.5.0

### Novidades
- **Rotas das masmorras:** nas 41 masmorras e raides do Forever (as novas incluídas), a planta mostra a rota curada andar por andar, com caminhos laterais, chefes opcionais e raros, notas e ligações entre andares. O painel de chefes segue a ordem da rota, e os chefes se marcam sozinhos pelo fim do encontro.
- **Sala atual:** o jogo não dá posição dentro da masmorra, mas dá o nome da sala. O painel mostra "Você está em: …", a planta troca de andar sozinha e destaca a sala.
- **Planta sem outro addon:** sem ForeverDungeonJournal, FojjiCore ou MapUtils, a planta usa as imagens do minimapa do próprio cliente.
- **Suas rotas:** no botão **Rotas** da planta, crie uma rota a partir da run (salas e chefes mortos), edite (caminho, caminho lateral, paradas, notas, desfazer), renomeie, exclua, exporte e importe no formato `!FDR1!` do ForeverDungeonRoutes.
- **Compartilhar:** envie a rota ao grupo ou à guilda (sempre com pergunta a quem recebe) ou a ordem dos chefes no chat. Funciona entre Carbonite e ForeverDungeonRoutes.
- Os dados vêm do ForeverDungeonRoutes, de Checkov23 (MIT), no addon interno **Carbonite.Dungeons**, carregado só dentro de masmorras. O ForeverDungeonRoutes não precisa estar instalado.

### Conhecido
- Ainda não testado no jogo. Nas masmorras clássicas com arte do MapUtils, o alinhamento da rota com a arte não foi conferido.

## v1.4.3

### Correções
- **Quests de masmorra:** clicar no monitor numa quest cujo objetivo fica dentro de uma masmorra traça a rota até a entrada da masmorra. Antes, nada era traçado. Dentro da masmorra, sem posição para o objetivo, o mapa fica como está.

### Conhecido
- Ainda não testado no jogo.

## v1.4.2

### Correções
- **Plantas das masmorras novas:** dentro da The Drowned City, Krol'dok Stronghold, Alcaz Prison e The Shaper's Terrace, a planta e o painel de chefes abrem sozinhos, sem precisar escolher a masmorra no menu.
- **Alcaz Prison com os dois andares:** Main Unit e Maximum Security Unit.

### Conhecido
- Ainda não testado no jogo. Sem o ForeverDungeonJournal, The Shaper's Terrace e o segundo andar da The Drowned City continuam sem chefes, e a Blackmaw Hold sem planta: nenhuma fonte tem esses dados.

## v1.4.1

### Correções
- **Rota até Mount Hyjal e Shen'dralas:** as duas zonas passam a ter ligação a pé com as vizinhas (Felwood e Winterspring; Mulgore, Desolace e Feralas), e a rota consegue chegar lá.
- **Barco para Southshore:** o The Bravery, que agora passa por Southshore entre Menethil e Auberdine, entra na rota da Aliança.
- **Portal de Dalaran:** a chegada em Stormwind fica no lugar certo.

### Conhecido
- As passagens a pé para Hyjal e Shen'dralas são provisórias: vêm do meio de cada borda de zona, não de uma passagem conferida, e podem cruzar uma montanha. Ainda não foram testadas no jogo, nem o barco para Southshore.

## v1.4.0

### Novidades
- **Mapa mais fluido:** arrastar e dar zoom no mapa acompanha o mouse quadro a quadro (até 60 por segundo), e o zoom desacelera suavemente no fim. Parado ou seguindo o personagem, o mapa continua na taxa de atualização das opções, sem custo extra. O botão de zoom da barra dá um passo, igual à roda do mouse.
- **Barra do mapa com ícones que dizem o que fazem:** zoom com lupa de + e −, Guia com lupa, Combate com as espadas de combate e Eventos com relógio, quando o jogo tem esses ícones; senão, ficam os de antes. O botão 3D aparece sempre, e os botões de outros addons adotados pela barra não somem mais quando ela é refeita.

### Correções
- **Zonas novas com nível:** Mount Hyjal (60), Shen'dralas e Riverglades (35-45) mostram a faixa de nível, e Zephras Isle passa a 1-12.
- **Voos novos:** Rog'mar (Riverglades, Horda), Summit of Eternity e Tainted Foothills (Mount Hyjal) entram no Guia e na rota.
- **Entradas das masmorras novas:** City of Dalaran, Ruins of Lordaeron, Excavation Site, The Hall of Thanes, Alcaz Prison, The Shaper's Terrace, The Drowned City e Blackmaw Hold apontam para a porta de verdade. Dalaran ganha a entrada de Silverpine e Ruins of Lordaeron a de Tirisfal.
- **Pedras de encontro:** The Drowned City e Excavation Site aparecem no Guia.

### Conhecido
- Os voos e as entradas novas vêm do MapUtils, do ForeverDungeonJournal e do Shortest Path Forever e ainda não foram conferidos no jogo. A entrada do The Hall of Thanes é provisória: as fontes divergem.
- O mapa mais fluido e os ícones novos da barra ainda não foram testados no jogo.
- Os ícones do mapa ainda são todos refeitos a cada atualização; redesenhar só o que mudou fica para uma próxima versão.

## v1.3.1

### Correções
- **Tooltip de missão preso na tela:** o quadro com as linhas de missão ("Missão: ...") que aparece ao passar o mouse em NPCs, itens e objetos fecha quando o mouse sai, em vez de ficar parado na tela.
- **Seta e pontos do minimapa no meio da tela:** fechar o mapa durante o combate não deixa mais a seta do personagem e os pontos do minimapa (minérios, missões) soltos na tela. Eles voltam quando o combate acaba ou quando o mapa é reaberto.

### Conhecido
- As duas correções passaram nos testes automatizados, mas ainda não foram testadas no jogo. Se depois de fechar o mapa em combate ainda sobrar alguma seta, abra uma issue com um print.

## v1.3.0

### Novidades
- **Distância em metros:** com o jogo em português, a seta, o mapa, o Guia, a lista de destinos e o monitor de quests mostram a distância em metros ("319 m") e, a partir de 1000, em quilômetros ("1,3 km"). Uma jarda conta como um metro, como no alcance das magias do jogo. Para escolher, use "Unidade de distância" em Opções > Rastreamento (Automática, Jardas ou Metros).
- **Ícones do mapa sem a moldura antiga:** correio, estalagem, banco, leiloeiro, mestre de voo e mestre de estábulo usam os ícones atuais da Blizzard quando o jogo os tem; os outros pontos do Guia (treinadores, nós de coleta) aparecem sem a moldura chanfrada, com o desenho inteiro. Para voltar ao visual antigo, ligue "Ícones clássicos" em Opções do Mapa.
- **Escolha dos ícones no assistente:** uma página nova pergunta quais ícones usar no mapa: os atuais da Blizzard, os clássicos ou, com o HandyNotes e o HandyNotes: MapNotes instalados, os do MapNotes. Com o MapNotes, os treinadores e os serviços do Guia ficam só com os ícones dele no mapa, sem duplicar; a lista do Guia continua guiando até eles.

### Correções
- **Seta ao fechar o RestedXP ou o Zygor:** fechar o guia tira o destino dele do Carbonite, e a seta some se não houver outro. Os seus destinos ficam; reabrir o guia devolve o destino do passo.
- **Ícone do jogador no mapa:** com o minimapa dentro do mapa, a seta do personagem não fica mais escondida embaixo das setas de rota e dos ícones.
- **Ícones do Guia:** as entradas de masmorra, os portais e os NPCs do Guia recebem o caminho completo do ícone. Antes, alguns podiam ficar sem imagem, e uma pasta do Guia sem ícone dava erro Lua.
- **Conexões das zonas novas:** os mapas do Forever com número acima de 2999 também entram no cálculo de rota entre zonas.

### Conhecido
- A distância em metros, os ícones novos, a página do assistente com o MapNotes e o ícone do jogador foram testados no jogo. A correção da seta do RestedXP e do Zygor e a das conexões das zonas novas ainda não foram.
- Uma quest que o guia colocou em destaque no rastreador do jogo continua sendo seguida depois de fechar o guia.
- Clicar num ícone do MapNotes no mapa não cria destino; para ser guiado, use a lista do Guia.

## v1.2.1

### Correções
- **Botão do Carbonite preso ao jogador:** com um coletor de botões (como o MinimapButtonButton), sair de uma masmorra não faz mais o botão do Carbonite aparecer no mapa seguindo o personagem.

### Conhecido
- Esta correção passou nos testes automatizados, mas ainda não foi testada no jogo. Se o botão continuar preso ao personagem, abra uma issue dizendo quando ele apareceu.

## v1.2.0

### Novidades
- **Sem seta dourada no mapa:** com o minimapa no mapa do Carbonite, a seta de quest do jogo some e a rota continua. O marcador 3D e o destaque dessa quest no jogo somem junto; para ter tudo de volta, desligue "Esconder seta de quest" em Opções do Minimapa.
- **Quem guia você até o destino:** escolha entre a seta do Carbonite, a do TomTom ou o Shortest Path Forever, no assistente de configuração ou em Opções > Rastreamento (exige recarregar a interface). Com o TomTom, o destino atual do Carbonite vira um waypoint dele. Com o Shortest Path Forever, ele planeja a rota mais rápida (voos, barcos, portais, pedra de regresso) e guia com a própria seta e linha. Só aparecem os addons instalados.
- **Caminho a pé pelo Shortest Path Forever:** com ele instalado, a linha de rota do Carbonite segue o caminho a pé dele (túneis e níveis das cidades), mesmo sem o GatherLite.
- **Assistente de configuração a cada versão:** abre de novo quando o addon é atualizado; o Novidades espera ele fechar.

### Correções
- **Zoom com rota:** o zoom que você escolhe fica até a rota acabar, e o mapa continua seguindo o personagem. Para voltar ao ajuste automático antes disso, clique no botão de zoom automático no mapa grande.
- Com o Shortest Path Forever instalado, o Carbonite não confunde mais o TomTom que ele cria com o TomTom de verdade.
- A opção "Ativar emulação do TomTom" passa a valer de fato.

### Conhecido
- TomTom e Shortest Path Forever como guia ainda não foram testados no jogo. Se com um deles a seta dourada voltar ou o marcador dele sumir, desligue "Esconder seta de quest" em Opções do Minimapa.

## v1.1.0

### Novidades
- **Usar só o minimapa da Blizzard:** opção nova em Opções do Minimapa. Esconde o mapa pequeno do Carbonite; M e o botão do minimapa abrem o mapa grande, e fechá-lo esconde o Carbonite de novo.
- **Monitor de missões redimensionável:** no tamanho fixo, arraste a borda esquerda ou direita para mudar a largura (fica salva); "Largura padrão" no menu do monitor volta ao padrão.

### Correções
- **Pontos de coleta no minimapa integrado:** com Localizar Plantas ou Minérios ativo, os pontos das ervas e minérios aparecem sobre o mapa do Carbonite, maiores e sem o terreno do minimapa. Três opções novas em Opções do Minimapa ajustam o comportamento.
- Monitor de missões: títulos e objetivos longos quebram em linhas em vez de alargar o card.
- Fechar o mapa grande com Esc durante o combate não gera mais erro.
- Com um coletor de botões (como o MinimapButtonButton), o botão do Carbonite não aparece mais solto ao lado do minimapa.
- README: o QuestieDB passa a ser obrigatório.

## v1.0.1

### Visual
- Novo logo da edição Forever no botão do minimapa (na coluna própria do Carbonite e nos coletores de botões), no brilho de novidade e na lista de addons.

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
