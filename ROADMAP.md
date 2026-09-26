# Próximas etapas

O que já existe (etapas 1 e 2): visual pixelado, trilha mais linear na Fase 01 com floresta em
volta, pipeline de assets (tiles gerados por código, modelos voxel em texto e procedurais,
objetos que aparecem sozinhos no editor) e o editor de fases dentro do jogo (F1).

Abaixo, o que ficou para depois, na ordem sugerida. Cada item diz **onde encaixa** no código
atual, para a arquitetura não precisar mudar.

Ideia que vale para quase tudo daqui em diante: cada fase escolhe quais **habilidades** o
cachorro tem (pular, cavar, latir...). Isso deixa as fases antigas corretas quando uma habilidade
nova entra — a Fase 01, por exemplo, depende de o cachorro *não* pular o barranco de 2 m.
Sugestão: `@export var habilidades: Array[StringName]` em `scripts/fase.gd`, editável no painel
da fase no editor, e o `jogo.gd` liga só as habilidades listadas.

## Etapa 3 — Graveto de verdade: tamanho, peso e equilíbrio

O núcleo do conceito. Hoje o graveto já tem `comprimento` e `peso` (editáveis no editor); o
comprimento só muda o visual e o peso deixa o cachorro mais lento.

- **Colisão do graveto na boca**: uma `ShapeCast3D` (ou forma extra no `CharacterBody3D`)
  com o comprimento do graveto, atravessada na boca. Se o graveto não passa, o cachorro não
  passa — túneis estreitos, árvores próximas e cercas viram o puzzle. Cuidado com a sensação de
  "preso": prever um giro de cabeça (segurar um botão para inclinar/virar o graveto) em vez de
  depender de sorte na colisão (ver notas de design no CONCEITO.md).
- **Equilíbrio em passagens estreitas** (tábua sobre água, pinguela sobre penhasco): o tile
  `Tábua` já existe. Ideia: numa superfície estreita, o cachorro ganha um "balanço" que cresce com
  `peso × comprimento` e com a velocidade; o jogador compensa com esquerda/direita; passou do
  limite, cai (já existe o retorno ao ponto seguro quando cai na água ou no abismo).
  Detectar "superfície estreita": tile `TABUA` embaixo (`Fase.tile_em`) ou um objeto/área
  `PassagemEstreita` colocado pelo editor.
- **Formatos**: gravetos em T/Y exigem ângulo — depende do giro de cabeça acima.
- Mostrar no HUD o tamanho/peso do graveto da fase quando ele é pego.

## Etapa 4 — Movimento: pular, subir e descer níveis

- **Pular**: ação `pular` no InputMap; impulso em `dachshund.gd`. Pulo baixo (≤ 0,6 m) para
  subir meio bloco (`Meio bloco` já existe) sem estragar barrancos de 2 m. Peso do graveto reduz
  a altura do pulo (ideia do CONCEITO.md).
- **Nivelamentos diferentes** já dá para montar no editor (blocos, meio bloco, rampas). Faltam
  tiles de canto de rampa e escada — acrescentar em `Tiles.definicoes()` (sempre com ID novo no
  fim) e gerar a biblioteca de novo.
- **Mais túneis**: já dá para cavar túneis no editor tirando blocos de mato/terra e tampando as
  bocas com *Tampa de folhagem* (só isométrico). Variações úteis: tampas "só 3D" (caminhos que
  existem na ida e fecham na volta) e túneis mais baixos que só passam com graveto curto.

## Etapa 5 — Cavar

- Tile novo **Terra fofa** (`Tiles`: `cavavel = true`). Ação `cavar`: olha a célula na frente e
  embaixo do focinho (`Fase.terreno.local_to_map`) e, se for cavável, remove com
  `GridMap.set_cell_item(celula, -1)` (com uma animação/partículas de terra).
- Possibilidades: cavar por baixo de cercas (passagem baixa), desenterrar o graveto (objeto
  "Graveto enterrado" que só aparece depois de cavar), cavar degraus.
- O jogo reinicia a fase recarregando a cena, então buracos cavados voltam sozinhos.

## Etapa 6 — Empurrar pedras e troncos

- Objeto `Empurravel` (base para `Pedra` e `Tronco caído` empurráveis, marcados por uma variável
  `empurravel` no editor). Duas opções:
  1. **Por células** (recomendado para puzzle): empurrar move o objeto 1 célula inteira com
     tween, se a célula de destino estiver livre e com chão; previsível, estilo Sokoban.
  2. Física (`RigidBody3D`): mais solto, menos previsível.
- Usos: fazer ponte/escada (tronco empurrado para dentro do riacho vira caminho), abrir passagem,
  segurar uma tampa aberta.
- O editor já trata qualquer objeto novo; basta a cena em `scenes/objetos/`.

## Etapa 7 — Riachos e água

- Já existe o tile `Água` (visual pixelado, sem colisão): cair nela devolve o cachorro ao último
  ponto seguro ("Splash!"). Próximos passos:
  - **Água rasa** (tile novo com leito a meio bloco): atravessável, mais lenta; graveto molhado
    pesa mais?
  - **Correnteza**: empurra o cachorro numa direção (variável por célula ou objeto "Corrente").
  - **Travessia**: tábua (já existe), tronco empurrado, pedras de apoio (meio bloco).

## Etapa 8 — Latir

- Ação `latir`: uma `Area3D` esférica momentânea em volta do cachorro; objetos dentro recebem
  `ao_ouvir_latido(cachorro)` — acrescentar esse método (vazio) em `ObjetoFase`.
- **Pássaros**: objeto `Passaro` pousado num galho/no graveto/no caminho; ao ouvir o latido, voa
  para longe (modelo voxel em texto, animação simples de bater asas). Pássaro em cima do graveto
  impede pegar; pássaro no caminho estreito bloqueia a passagem.
- Outros usos: acordar o dono, espantar esquilo que leva o graveto embora.
- Som: gerar os efeitos (sem assets externos) com `AudioStreamGenerator` ou deixar para quando a
  regra de "nada de assets externos" for revista.

## Etapa 9 — Truques (rolar, abanar o rabo, ficar em duas patas)

- Primeiro separar o modelo do cachorro em pivôs (cabeça, rabo, patas, corpo) em
  `scenes/dachshund.tscn` e animar por código (tweens) ou com `AnimationPlayer`.
- Truques como mecânica: o dono (ou outro personagem) pede um truque para liberar algo;
  **duas patas** alcança/enxerga mais alto (e o graveto sobe junto — passa por cima de
  obstáculos baixos); **rolar** passa por baixo de algo baixo sem o graveto (larga e pega de
  novo); **abanar o rabo** para interagir com animais.
- Ações novas no InputMap (`truque_rolar`, `truque_rabo`, `truque_duas_patas`) ou um menu radial.

## Editor de fases — melhorias

- Retângulo de preenchimento (Shift + arrastar) e balde de tinta.
- Conta-gotas (pegar o tile/objeto sob o cursor).
- "Pincel de floresta": espalhar árvores aleatórias arrastando.
- Seleção múltipla, copiar/colar regiões entre fases.
- Mostrar no editor as habilidades liberadas e o comprimento do graveto (prévia de passagens).
- Validação ao salvar/testar (falta início, dono ou graveto; graveto fora do alcance...).
- Preservar os IDs internos ao salvar para o diff no git ficar menor.

## Visual e câmera

- Árvores entre a câmera 3D e o cachorro ficarem transparentes (dither) em vez de taparem.
- Modelo do cachorro em voxel e animações de andar.
- Céu e luz por fase (hoje ficam em `scenes/ambiente.tscn`, iguais para todas).
- Se um dia houver objetos transparentes que precisem de contorno, trocar o quad de contorno por
  um `CompositorEffect`.

## Técnico

- Preset de exportação incluindo `*.txt` (modelos voxel) nos arquivos não-recurso.
- Testes automatizados de fase: um roteiro que joga a fase com entradas simuladas e confere que
  dá para chegar ao graveto e voltar (foi assim que a Fase 01 foi testada nesta etapa).
- Menu inicial / seleção de fases.
