# Weiner Game

Jogo de puzzle 3D: um cachorro salsicha busca gravetos lendários e precisa voltar carregando
o graveto na boca — a colisão do graveto pelo cenário é o núcleo do puzzle.

Ver [CONCEITO.md](CONCEITO.md) para a ideia completa e [ROADMAP.md](ROADMAP.md) para as
próximas etapas (túneis, pulo, cavar, empurrar, riachos, latir, truques, peso do graveto...).

## Rodando

Abrir a pasta no **Godot 4.7** e rodar (F5). A cena principal é `scenes/jogo.tscn`, que
carrega a primeira fase de `scenes/fases/`. Para jogar uma fase específica, abra a cena dela
e use F6 (rodar cena atual).

| Tecla | Jogo | Editor de fases |
|---|---|---|
| WASD / setas | andar | mover a câmera |
| Mouse | câmera 3D | clique esq. coloca, dir. apaga, meio gira |
| E | largar o graveto | girar (com Q) |
| Q | virar o graveto (atravessado ↔ ao comprido) | girar (com E) |
| Espaço | pular (se a fase liberar) | — |
| C | cavar terra fofa (se a fase liberar) | — |
| B | latir (se a fase liberar) | — |
| F (segurando) + trás | puxar o bloco de pedra (sem graveto) | — |
| Ctrl + arrastar | — | preencher um retângulo de tiles |
| Shift + arrastar | — | espalhar o objeto escolhido (pincel de floresta) |
| G | — | conta-gotas (pega o tile/objeto sob o cursor) |
| Shift | andar devagar (equilíbrio) | modificador (trocar tile, girar 15°) |
| R | reiniciar | subir camada (com F: descer) |
| **F1** | **abrir o editor nesta fase** | **testar a fase** (F1 volta) |
| F3 | liga/desliga o pixelado | idem |
| H | — | lista de atalhos do editor |

## Fase 01 — "O Primeiro Graveto"

Ida em visão isométrica: a trilha é estreita, cercada por mato e floresta. O mato bloqueia o
caminho, então o salsicha sobe a rampa, anda pelo barranco e pula lá de cima perto do graveto.
Ao pegar o graveto a câmera vira 3D e revela o túnel no mato (as bocas ficam tampadas por
folhagem "só isométrica") — o único caminho de volta, porque o barranco é de mão única.

## Fase 02 — "A Pinguela"

O graveto agora é grande e pesado (1,4 m, peso 2). Na ida o salsicha cruza o riacho por uma
ponte larga, passa por um vão estreito num muro de pedra e **pula** para o degrau onde está o
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

## O graveto

- **Colisão própria**: o graveto na boca é uma forma do corpo do cachorro. Se ele não passa,
  o cachorro não passa; o cachorro também não gira se o graveto bater em algo no giro. Uma
  "correção de quina" desliza o cachorro para encaixar quando falta pouco (senão passar com o
  graveto atravessado exigiria mira de milímetros).
- **Q** alterna entre atravessado e ao comprido (apontando para a frente). Ao comprido passa em
  vãos estreitos, mas o graveto vai longe à frente e bate em paredes ao virar.
- **Peso**: deixa o cachorro mais lento e o pulo mais baixo, mas mais firme na correnteza
  (o arrasto é dividido pelo peso).
- **Equilíbrio**: em passagens estreitas (tile *Tábua*), carga = peso × comprimento acima de 1,2
  faz o cachorro balançar; o balanço cresce com o quadrado da velocidade e é menor ao comprido.
  Com o centro do corpo fora da tábua, ele cai. Ajustes no grupo "Equilíbrio" de
  `scripts/dachshund.gd`.

## Visual pixelado

- O 3D é renderizado em baixa resolução e ampliado sem filtro (`Viewport.scaling_3d_mode =
  NEAREST`); a interface continua nítida. Tudo no autoload `scripts/autoload/visual.gd`:
  **`LINHAS_ALVO`** (padrão 240) controla o quanto fica pixelado — menor = pixels maiores.
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
As fases são jogadas em ordem de nome de arquivo, então comece o nome com "Fase 02", "Fase 03"...
Num jogo exportado as fases salvas vão para `user://fases/`.

**Pelo editor do Godot** — também funciona: pinte o GridMap `Terreno` com a biblioteca de tiles e
arraste cenas de `scenes/objetos/` para dentro de `Objetos`.

Atalhos de construção: **Ctrl + arrastar** preenche um retângulo com o tile escolhido (um só
desfazer); **Shift + arrastar** com um objeto escolhido espalha cópias com espaçamento e
variações sorteadas — o "pincel de floresta"; **G** é o conta-gotas. Ao **Testar** o editor valida
a fase (falta início, dono ou graveto; início sem chão...) e pede confirmação se houver problema
grave; ao salvar, mostra os avisos.

Toda fase precisa de um **Início do cachorro**, um **Dono** e um **Graveto** (categoria "Regras").
Nas propriedades da fase (nada selecionado) ficam as **habilidades do cachorro** que a fase
libera (pular, cavar, latir) — a Fase 01 depende de o cachorro *não* pular o barranco. O comprimento e
o peso do graveto ficam nas propriedades do Graveto.

### A mecânica da perspectiva no editor

Todo objeto tem **Visibilidade**: *Sempre*, *Só isométrico* ou *Só 3D*. Objetos "só isométrico"
somem — e perdem a colisão — quando o cachorro pega o graveto (ex.: a *Tampa de folhagem* que
esconde a boca de um túnel); "só 3D" só aparecem depois (ex.: árvores na frente da trilha, que
tapariam a visão isométrica). Use a *Zona sem largar* onde largar o graveto deixaria o cachorro
preso quando as tampas voltarem.

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
  rampa), *Canto de rampa* (externo e interno, baixo e alto) para fechar montes e barrancos.
- **Modelos voxel em texto** — `assets/voxel/*.txt`: camadas desenhadas com letras, uma cor por
  letra (formato em [assets/voxel/LEIA-ME.md](assets/voxel/LEIA-ME.md)). Exemplos: `dono.txt`,
  `tronco_caido.txt`. Use com o nó `ModeloVoxel`.
- **Modelos voxel gerados por código** — `scripts/assets/voxel.gd`: árvores (pinheiro, redonda,
  arbusto), pedras e flores, cada uma com 8 variantes. As malhas ficam em cache.
- **Objetos de fase** — uma cena em `scenes/objetos/` cuja raiz estende `ObjetoFase`
  (`scripts/objetos/objeto_fase.gd`) aparece sozinha na paleta do editor, com ícone. Para
  expor parâmetros no painel do editor, liste as variáveis `@export` em
  `propriedades_editaveis()`; para sortear variações ao colocar, implemente
  `ao_colocar_no_editor(rng)`. Objetos sem lógica própria podem usar `objeto_simples.gd`.

## Estrutura

```
scenes/jogo.tscn              jogo: cachorro, câmera, HUD (a fase é carregada por código)
scenes/editor/editor_fase.tscn  editor de fases (F1)
scenes/fases/                 fases (conteúdo: terreno + objetos)
scenes/objetos/               objetos que o editor coloca
scripts/jogo.gd               regras: pegar/largar graveto, perspectiva, vitória
scripts/fase.gd               raiz de uma fase (consultas: objetos, tiles, água)
scripts/autoload/fases.gd     qual fase jogar/editar; troca jogo ↔ editor
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
| Quanto pixelado | `LINHAS_ALVO` em `scripts/autoload/visual.gd` |
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
