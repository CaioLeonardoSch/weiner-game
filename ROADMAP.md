# Próximas etapas

O que já existe: visual pixelado, trilha mais linear na Fase 01 com floresta em volta, pipeline
de assets (tiles gerados por código, modelos voxel em texto e procedurais, objetos que aparecem
sozinhos no editor), o editor de fases dentro do jogo (F1), o graveto com colisão, peso e
equilíbrio (etapa 3), habilidades por fase com o pulo, escadas e cantos de rampa (etapa 4),
cavar (5), empurrar e puxar (6), água rasa e correnteza (7), latir e passarinhos (8), as
melhorias principais do editor, o menu principal com pausa, o cachorro em voxel com raças e
pelagens, o objetivo da fase como dado (graveto ou pastoreio) e as Fases 02 a 05.

Abaixo, o que ficou para depois, na ordem sugerida. Cada item diz **onde encaixa** no código
atual, para a arquitetura não precisar mudar.

Ideia que vale para quase tudo daqui em diante: cada fase escolhe quais **habilidades** o
cachorro tem (pular, cavar, latir...). Isso deixa as fases antigas corretas quando uma habilidade
nova entra — a Fase 01, por exemplo, depende de o cachorro *não* pular o barranco de 2 m.
Sugestão: `@export var habilidades: Array[StringName]` em `scripts/fase.gd`, editável no painel
da fase no editor, e o `jogo.gd` liga só as habilidades listadas.

## Etapa 3 — Graveto de verdade ✅ (feito)

Colisão própria do graveto na boca, bloqueio de giro, correção de quina, virar o graveto ao
comprido (Q), peso (velocidade e pulo) e equilíbrio em passagens estreitas (tile *Tábua*),
com barra de equilíbrio no HUD. Fase 02 ("A Pinguela") usa tudo isso. Ficou para depois:

- **Formatos T/Y**: gravetos com galhos exigindo ângulo. A base já existe (forma de colisão do
  graveto no corpo); faltaria uma forma composta por formato e mais ângulos de virar
  (hoje são dois: atravessado e ao comprido).
- **Inclinar o graveto** (para cima/baixo) para passar por baixo/cima de obstáculos baixos.
- **Mais passagens estreitas**: tronco caído como pinguela, beirada de penhasco. Basta marcar
  `estreita = true` no tile (ou criar um objeto que responda a `Fase.passagem_estreita_em`).

## Etapa 4 — Movimento: pular, subir e descer níveis (quase toda ✅)

- ✅ **Habilidades por fase**: `Fase.habilidades` (flags, no painel da fase no editor).
- ✅ **Pular** (Espaço): 0,65 m sem graveto — sobe meio bloco, não um bloco inteiro; o peso
  do graveto reduz a altura.
- ✅ **Nivelamentos**: *Escada baixa/alta* (colide como rampa, parece degraus) e *Canto de
  rampa* externo e interno, baixo e alto (malhas geradas em `Tiles.malha_canto`). A Fase 04
  tem um monte fechado com cantos e uma escada até o platô.
- Ideias: rampa "de mão única" (escorrega, não dá para subir com graveto pesado), degrau alto
  que só se sobe pulando sem graveto.
- **Mais túneis**: já dá para montar no editor; variações úteis: tampas "só 3D" (caminhos que
  existem na ida e fecham na volta) e túneis baixos que só passam com o graveto ao comprido.

## Etapa 5 — Cavar ✅ (feito)

Tile **Terra fofa** (`cavavel`), habilidade *Cavar* e ação C: desfaz o bloco na frente do
focinho, na altura do corpo, com animação e torrões de terra. Não cava com o graveto na boca.
Usada na Fase 03 (túnel cavado num monte). Ideias para depois:

- Cavar para baixo (buraco) — precisa de jeito de sair (rampa de terra, pulo).
- Graveto enterrado: objeto que só aparece depois de cavar a célula onde ele está.
- Cavar por baixo de cercas (passagem baixa), combinando com graveto ao comprido.

## Etapa 6 — Empurrar ✅ (feito)

Objeto **Bloco empurrável**: andar contra ele por um instante empurra uma célula (estilo
Sokoban), se o destino estiver livre e tiver chão. Empurrado para dentro da água, afunda até
ficar rente ao chão e vira passagem. Não entra em cima do graveto nem de passarinhos; se
ficar encurralado num canto (nenhum empurrão possível), volta sozinho para onde começou.
Ideias para depois:

- Tronco empurrável que rola e vira ponte sobre dois blocos de água.
- Empurrar com o graveto ao comprido (alcance maior) ou só sem graveto.
- Blocos que tampam túneis (abrir caminho empurrando) e placas de pressão.
- ✅ **Puxar**: segurando F e andando para trás (sem graveto), o cachorro puxa o bloco que
  está à frente dele uma célula. Tira blocos de nichos e desfaz empurrões errados. Usado na
  Fase 04.

## Etapa 7 — Riachos e água (em parte ✅)

- ✅ **Água** funda (sem colisão, "Splash!"), **Água rasa** (atravessável, mais lenta) e
  **Correnteza** (água rasa que arrasta no sentido +X do tile; o graveto pesado deixa o cachorro
  mais firme). O shader da água mostra o sentido do fluxo. Levado pela correnteza até a água
  funda, o cachorro cai. Fase 04 ("A Correnteza").
- Próximos passos:
  - Graveto molhado pesa mais (por alguns segundos depois de passar na água rasa)?
  - Objetos que boiam e descem a correnteza (folhas, tronco) — dá para subir neles.
  - **Travessia**: tronco empurrado, pedras de apoio (meio bloco + pulo).

## Etapa 8 — Latir ✅ (feito)

Habilidade *Latir* e ação B: onda e "Au!" em volta do cachorro; objetos até 5 m recebem
`ao_ouvir_latido(origem)` (método base em `ObjetoFase`). **Passarinho**: pousado a até 1 m do
graveto, não deixa pegar; com `bloqueia_passagem`, fica no caminho; ao ouvir o latido, voa
embora. Não dá para latir com o graveto na boca. Ideias para depois:

- Esquilo que pega o graveto e foge (latir faz largar).
- Acordar o dono / outros cachorros que respondem ao latido.
- Som do latido gerado por código (`AudioStreamGenerator`), mantendo "nada de assets externos".

## Etapa 9 — Truques (rolar, abanar o rabo, ficar em duas patas)

- Primeiro separar o modelo do cachorro em pivôs (cabeça, rabo, patas, corpo) em
  `scenes/dachshund.tscn` e animar por código (tweens) ou com `AnimationPlayer`.
- Truques como mecânica: o dono (ou outro personagem) pede um truque para liberar algo;
  **duas patas** alcança/enxerga mais alto (e o graveto sobe junto — passa por cima de
  obstáculos baixos); **rolar** passa por baixo de algo baixo sem o graveto (larga e pega de
  novo); **abanar o rabo** para interagir com animais.
- Ações novas no InputMap (`truque_rolar`, `truque_rabo`, `truque_duas_patas`) ou um menu radial.

## Editor de fases — melhorias

- ✅ Retângulo de preenchimento (Ctrl + arrastar), conta-gotas (G), "pincel de floresta"
  (Shift + arrastar com um objeto) e validação ao testar/salvar.
- Balde de tinta.
- Seleção múltipla, copiar/colar regiões entre fases.
- Mostrar no editor as habilidades liberadas e o comprimento do graveto (prévia de passagens).
- Validação mais esperta: o graveto é alcançável? (rodar uma busca de caminho pela grade).
- Preservar os IDs internos ao salvar para o diff no git ficar menor.

## Visão: raças, skins e missões (começou ✅)

O editor de fases é a base de tudo isso.

- ✅ **Skins**: o cachorro virou voxel gerado por código, e uma pelagem é só um conjunto de
  cores (recurso `Pelagem`). O salsicha tem 8: vermelho, preto e fogo, chocolate, malhado,
  creme, branco e pelo longo (vermelho, preto e fogo). Escolha no menu (tela Cachorro).
- ✅ **Raças como dados** (`assets/racas/*.tres`, recurso `Raca`): proporções, orelha, rabo,
  velocidade e habilidades nativas; a fase escolhe a raça. Já existem salsicha, pug e border
  collie.
- ✅ **Objetivo da fase como dado** (`Fase.objetivo`): trazer o graveto ao dono (o de sempre) ou
  levar as ovelhas ao cercado. Cada objetivo diz o que a fase precisa (`Fase.requisitos()`) e
  o `jogo.gd` prepara e confere o objetivo (`_preparar_objetivo` / `_verificar_objetivo`).
- ✅ **Border Collie**: objetos *Ovelha* (foge do cachorro, anda em rebanho, se espanta com o
  latido, não entra na água funda) e *Cercado*; Fase 05 ("O Pastor").
- Próximas raças (o formato já comporta, falta a mecânica de cada uma):
  - *Pug*: já tem modelo e pelagens (bege, preto); falta uma fase com a cara dele (mais lento,
    mas passa por baixo de coisas? empurra com o peso?).
  - *Malinois*: cão policial que segue o **faro** — objetivo novo "achar o objeto": rastro
    de cheiro visível ao farejar (tecla nova), em casas, cidade, fazenda, fases noturnas.
  - *Corgi*: tema britânico (patas curtíssimas: passa em túneis bem baixos).
  - *Akita*: homenagem ao Hachiko (esperar o dono na estação?).
  - *Jack Russell*: buscar uma máscara mágica do dono, com homenagens a filmes na visão 3D.
  - Fases especiais com **gato** (ex.: um gato laranja preguiçoso atrás de lasanha), como skin
    da primeira fase — um gato é outro gerador voxel (ou uma "raça" com orelhas em pé e rabo
    longo) mais um objetivo "buscar a comida".
- Ideias para o pastoreio: ovelha teimosa (só anda com latido), carneiro que dá cabeçada,
  porteira que fecha com um botão, vários cercados (separar as ovelhas negras).
- **Temas** (fazenda, cidade, noite, Reino Unido) = paleta de tiles/materiais + céu e luz por
  fase.
- Colisão por raça: hoje todas usam a cápsula do salsicha; um border collie alto passaria por
  onde não deveria (a altura importa em túneis). Dá para derivar a cápsula das medidas da raça.
- Som por raça (latido grave/agudo), quando houver áudio.
- Cuidado com propriedade intelectual: nada de nomes, personagens ou visual copiados de
  filmes e quadrinhos — homenagens genéricas (um gato laranja guloso, uma máscara mágica) são
  o caminho seguro.

## Visual e câmera

- Árvores entre a câmera 3D e o cachorro ficarem transparentes (dither) em vez de taparem.
- ✅ Modelo do cachorro em voxel e animações de andar (patas, rabo, orelhas). Faltam animações
  de cavar, latir e pular mais caprichadas (hoje o corpo todo inclina).
- Céu e luz por fase (hoje ficam em `scenes/ambiente.tscn`, iguais para todas).
- Se um dia houver objetos transparentes que precisem de contorno, trocar o quad de contorno por
  um `CompositorEffect`.

## Técnico

- Preset de exportação incluindo `*.txt` (modelos voxel) nos arquivos não-recurso.
- Testes automatizados de fase: um roteiro que joga a fase com entradas simuladas e confere que
  dá para chegar ao graveto e voltar (foi assim que a Fase 01 foi testada nesta etapa).
- ✅ Menu inicial, seleção de fases, pausa, progresso salvo. Falta: opções (volume, tela
  cheia, sensibilidade do mouse, tamanho do pixel) e remapear teclas.
