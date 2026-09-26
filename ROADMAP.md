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
Já é assim: `Fase.habilidades` (flags no painel da fase no editor), somadas às habilidades
nativas da raça; o `jogo.gd` liga só essas.

## Visão

O Weiner Game começa com um salsicha atrás de gravetos, mas quer ir além: mostrar as muitas
vidas que os cães levam ao nosso lado, pelo mundo afora — cães de família, de rua, de fazenda,
de trabalho, de gente rica. No dia a dia pensamos na vida que temos e na que damos ao nosso
cachorro, e está tudo bem; o jogo só quer lembrar que, ao mesmo tempo, outros cães estão
vivendo vidas bem diferentes.

Como isso vira jogo:

- **Regiões** agrupam as fases: cada uma tem um tema e uma pequena história (ver abaixo).
- **Temas** são lugares e vidas: o parque, a fazenda, a neve, o mar, a casa à noite, a cidade
  grande e suas ruas, cidades, favelas e o interior do Brasil...
- **Raças** são jeitos de resolver: cada uma tem uma mecânica própria (ver "Raças com mecânica
  própria" em *Raças, skins, missões e temas*).
- **Missões** são o que cada vida pede: buscar o graveto, pastorear, guardar a casa, farejar,
  alimentar os filhotes...

### Regiões e história

- Seguindo nessa linha, dá para chegar a umas **10 regiões, somando 25 a 50 fases**, de
  tamanhos diferentes, misturando mecânicas novas e antigas, com uma pequena história ligando
  as fases de cada região.
- **Exemplo — a primeira região, o parque**: um cão e seu dono passeiam por um parque, e o
  cãozinho vai coletando seus gravetos favoritos; cada fase é um dia de passeio diferente. No
  fim da última fase, vemos o dono e o cão em casa, com uma pilha de gravetos lendários.
- Outras regiões candidatas (deste brainstorm): fazenda (pastoreio — a Fase 05 já é dela),
  neve, mar, a casa à noite (cão de guarda), a cidade e suas ruas (a mãe e os filhotes),
  Brasil (cidade, favela, interior), Reino Unido (corgi)...
- **Raça e pelagem por região**: nem toda fase serve para todo cão, então cada região diz com
  quais raças é compatível. Antes de entrar numa região, o jogador escolhe a raça entre as
  compatíveis e, depois, a pelagem. Jogar a região de novo com outra raça mostra outros
  caminhos.
- *Onde encaixa:* recurso `Regiao` (`assets/regioes/*.tres`: nome, tema, fases em ordem, raças
  compatíveis, textos ou cenas de abertura e de final). O menu passa a ser Regiões → raça →
  pelagem → fases, e o progresso guarda (fase, raça). Hoje as fases são uma lista só
  (`Fases.listar()`, em ordem de nome), a pelagem se escolhe na tela Cachorro do menu e a raça
  vem de `Fase.raca` — que continua útil como raça padrão para testar no editor. Toda fase
  precisa ter solução com cada raça compatível da região.

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
  O próprio graveto também pode virar pinguela — ver Etapa 10.

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
  Tocas de texugo e portinholas (Etapa 10) levam a ideia adiante.

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
- Blocos que tampam túneis (abrir caminho empurrando).
- Placas de pressão — detalhadas na Etapa 10 (bloco como peso é o uso mais direto).
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
  - **Travessia**: tronco empurrado, pedras de apoio (meio bloco + pulo), graveto ou tronco
    como ponte (Etapa 10), comporta que baixa a água (Etapa 10) e, no mar, o barquinho
    (Etapa 12).

## Etapa 8 — Latir ✅ (feito)

Habilidade *Latir* e ação B: onda e "Au!" em volta do cachorro; objetos até 5 m recebem
`ao_ouvir_latido(origem)` (método base em `ObjetoFase`). **Passarinho**: pousado a até 1 m do
graveto, não deixa pegar; com `bloqueia_passagem`, fica no caminho; ao ouvir o latido, voa
embora. Não dá para latir com o graveto na boca. Ideias para depois:

- Pássaros pousados numa alavanca ou contrapeso: o latido faz o mecanismo mexer, mas eles
  voltam com o tempo — ver "Pássaros no contrapeso", Etapa 10.
- Esquilo que pega o graveto e foge (latir faz largar) — só vale se houver um bom motivo para
  ele querer o graveto (ex.: na neve, estocando coisas para o inverno).
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

## Etapa 10 — Quebra-cabeças com gravetos: placas, pontes, tocas e mirantes

A ideia central: o graveto deixa de ser só o prêmio e vira também **ferramenta**. Tudo aqui
combina com o que já existe — a troca de perspectiva, a colisão e o peso do graveto, blocos,
água e latido.

- **Gravetos comuns e o graveto lendário.** Uma fase pode ter vários gravetos. Só o
  **lendário** — dourado, com um brilho — conclui a fase ao ser entregue ao dono. Os outros,
  marrons e comuns, também mudam a perspectiva quando o cachorro os pega, mas servem de
  ferramenta no caminho: ponte, peso numa placa, algo para trocar. Largar um para pegar outro
  vira decisão de quebra-cabeça.
  *Onde encaixa:* `Graveto.lendario` (material dourado e partículas). O `jogo.gd` hoje liga só
  `fase.primeiro(Graveto)`; passa a ligar todos, e o dono só aceita o lendário. A validação do
  editor exige exatamente um lendário.
- **Placa de pressão e portão.** A placa abre (ou fecha) portões enquanto tem peso em cima: um
  bloco, uma ovelha, o próprio cachorro, um graveto largado, um bando de pássaros. O melhor
  dilema: quando só o graveto pesa o bastante, ele é **a chave e o prêmio** ao mesmo tempo — é
  preciso pôr outra coisa na placa antes de levá-lo embora. Placas "só isométrico" ou "só 3D"
  amarram o mecanismo à perspectiva.
  *Onde encaixa:* objetos `Placa` (Area3D que soma o peso do que está em cima) e `Portao`
  (colisão ligada/desligada, como `ObjetoFase.definir_ativo`), ligados por um **canal** (nome ou
  número no painel do editor). O mesmo canal serve para comporta, ponte levadiça, lanterna...
- **O graveto vira ponte.** Largado ao comprido sobre um vão de uma célula (buraco, riacho
  estreito), um graveto longo vira pinguela, com o equilíbrio da Tábua. Como largar volta para a
  isométrica (e as tampas voltam!), **onde** fazer a ponte importa. O cachorro atravessa e pega
  o graveto de volta pela outra ponta; um graveto curto não alcança os dois lados.
  *Onde encaixa:* ao largar ao comprido com as duas pontas apoiadas, o graveto ganha uma colisão
  fina e passa a responder a `Fase.passagem_estreita_em`.
- **Troncos: gravetos gigantes.** Praticamente troncos, pesados demais para carregar: o cachorro
  morde perto da ponta e arrasta o resto pelo chão. Anda devagar, não pula, faz curvas abertas
  (o tronco vem atrás, como um reboque) e enrosca em quinas. Largados sobre água ou vãos de 2 a
  3 células, viram pontes largas.
  *Onde encaixa:* modo "arrastar" no `dachshund.gd`: uma ponta presa na boca e a outra seguindo
  a trajetória, com colisão ao longo do tronco; ao soltar, encaixa na grade.
- **Toca de texugo (a mecânica do salsicha).** "Dachshund" quer dizer "cão de texugo": o
  salsicha foi criado para entrar em tocas. Duas tocas ligadas: o cachorro entra numa e sai na
  outra. O graveto precisa caber (só ao comprido, ou só gravetos curtos), e uma toca "só 3D" é
  um atalho que só existe na volta. Raças grandes não entram — uma rota que só o salsicha faz.
  *Onde encaixa:* objeto `Toca` com um canal para o par; entrando de frente, a tela escurece e
  o cachorro sai pela outra. A raça e o graveto na boca dizem se cabe.
- **Portinhola de cachorro.** A portinha na porta de casa ou do quintal: o cachorro passa; com
  o graveto, só ao comprido — e um graveto grande demais não passa de jeito nenhum. Pode ser de
  mão única. É por onde o cão policial entra na casa para farejar (ver missões), e o tamanho do
  cão também conta: um pastor alemão não cabe na portinhola de um salsicha. O mesmo raciocínio
  vale para vãos, cercas e troncos: cada tamanho de graveto passa por lugares diferentes (a
  colisão do graveto já garante isso).
  *Onde encaixa:* objeto com moldura (colisão) e abertura do tamanho escolhido; a mão única é
  uma área que só deixa passar num sentido. Depende da colisão por raça (seção de raças).
- **Pássaros no contrapeso (corrida contra o tempo).** Um bando pousado numa alavanca ou num
  contrapeso: o peso deles segura o mecanismo. Um latido e eles voam — a alavanca se mexe (abre
  um portão, baixa a água, levanta uma ponte) —, mas com o tempo eles voltam e pousam de novo,
  desfazendo tudo. É preciso ser rápido para passar.
  *Onde encaixa:* `Passaro` ganha "voltar ao pouso depois de N segundos"; a alavanca é uma
  `Placa` que conta os pássaros pousados.
- **Comporta: o nível da água.** Ligada a uma placa, a uma alavanca ou aos pássaros, a comporta
  troca a água de uma área — funda ↔ rasa, ou seca — por um tempo ou de vez. Junta placa,
  pássaros, correnteza e o barco (Etapa 12).
  *Onde encaixa:* objeto `Comporta` com uma área marcada no editor; troca os tiles `AGUA` ↔
  `AGUA_RASA` do GridMap, do mesmo jeito que o cavar tira a terra fofa.
- **Mirante: o graveto fincado.** Num ponto alto, um graveto preso (fincado no chão ou num
  tronco) que não sai do lugar. Mordendo-o, a perspectiva muda — só para olhar: o jogador estuda
  a fase pelo outro ângulo e planeja os próximos passos; soltando, volta. Evolução: no mirante,
  girar a isométrica 90° (as faces escondidas mudam e outros caminhos aparecem).
  *Onde encaixa:* objeto `GravetoFincado`; ao morder, a câmera vai para o 3D (ou para uma vista
  panorâmica) sem ligar nem desligar passagens, e o cachorro fica parado.
- **Botão de ação (F), conforme o que está na frente.** Um botão só, que muda de acordo com o
  que está por perto e para onde o cachorro está olhando: olhando para uma pedra ou um bloco,
  F + trás puxa (como hoje); para um tronco, F morde e arrasta; para uma corda, F puxa e aciona;
  para o graveto fincado, F morde (mirante); para um invasor, F morde a bunda dele. E assim por
  diante. Sem graveto na boca, claro.
  *Onde encaixa:* método base em `ObjetoFase` (ex.: `acao_da_boca(cachorro)`, que devolve o nome
  da ação ou vazio); o cachorro procura o objeto à frente do focinho (como o `_bloco_na_frente`
  do puxar) e o HUD mostra a ação disponível ("F: morder", "F: puxar corda").

## Etapa 11 — Neve: frio, fogo e vento

Fases de inverno em que andar já é um esforço e o caminho precisa ser aberto com fogo.

- **Neve fofa**: movimento pesado — mais lento, e o cachorro demora a arrancar e a parar.
  *Onde encaixa:* tile `Neve` com `lentidao` (como a água rasa) e um pouco de inércia no
  `dachshund.gd`.
- **Montes de neve**: bloqueiam o caminho; derretem com fogo ou são cavados.
  *Onde encaixa:* tile `Neve funda` com `cavavel`.
- **Gelo**: o cachorro desliza até bater em algo (o quebra-cabeça clássico de deslizar). Com o
  graveto atravessado ele bate antes — virar (Q) muda onde ele para. Blocos também deslizam.
  *Onde encaixa:* tile com uma flag `escorrega`: no gelo o cachorro mantém a direção até
  colidir, e o `Empurravel` desliza até ser bloqueado.
- **Fogo que derrete**: lanternas, lareiras e fogueiras acesas derretem a neve em volta e
  facilitam o acesso. Jeitos de acender: puxar a corda de um lampião, empurrar uma brasa ou
  **levar um graveto aceso** de uma fogueira a outra — com o vento tentando apagar a chama pelo
  caminho. **Fogueira maior**: gravetos comuns enterrados na neve são cavados e levados, um a um,
  até a fogueira; quanto mais gravetos, maior o fogo e maior a área de neve que ele derrete.
  *Onde encaixa:* objeto `Fogo` (apagado/aceso, com um raio que cresce a cada graveto recebido);
  ao acender ou crescer, troca os tiles de neve em volta (com um efeito de derreter). Pode ser
  alvo de um canal (placa, alavanca).
- **Cavar na neve**: descobre um pedacinho do chão, onde pode haver algo útil (um osso, um pano,
  uma chave, gravetos para a fogueira) ou o próprio graveto lendário, se for o lugar certo. O
  faro ajuda a saber onde cavar.
  *Onde encaixa:* objeto "montinho de neve" que esconde outro objeto e some ao ser cavado (o
  mesmo mecanismo do "graveto enterrado", Etapa 5).
- **Vento forte**: rajadas que empurram o cachorro para trás; é preciso avançar de abrigo em
  abrigo, atrás de paredes, árvores e pedras. O graveto atravessado vira vela (empurra mais), ao
  comprido corta o vento, e um graveto pesado deixa o cachorro mais firme.
  *Onde encaixa:* objeto `Vento` (área com direção e rajadas) que soma um arrasto como a
  correnteza (`_efeito_da_agua`); um raio na direção do vento diz se há abrigo.

## Etapa 12 — Mar: o barquinho

- Atravessar um corpo d'água grande (até uma ilha, o outro lado da baía) num barquinho. Só que
  o barco está quebrado: é preciso buscar gravetos para montar ou consertar as partes e um pano
  para a vela — um de cada vez, na boca. Cada peça entregue aparece no barco.
- Pronto o barco, o **vento** enche a vela (o mesmo da neve); correnteza e ondas atrapalham. Como
  pilotar fica em aberto: virar a vela com Q, inclinar o corpo, esperar a rajada certa...
- *Onde encaixa:* objeto `Barco` (recebe as peças e depois vira uma plataforma que anda sobre a
  água funda); as peças são gravetos comuns e um objeto `Pano` carregado na boca. Pode ser um
  objetivo novo ("consertar o barco e atravessar") ou parte do caminho até o graveto lendário.

## Editor de fases — melhorias

- ✅ Retângulo de preenchimento (Ctrl + arrastar), conta-gotas (G), "pincel de floresta"
  (Shift + arrastar com um objeto) e validação ao testar/salvar.
- Balde de tinta.
- Seleção múltipla, copiar/colar regiões entre fases.
- Mostrar no editor as habilidades liberadas e o comprimento do graveto (prévia de passagens).
- Validação mais esperta: o graveto é alcançável? (rodar uma busca de caminho pela grade).
- Preservar os IDs internos ao salvar para o diff no git ficar menor.

## Raças, skins, missões e temas (começou ✅)

O editor de fases é a base de tudo isso (e a seção *Visão*, no começo, diz o porquê).

- ✅ **Skins**: o cachorro virou voxel gerado por código, e uma pelagem é só um conjunto de
  cores (recurso `Pelagem`). O salsicha tem 8: vermelho, preto e fogo, chocolate, malhado,
  creme, branco e pelo longo (vermelho, preto e fogo). Escolha no menu (tela Cachorro); com as
  regiões, passa a ser escolhida ao entrar na região, depois da raça.
- ✅ **Raças como dados** (`assets/racas/*.tres`, recurso `Raca`): proporções, orelha, rabo,
  velocidade e habilidades nativas; a fase escolhe a raça. Já existem salsicha, pug e border
  collie.
- ✅ **Objetivo da fase como dado** (`Fase.objetivo`): trazer o graveto ao dono (o de sempre) ou
  levar as ovelhas ao cercado. Cada objetivo diz o que a fase precisa (`Fase.requisitos()`) e
  o `jogo.gd` prepara e confere o objetivo (`_preparar_objetivo` / `_verificar_objetivo`).
- ✅ **Border Collie**: objetos *Ovelha* (foge do cachorro, anda em rebanho, se espanta com o
  latido, não entra na água funda) e *Cercado*; Fase 05 ("O Pastor").
- **Raças com mecânica própria.** Cada raça resolve os quebra-cabeças do seu jeito; a raça é
  escolhida ao entrar na região, entre as compatíveis (ver *Visão → Regiões e história*).
  Regra geral do corpo: raças **mais gordinhas são mais pesadas** (seguram uma placa de pressão
  sozinhas, empurram melhor) e raças **mais esguias passam por frestas** (vira-lata, galgo,
  salsicha). Ideias por raça (a definir):
  - *Salsicha*: tocas de texugo, cavar, túneis baixos, frestas.
  - *Border Collie*: pastoreio e latido (feito).
  - *Pastor Alemão e Malinois*: faro, morder e guardar a casa (ver missões); o Malinois pula
    alto.
  - *Pug*: pesado — segura uma placa sozinho, empurra melhor.
  - *Corgi*: túneis bem baixos.
  - *Vira-lata caramelo*: se vira na cidade — acha comida pelo faro, passa por frestas de muros
    e grades, conhece os atalhos.
  - *Galgo*: esguio e rápido — frestas.

  *Onde encaixa:* o level design ganha rotas que só certas raças usam (toca, portinhola,
  fresta, pulo alto, peso). Depende da colisão por raça e de um "peso" na `Raca`.
- Próximas raças (o formato já comporta, falta a mecânica de cada uma):
  - *Pug*: já tem modelo e pelagens (bege, preto); falta uma fase com a cara dele (mais lento,
    mas passa por baixo de coisas? empurra com o peso?).
  - *Pastor Alemão e Malinois*: cães policiais e de guarda. Seguem o **faro** — objetivo novo
    "achar o objeto": rastro de cheiro visível ao farejar (tecla nova), em casas, cidade,
    fazenda, fases noturnas (ex.: entrar numa casa pela portinhola e farejar um item) — e
    guardam a casa à noite (ver missões).
  - *Vira-lata caramelo*: o cachorro brasileiro por excelência, com pelagens de vira-lata
    (caramelo e outras); fases na cidade grande, em favelas e no interior do Brasil.
  - *Galgo*: esguio e rápido; passa por frestas.
  - *Corgi*: tema britânico (patas curtíssimas: passa em túneis bem baixos).
  - *Akita*: homenagem ao Hachiko (esperar o dono na estação?).
  - *Jack Russell*: buscar uma máscara mágica do dono, com homenagens a filmes na visão 3D.
  - Fases especiais com **gato** (ex.: um gato laranja preguiçoso atrás de lasanha), como skin
    da primeira fase — um gato é outro gerador voxel (ou uma "raça" com orelhas em pé e rabo
    longo) mais um objetivo "buscar a comida".
- Ideias para o pastoreio: ovelha teimosa (só anda com latido), carneiro que dá cabeçada,
  porteira que fecha com um botão (placa + portão, Etapa 10), vários cercados (separar as
  ovelhas negras).
- **Missões novas** (cada uma é um `Fase.objetivo` novo, com seus requisitos):
  - **Cão de guarda (a casa à noite)**: um Pastor Alemão ou Malinois ouve um barulho e sai para
    investigar. Os invasores fogem correndo quando levam uma mordida na bunda e tentam se
    esconder; o cão precisa encontrá-los — pelo faro, pelos barulhos — e impedir que cheguem
    aos quartos dos donos. Falha se um invasor chegar a um quarto.
    *Onde encaixa:* objeto `Invasor` (IA parecida com a da ovelha, mas indo para os quartos e se
    escondendo), o botão de ação (Etapa 10) e o tema noite (luz baixa, lanternas).
  - **A mãe e os filhotes (cães de rua)**: uma cadela de rua procura comida em latas e lixeiras
    da cidade e volta para alimentar os filhotes — várias viagens, passando por vielas, outros
    cães (território), gatos e pessoas (umas ajudam, outras espantam). Uma fase melancólica,
    contada com carinho.
    *Onde encaixa:* objetivo "levar comida aos filhotes": a comida vai na boca (boca cheia, como
    o graveto) até o ninho, com um contador como o das ovelhas; objetos da cidade e personagens
    que reagem ao cachorro.
- **Temas** = paleta de tiles/materiais + céu e luz por fase + objetos próprios: parque e
  fazenda (já há fases), neve (Etapa 11), mar (Etapa 12), casa à noite, cidade grande e suas
  ruas, Brasil (cidade, favela, interior), Reino Unido... Lugares reais precisam ser
  reconhecíveis — com os elementos que todo mundo identifica — e retratados com respeito.
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
- Céu e luz por fase (hoje ficam em `scenes/ambiente.tscn`, iguais para todas) — necessário
  para os temas de noite, neve e mar.
- Se um dia houver objetos transparentes que precisem de contorno, trocar o quad de contorno por
  um `CompositorEffect`.

## Técnico

- Preset de exportação incluindo `*.txt` (modelos voxel) nos arquivos não-recurso.
- Testes automatizados de fase: um roteiro que joga a fase com entradas simuladas e confere que
  dá para chegar ao graveto e voltar (foi assim que a Fase 01 foi testada nesta etapa).
- ✅ Menu inicial, seleção de fases, pausa, progresso salvo. Falta: opções (volume, tela
  cheia, sensibilidade do mouse, tamanho do pixel) e remapear teclas.
