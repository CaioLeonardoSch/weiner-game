# Próximas etapas

O que já existe: visual pixelado, trilha mais linear na Fase 01 com floresta em volta, pipeline
de assets (tiles gerados por código, modelos voxel em texto e procedurais, objetos que aparecem
sozinhos no editor), o editor de fases dentro do jogo (F1), o graveto com colisão, peso e
equilíbrio (etapa 3), habilidades por fase com o pulo, escadas e cantos de rampa (etapa 4),
cavar (5), empurrar e puxar (6), água rasa e correnteza (7), latir e passarinhos (8), as
melhorias principais do editor, o menu principal com pausa, o cachorro em voxel com raças e
pelagens, o objetivo da fase como dado (graveto ou pastoreio) e as Fases 02 a 12. As etapas 3 a
8 estão fechadas (as ideias que sobraram delas também: rampa lisa, degrau alto, buraco, graveto
enterrado, cavar sob a cerca, tronco que rola e boia, graveto molhado, esquilo, dono dormindo,
cão vizinho e o som do latido — Fases 10, 11 e 12). Depois vieram o bioma de neve (tiles e
texturas, céu, entorno, neve caindo), as regiões no menu, o frio e a fogueira montada com
gravetos, o celeiro para o rebanho e o editor modular (trechos, copiar/colar entre fases, módulos,
balde) — ver *Versão de teste*. Do Pacote 1
(Etapa 10) já existem o botão de ação (F), gravetos lendário e comuns, placas de pressão e
portões por canal de cor, o graveto-ponte e o mirante. Também o menu de opções (tela, gráficos,
áudio, teclas), a tela para monitores largos e a exportação para Windows, Linux e macOS (ver
`docs/ANALISE_PACOTE_1.md`).

Abaixo, o que ficou para depois, na ordem sugerida. Cada item diz **onde encaixa** no código
atual, para a arquitetura não precisar mudar.

Ideia que vale para quase tudo daqui em diante: cada fase escolhe quais **habilidades** o
cachorro tem (pular, cavar, latir...). Isso deixa as fases antigas corretas quando uma habilidade
nova entra — a Fase 01, por exemplo, depende de o cachorro *não* pular o barranco de 2 m.
Já é assim: `Fase.habilidades` (flags no painel da fase no editor), somadas às habilidades
nativas da raça; o `jogo.gd` liga só essas.

## Versão de teste: Floresta e Neve

O plano para a primeira versão jogável por outras pessoas: **dois biomas**, cada um uma região.

- **Floresta**: as fases de buscar o graveto com as mecânicas de sempre (Fases 01 a 12, e a 05
  de pastoreio).
- **Neve**: buscar o graveto no frio (fogueiras montadas com gravetos, neve para derreter ou
  cavar, gelo) e **abrigar o rebanho**: fases do Border Collie em que ele explora um mapa grande,
  acha as ovelhas (elas balem) e as guia com segurança até o **celeiro** — protegidas do frio ou
  do tempo ruim.
- Os mapas das fases ficam com o autor (montados no editor, com módulos); o código cuida das
  peças e do editor. ✅ Feito para isso: bioma Neve, tiles de neve, Fogueira, frio, Celeiro,
  balido, regiões no menu, editor modular (trecho, módulos, balde, busca) e mapas de qualquer
  tamanho e formato (entorno que segue o formato do mapa, queda relativa).
- Falta: as fases da região Neve (mapas) e, se preciso, ajustes finos de frio/fogo com elas.

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
- ✅ **Regiões como dado**: recurso `Regiao` (`assets/regioes/*.tres`: id, nome, descrição,
  ordem, bioma sugerido); cada fase diz a sua (`Fase.regiao`) e o menu (Fases) agrupa por região,
  com a descrição. A ordem do jogo é a das regiões, depois o nome do arquivo. Hoje: Floresta e
  Neve.
- Falta: raças compatíveis por região e o menu Regiões → raça → pelagem → fases (o progresso
  guardaria (fase, raça)); textos ou cenas de abertura e de final. Hoje a pelagem se escolhe na
  tela Cachorro e a raça vem de `Fase.raca` — que continua útil como raça padrão para testar no
  editor. Toda fase precisa ter solução com cada raça compatível da região.

## Etapa 3 — Graveto de verdade ✅ (feito, com ideias para depois)

Colisão própria do graveto na boca, bloqueio de giro, correção de quina, virar o graveto ao
comprido (Q), peso (velocidade e pulo) e equilíbrio em passagens estreitas (tile *Tábua*),
com barra de equilíbrio no HUD. Fase 02 ("A Pinguela") usa tudo isso.

- ✅ **Mais passagens estreitas**: o *Tronco caído* com `pinguela` (atravessado sobre um vão) e o
  graveto que vira ponte (Etapa 10) são passagens estreitas feitas por objetos (grupo
  `passagens_estreitas`, método `passagem_em`).
- Ideias para depois (mudam o controle do graveto; melhor desenhar junto com fases para elas):
  - **Formatos T/Y**: gravetos com galhos exigindo ângulo. A base já existe (forma de colisão do
    graveto no corpo); faltaria uma forma composta por formato e mais ângulos de virar (hoje são
    dois: atravessado e ao comprido).
  - **Inclinar o graveto** (para cima/baixo) para passar por baixo/cima de obstáculos baixos.
  - **Beirada de penhasco** como passagem estreita (um tile `estreita` na borda).

## Etapa 4 — Movimento: pular, subir e descer níveis ✅ (feito)

- ✅ **Habilidades por fase**: `Fase.habilidades` (flags, no painel da fase no editor).
- ✅ **Pular** (Espaço): 0,65 m sem graveto — sobe meio bloco, não um bloco inteiro. Com graveto
  na boca o pulo é 12% mais baixo, e o peso baixa mais.
- ✅ **Nivelamentos**: *Escada baixa/alta* (colide como rampa, parece degraus) e *Canto de
  rampa* externo e interno, baixo e alto. A Fase 04 tem um monte fechado com cantos e uma escada.
- ✅ **Rampa lisa** (baixa e alta): com graveto pesado (1,5+) o cachorro escorrega e não sobe —
  caminho de mão única para quem carrega peso (e um graveto molhado pesa mais!).
- ✅ **Degrau alto** (0,72 m): só pulando, e com graveto na boca o pulo não chega. Fase 10.
- ✅ **Túneis**: montados no editor — tampas "só isométrico"/"só 3D" (caminhos que abrem ou fecham
  na volta) e túneis de uma célula, onde graveto comprido só passa ao comprido. Tocas de texugo
  e portinholas (Etapa 10) levam a ideia adiante.
- Correção feita junto: o graveto numa beirada na altura da boca não segura mais o cachorro
  pendurado no ar.

## Etapa 5 — Cavar ✅ (feito)

Tile **Terra fofa** (`cavavel`), habilidade *Cavar* e ação C. Não cava com o graveto na boca.

- ✅ Bloco de terra fofa na frente do focinho: some (túnel cavado — Fase 03).
- ✅ **Cavar para baixo**: terra fofa no chão vira **Buraco** (meio metro). O cachorro sai
  escalando a borda; um bloco empurrado para dentro cai e tapa o buraco.
- ✅ **Graveto enterrado** (`Graveto.enterrado`): só um montinho com a pontinha de fora; cavar de
  frente desenterra. Fase 10.
- ✅ **Cavar por baixo de cercas**: *Cerca* com `terra_fofa` — cavar abre um vão baixo naquele
  metro (0,66 m): salsicha e pug passam, border collie não; graveto comprido, só ao comprido.
  Fase 10 ("Debaixo da Cerca").

## Etapa 6 — Empurrar ✅ (feito)

Objeto **Bloco empurrável**: andar contra ele por um instante empurra uma célula (estilo
Sokoban), se o destino estiver livre e tiver chão. Empurrado para dentro da água, afunda até
ficar rente ao chão e vira passagem; num buraco, tapa o buraco. Se ficar encurralado, volta
sozinho para onde começou.

- ✅ **Puxar**: segurando F de frente para o bloco e andando para trás (sem graveto). Segurando
  F perto do bloco, o cachorro vira de frente e agarra; se não dá, avisa por quê. Fase 04.
- ✅ **Tronco que rola** (duas células): empurrado de lado rola uma célula (ao comprido não). Na
  água funda afunda e vira ponte larga; na água rasa boia (Etapa 7). Fase 11.
- ✅ **Empurrar com o graveto**: o graveto na boca empurra também; ao comprido, a ponta vai longe
  (alcance maior — empurrar algo do outro lado de um vão).
- ✅ **Blocos que tampam túneis**: montado no editor (bloco na boca do túnel).
- ✅ Placas de pressão (Etapa 10).

## Etapa 7 — Riachos e água ✅ (feito)

- ✅ **Água** funda (sem colisão, "Splash!"), **Água rasa** (atravessável, mais lenta) e
  **Correnteza** (água rasa que arrasta no sentido +X do tile; graveto pesado deixa o cachorro
  mais firme). O shader da água mostra o fluxo. Fase 04 ("A Correnteza").
- ✅ **Graveto molhado**: na boca, na água rasa, encharca e pesa +0,5 por 8 s (pinga) — mais lento,
  pulo mais baixo, mais firme na correnteza, escorrega na rampa lisa e pesa mais numa placa.
  Fase 11 usa isso numa placa.
- ✅ **Objetos que boiam e descem a correnteza**: o tronco desce o rio célula por célula, com o
  cachorro em cima, até encalhar; parando sobre água funda, encaixa e vira ponte. Fase 11
  ("O Tronco no Rio"). Folhas boiando ficam como enfeite para depois.
- ✅ **Travessias**: tronco, pedras de apoio (meio bloco + pulo, no editor), graveto como ponte
  (Etapa 10). Ainda por vir: comporta que baixa a água (Etapa 10) e o barquinho (Etapa 12).

## Etapa 8 — Latir ✅ (feito)

Habilidade *Latir* e ação B: onda, "Au!" e o **som do latido** (gerado por código, tom pela
raça — agudo no salsicha e no pug, grave no border collie); objetos até 5 m recebem
`ao_ouvir_latido(origem)` (`Fase.espalhar_latido`). Não dá para latir com o graveto na boca.

- ✅ **Passarinho**: guarda o graveto ou bloqueia a passagem; o latido espanta. Fase 03.
- ✅ **Esquilo** (com a toca): junta gravetos largados por perto na porta da toca e guarda; um
  latido assusta (larga o que levava e se esconde um tempo). Fase 12.
- ✅ **Acordar o dono**: `Dono.dormindo` — só recebe o graveto depois de um latido. Fase 12.
- ✅ **Outros cachorros**: o *Cão vizinho* late de volta quando ouve um latido e late de ciúme
  quando passa perto um cachorro com graveto na boca; o latido dele alcança o que está perto
  dele. É o jeito de latir com o graveto na boca. Fase 12 ("O Vizinho").
- Pássaros no contrapeso (voam e voltam, corrida contra o tempo): Etapa 10.

## Etapa 9 — Truques (rolar, abanar o rabo, ficar em duas patas) — para depois

- O modelo já é separado em pivôs (corpo, cabeça, orelhas, rabo, patas) e animado por código
  em `ModeloCachorro`; os truques entram como animações novas ali.
- Truques como mecânica: o dono (ou outro personagem) pede um truque para liberar algo;
  **duas patas** alcança/enxerga mais alto (e o graveto sobe junto — passa por cima de
  obstáculos baixos); **rolar** passa por baixo de algo baixo sem o graveto (larga e pega de
  novo); **abanar o rabo** para interagir com animais.
- Ações novas no InputMap (`truque_rolar`, `truque_rabo`, `truque_duas_patas`) ou um menu radial.

## Etapa 10 — Quebra-cabeças com gravetos: placas, pontes, tocas e mirantes (em parte ✅)

A ideia central: o graveto deixa de ser só o prêmio e vira também **ferramenta**. Tudo aqui
combina com o que já existe — a troca de perspectiva, a colisão e o peso do graveto, blocos,
água e latido.

- **Gravetos comuns e o graveto lendário. ✅** Uma fase pode ter vários gravetos. Só o
  **lendário** — dourado, com um brilho — conclui a fase ao ser entregue ao dono. Os outros,
  marrons e comuns, também mudam a perspectiva quando o cachorro os pega, mas servem de
  ferramenta no caminho: ponte, peso numa placa, algo para trocar. Largar um para pegar outro
  vira decisão de quebra-cabeça.
  *Onde encaixa:* `Graveto.lendario` (material dourado e partículas). O `jogo.gd` hoje liga só
  `fase.primeiro(Graveto)`; passa a ligar todos, e o dono só aceita o lendário. A validação do
  editor exige exatamente um lendário.
- **Placa de pressão e portão. ✅** A placa abre (ou fecha) portões enquanto tem peso em cima: um
  bloco, uma ovelha, o próprio cachorro, um graveto largado, um bando de pássaros. O melhor
  dilema: quando só o graveto pesa o bastante, ele é **a chave e o prêmio** ao mesmo tempo — é
  preciso pôr outra coisa na placa antes de levá-lo embora. Placas "só isométrico" ou "só 3D"
  amarram o mecanismo à perspectiva.
  *Onde encaixa:* objetos `Placa` (Area3D que soma o peso do que está em cima) e `Portao`
  (colisão ligada/desligada, como `ObjetoFase.definir_ativo`), ligados por um **canal** (nome ou
  número no painel do editor). O mesmo canal serve para comporta, ponte levadiça, lanterna...
  Feito também: regra OU / E no portão e a ferramenta **Ligar (L)** do editor. Próximos passos:
  mostrar no próprio portão (para o jogador) quantas placas a regra E pede — lampadinhas que
  acendem uma por placa; **atraso ao fechar** (fica aberto N segundos: corrida contra o tempo);
  **alavanca** (F liga e desliga, sem precisar de peso); e outros que reagem ao canal (ponte
  levadiça, comporta, plataforma), todos via `ObjetoFase.papel_no_canal()`.
- **O graveto vira ponte. ✅** Largado ao comprido sobre um vão de uma célula (buraco, riacho
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
- **Mirante: o graveto fincado. ✅** Num ponto alto, um graveto preso (fincado no chão ou num
  tronco) que não sai do lugar. Mordendo-o, a perspectiva muda — só para olhar: o jogador estuda
  a fase pelo outro ângulo e planeja os próximos passos; soltando, volta. Evolução: no mirante,
  girar a isométrica 90° (as faces escondidas mudam e outros caminhos aparecem).
  *Onde encaixa:* objeto `GravetoFincado`; ao morder, a câmera vai para o 3D (ou para uma vista
  panorâmica) sem ligar nem desligar passagens, e o cachorro fica parado.
- **Botão de ação (F), conforme o que está na frente. ✅** Um botão só, que muda de acordo com o
  que está por perto e para onde o cachorro está olhando: olhando para uma pedra ou um bloco,
  F + trás puxa (como hoje); para um tronco, F morde e arrasta; para uma corda, F puxa e aciona;
  para o graveto fincado, F morde (mirante); para um invasor, F morde a bunda dele. E assim por
  diante. Sem graveto na boca, claro.
  *Onde encaixa:* método base em `ObjetoFase` (ex.: `acao_da_boca(cachorro)`, que devolve o nome
  da ação ou vazio); o cachorro procura o objeto à frente do focinho (como o `_bloco_na_frente`
  do puxar) e o HUD mostra a ação disponível ("F: morder", "F: puxar corda").

## Etapa 11 — Neve: frio, fogo e vento (em boa parte ✅)

Fases de inverno em que andar já é um esforço e o caminho precisa ser aberto com fogo.

- ✅ **Bioma Neve**: as mesmas peças com texturas de inverno (biblioteca de tiles por bioma),
  céu frio, neve caindo, entorno branco, árvores e pedras com neve (`Fase.bioma`, `Biomas`).
- ✅ **Neve fofa**: mais lenta, e o cachorro demora a arrancar e a parar (tile com `lentidao` e
  `aderencia`). As ovelhas também ficam mais lentas.
- ✅ **Montes de neve**: bloco que se cava (C) ou derrete no fogo.
- ✅ **Gelo** (versão simples): aderência baixa — o cachorro desliza e demora a parar.
  Ideia para depois: o quebra-cabeça clássico de deslizar até bater em algo (com o graveto
  atravessado ele bate antes; virar com Q muda onde ele para) e blocos que deslizam no gelo.
- ✅ **Frio**: `Fase.frio` — longe do fogo o calor cai (barra no HUD, mais rápido na água); com
  pouco calor o cachorro treme e fica lento; gelado, volta para o último lugar quente.
- ✅ **Fogueira montada com gravetos**: pede N gravetos comuns (F perto dela, ou largar junto);
  acesa, esquenta, derrete a neve em volta (neve fofa vira terra, montes somem, com vapor) e
  revela o que estava enterrado na neve; cada graveto a mais aumenta o raio. Aciona um canal
  (opcional) — dá para abrir um portão quando ela acende.
- ✅ **Cavar na neve**: o graveto enterrado vira um montinho de neve no bioma de neve (cava-se
  com C, ou o fogo revela).
- Ideias para depois: outros jeitos de acender (a corda de um lampião, empurrar uma brasa,
  **levar um graveto aceso** de uma fogueira a outra com o vento tentando apagar); o fogo derreter
  gelo em água (o caminho que piora); "montinho de neve" que esconde outro objeto qualquer (um
  osso, um pano, uma chave), achado pelo faro.
- ✅ **Celeiro** (para o pastoreio na neve): abrigo das ovelhas, quente por dentro; telhado e
  paredes altas somem com o cachorro perto. As ovelhas **balem** (com som) quando estão longe —
  para achá-las em mapas grandes.
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
- ✅ Balde de tinta (Alt + clique).
- ✅ **Trecho (T)**: marcar um retângulo (todas as camadas + objetos), copiar, recortar, apagar e
  colar (Ctrl+V) girando e subindo/descendo, também em outra fase.
- ✅ **Módulos**: salvar um trecho como módulo (`scenes/modulos/`), que aparece na paleta; as
  classes `Trecho` e `Modulos` servem também para um gerador de mapas montar fases com peças.
- ✅ Busca na paleta; ícones dos tiles no bioma da fase; painel da fase com região, bioma e frio.
- ✅ Mapas de qualquer tamanho e formato (entorno que segue o formato, queda relativa).
- Ideias: editar um módulo direto (abrir como fase), prévia/miniatura dos módulos na paleta,
  minimapa para mapas grandes, pontos de encaixe nos módulos (para um gerador saber onde ligar
  uma peça na outra).
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
  levar as ovelhas ao abrigo (cercado ou celeiro). Cada objetivo é uma classe em
  `scripts/objetivos/` que diz o que a fase precisa (`faltando`, `avisos`) e prepara e confere a fase (`preparar`, `processar`).
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
- ✅ Colisão por raça: a cápsula vem das medidas da raça (`raio_colisao`, `altura_colisao`) — o
  border collie não passa no vão cavado embaixo da cerca.
- ✅ Som por raça: o tom do latido sai da altura da raça.
- Cuidado com propriedade intelectual: nada de nomes, personagens ou visual copiados de
  filmes e quadrinhos — homenagens genéricas (um gato laranja guloso, uma máscara mágica) são
  o caminho seguro.

## Visual e câmera

- Árvores entre a câmera 3D e o cachorro ficarem transparentes (dither) em vez de taparem.
- ✅ Modelo do cachorro em voxel e animações de andar (patas, rabo, orelhas). Faltam animações
  de cavar, latir e pular mais caprichadas (hoje o corpo todo inclina).
- ✅ Céu e luz por bioma (`Biomas.aplicar_ambiente`). Faltam biomas de noite e mar.
- Se um dia houver objetos transparentes que precisem de contorno, trocar o quad de contorno por
  um `CompositorEffect`.

## Áudio

- ✅ Barramentos e volumes nas opções (geral, música, efeitos, ambiente) e os primeiros sons: o
  latido e o balido, gerados por código (`scripts/som.gd`), no barramento Efeitos.
- Faltam: passos (grama, terra, água), água corrente, pássaros, portão, cavar, música e ambiente
  por tema. Mantendo "nada de assets externos", tudo pode sair do mesmo gerador (`Som`), ou
  entrar como arquivos quando houver quem componha.

## Técnico

- ✅ Exportação para Windows, Linux e macOS (inclui os modelos voxel `*.txt`), com teste de
  fumaça na CI.
- ✅ Testes automatizados: `ferramentas/testar_fases.sh` joga cada fase com entradas simuladas
  (rotas em `ferramentas/testes/rotas/`), mais rotas das mecânicas (mecanismos, save, hud,
  bichos, cavar, movimento, tronco, editor, neve, celeiro). Rodam na CI em todo push.
- ✅ Menu inicial, seleção de fases, pausa, progresso salvo (com versão e migração), opções (tela,
  gráficos, áudio, controles) e remapear teclas.
