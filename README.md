# Weiner Game

Jogo de puzzle 3D: um cachorro salsicha busca gravetos lendários e precisa voltar carregando
o graveto na boca — a colisão do graveto pelo cenário é o núcleo do puzzle.

Ver [CONCEITO.md](CONCEITO.md) para a ideia completa e [ROADMAP.md](ROADMAP.md) para as
próximas etapas (túneis, pulo, cavar, empurrar, riachos, latir, truques, peso do graveto...).

## Rodando

Abrir a pasta no **Godot 4.7** e rodar (F5). O jogo abre no **menu principal**
(`scenes/menu.tscn`): continuar de onde parou, escolher uma fase (✓ nas concluídas), escolher a
pelagem do cachorro (com prévia ao fundo) ou abrir o **editor de fases** — numa fase existente ou
numa nova, do zero. Para jogar uma fase direto, abra a cena dela e use F6 (rodar cena atual).
O progresso (fases concluídas, pelagens escolhidas) fica em `user://progresso.cfg`.

A dica no topo da tela mostra só os controles que valem no momento; reiniciar (R) e o editor
(F1) aparecem na pausa, com as teclas.

| Tecla | Jogo | Editor de fases |
|---|---|---|
| WASD / setas | andar | mover a câmera |
| Mouse | câmera 3D | clique esq. coloca, dir. apaga, meio gira |
| E | largar o graveto | girar (com Q) |
| Q | virar o graveto (atravessado ↔ ao comprido) | girar (com E) |
| Espaço | pular (se a fase liberar) | — |
| C | cavar terra fofa (se a fase liberar) | — |
| B | latir (se a fase liberar) | — |
| F | ação do que está à frente (morder o mirante, pegar a ponte de graveto...) | — |
| F (segurando) + trás | puxar o bloco de pedra (sem graveto): segurando F perto do bloco, o cachorro vira de frente e agarra | — |
| Ctrl + arrastar | — | preencher um retângulo de tiles |
| Shift + arrastar | — | espalhar o objeto escolhido (pincel de floresta) |
| G | — | conta-gotas (pega o tile/objeto sob o cursor) |
| Shift | andar devagar (equilíbrio) | modificador (trocar tile, girar 15°) |
| R | reiniciar | subir camada (com F: descer) |
| Esc | pausa (solta o mouse; ao continuar, prende de novo); no mirante, sai dele | ferramenta Selecionar / desmarcar |
| **F1** | **abrir o editor nesta fase** | **testar a fase** (F1 volta) |
| F3 | liga/desliga o pixelado | idem |
| H | — | lista de atalhos do editor |

## Opções e tela

**Opções** (menu principal ou pausa), guardadas em `user://opcoes.cfg` (autoload `Opcoes`):

- **Tela**: janela, tela cheia (padrão, na resolução do monitor) ou tela cheia exclusiva;
  tamanho da janela; VSync; limite de FPS; tamanho da interface (75% a 125% — o jogo inteiro
  já acompanha a resolução do monitor; o editor de fases usa sempre 100%).
- **Gráficos**: intensidade do pixelado, contorno, sombras, brilho.
- **Áudio**: volumes (geral, música, efeitos, ambiente) — prontos para quando houver som.
- **Controles**: sensibilidade da câmera, inverter Y e **trocar as teclas** (clique e aperte
  a nova; se a tecla já era de outra ação, as duas trocam). Os textos do jogo sempre mostram a
  tecla atual; nas *Zonas de dica*, escreva `{nome_da_ação}` (ex.: `{virar_graveto}`).

**Monitores largos** (21:9, 32:9): o 3D ocupa a tela toda sem esticar — a câmera isométrica
tem altura fixa, então a tela larga mostra mais mundo dos lados — e a interface fica numa
**área segura** central de no máximo 16:9 (`scripts/ui/area_segura.gd`). Para nunca aparecer o
"fim do mundo", o jogo gera em volta de cada fase um **entorno** de grama e floresta
(`scripts/entorno.gd`, árvores em MultiMesh), que não é salvo na fase.

## Exportar e compartilhar

O jogo exporta para **Windows** (`WeinerGame.exe`, um arquivo só), **Linux** e **macOS**
(presets em `export_presets.cfg`):

- **Pelo editor do Godot:** Projeto → Exportar → escolha a plataforma → *Exportar Projeto*. Na
  primeira vez o Godot pede os *templates de exportação* (Editor → Gerenciar Templates de
  Exportação → Baixar, ~1,3 GB).
- **Pela linha de comando:** `ferramentas/exportar.sh` (ou `ferramentas/exportar.sh Windows`)
  gera `build/WeinerGame-<versão>-<plataforma>.zip`. A versão vem de `config/version` no
  `project.godot`.
- **Pelo GitHub (CI):** o workflow `.github/workflows/jogo.yml` joga todas as fases a cada push e,
  na `main`, exporta as três plataformas (os `.zip` ficam nos artefatos da execução, em *Actions*).
  Criando uma **tag** `v0.1`, `v0.2`... ele também publica uma **Release** com os `.zip` — é só
  mandar o link para os amigos (se o repositório for privado, mande o `.zip`).

Para os amigos: no Windows, o SmartScreen avisa que o programa não é assinado ("Mais
informações → Executar assim mesmo"); no macOS, abra com clique direito → Abrir. O progresso e
as opções ficam em `%APPDATA%\WeinerGame` (Windows) ou `~/.local/share/WeinerGame` (Linux).
O jogo exportado precisa de placa de vídeo com Vulkan ou Direct3D 12.

**Teste de fumaça:** `WeinerGame -- --fumaca=<pasta>` abre o menu, joga a primeira fase, salva
duas fotos e diz `FUMACA ok` (a CI usa isso para testar o próprio executável).

## Save do jogador (progresso entre versões)

O progresso (fases concluídas e pelagens) fica em `progresso.cfg`, na pasta do jogo
(`%APPDATA%\WeinerGame` no Windows). Para ninguém perder o progresso numa atualização:

- **A pasta é fixa:** `application/config/custom_user_dir_name = "WeinerGame"` no
  `project.godot`. Não mude — o jogo novo não acharia o save antigo. O teste `save` confere.
- **O save tem versão** (`[save] versao`, `Fases.VERSAO_PROGRESSO`). Mudou o formato? Aumente o
  número, escreva a conversão em `Fases.migrar()` e ponha um save de exemplo da versão antiga
  em `ferramentas/testes/saves/` (o teste `save` carrega e confere). Um save de uma versão mais
  nova do jogo não é mexido.
- **Cada fase tem um id** (`Fase.id`, ex.: `fase_01`) — é ele que vai para o save, não o nome
  do arquivo. Renomear ou mover o arquivo (ex.: para pastas de região) não apaga o ✓. O editor
  dá um id novo ao **Salvar como** (fase nova); nunca reaproveite o id de outra fase. Se um id
  precisar mudar, anote o antigo → novo em `Fases.IDS_RENOMEADOS`.

## Testes das fases

`ferramentas/testar_fases.sh` joga cada fase com as entradas de `ferramentas/testes/rotas/*.txt`
(sem janela, em segundos) e confere que ela termina. Ao mudar uma fase, rode de novo; se o
caminho mudou, ajuste a rota (o formato está no topo de `ferramentas/testes/roteiro.gd`).
A rota `save` testa a pasta do save, os ids das fases e a migração de saves antigos; a rota
`mecanismos` testa a regra OU / E dos portões e a ferramenta Ligar do editor
(`ferramentas/testes/teste_mecanismos.gd`); `editor` testa trechos, colar girado, módulos,
balde e bioma (`teste_editor.gd`); `neve` e `celeiro` montam fases de neve por código
(`teste_neve.gd`) e testam frio, fogueira, gelo e o celeiro.
Precisa do Godot no PATH (ou `GODOT=/caminho/do/godot`).
Os testes não mexem nos arquivos do jogador: usam as opções de fábrica e guardam o progresso
só na memória (se o `progresso.cfg` real mudar durante um teste, o teste falha).

## Fase 01 — "O Primeiro Graveto"

Ida em visão isométrica: a trilha é estreita, cercada por mato e floresta. O mato bloqueia o
caminho, então o salsicha sobe a rampa, anda pelo barranco e pula lá de cima perto do graveto.
Ao pegar o graveto a câmera vira 3D e revela o túnel no mato (as bocas ficam tampadas por
folhagem "só isométrica") — o único caminho de volta, porque o barranco é de mão única.

## Fase 02 — "A Pinguela"

O graveto agora é grande e pesado (1,4 m, peso 2). Na ida o salsicha cruza o riacho por uma
ponte larga, segue o caminho de terra por um vão estreito no muro de pedra (a parte da frente é
uma cerca de madeira, para o vão aparecer na câmera de cima) e **pula** para o degrau onde está o
graveto. Na volta, em 3D, a ponte larga não existe (era "só isométrica"): sobra a **pinguela**.
Atravessado na boca, o graveto não passa no vão — **Q** vira o graveto ao comprido. Na
pinguela, graveto grande desequilibra: atravessado e correndo, o cachorro cai na água; ao
comprido ou andando devagar (Shift), passa.

## Fase 03 — "O Monte e o Passarinho"

Um monte de **terra fofa** fecha a trilha: o salsicha **cava** (C) um túnel através dele. Do
outro lado do riacho, um **passarinho** está pousado no graveto e não deixa pegar — um **latido**
(B) e ele voa. Na volta, em 3D, a ponte (só isométrica) sumiu: **empurre o bloco de pedra**
para dentro do riacho; ele afunda e vira passagem (se o bloco ficar encurralado num canto,
volta sozinho para o lugar). Com o graveto na boca não dá para cavar
nem latir.

## Fase 04 — "A Correnteza"

Primeira fase sem habilidades extras. Um **monte** de rampas e cantos logo no começo; depois
um rio de **correnteza** (água rasa que arrasta o cachorro rio abaixo — se ele for levado até a
água funda, "Splash!"). Um bloco de pedra está **encaixado num nicho**: empurrar não resolve,
é preciso **puxar** (segurar F e andar para trás) para tirá-lo e depois empurrá-lo para dentro
do canal. Uma **escada** sobe ao platô do graveto, que é pesado — e graveto pesado deixa o
cachorro mais firme na correnteza na volta.

## Fase 05 — "O Pastor"

Primeira fase com outra raça (**Border Collie**) e outro objetivo: **levar as ovelhas ao
cercado**. As ovelhas fogem do cachorro que chega perto — é preciso ficar *atrás* delas em
relação ao cercado para empurrar o rebanho. **Latir** (B, nativo da raça) espanta de vez. Elas
não entram na água funda: o riacho só se atravessa pelo **vau** de água rasa. A porteira do
cercado fica no lado oeste; dentro dele a ovelha se acalma e não sai mais.

## Fase 06 — "O Portão"

Uma cerca viva atravessa a trilha com um **portão amarelo**. A **placa de pressão amarela** abre
o portão — mas só enquanto tiver peso em cima: o cachorro sozinho abre, mas o portão fecha quando
ele sai. A saída é **empurrar o bloco de pedra** para a placa.

## Fase 07 — "A Chave e o Prêmio"

O **graveto lendário** (dourado) está sobre uma placa azul, segurando o portão azul aberto. Pegou,
o portão fecha — com o cachorro do lado de dentro. Qualquer placa da mesma cor segura o portão:
antes, é preciso levar um **graveto comum** (pesado como o lendário) para a outra placa azul,
lá fora. O cachorro sozinho (peso 1) não basta.

## Fase 08 — "A Ponte de Graveto"

A ponte da ida é "só isométrica": na volta, em 3D, ela some. Antes de atravessar, o **mirante**
(um graveto fincado num toco, com fita vermelha) mostra isso: **F** morde e a câmera mostra a
fase como ela fica na volta; F (ou Esc) solta. Do outro lado há um **graveto comum comprido**:
virado ao comprido (**Q**) e largado sobre o riacho, ele **vira ponte**. Aí é buscar o lendário
e voltar pela ponte de graveto.

## Fase 09 — "O Passeio Completo"

Junta tudo: mirante, ponte só da ida, uma **placa vermelha que pede peso 3** (os pontinhos no
tampo dizem quanto — só o bloco de pedra basta) segurando o portão vermelho, e o graveto
comprido que vira a ponte da volta.

## Fase 10 — "Debaixo da Cerca"

Uma **cerca com terra fofa** embaixo atravessa a trilha: cavando (C) de frente para ela, o
salsicha abre um vão por baixo. Depois, um **degrau alto** — só pulando, e com graveto na boca o
pulo não chega (caminho de mão única). No platô, um **montinho de terra**: o graveto lendário
está enterrado, é só cavar. Ele é comprido: na volta, pelo vão da cerca, só passa ao comprido (Q).

## Fase 11 — "O Tronco no Rio"

Não há ponte: o jeito é empurrar o **tronco** de lado para dentro da correnteza. Ele desce o rio
(dá para ir em cima) e encaixa no poço fundo, virando ponte. Do outro lado, a **placa verde pede
3**: o salsicha com o graveto comum pesa 2,5 — mas **graveto molhado pesa mais**. Uma passada na
lagoinha rasa, e o portão verde abre (e trava aberto).

## Fase 12 — "O Vizinho"

Um latido espanta o passarinho do vão do muro. O **esquilo** guarda o graveto lendário na porta da
toca: um latido e ele se esconde por alguns segundos — corra. Na volta, com o graveto na boca,
outro passarinho fecha o vão, e ali não dá para largar o graveto… mas o **cão vizinho** late de
ciúme quando o salsicha passa com o graveto, e o latido dele espanta o passarinho. E o **dono
cochilou**: larga o graveto, late, pega de novo e entrega.

## Gravetos, placas e portões

- **Graveto lendário × comum:** o dono só aceita o **lendário** (dourado, com brilho). Os
  **comuns** (marrons) também trocam a perspectiva ao serem pegos, mas servem de ferramenta
  (peso numa placa, algo para trocar). Com um graveto na boca não dá para pegar outro — largue
  antes.
- **Canais são cores:** uma **placa de pressão** aciona tudo da mesma cor enquanto o peso em
  cima chega ao mínimo dela; um **portão** da mesma cor abre (ou fecha, com *inverter*). Várias
  placas da mesma cor: basta uma acionada. O portão nunca fecha em cima de alguém.
- **Pesos:** salsicha 1 (border collie 1,5; pug 1,8), cachorro com graveto = raça + graveto,
  graveto largado = o peso dele, bloco de pedra 3, ovelha 1,5, passarinho 0,3.
- **Pontinhos na placa:** cada pontinho no tampo é uma unidade de peso que ela pede.
- **Graveto-ponte:** um graveto de 1,6 m ou mais, largado **ao comprido** sobre um vão de uma
  célula (riacho, buraco) com chão dos dois lados, encaixa na grade e vira uma pinguela (com o
  equilíbrio da Tábua). Para pegar de volta, chegue por uma das pontas e aperte F.
- **Mirante:** F morde e mostra a fase como fica na volta (sem ligar nem desligar nada); o
  cachorro fica parado até soltar (F ou Esc).
- **Botão de ação (F):** objetos que respondem ao F mostram a ação embaixo da tela
  ("F: ..."). Segurar F + andar para trás continua puxando o bloco.
- **Regra OU / E:** com várias placas da mesma cor, o portão abre com **qualquer uma** acionada
  (OU, o padrão) ou só com **todas** ao mesmo tempo (E) — propriedade *Regra* do portão.
- **No editor:** Placa, Portão e Mirante ficam em *Mecanismos*; linhas tracejadas na cor do canal
  ligam as placas aos portões, e o portão que reage a mais de uma placa mostra a regra ("OU" /
  "E"). A validação avisa placa sem portão (e vice-versa) e regra E com uma placa só. Ver
  *Ligando mecanismos* em "Criando fases".

## Cavar, empurrar e bichos

- **Cavar (C)**, de frente para: um **montinho** (graveto enterrado — desenterra); uma **cerca
  com terra fofa** (abre um vão baixo naquele metro: salsicha e pug passam, border collie não);
  um bloco de **terra fofa** (some); a **terra fofa do chão** (vira um *Buraco* de meio metro — o
  cachorro sai escalando, e um bloco empurrado para dentro tapa o buraco).
- **Tronco que rola**: ocupa duas células; empurrado de lado rola uma célula. Na água funda vira
  ponte; na correnteza desce o rio (com o cachorro em cima) até encalhar ou encaixar na funda.
- **Tronco caído** com *pinguela*: atravessado sobre um vão, é passagem estreita (equilíbrio).
- **Esquilo** (e a toca): leva gravetos largados por perto (até `raio` m) para a porta da toca e
  guarda; um latido assusta — larga o que levava e se esconde por `tempo_escondido` s.
- **Cão vizinho**: late de volta quando ouve um latido e late de ciúme quando um cachorro com
  graveto passa perto (3 m); o latido dele alcança o que está perto dele.
- **Dono dormindo** (`dormindo`, no painel do Dono): "Zzz" — só recebe o graveto depois de um
  latido (a validação avisa se ninguém pode latir).
- **Som**: o latido é gerado por código (`scripts/som.gd`), com o tom pela altura da raça.

## Neve, fogo e o celeiro

- **Bioma Neve** (propriedade *Bioma* da fase): os mesmos tiles com texturas de inverno (grama
  coberta de neve, pedra nevada, mato nevado, terra gelada), céu frio, neve caindo, entorno
  branco e árvores e pedras com neve. Tiles próprios: **Neve fofa** (mais lento, e o cachorro
  demora a arrancar e a parar), **Monte de neve** (bloco que se cava com C ou derrete no fogo) e
  **Gelo** (desliza: solta a tecla e ele continua).
- **Frio** (propriedade *Frio* da fase): longe do fogo o **calor** cai (barra no canto de baixo)
  em *Segundos até gelar*, e mais rápido na água; com pouco calor o cachorro treme e anda mais
  devagar; gelado, volta para o último lugar quente. Esquentam: fogueira acesa (perto) e celeiro
  (dentro).
- **Fogueira**: um círculo de pedras que acende com `gravetos_para_acender` gravetos comuns —
  traga na boca e aperte **F** perto dela (ou largue o graveto junto dela). Acesa, esquenta,
  derrete a neve em volta (neve fofa vira terra, montes somem) e revela o que estava enterrado
  na neve; cada graveto a mais aumenta o raio (`raio_por_graveto`, até `raio_maximo`). O
  lendário não vai para o fogo. Acesa, também aciona a cor dela (dá para abrir um portão com a
  ferramenta Ligar) — ou fica sem ligação.
- **Celeiro**: abrigo das ovelhas (como o Cercado): porta larga no lado +X, feno num canto,
  telhado com neve no bioma de neve. Com o cachorro perto, o telhado e a parte alta das paredes
  somem para dar para ver dentro. Uma ovelha que entra fica guardada; dentro é quente.
- **Ovelhas balem** ("Béé!", com som) de vez em quando quando estão longe do cachorro — é assim
  que se acha uma ovelha perdida num mapa grande. Neve fofa e água rasa atrasam as ovelhas também.

## Regiões e biomas

- **Regiões** (`assets/regioes/*.tres`, recurso `Regiao`: nome, descrição, ordem, bioma
  sugerido) agrupam as fases no menu (**Fases**, com a história curta de cada região). Cada fase
  diz a sua na propriedade *Região*. Hoje: **Floresta** (as Fases 01 a 12) e **Neve** (vazia,
  esperando as fases). A ordem do jogo (continuar, próxima fase) é a das regiões e, dentro de
  cada uma, a do nome do arquivo. Para uma região nova, duplique um `.tres` e mude `id`, `nome`
  e `ordem`.
- **Biomas** (`scripts/biomas.gd`): Floresta e Neve. O bioma troca a biblioteca de tiles
  (`assets/tiles/tiles.tres`, `tiles_neve.tres` — mesmos IDs, materiais trocados em
  `Tiles.MATERIAIS_POR_BIOMA`), o céu e a luz, o chão e as árvores do entorno e se neva.

## Raças e pelagens

O cachorro é um modelo **voxel gerado por código** (`scripts/racas/cachorro_voxel.gd`) a partir
de dois dados:

- **Raça** (`assets/racas/*.tres`, recurso `Raca`): proporções (corpo, patas, cabeça, focinho),
  tipo de orelha (caída, em pé, dobrada) e de rabo (reto, enrolado, curto), fator de velocidade
  e **habilidades nativas** (somadas às da fase). Hoje: salsicha, pug e border collie.
- **Pelagem** (recurso `Pelagem`, dentro da raça): cores do pelo, cabeça, orelhas, marcas
  (barriga/patas/focinho/sobrancelhas), máscara, manchas (malhado/merle) e pelo longo.

Para criar uma raça: duplique um `.tres` em `assets/racas/`, mude `id`, `nome` e as medidas no
inspetor do Godot — ela aparece sozinha no menu (tela Cachorro) e nas propriedades da fase.
Para uma pelagem nova, acrescente um item em `pelagens`. O modelo sai em partes com pivôs
(corpo, cabeça, orelhas, rabo, patas) animadas por código em `ModeloCachorro` (andar, abanar
o rabo, balançar as orelhas).

## O graveto

- **Colisão própria**: o graveto na boca é uma forma do corpo do cachorro. Se ele não passa,
  o cachorro não passa; o cachorro também não gira se o graveto bater em algo no giro. Uma
  "correção de quina" desliza o cachorro para encaixar quando falta pouco (senão passar com o
  graveto atravessado exigiria mira de milímetros).
- **Q** alterna entre atravessado e ao comprido (apontando para a frente). Ao comprido passa em
  vãos estreitos, mas o graveto vai longe à frente e bate em paredes ao virar.
- **Peso**: deixa o cachorro mais lento e o pulo mais baixo, mas mais firme na correnteza
  (o arrasto é dividido pelo peso). Com qualquer graveto na boca o pulo já é um pouco mais baixo
  (não passa do *Degrau alto*), e graveto pesado (1,5+) escorrega na *Rampa lisa*.
- **Molhado**: na água rasa, na boca, o graveto encharca e pesa +0,5 por 8 s (pinga).
- **Empurra**: o graveto na boca empurra blocos e troncos; ao comprido, de longe.
- **Equilíbrio**: em passagens estreitas (tile *Tábua*), carga = peso × comprimento acima de 1,2
  faz o cachorro balançar; o balanço cresce com o quadrado da velocidade e é menor ao comprido.
  Com o centro do corpo fora da tábua, ele cai. Ajustes no grupo "Equilíbrio" de
  `scripts/dachshund.gd`.

## Visual pixelado

- O 3D é renderizado em baixa resolução e ampliado sem filtro (`Viewport.scaling_3d_mode =
  NEAREST`); a interface continua nítida. Tudo no autoload `scripts/autoload/visual.gd`:
  a intensidade (linhas de pixel na vertical, padrão 240 — menor = pixels maiores) fica nas
  **Opções → Gráficos**.
- Contorno escuro nas silhuetas e realce claro nas quinas: `shaders/contorno_pixel.gdshader`
  (quad de tela cheia preso à câmera; força e limiares são `uniform`s).
- A câmera isométrica é alinhada à grade de pixels, para o cenário não "tremer".
- Materiais do mundo (`shaders/pixel_mundo.gdshader`): cor chapada + textura de pixels gerada
  pela posição no mundo (8 texels por metro). Cores em `assets/materiais/*.tres`.
- Use materiais opacos (ou com alpha scissor): o contorno lê a profundidade só do que é opaco.

## Criando fases

Cada fase é uma cena em `scenes/fases/` com:

```
Fase (scripts/fase.gd: nome, giro da câmera 3D)
├─ Terreno  GridMap (assets/tiles/tiles.tres), células de 1 m; o chão fica na camada -1
└─ Objetos  instâncias de scenes/objetos/*.tscn
```

**Pelo editor do jogo (F1)** — o jeito principal. Escolha um tile ou objeto na paleta à esquerda
e clique; a ferramenta Selecionar (Esc) seleciona e arrasta objetos e mostra as propriedades à
direita. A visão (V) alterna entre ver tudo, **isométrica** (o que o jogador vê na ida) e **3D**
(a volta). **Salvar** (Ctrl+S) grava por cima do arquivo da fase. Para criar uma fase nova:
**Nova** (parte de um modelo) ou abra uma fase existente, mude o nome e use **Salvar como** — o
arquivo novo leva o nome da fase (`Fase 02 — A ponte` → `scenes/fases/fase_02_a_ponte.tscn`).
As fases são jogadas na ordem das regiões e, dentro de cada região, pelo nome do arquivo — então
comece o nome com "Fase 02", "Fase 03"... (ou "Neve 01", "Neve 02"...).
Num jogo exportado as fases salvas vão para `user://fases/`.

**Pelo editor do Godot** — também funciona: pinte o GridMap `Terreno` com a biblioteca de tiles e
arraste cenas de `scenes/objetos/` para dentro de `Objetos`.

Atalhos de construção: **Ctrl + arrastar** preenche um retângulo com o tile escolhido (um só
desfazer); **Shift + arrastar** com um objeto escolhido espalha cópias com espaçamento e
variações sorteadas — o "pincel de floresta"; **G** é o conta-gotas. Ao **Testar** o editor valida
a fase (falta início, dono ou graveto; início sem chão...) e pede confirmação se houver problema
grave; ao salvar, mostra os avisos.

Nas propriedades da fase (nada selecionado) ficam a **região**, o **bioma**, o **objetivo**, a
**raça** do cachorro, as **habilidades** que a fase libera (pular, cavar, latir; a raça pode
somar as dela) — a Fase 01 depende de o cachorro *não* pular o barranco — e o **frio**. Cada
objetivo pede alguns objetos:

| Objetivo | Precisa de |
|---|---|
| Trazer o graveto ao dono | **Início do cachorro**, **Dono** e um **Graveto lendário** (categoria "Regras"); gravetos comuns são opcionais |
| Levar as ovelhas ao abrigo | **Início do cachorro**, **Ovelhas** ("Bichos") e um **Cercado** ou um **Celeiro** ("Regras"; tamanho no painel, porta no lado +X — gire para mudar); vale qualquer abrigo, e pode haver vários |

O comprimento e o peso do graveto ficam nas propriedades do Graveto.

### Trechos e módulos: montar mapas com peças

A ferramenta **Trecho (T)** marca um retângulo do mapa arrastando o mouse — entram os blocos de
todas as camadas e os objetos de dentro (menos o Início do cachorro). Com ele marcado:

- **Ctrl+C** copia, **Ctrl+X** recorta, **Del** apaga (tudo com desfazer). Com um objeto
  selecionado (Selecionar), Ctrl+C copia só ele.
- **Ctrl+V** cola: a prévia segue o mouse, **Q/E** gira 90° (rampas, escadas, cercas e objetos
  giram junto), **PgUp/PgDn** sobe ou desce, clique cola (e continua colando; Esc sai). O que foi
  copiado continua copiado ao abrir outra fase. Blocos colados substituem os do lugar; onde o
  trecho não tem bloco, nada muda. Mecanismos colados mantêm a cor.
- **Salvar como módulo** (painel da direita): o trecho vira `scenes/modulos/<nome>.tscn` (no jogo
  exportado, `user://modulos/`) e aparece no fim da paleta, em **Módulos** — clique para colar,
  em qualquer fase. Um módulo é uma fase pequena (terreno + objetos, com o canto na origem).
  Nome repetido pede confirmação para substituir.

Para um gerador de mapas, o mesmo pelo código (`scripts/modulos/`):

```gdscript
var peca := Modulos.carregar("res://scenes/modulos/ponte_de_troncos.tscn")  # Trecho
peca.girado(1).aplicar_em(fase, Vector3i(10, 0, -4))  # canto na coluna (10, -4), mesma altura
var trecho := Trecho.da_fase(fase, Vector2i(0, 0), Vector2i(7, 5))  # recortar um pedaço
Modulos.salvar(trecho, "Clareira", "clareira", Biomas.NEVE)
```

Outros atalhos para mapas grandes: **Alt + clique** no terreno é o **balde** (troca pelo tile
escolhido a mancha inteira de blocos iguais ligados ao apontado, na mesma camada; no vazio,
preenche o vazio da camada dentro do retângulo do terreno) e a **busca** no topo da paleta
filtra tiles, objetos e módulos pelo nome.

**Mapas grandes e para vários lados**: a grade não tem limite — pinte para qualquer lado. O
entorno (chão e árvores em volta) acompanha o formato do mapa: num mapa em L, o que sobra do
retângulo em volta também ganha chão e árvores; um vazio cercado pelo mapa continua abismo. O
limite de queda acompanha a camada mais funda do terreno.

### Ligando mecanismos

Placas e portões se ligam pela **cor** (o canal): peças da mesma cor estão ligadas. Uma peça
nova já vem com uma cor que ninguém usa (o conta-gotas mantém a cor copiada; duplicar com Ctrl+D
também — bom para uma segunda placa do mesmo portão). Para ligar, use a ferramenta **Ligar
mecanismos (L)**:

- **Clique numa peça e depois em outra:** a segunda fica com a cor da primeira (se só a segunda
  já tinha ligações, a primeira é que entra no grupo dela). Uma linha sai da primeira peça até
  o mouse enquanto você escolhe.
- **Clicar num par já ligado** desliga a segunda peça (ela ganha uma cor livre).
- **Shift + clique** liga e mantém a primeira peça escolhida — uma placa para vários portões.
- **Clique direito** solta a peça de todas as ligações. **Esc** cancela.
- Tudo entra no desfazer (Ctrl+Z). A cor também pode ser trocada à mão, no campo *Canal*.

### A mecânica da perspectiva no editor

Todo objeto tem **Visibilidade**: *Sempre*, *Só isométrico* ou *Só 3D*. Objetos "só isométrico"
somem — e perdem a colisão — quando o cachorro pega o graveto (ex.: a *Tampa de folhagem* que
esconde a boca de um túnel); "só 3D" só aparecem depois (ex.: árvores na frente da trilha, que
tapariam a visão isométrica). Use a *Zona sem largar* onde largar o graveto deixaria o cachorro
preso quando as tampas voltarem, e a *Zona de dica* (texto mostrado quando o cachorro entra
nela) para explicar a virada: com visibilidade "Só 3D" ela só vale na volta — ex.: "A ponte
sumiu! Empurre a pedra para dentro do riacho". As Fases 02, 03 e 04 usam uma assim.

Cuidado com a câmera isométrica (inclinação de 55°): um bloco de altura *h* esconde uns
0,7 × *h* metros de chão logo atrás dele. Um muro de 2 m esconde por inteiro uma passagem de 1 m
que esteja atrás dele — use a *Cerca* (dá para ver através) ou deixe a passagem na frente.

## Criando assets

Nada de arquivos externos: tudo é gerado pelo próprio Godot.

- **Tiles do terreno** — `scripts/assets/tiles.gd`: cada tile é um perfil 2D extrudado (bloco,
  meio bloco, rampas, água, tábua...) com um material e colisão. Depois de mudar ou acrescentar
  um tile, gere a biblioteca de novo: no editor do Godot abra `ferramentas/gerar_tiles_editor.gd`
  e use Arquivo → Executar (gera também os ícones), ou pela linha de comando
  `godot --headless --script res://ferramentas/gerar_tiles.gd`. **Nunca renumere um ID** (ele
  fica gravado nas fases). Mudar só as cores (em `assets/materiais/`) não precisa gerar de novo.
  Tiles especiais: *Água* (funda, sem colisão), *Água rasa* (leito rente ao chão, deixa mais
  lento), *Correnteza* (água rasa que arrasta no sentido +X do tile — gire o tile no editor para
  mudar o sentido; as listras da água mostram o fluxo), *Escada baixa/alta* (colide como
  rampa), *Canto de rampa* (externo e interno, baixo e alto) para fechar montes e barrancos,
  *Rampa lisa* baixa/alta (graveto pesado escorrega), *Degrau alto* (0,72 m, só pulando sem
  graveto), *Buraco* (o que a terra fofa do chão vira ao ser cavada), *Neve fofa* (`lentidao` e
  `aderencia`), *Monte de neve* e *Gelo* (`aderencia` baixa: desliza). `derrete_em` diz no que o
  fogo transforma o tile. Cada **bioma** tem a sua biblioteca (`Tiles.BIBLIOTECAS`): os
  geradores fazem todas; a troca de materiais por bioma fica em `Tiles.MATERIAIS_POR_BIOMA`.
- **Modelos voxel em texto** — `assets/voxel/*.txt`: camadas desenhadas com letras, uma cor por
  letra (formato em [assets/voxel/LEIA-ME.md](assets/voxel/LEIA-ME.md)). Exemplos: `dono.txt`,
  `tronco_caido.txt`. Use com o nó `ModeloVoxel`.
- **Modelos voxel gerados por código** — `scripts/assets/voxel.gd`: árvores (pinheiro, redonda,
  arbusto), pedras e flores, cada uma com 8 variantes (árvores e pedras também com neve). As
  malhas ficam em cache. Objetos que mudam com o bioma usam `bioma_da_fase()` e
  `ao_mudar_bioma()` de `ObjetoFase`.
- **Sons gerados por código** — `scripts/som.gd`: latido e balido.
- **Objetos de fase** — uma cena em `scenes/objetos/` cuja raiz estende `ObjetoFase`
  (`scripts/objetos/objeto_fase.gd`) aparece sozinha na paleta do editor, com ícone. Para
  expor parâmetros no painel do editor, liste as variáveis `@export` em
  `propriedades_editaveis()`; para sortear variações ao colocar, implemente
  `ao_colocar_no_editor(rng)`. Objetos sem lógica própria podem usar `objeto_simples.gd`.

## Estrutura

```
scenes/menu.tscn              menu principal (cena inicial)
scenes/jogo.tscn              jogo: cachorro, câmera, HUD (a fase é carregada por código)
scenes/editor/editor_fase.tscn  editor de fases (F1)
scenes/fases/                 fases (conteúdo: terreno + objetos)
scenes/modulos/               módulos: trechos de fase para reusar (criados pelo editor)
scenes/objetos/               objetos que o editor coloca
scripts/jogo.gd               regras: pegar/largar graveto, perspectiva, vitória
scripts/fase.gd               raiz de uma fase (consultas: objetos, tiles, água)
scripts/biomas.gd             biomas: tiles, céu, luz, entorno, neve caindo
scripts/regioes/, assets/regioes/  regiões (agrupam as fases no menu)
scripts/modulos/              Trecho (copiar/colar/girar pedaços de fase) e Modulos (catálogo)
scripts/autoload/fases.gd     qual fase jogar/editar; troca menu ↔ jogo ↔ editor; progresso
scripts/racas/                raça, pelagem, gerador voxel e modelo animado do cachorro
scripts/ui/                   tema dos menus e menu de pausa
scripts/autoload/visual.gd    pixelado (F3)
scripts/assets/               tiles, voxel
scripts/editor/               editor de fases
shaders/, assets/             shaders, materiais, tiles gerados, modelos voxel
ferramentas/                  geradores (rodar pelo editor do Godot ou linha de comando)
```

Camadas de física: 1 `mundo` (terreno), 2 `bordas` (paredes invisíveis; a câmera 3D passa
por elas), 3 `objetos`, 4 `cachorro`.

## Valores fáceis de ajustar

| O quê | Onde |
|---|---|
| Quanto pixelado | Opções → Gráficos (padrão em `Opcoes.PADRAO`) |
| Contorno (cor, força, limiares) | `uniform`s em `shaders/contorno_pixel.gdshader` |
| Cores dos blocos | `assets/materiais/*.tres` (inspetor do Godot) |
| Velocidade do cachorro | `velocidade` em `scenes/dachshund.tscn` / `scripts/dachshund.gd` |
| Câmera isométrica (ângulo, zoom) e 3D | exports de `scripts/camera_controller.gd` |
| Duração da transição de câmera | `duracao_transicao` em `scripts/camera_controller.gd` |
| Comprimento/peso do graveto | propriedades do Graveto no editor de fases |
| Altura do pulo, equilíbrio | exports de `scripts/dachshund.gd` (grupo "Equilíbrio") |
| Habilidades liberadas | propriedades da fase no editor (nada selecionado) |
| Alcance do latido | `ALCANCE_LATIDO` em `scripts/dachshund.gd` |
| Força da correnteza, lentidão da água rasa | `correnteza` / `lentidao` em `Tiles.definicoes()` |
| Tempo segurando para puxar | `DURACAO_PUXAR` em `scripts/dachshund.gd` |
| Giro inicial da câmera 3D por fase | "Giro da câmera 3D" nas propriedades da fase |
| Medidas, velocidade e cores de uma raça | `assets/racas/*.tres` (inspetor do Godot) |
| Medo e velocidade das ovelhas | constantes no topo de `scripts/objetos/ovelha.gd` |
| Frio (tempo até gelar) | "Segundos até gelar" nas propriedades da fase |
| Raio e gravetos da fogueira | propriedades da Fogueira no editor |
| Neve fofa e gelo (lentidão, aderência) | `lentidao` / `aderencia` em `Tiles.definicoes()` |
| Céu, luz e chão de cada bioma | `Biomas.dados()` em `scripts/biomas.gd` |
