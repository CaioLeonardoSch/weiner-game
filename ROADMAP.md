# Próximas etapas

O que já existe: visual pixelado, trilha mais linear na primeira fase com floresta em volta, pipeline
de assets (tiles gerados por código, modelos voxel em texto e procedurais, objetos que aparecem
sozinhos no editor), o editor de fases dentro do jogo (F1), o graveto com colisão, peso e
equilíbrio (etapa 3), habilidades por fase com o pulo, escadas e cantos de rampa (etapa 4),
cavar (5), empurrar e puxar (6), água rasa e correnteza (7), latir e passarinhos (8), as
melhorias principais do editor, o menu principal com pausa, o cachorro em voxel com raças e
pelagens, o objetivo da fase como dado (graveto ou pastoreio) e a esteira de fases de teste
(F01 a F33 na Floresta, N01 a N10 na Neve). As etapas 3 a
8 estão fechadas (as ideias que sobraram delas também: rampa lisa, degrau alto, buraco, graveto
enterrado, cavar sob a cerca, tronco que rola e boia, esquilo, dono dormindo,
cão vizinho e o som do latido). Depois vieram o bioma de neve (tiles e
texturas, céu, entorno, neve caindo), as regiões no menu, o frio e a fogueira montada com
gravetos, o celeiro para o rebanho e o editor modular (trechos, copiar/colar entre fases, módulos,
balde) — ver *Versão de teste*. Do Pacote 1
(Etapa 10) já existem o botão de ação (F), gravetos lendário e comuns, placas de pressão e
portões por canal de cor (o mirante saiu com a isométrica; o graveto-ponte saiu: quem vira pinguela agora é o tronco). Também o menu de opções (tela, gráficos,
áudio, teclas), a tela para monitores largos e a exportação para Windows, Linux e macOS (ver
`docs/ANALISE_PACOTE_1.md`).

Abaixo, o que ficou para depois, na ordem sugerida. Cada item diz **onde encaixa** no código
atual, para a arquitetura não precisar mudar.

Ideia que vale para quase tudo daqui em diante: cada fase escolhe quais **habilidades** o
cachorro tem (pular, cavar, latir...). Isso deixa as fases antigas corretas quando uma habilidade
nova entra — uma fase pode depender, por exemplo, de o cachorro *não* pular um barranco.
Já é assim: `Fase.habilidades` (flags no painel da fase no editor); o `jogo.gd` liga só essas.
As raças não têm habilidades nem peso próprios: todas fazem o mesmo, e só o **tamanho** muda
(colisão, o vão embaixo da cerca, o tempo de passar na portinhola).

## Nova direção (2026-10) — o que programar

O design mudou depois da análise crítica: ver [docs/DESIGN.md](docs/DESIGN.md). Os itens 1 e 2
foram feitos, o 4 (o parque) e o 5 (animais) começaram. Ordem sugerida:

1. ✅ **Tirar a isométrica**: o jogo fica só em terceira pessoa. Saem a câmera isométrica e a
   transição (`CameraController`), a *Visibilidade* só isométrico / só 3D (`ObjetoFase`), as
   tampas de folhagem, o mirante, o aviso "Nova perspectiva!" e a F02 como está. Câmera que não
   briga com o graveto em corredores e recua em pontos-chave.
   - **Feito**: tudo isso saiu; a isométrica ficou só como visão do editor (V: livre /
     isométrica). Nas fases da esteira o passarinho da F28 passou a voltar depois de 4 s (sem
     a isométrica, ele não fechava mais o caminho na volta). Câmera que recua em pontos-chave:
     por enquanto só as cenas com foco (`CameraController.focar`).
2. ✅ **Textos**: tirar os textos de `ZonaDica` que ensinam a solução e os nomes de fase que
   entregam a mecânica; prompts só com o ícone da tecla; a dica vira o assobio do dono, vindo
   da direção do caminho.
   - **Feito**: sem textos de dica nas fases (as dicas da esteira viraram comentários no
     gerador; `ZonaDica` só nas cenas de teste), nomes de fase da esteira são só o código
     ("F13"), sem título na tela ao abrir (o parque ainda mostra "Dia N"), e sem os avisos que
     explicavam uma falha (puxar sem espaço, pulo recusado, placa de pedra, virar o graveto).
   - **Falta**: o assobio do dono e um retorno sem texto para as falhas (som ou animação).
3. **Ações**: ações de contexto com animação (pular as pedras, pular na moita, rastejar) e a
   ação de força (apertar repetidamente para puxar ou cavar; parou, recomeça). Falhas naturais
   (cair na água, sair se sacudindo).
4. **O parque, demo**: a área central (dono no banco, tirar e pôr a coleira, buscar a bolinha,
   rolar na grama, alguns cães e donos passeando), o ciclo do dia (assobio, *fade*, saída do
   parque) e os **dias 1 a 3**, com regiões liberadas pelo número de gravetos e bloqueios
   naturais.
   - **Começou (estrutura, visual provisório)**: a área central gerada
     (`ferramentas/gerar_parque.gd`), o dono que chega com a guia, solta e senta no banco, a
     bolinha, rolar (T), deitar parado, dois passeantes, as 10 entradas (abertas pelo número de
     fases dos dias concluídas, fechadas por troncos), o assobio ao pegar o graveto, a volta ao
     parque e a saída, e o dia seguinte. Ver *O parque* no README.
   - **Dia 1 feito (visual provisório)**: chegada saindo de uma moita, a cena do esquilo sem
     controle (a câmera foca o esquilo e depois o galho), a volta cortada na moita até perto do
     dono, a barreira perto das pedras e a queda na água (volta à margem e se sacode).
     `ferramentas/gerar_dia_01.gd`; tronco semicaído, pedras do córrego, moita, o esquilo que
     derruba o galho no raio de sol, o cajado lendário (objetivo *Dia do parque*). Com isso começaram as ações de contexto do
     item 3 (rastejar, pular as pedras, pular na moita).
   - **Falta**: as fases dos dias 2 a 10 (2 e 3 usam F03 e F04 da esteira; 4 a 10 sem fase), a
     moita da saída da área central (as entradas ainda são as aberturas no mato), a ação de força, o cachorro reparar no que mudou, os
     bloqueios naturais de verdade (o urso, a correnteza), o marco de cada região e toda a
     arte e animação (depois da direção visual, item 6).
5. **Animais novos**: tartaruga, peixe-cuspidor, castor, texugo e urso; personagens que voltam
   e aparecem na área central depois de ajudados. Diálogo em balões (cães) e murmúrio (humanos).
   - **Começou**: os cinco com modelo voxel provisório e movimento básico (`scripts/objetos/bicho.gd`:
     passeiam dentro de um raio; a tartaruga e o peixe na água, o castor na terra e na água, o
     texugo foge do cachorro, o peixe cospe um jato, o urso tem colisão). Rota `animais`.
   - **Falta**: encaixar cada um num dia, as interações da história e a volta à área central.
6. **Direção de arte, menu e nome**: depois de escolhida a direção visual (conceitos com IA de
   imagem, ver DESIGN.md). O menu novo é original (o atual lembra o Minecraft).
7. **O resto do capítulo**: dias 4 a 10, missões secundárias, a casa com a parede de gravetos;
   depois, a Fazenda na neve.

Saem das fases novas (o código pode ficar até decidirmos apagá-lo): placas de madeira e de
pedra, regra E, portão com atraso, alavanca, comporta, mirante e o cão vizinho. O medidor de
frio também sai; o frio vira motivo da história.

## Pontes, gatilho e tronco ✅ (feito)

Pedido depois de testar: a ponte "passava" do bloco e sumia na troca de perspectiva sem explicação;
a correnteza quase não fazia efeito; o equilíbrio mal aparecia em pontes curtas; e o graveto fino
como ponte não fazia sentido.

1. ✅ **Ponte dentro do bloco**: tábuas soltas (com frestas) e vigas, tudo dentro do `tamanho`,
   rente ao chão das margens.
2. ✅ **Ponte fraca**: tipo *Cede com o tempo* (range, treme e quebra com alguém parado em cima) e
   *Quebra num gatilho* (cai quando o canal liga). As tábuas caem e a água leva, com respingos,
   rangido e estalo gerados por código. Novo objeto **Gatilho** (área que liga o canal quando o
   cachorro entra, entra com graveto, ou quando um graveto de dentro dela é pego).
3. ✅ **Sem peso na água**: o tronco só pesa em placa em terra; o graveto-ponte saiu.
4. ✅ **Equilíbrio no precipício**: dois platôs de 2 m e um tronco redondo entre eles, que balança
   mesmo sem graveto (hoje na F08).
5. ✅ **Tronco novo**: comprimento de 2 a 5; rola de lado, desliza ao comprido; mordendo a ponta,
   puxa (para trás) e **gira 90°** (de lado); vira pinguela entre margens; boia e desce a
   correnteza (mais forte agora) até parar numa pedra ou encaixar onde o rio estreita; encalhado,
   volta para o lugar.
6. ✅ **Fases refeitas**: 02 (precipício), 03 (a ponte cai ao pegar o graveto; volta pela pedra),
   04 (pedra + tronco na correnteza), 08 (a ponte velha cai atrás; volta girando o tronco), 09
   (placa de pedra + ponte que cai + tronco), 11 (girar o tronco e deixar a correnteza levar).
   Nenhuma fase depende mais de "a ponte some na troca de perspectiva".

Ideias que ficaram: usar a ponte que **cede com o tempo** numa fase (sem prender o jogador do lado
errado se ela quebrar); troncos empurrados na água rasa parada; um tronco que role morro abaixo.

## Editor de fases 2 ✅ (feito)

Pedido depois de testar o editor: construir mais rápido e ver melhor o que está sendo feito. Antes,
uma olhada em como outros jogos com construção em grade resolvem isso:

- **Super Mario Maker 1 e 2**: pinta-se arrastando; uma barra no topo guarda os itens usados por
  último; *Multi-Grab* seleciona um retângulo para mover ou copiar; a mão (cursor) agarra e
  arrasta sem colocar nada; testar começa de onde o Mario está ("jogar daqui"); desfazer é um
  botão só.
- **Minecraft (criativo)**: barra de atalhos com os blocos à mão e "escolher bloco" apontando
  (o nosso conta-gotas, G). As placas de pressão: a de madeira é acionada por tudo (até itens
  largados), a de pedra só por quem anda (jogador e bichos) — ideia que adaptamos abaixo.
- **Axiom** (editor de mundo do Minecraft): cada ferramenta tem forma e raio, com atalho para
  mudar o raio na hora (Ctrl + botão do meio); a prévia aparece antes de confirmar.
- **Dragon Quest Builders**: segurar o botão coloca em sequência, com uma pausa depois do
  primeiro bloco para não pôr um a mais sem querer — prévia + confirmação resolve melhor.
- **Captain Toad**: fases como dioramas pequenos, e a câmera gira em volta o tempo todo — no
  editor, girar a vista precisa ser fácil e estar sempre à mão.

O plano:

1. ✅ **Tamanho do pincel**: Ctrl + roda do mouse (ou [ e ]) aumenta e diminui a área — 1×1, 2×2, 3×3...
   — para colocar, apagar e trocar vários blocos de uma vez (um chão de grama inteiro).
2. ✅ **Linha com prévia**: Shift + clique marca o começo; a prévia mostra os blocos (ou objetos) em
   linha reta até o mouse; outro clique confirma. Substitui o "Shift + arrastar espalha" dos
   objetos (o pincel de floresta passa para Ctrl + arrastar).
3. ✅ **Barra de ferramentas do terreno**: Pincel, Trocar, Linha, Retângulo e Balde (teclas 1 a 5),
   com os atalhos de sempre (Shift linha, Ctrl retângulo, Alt balde).
4. ✅ **Cursor**: uma ferramenta com ícone de seta que não coloca nada — clique seleciona, arrastar um
   objeto move, arrastar no vazio gira a vista (com Shift, arrasta). Em qualquer ferramenta,
   **Espaço + botão esquerdo** gira a vista.
5. ✅ **Prévia translúcida** do que vai ser colocado (pincel, linha, retângulo), na cor do tile.
6. ✅ **Menos texto na tela**: nada de rótulos em cima dos objetos; o nome do que está sob o mouse vai
   para a barra de status.
7. ✅ **Paredes invisíveis e zonas** com um efeito leve (translúcido) só no editor.
8. ✅ **Ícones para tudo** na paleta: ferramentas, início do cachorro, zonas, paredes, módulos.
9. ✅ **Recentes** no topo da paleta (os últimos itens usados) e categorias que se recolhem.
10. ✅ **Testar daqui (F2)**: joga a fase com o cachorro começando onde está o cursor.

Junto, duas mudanças de mecânica pedidas:

- ✅ **Placas de madeira e de pedra** (no lugar do peso mínimo com pontinhos): a de madeira é acionada
  por qualquer coisa em cima (o cachorro, um graveto, uma ovelha, um bloco...); a de pedra só por
  algo pesado — o bloco de pedra e o tronco. A cor da moldura continua dizendo o que ela aciona.
- ✅ **Sem graveto molhado**: a água não muda mais o peso do graveto. (Na esteira: F15 e F16.)

## Versão de teste: Floresta e Neve

> Substituída pela *Nova direção (2026-10)* acima: a Floresta vira o capítulo do parque (10 dias
> com área central) e a Neve, a fazenda do border collie. A esteira de fases continua servindo
> de teste das mecânicas.

O plano para a primeira versão jogável por outras pessoas: **dois biomas**, cada um uma região.

- **Floresta**: as fases de buscar o graveto com as mecânicas de sempre.
- ✅ **Esteira de fases de teste**: as fases antigas saíram; no lugar, uma fase simples por
  mecânica — F01 a F33 na Floresta e N01 a N10 na Neve (neve fofa, gelo, monte de neve, frio e
  fogueira, vento, pastoreio, celeiro). Cada uma tem uma rota em `ferramentas/testes/rotas/` que
  a joga sozinha (`ferramentas/testar_fases.sh`) e as cenas saem de `ferramentas/gerar_esteira.gd`.
  Os bugs achados ao montar as rotas viraram issues, para corrigir em sessões separadas.
- **Neve**: buscar o graveto no frio (fogueiras montadas com gravetos, neve para derreter ou
  cavar, gelo) e **abrigar o rebanho**: fases do Border Collie em que ele explora um mapa grande,
  acha as ovelhas (elas balem) e as guia com segurança até o **celeiro** — protegidas do frio ou
  do tempo ruim.
- Os mapas das fases ficam com o autor (montados no editor, com módulos); o código cuida das
  peças e do editor. ✅ Feito para isso: bioma Neve, tiles de neve, Fogueira, frio, Celeiro,
  balido, regiões no menu, editor modular (trecho, módulos, balde, busca) e mapas de qualquer
  tamanho e formato (entorno que segue o formato do mapa, queda relativa).
- Falta: as fases de verdade (mapas maiores, montados no editor) e os ajustes finos que as
  issues da esteira apontarem.
- ✅ **Progressão de habilidades**: a habilidade liberada numa fase vale nas seguintes (pular
  desde a F03, cavar desde a F10, latir desde a F25). Ajustes para isso: o pulo "de salsicha"
  (pouco alcance no ar e recusa pular em água funda), o passarinho que bloqueia com uma caixa
  alta (não dá para pular por cima), o platô da F04 alto demais e a parede de **bloco de gelo**
  da N06 (não se cava; o fogo derrete).
- ✅ **Correr** (Ctrl), **tela cheia** no F11 e, no editor, **Tab** esconde os painéis.
- ✅ **HUD "Coleira"** (ver README): objetivo, controles com teclas, avisos, balão do cachorro,
  medidores e o cartão de fim de fase.

## Visão

O *The Weiner and the Legendary Sticks* começa com um salsicha atrás de gravetos, mas quer ir além: mostrar as muitas
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
- Outras regiões candidatas (deste brainstorm): fazenda (pastoreio — a N09 já testa),
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
- ✅ **Raça por região**: `Regiao.racas` (compatíveis; Floresta: salsicha e pug; Neve: salsicha
  e border collie). Menu **Regiões → região (história, raça, fases)**; a tela *antes de jogar*
  (Continuar, região nova, *Trocar de raça* na pausa) mostra a história e a escolha da raça. A
  escolha fica por região no progresso (`[racas]`), e o ✓ guarda com que raça (`[racas_concluidas]`;
  ✓ verde = com a raça escolhida, apagado = com outra). `Fase.raca_fixa` (N09) ignora a
  escolha; `Fase.raca` é a do teste no editor. A **pelagem** é só aparência, no menu principal
  (Pelagens).
- Todas as raças andam, pulam, pesam e fazem o mesmo (sem velocidade, peso ou habilidades por
  raça); o que muda é só o tamanho do corpo (colisão). As rotas da Floresta passam com o pug.
- Falta: **conferir jogando cada fase da Floresta com o pug**; textos ou cenas de abertura e de
  final de região (a descrição da região e das raças saiu do menu). Toda fase precisa ter solução
  com cada raça compatível da região; o tamanho do cão só muda o caminho onde o corpo não cabe
  (o vão embaixo da cerca) ou o tempo (a portinhola).

## Etapa 3 — Graveto de verdade ✅ (feito, com ideias para depois)

Colisão própria do graveto na boca, bloqueio de giro, correção de quina, virar o graveto ao
comprido (Q), peso (velocidade e pulo) e equilíbrio em passagens estreitas (tile *Tábua*),
com barra de equilíbrio no HUD. A F08 usa tudo isso.

- ✅ **Mais passagens estreitas**: o *Tronco caído* com `pinguela` (atravessado sobre um vão) e o
  *Tronco* que boia de pinguela são passagens estreitas feitas por objetos (grupo
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
  rampa* externo e interno, baixo e alto. A F04 tem as rampas e os cantos.
- ✅ **Rampa lisa** (baixa e alta): com graveto pesado (1,5+) o cachorro escorrega e não sobe —
  caminho de mão única para quem carrega peso.
- ✅ **Degrau alto** (0,72 m): só pulando, e com graveto na boca o pulo não chega. F05.
- ✅ **Túneis**: montados no editor — tampas "só isométrico"/"só 3D" (caminhos que abrem ou fecham
  na volta) e túneis de uma célula, onde graveto comprido só passa ao comprido. Tocas de texugo
  e portinholas (Etapa 10, ✅) levam a ideia adiante.
- Correção feita junto: o graveto numa beirada na altura da boca não segura mais o cachorro
  pendurado no ar.

## Etapa 5 — Cavar ✅ (feito)

Tile **Terra fofa** (`cavavel`), habilidade *Cavar* e ação C. Não cava com o graveto na boca.

- ✅ Bloco de terra fofa na frente do focinho: some (túnel cavado — F10).
- ✅ **Cavar para baixo**: terra fofa no chão vira **Buraco** (meio metro). O cachorro sai
  escalando a borda; um bloco empurrado para dentro cai e tapa o buraco.
- ✅ **Graveto enterrado** (`Graveto.enterrado`): só um montinho com a pontinha de fora; cavar de
  frente desenterra. F12.
- ✅ **Cavar por baixo de cercas**: *Cerca* com `terra_fofa` — cavar abre um vão baixo naquele
  metro (0,66 m): salsicha e pug passam, border collie não; graveto comprido, só ao comprido.
  F11.

## Etapa 6 — Empurrar ✅ (feito)

Objeto **Bloco empurrável**: andar contra ele por um instante empurra uma célula (estilo
Sokoban), se o destino estiver livre e tiver chão. Empurrado para dentro da água, afunda até
ficar rente ao chão e vira passagem; num buraco, tapa o buraco. Se ficar encurralado, volta
sozinho para onde começou.

- ✅ **Puxar**: segurando F de frente para o bloco e andando para trás (sem graveto). Segurando
  F perto do bloco, o cachorro vira de frente e agarra; se não dá, avisa por quê. F13 e F14.
- ✅ **Tronco que rola** (duas células): empurrado de lado rola uma célula (ao comprido não). Na
  água funda afunda e vira ponte larga; na água rasa boia (Etapa 7). F30 a F32.
- ✅ **Empurrar com o graveto**: o graveto na boca empurra também; ao comprido, a ponta vai longe
  (alcance maior — empurrar algo do outro lado de um vão).
- ✅ **Blocos que tampam túneis**: montado no editor (bloco na boca do túnel).
- ✅ Placas de pressão (Etapa 10).

## Etapa 7 — Riachos e água ✅ (feito)

- ✅ **Água** funda (sem colisão, "Splash!"), **Água rasa** (atravessável, mais lenta) e
  **Correnteza** (água rasa que arrasta no sentido +X do tile; graveto pesado deixa o cachorro
  mais firme). O shader da água mostra o fluxo. F09.
- ~~Graveto molhado~~: existiu e foi retirado (a água não muda o peso do graveto).
- ✅ **Objetos que boiam e descem a correnteza**: o tronco desce o rio célula por célula, com o
  cachorro em cima, até encalhar; parando sobre água funda, encaixa e vira ponte. F32. Folhas boiando ficam como enfeite para depois.
- ✅ **Travessias**: tronco, pedras de apoio (meio bloco + pulo, no editor), graveto como ponte
  (Etapa 10), comporta que baixa a água (Etapa 10 ✅). Ainda por vir: o barquinho (Etapa 12).

## Etapa 8 — Latir ✅ (feito)

Habilidade *Latir* e ação B: onda, "Au!" e o **som do latido** (gerado por código, tom pela
raça — agudo no salsicha e no pug, grave no border collie); objetos até 5 m recebem
`ao_ouvir_latido(origem)` (`Fase.espalhar_latido`). Não dá para latir com o graveto na boca.

- ✅ **Passarinho**: guarda o graveto ou bloqueia a passagem; o latido espanta. F25 e F26.
- ✅ **Esquilo** (com a toca): junta gravetos largados por perto na porta da toca e guarda; um
  latido assusta (larga o que levava e se esconde um tempo). F27.
- ✅ **Acordar o dono**: `Dono.dormindo` — só recebe o graveto depois de um latido. F29.
- ✅ **Outros cachorros**: o *Cão vizinho* late de volta quando ouve um latido e late de ciúme
  quando passa perto um cachorro com graveto na boca; o latido dele alcança o que está perto
  dele. É o jeito de latir com o graveto na boca. F28.
- ✅ Pássaros no contrapeso (voam e voltam, corrida contra o tempo): Etapa 10.

## Etapa 9 — Truques (rolar, abanar o rabo, ficar em duas patas) — para depois

- O modelo já é separado em pivôs (corpo, cabeça, orelhas, rabo, patas) e animado por código
  em `ModeloCachorro`; os truques entram como animações novas ali.
- Truques como mecânica: o dono (ou outro personagem) pede um truque para liberar algo;
  **duas patas** alcança/enxerga mais alto (e o graveto sobe junto — passa por cima de
  obstáculos baixos); **rolar** passa por baixo de algo baixo sem o graveto (larga e pega de
  novo); **abanar o rabo** para interagir com animais.
- Ações novas no InputMap (`truque_rolar`, `truque_rabo`, `truque_duas_patas`) ou um menu radial.

## Etapa 10 — Quebra-cabeças com gravetos: placas, pontes, tocas e mirantes (quase toda ✅)

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
  Feito também: regra OU / E no portão e a ferramenta **Ligar (L)** do editor.
  - ✅ **Lampadinhas** em cima do portão da regra E: uma por placa da cor, acesas as acionadas.
  - ✅ **Atraso ao fechar** (`Portao.atraso`): fica aberto N segundos depois que o canal desliga
    — corrida contra o tempo.
  - ✅ **Alavanca**: F morde e ela vira, ligando ou desligando o canal; fica como está (sem peso).
  - Próximos: outros que reagem ao canal (ponte levadiça, plataforma), via
    `ObjetoFase.papel_no_canal()`.
- ~~**O graveto vira ponte.**~~ Feito e depois **retirado** (ver *Pontes, gatilho e tronco*): o
  papel de pinguela ficou com o tronco que se morde, gira e boia.
- **Troncos: gravetos gigantes.** Praticamente troncos, pesados demais para carregar: o cachorro
  morde perto da ponta e arrasta o resto pelo chão. Anda devagar, não pula, faz curvas abertas
  (o tronco vem atrás, como um reboque) e enrosca em quinas. Largados sobre água ou vãos de 2 a
  3 células, viram pontes largas.
  *Onde encaixa:* modo "arrastar" no `dachshund.gd`: uma ponta presa na boca e a outra seguindo
  a trajetória, com colisão ao longo do tronco; ao soltar, encaixa na grade. Hoje o tronco se
  morde pela ponta, gira e é puxado de célula em célula; o **reboque** de verdade (a outra ponta
  seguindo a trajetória em curvas abertas e enroscando nas quinas) fica para depois.
- **Toca de texugo. ✅** "Dachshund" quer dizer "cão de texugo", mas a toca vale para **todos os
  cães**. Objeto `Toca` (monte de terra com um buraco, +Z local): o cachorro entra andando para
  dentro (ou com F), a tela escurece e ele sai pela outra toca da **mesma cor**. Com o graveto na
  boca: `so_ao_comprido` e `comprimento_maximo` dizem se ele cabe. Uma toca "só 3D" (um atalho que
  só existe na volta) sai do mesmo objeto com a visibilidade por perspectiva.
- **Portinhola de cachorro. ✅** Objeto `Portinhola`: parede de tábuas com a portinha no meio; o
  cachorro passa andando contra ela (ou com F) e a aba balança. **Todas as raças passam**; o
  tamanho do cão só muda o **tempo** de se espremer. O graveto só passa ao comprido, e
  `comprimento_maximo` barra os compridos demais; `mao_unica` só abre num sentido (o da seta).
  Para depois: uma animação cômica dos cães grandes **entalando** na portinhola (o bumbum preso,
  as patinhas de trás pedalando) antes de passar.
- **Pássaros no contrapeso (corrida contra o tempo). ✅** `Passaro.volta_depois`: espantado pelo
  latido, o passarinho volta e pousa no mesmo lugar depois de N segundos. Pousados numa placa,
  são um contrapeso que vai e volta — é preciso ser rápido para passar.
- **Comporta: o nível da água. ✅** Objeto `Comporta` ligado a um canal (placa, alavanca ou os
  pássaros): com o canal ligado, a água funda do trecho à frente (`largura` × `comprimento`)
  vira rasa; com `encher`, a rasa vira funda (fecha um caminho). `de_vez` deixa a mudança para
  sempre; senão ela volta quando o canal desliga — nunca com o cachorro dentro. Junta placa,
  pássaros, correnteza e o barco (Etapa 12).
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

## Etapa 11 — Neve: frio, fogo e vento ✅ (feito)

Fases de inverno em que andar já é um esforço e o caminho precisa ser aberto com fogo.

- ✅ **Bioma Neve**: as mesmas peças com texturas de inverno (biblioteca de tiles por bioma),
  céu frio, neve caindo, entorno branco, árvores e pedras com neve (`Fase.bioma`, `Biomas`).
- ✅ **Neve fofa**: mais lenta, e o cachorro demora a arrancar e a parar (tile com `lentidao` e
  `aderencia`). As ovelhas também ficam mais lentas.
- ✅ **Montes de neve**: bloco que se cava (C) ou derrete no fogo.
- ✅ **Gelo** (versão simples): aderência baixa — o cachorro desliza e demora a parar.
- ✅ **Gelo liso** (tile `GELO_LISO`, com reflexos): o quebra-cabeça clássico — pisando nele, o
  cachorro desliza em linha reta (na direção da grade mais perto de onde andava) sem poder virar
  nem frear, até bater em algo ou sair do gelo. Com o graveto atravessado ele bate antes; virar
  com Q muda onde ele para. Blocos empurrados também deslizam até bater. Parado no gelo, uma
  rajada de vento põe o cachorro para deslizar.
- ✅ **Frio**: `Fase.frio` — longe do fogo o calor cai (barra no HUD, mais rápido na água); com
  pouco calor o cachorro treme e fica lento; gelado, volta para o último lugar quente.
- ✅ **Fogueira montada com gravetos**: pede N gravetos comuns (F perto dela, ou largar junto);
  acesa, esquenta, derrete a neve em volta (neve fofa vira terra, montes somem, com vapor) e
  revela o que estava enterrado na neve; cada graveto a mais aumenta o raio. Aciona um canal
  (opcional) — dá para abrir um portão quando ela acende.
- ✅ **Cavar na neve**: o graveto enterrado vira um montinho de neve no bioma de neve (cava-se
  com C, ou o fogo revela).
- ✅ **Graveto aceso**: a ponta de um graveto comum encostada numa fogueira acesa pega fogo. A
  chama derrete a neve em que encosta (montes de neve), acende fogueiras e vai se acabando (uns
  25 s; mais rápido na chuva e no vento forte), e o graveto volta a ser comum. O lendário não pega
  fogo.
- ✅ **Fogueira que só acende com fogo** (`Fogueira.acende_com_fogo`): a pilha completa fica só
  montada, esperando um graveto aceso — levar o fogo de uma fogueira a outra com o vento tentando
  apagar.
- Ideias para depois: outros jeitos de acender (a corda de um lampião, empurrar uma brasa); o fogo
  derreter gelo em água (o caminho que piora); "montinho de neve" que esconde outro objeto
  qualquer (um osso, um pano, uma chave), achado pelo faro.
- ✅ **Celeiro** (para o pastoreio na neve): abrigo das ovelhas, quente por dentro; telhado e
  paredes altas somem com o cachorro perto. As ovelhas **balem** (com som) quando estão longe —
  para achá-las em mapas grandes.
- ✅ **Vento forte**: objeto `Vento` — uma biruta e um corredor (`largura` × `comprimento`) com
  vento fraco o tempo todo e **rajadas** a cada `intervalo` (a biruta levanta e os riscos
  aparecem um pouco antes, para dar tempo de se abrigar). A rajada empurra o cachorro para trás;
  atrás de algo sólido (pedra, bloco, muro) ele fica abrigado. O graveto atravessado vira vela
  (empurra mais), ao comprido corta o vento, e o peso do graveto segura. Apaga mais rápido o
  graveto aceso, e reforça o vento do clima (árvores, chuva) perto dele.

## Clima e chão molhado ✅ (feito)

- ✅ **Clima da fase** (`Fase.clima`: do bioma, tempo bom, chuva, neve, ventania, tempestade). O
  nó `Clima` segue o cachorro: chuva com respingos no chão, neve caindo, folhas voando, céu mais
  cinzento, raios e trovões, sons de chuva e vento. É só visual e sonoro (quem empurra é o Vento
  forte).
- ✅ **Vento nas árvores**: parâmetros globais de shader (`vento`, `chuva`) balançam árvores,
  capim e flores e, na chuva, abrem anéis na água e pingos nas poças.
- ✅ **Grama com poças** (cosmético; na neve, poças de neve derretida) e **Lama**. Para depois: a
  lama e as poças **sujarem o cão** (pelagem manchada que sai na água).

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
- ✅ Minimapa para mapas grandes e miniatura dos módulos na paleta.
- Ideias: editar um módulo direto (abrir como fase), pontos de encaixe nos módulos (para um
  gerador saber onde ligar uma peça na outra).
- Mostrar no editor as habilidades liberadas e o comprimento do graveto (prévia de passagens).
- ✅ Validação: o graveto é alcançável? (`AlcanceEditor`, busca de caminho pela grade). A
  portinhola deixa passar e a água que uma comporta acionável baixa conta como rasa (issue #32).
- Preservar os IDs internos ao salvar para o diff no git ficar menor.

## Raças, skins, missões e temas (começou ✅)

O editor de fases é a base de tudo isso (e a seção *Visão*, no começo, diz o porquê).

- ✅ **Skins**: o cachorro virou voxel gerado por código, e uma pelagem é só um conjunto de
  cores (recurso `Pelagem`). O salsicha tem 8: vermelho, preto e fogo, chocolate, malhado,
  creme, branco e pelo longo (vermelho, preto e fogo). Escolha no menu (tela Cachorro); com as
  regiões, passa a ser escolhida ao entrar na região, depois da raça.
- ✅ **Raças como dados** (`assets/racas/*.tres`, recurso `Raca`): proporções, orelha, rabo e
  as medidas da colisão; a fase escolhe a raça. Já existem salsicha, pug e border
  collie.
- ✅ **Objetivo da fase como dado** (`Fase.objetivo`): trazer o graveto ao dono (o de sempre) ou
  levar as ovelhas ao abrigo (cercado ou celeiro). Cada objetivo é uma classe em
  `scripts/objetivos/` que diz o que a fase precisa (`faltando`, `avisos`) e prepara e confere a fase (`preparar`, `processar`).
- ✅ **Border Collie**: objetos *Ovelha* (foge do cachorro, anda em rebanho, se espanta com o
  latido, não entra na água funda) e *Cercado*; N09.
- **Raças com mecânica própria.** Cada raça resolve os quebra-cabeças do seu jeito; a raça é
  escolhida ao entrar na região, entre as compatíveis (ver *Visão → Regiões e história*).
  Decidido: **sem peso nem habilidades por raça** — todas fazem o mesmo, e só o **tamanho**
  muda (o que cabe num vão, o tempo de passar na portinhola). O que diferencia as raças são as
  **missões** e os temas de cada uma:
  - *Salsicha*: buscar gravetos (a história principal).
  - *Border Collie*: pastoreio (feito).
  - *Pastor Alemão e Malinois*: faro, morder e guardar a casa (ver missões).
  - *Corgi*: pequeno — cabe em túneis bem baixos.
  - *Vira-lata caramelo*: a cidade — acha comida pelo faro, conhece os atalhos.
- Próximas raças (o formato já comporta, falta a mecânica de cada uma):
  - *Pug*: já tem modelo e pelagens (bege, preto); falta uma fase com a cara dele.
  - *Pastor Alemão e Malinois*: cães policiais e de guarda. Seguem o **faro** — objetivo novo
    "achar o objeto": rastro de cheiro visível ao farejar (tecla nova), em casas, cidade,
    fazenda, fases noturnas (ex.: entrar numa casa pela portinhola e farejar um item) — e
    guardam a casa à noite (ver missões).
  - *Vira-lata caramelo*: o cachorro brasileiro por excelência, com pelagens de vira-lata
    (caramelo e outras); fases na cidade grande, em favelas e no interior do Brasil.
  - *Galgo*: esguio e alto.
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

- ✅ Árvores entre a câmera 3D e o cachorro ficam transparentes (dither) em vez de taparem.
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
