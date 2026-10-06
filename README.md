# The Weiner and the Legendary Sticks

*and other dog stories*

Jogo de puzzle 3D: um cachorro salsicha busca gravetos lendários e precisa voltar carregando
o graveto na boca — a colisão do graveto pelo cenário é o núcleo do puzzle.

Ver [docs/DESIGN.md](docs/DESIGN.md) para o design atual (a nova direção de 2026-10: capítulos,
o parque, só terceira pessoa), [CONCEITO.md](CONCEITO.md) para a ideia original e
[ROADMAP.md](ROADMAP.md) para as próximas etapas (túneis, pulo, cavar, empurrar, riachos, latir, truques, peso do graveto...).

## Rodando

Abrir a pasta no **Godot 4.7** e rodar (F5). O jogo abre no **menu principal**
(`scenes/menu.tscn`): continuar de onde parou, escolher **região → raça → fase** (✓ nas
concluídas), escolher a pelagem de cada raça (só aparência, com prévia ao fundo) ou abrir o
**editor de fases** — numa fase existente ou numa nova, do zero. Antes de jogar, a raça se
escolhe entre as compatíveis com a região (ver *Regiões e biomas*). Para jogar uma fase direto,
abra a cena dela e use F6 (rodar cena atual). O progresso (fases concluídas e com que raça,
raça escolhida por região, pelagens) fica em `user://progresso.cfg`.

Os controles (canto de baixo, à direita) mostram só os que valem no momento; reiniciar (R) e o editor
(F1) aparecem na pausa, com as teclas.

| Tecla | Jogo | Editor de fases |
|---|---|---|
| WASD / setas | andar | mover a câmera |
| Mouse | câmera | clique esq. coloca, dir. apaga, meio gira; Cursor: arrastar no vazio gira |
| E | largar o graveto | girar (com Q) |
| Q | virar o graveto (atravessado ↔ ao comprido) | girar (com E) |
| Ctrl | correr | modificador (Ctrl + roda: tamanho do pincel) |
| Espaço | pular (depois da F03; parado na beira de água funda, o salsicha não pula) | segurando + botão esquerdo: girar a vista |
| C | cavar terra fofa (se a fase liberar) | — |
| B | latir (se a fase liberar) | — |
| T | rolar na grama (na área central do parque) | — |
| F | ação do que está à frente (a ponta de um tronco, uma alavanca...) | — |
| F (segurando) + trás | puxar o bloco de pedra ou o tronco pela ponta (sem graveto): segurando F perto, o cachorro vira de frente e agarra | — |
| F (segurando) + lado | mordendo a ponta de um tronco: gira o tronco 90° em volta da outra ponta | — |
| 1 a 5 | — | ferramentas do terreno: Pincel, Trocar, Linha, Retângulo, Balde |
| Ctrl + roda, [ e ] | — | tamanho do pincel (1×1, 2×2, 3×3...) |
| Shift + clique, clique | — | linha com prévia (tiles ou objetos): o 2º clique confirma |
| Ctrl + arrastar | — | retângulo de tiles; com um objeto, espalhar cópias (pincel de floresta) |
| Alt + clique | — | balde |
| G | — | conta-gotas (pega o tile/objeto sob o cursor) |
| Shift | andar devagar (equilíbrio) | modificador (trocar tile, girar 15°) |
| R | reiniciar | subir camada (com F: descer) |
| Esc | pausa (solta o mouse; ao continuar, prende de novo) | Cursor / cancelar linha / desmarcar |
| **F1** | **abrir o editor nesta fase** | **testar a fase** (F1 volta) |
| F2 | — | testar daqui (o cachorro começa no cursor, em chão firme) |
| F3 | liga/desliga o pixelado | idem |
| H | — | lista de atalhos do editor |
| Tab | — | esconder / mostrar os painéis (ver o mapa inteiro); o botão **Esconder painéis** no topo faz o mesmo |
| F11 | tela cheia / janela (guarda nas opções) | idem |

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

**Monitores largos** (21:9, 32:9): o 3D ocupa a tela toda sem esticar — a tela larga mostra
mais mundo dos lados — e a interface fica numa
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
- **Cada fase tem um id** (`Fase.id`, ex.: `floresta_01_andar`) — é ele que vai para o save, não o nome
  do arquivo. Renomear ou mover o arquivo (ex.: para pastas de região) não apaga o ✓. O editor
  dá um id novo ao **Salvar como** (fase nova); nunca reaproveite o id de outra fase. Se um id
  precisar mudar, anote o antigo → novo em `Fases.IDS_RENOMEADOS`.

## Testes das fases

`ferramentas/testar_fases.sh` joga cada fase com as entradas de `ferramentas/testes/rotas/*.txt`
(sem janela, em segundos) e confere que ela termina. Um `SCRIPT ERROR` na saída reprova a rota,
mesmo que as checagens passem. Ao mudar uma fase, rode de novo; se o
caminho mudou, ajuste a rota (o formato está no topo de `ferramentas/testes/roteiro.gd`).
A rota `save` testa a pasta do save, os ids das fases e a migração de saves antigos; a rota
`mecanismos` testa a regra OU / E dos portões e a ferramenta Ligar do editor
(`ferramentas/testes/teste_mecanismos.gd`); `editor` testa trechos, colar girado, módulos,
balde, bioma, o F2 sem chão firme e o tronco escolhido no editor (`teste_editor.gd`); `neve` e `celeiro` montam fases de neve por código
(`teste_neve.gd`) e testam frio, fogueira, gelo e o celeiro; `menu` escolhe a raça da região
no menu e confere que ela vale no jogo, a raça fixa do rebanho (N09) e a tela *antes de jogar*
(`teste_menu.gd`); `passagens` testa toca de texugo, portinhola, alavanca, comporta, portão
com atraso e lampadinhas e passarinhos que voltam (`teste_passagens.gd`); `clima` testa os
climas da fase e os tiles de poças e lama (`teste_clima.gd`); `vento_gelo_fogo` testa gelo liso,
vento forte e graveto aceso (`teste_etapa11.gd`).
Precisa do Godot no PATH (ou `GODOT=/caminho/do/godot`).
Os testes não mexem nos arquivos do jogador: usam as opções de fábrica e guardam o progresso
só na memória (se o `progresso.cfg` real mudar durante um teste, o teste falha).

## O parque (área central)

**▶ O Parque** no menu principal abre a área central do capítulo 1 (ver *O ciclo de um dia* em
[docs/DESIGN.md](docs/DESIGN.md)): `scenes/parque/area_central.tscn`, objetivo *Parque*
(`scripts/objetivos/objetivo_parque.gd`). A arte, o *layout* final e as animações ficam para
depois da direção visual; o que existe agora é a estrutura, com visual provisório.

- **Começo do dia**: "Dia N"; o dono chega pela saída com o cachorro na guia, tira a guia, diz a
  frase do dia (a da entrada do dia, ou "Vai lá, garotão, pode brincar") e senta no banco.
- **Brincar**: a **bolinha** vai para a boca encostando; levada ao dono sentado, ele joga longe;
  E larga. **T** rola na grama (e se sacode no fim); parado um tempo, o cachorro deita. Dois
  passeantes (pessoa + cão na guia) dão voltas na clareira.
- **As 10 entradas** (`EntradaDia`): uma por dia, em volta da clareira, com uma placa colorida.
  Abre a do dia atual e as anteriores (dia = fases dos dias concluídas + 1); as outras ficam
  fechadas por troncos. Entrar numa aberta joga a fase do dia.
- **Na fase do dia**: pegar o graveto lendário faz o dono **assobiar**; concluída, o jogo volta
  ao parque: o cachorro chega ao dono, que levanta, põe a guia, e os dois vão embora pela saída.
  Aí começa o dia seguinte.
- **Provisório**: os dias 2 e 3 usam fases da esteira (F03 e F04); os dias 4 a 10 ainda não têm
  fase e ficam fechados.

### Dia 1, "O primeiro graveto"

`scenes/parque/dia_01.tscn`, gerada por `ferramentas/gerar_dia_01.gd` (sobrescreve a cena),
objetivo *Dia do parque* (`scripts/objetivos/objetivo_dia.gd`; rota `dia_01`). Uma trilha no mato
saindo da área central, com uma curva: o cachorro chega saindo de uma **moita** (a câmera
mostra a moita sacudindo); o **tronco semicaído** (rastejar por baixo); dali, ao
longe, a **moita** que se mexe sozinha; o **córrego** fundo com **pedras** (pular); a moita (pular
dentro) leva a uma pequena clareira, onde o **esquilo** come uma noz, vê o cachorro, se assusta,
sobe na árvore e quebra um galho, que cai no **raio de sol** e fica dourado (o cajado lendário).
Nessa cena o jogador não controla o cachorro: a câmera mostra o esquilo, depois o galho, e só
devolve o controle com o galho no chão, iluminado. Pegando, o cachorro abana o rabo e o dono
assobia ao longe. Na volta, pulando de novo na moita com o cajado na boca, a tela escurece e o
cachorro reaparece no parque, já perto do dono.

O objetivo *Dia do parque* começa com o cachorro saindo da moita com *chegada* e termina quando
ele, com o graveto lendário, pula numa moita (ou entra num **Corte da volta**; sem dono na fase). As ações de contexto (categoria **Ações** no editor) mostram só a
tecla: perto da ponta, olhando para o obstáculo, **F**.

- **Tronco semicaído** (*comprimento*): andando não passa; F rasteja por baixo.
- **Pedras do córrego** (*quantidade*, *espaçamento*): F (ou Espaço) pula de pedra em pedra.
  As pedras não têm colisão, mas perto delas uma barreira invisível na beira não deixa o cachorro
  cair nem andar por cima delas; longe delas, ele cai na água, volta à margem e se sacode.
- **Moita (pular dentro)** (*largura*, *chamar atenção*): F pula para dentro e sai do outro lado;
  com *chamar atenção*, ela se mexe sozinha até alguém atravessar; com *chegada*, o cachorro
  começa a fase saindo dela.

Outros objetos novos: **Esquilo na árvore (derruba o galho)** (Bichos; *distância do susto*,
*altura do galho*: pega o graveto e a árvore mais perto e põe o galho lá em cima, com cara de
galho comum), **Raio de sol** (Cenário; *raio*, *altura*), **Corte da volta** (Regras;
*tamanho*) e o **formato** do graveto (reto ou cajado).

A cena é gerada por `ferramentas/gerar_parque.gd` (sobrescreve a cena; as fases dos dias ficam
em `FASES_DOS_DIAS`):

    godot --headless --path . --script res://ferramentas/gerar_parque.gd

No editor, os objetos estão na categoria **Parque**: Banco, Bolinha, Entrada do dia (dia, fase,
frase do dono, largura), Saída do parque e Passeante (raça, raio, velocidade, sentido). A rota
`parque` testa o ciclo inteiro: chegada, bolinha, rolar, entrar no dia 1, voltar e o dia 2.

## Esteira de fases de teste

As fases de agora são uma **esteira de teste**: cada uma valida **uma mecânica**, numa trilha
simples e igual para todas. O cachorro começa ao lado do dono, busca o graveto lendário no fim da
trilha e volta. Cada fase tem uma rota em `ferramentas/testes/rotas/` com o mesmo nome, que
joga a fase e confere a mecânica, não só o fim.

As cenas são geradas por `ferramentas/gerar_esteira.gd`, que tem um método por fase:

    godot --headless --path . --script res://ferramentas/gerar_esteira.gd [-- floresta_07_ponte ...]

Sem nomes, o gerador refaz todas as fases. **Atenção:** ele sobrescreve as cenas, então quem
editar uma fase no editor deve levar a mudança para o gerador (ou parar de usá-lo para ela).

**Floresta** (`scenes/fases/floresta_*.tscn`):

| Fase | Mecânica |
|---|---|
| F01 Andar e pegar | andar, pegar o graveto, entregar ao dono |
| F03 Pular | pular um vão e um degrau (a habilidade vem da fase) |
| F04 Rampas e escadas | o platô é alto demais para pular: sobe pela rampa, desce pela escada |
| F05 Degrau alto | só pulando; com o graveto na boca o pulo não chega (a volta é descendo) |
| F06 Rampa lisa | com um graveto pesado na boca, escorrega; a escada do lado é a saída |
| F07 A ponte | ponte sobre água funda |
| F08 Tábua e pinguela | passagens estreitas de 5 e 6 m: equilíbrio, andar devagar, graveto ao comprido |
| F09 Correnteza e vau | a correnteza arrasta; o vau de água rasa só deixa mais lento |
| F10 Cavar | túnel no monte de terra fofa; no chão, a terra fofa vira buraco |
| F11 Debaixo da cerca | cavar sob a cerca; o graveto comprido só passa ao comprido |
| F12 Graveto enterrado | cavar o montinho para desenterrar o graveto |
| F13 Empurrar o bloco | bloco de pedra para dentro do riacho (vira passagem) |
| F14 Puxar o bloco | F de frente para o bloco e andar para trás |
| F15 Placa de madeira | qualquer coisa aciona; um graveto largado segura o portão |
| F16 Placa de pedra | só algo pesado (o bloco) aciona; o cachorro não |
| F17 Duas placas (regra E) | o portão só abre com as duas placas acionadas |
| F18 Portão com atraso | o portão demora a fechar: dá para passar correndo |
| F19 Alavanca | F na alavanca liga e desliga o canal |
| F20 A ponte que cai | pegar o graveto derruba a ponte (gatilho) |
| F21 A ponte que cede | a ponte fraca cai com alguém parado em cima |
| F22 Comporta | a alavanca liga a comporta: a água funda baixa e dá pé |
| F23 Toca de texugo | a toca leva à outra da mesma cor, por baixo da terra |
| F24 Portinhola | a portinhola só passa com o graveto ao comprido |
| F25 Passarinhos | o latido espanta o passarinho que guarda o graveto e o que fecha o vão |
| F26 O passarinho na placa | o passarinho pousado segura o portão fechado; o latido o faz voar por um tempo |
| F27 O esquilo | guarda o graveto; um latido e ele se esconde |
| F28 O cão vizinho | late de ciúme quando o salsicha passa com o graveto e espanta o passarinho |
| F29 O dono cochilou | largar o graveto, latir e entregar |
| F30 O tronco rola | de lado rola; ao comprido desliza até virar pinguela sobre o riacho |
| F31 Girar o tronco | mordendo a ponta e andando de lado, gira 90°; depois vira pinguela |
| F32 O tronco no rio | na correnteza rasa o tronco boia; onde o rio fica fundo, afunda atravessado (pinguela) |
| F33 Dia de tempestade | clima com chuva, vento e raios; poças e lama |

**Neve** (`scenes/fases/neve_*.tscn`, região Neve):

| Fase | Mecânica |
|---|---|
| N01 Neve fofa | mais devagar, e demora a parar |
| N02 Gelo | soltando a tecla, continua deslizando |
| N03 Gelo liso | desliza em linha reta (na grade) até bater |
| N04 Monte de neve | cavar através do monte |
| N05 Frio e fogueira | o calor cai longe do fogo; a fogueira acende com 2 gravetos; gelado, volta ao último lugar quente |
| N06 O fogo derrete | a parede de gelo não se cava: a fogueira acesa derrete |
| N07 Graveto aceso | leva o fogo de uma fogueira a outra; a acesa abre o portão |
| N08 Vento forte | rajadas empurram; atrás das pedras fica abrigado |
| N09 O rebanho | Border Collie: ovelhas ao cercado |
| N10 O celeiro | com frio, ovelhas ao celeiro (o latido espanta; a fogueira e o celeiro aquecem) |

**Progressão:** a habilidade que uma fase libera vale em todas as seguintes (pelo menu, na
ordem das regiões): pular a partir da F03, cavar da F10, latir da F25 — e na Neve, tudo. As
fases foram pensadas para isso (o platô da F04 é alto demais para o pulo, o gelo da N06 não se
cava). Testando no editor valem só as habilidades da própria fase.

Bugs encontrados nas rotas viram issues no repositório (#27 a #33), e as rotas citam o número.

## Gravetos, placas e portões

- **Graveto lendário × comum:** o dono só aceita o **lendário** (dourado, com brilho). Os
  **comuns** (marrons) servem de ferramenta (peso numa placa, algo para trocar). Com um graveto na boca não dá para pegar outro — largue
  antes.
- **Canais são cores:** uma **placa de pressão** aciona tudo da mesma cor enquanto tiver algo em
  cima; um **portão** da mesma cor abre (ou fecha, com *inverter*). Várias placas da mesma cor:
  basta uma acionada. O portão nunca fecha em cima de alguém.
- **Madeira ou pedra** (como no Minecraft): a placa de **madeira** (tábuas) é acionada por
  qualquer coisa — o cachorro, um graveto largado, uma ovelha, um passarinho, o bloco, o tronco;
  a de **pedra** (laje cinza) só por algo pesado — o **bloco de pedra** e o **tronco**. O tronco aciona com qualquer uma das
  células em cima (o meio ou uma ponta), e o graveto comprido, com qualquer parte dele.
- **Pontes de madeira:** as tábuas ficam dentro do bloco (do tamanho do vão, rente ao chão). Há
  três tipos (propriedade *Tipo* no painel): **Firme**; **Cede com o tempo** (ponte velha, mais
  escura: quem fica parado em cima mais que *tempo para ceder* segundos faz ela ranger, tremer e
  quebrar); **Quebra num gatilho** (cai quando o canal dela liga). Quebrada, as tábuas caem na
  água e a correnteza leva. *Aviso ao quebrar* é um texto opcional para a hora (as fases do jogo não usam).
- **Gatilho:** uma área invisível (roxa no editor) que liga o canal uma vez, de vez: quando o
  cachorro **entra**, **entra com um graveto** ou quando **um graveto de dentro dela é pego**.
  Ligue com a ferramenta Ligar (ex.: à ponte que cai).
- **Botão de ação (F):** objetos que respondem ao F mostram a ação embaixo da tela
  ("F: ..."). Segurar F + andar para trás continua puxando o bloco.
- **Regra OU / E:** com várias placas da mesma cor, o portão abre com **qualquer uma** acionada
  (OU, o padrão) ou só com **todas** ao mesmo tempo (E) — propriedade *Regra* do portão.
- **Alavanca:** o cachorro morde (F) e ela vira para o outro lado, ligando ou desligando a cor
  dela — ao contrário da placa, fica como está. Com *ligada*, a fase começa com ela ligada.
- **Portão com atraso:** com *atraso* (s), continua aberto uns segundos depois que o canal
  desliga — dá tempo de correr da placa até ele. Na regra E, **lampadinhas** em cima do portão
  mostram quantas placas da cor já estão acionadas.
- **Comporta:** com a cor dela ligada, a tábua sobe e a água do trecho à frente (*largura* ×
  *comprimento* células) baixa — a funda vira rasa e dá para atravessar a pé. Com *encher*, o
  contrário (a rasa vira funda); com *de vez*, a mudança fica mesmo quando o canal desliga
  (senão volta — nunca com o cachorro dentro).
- **Toca de texugo:** um monte de terra com um buraco; qualquer cachorro entra (andando para
  dentro ou com F) e sai pela outra toca da **mesma cor**, por baixo da terra. Com o graveto:
  *só ao comprido* e *comprimento máximo* (0 = qualquer).
- **Portinhola:** parede de tábuas com uma portinhola de cachorro. Todas as raças passam — quanto
  maior o cachorro, mais ele demora para se espremer. O graveto só passa ao comprido (e com
  *comprimento máximo*); com *mão única*, só se entra pela frente (a seta).
- **No editor:** Placa, Portão, Alavanca, Comporta, Gatilho e Vento forte ficam em *Mecanismos*; linhas tracejadas na cor do canal
  ligam as placas aos portões, e o portão que reage a mais de uma placa mostra a regra ("OU" /
  "E"). A validação avisa placa sem portão (e vice-versa) e regra E com uma placa só. Ver
  *Ligando mecanismos* em "Criando fases".

## Cavar, empurrar e bichos

- **Cavar (C)**, de frente para: um **montinho** (graveto enterrado — desenterra); uma **cerca
  com terra fofa** (abre um vão baixo naquele metro: salsicha e pug passam, border collie não);
  um bloco de **terra fofa** (some); a **terra fofa do chão** (vira um *Buraco* de meio metro — o
  cachorro sai escalando, e um bloco empurrado para dentro tapa o buraco).
- **Tronco** (*comprimento* de 2 a 5 células): empurrado **de lado** rola uma célula; **ao
  comprido**, desliza. **Mordendo a ponta** (segurar F de frente para ela, sem graveto): andando
  para trás, puxa; andando **de lado**, gira 90° em volta da outra ponta (precisa de espaço livre
  no caminho do giro). Com as duas pontas apoiadas em margens e o meio sobre água ou um vão, vira
  **pinguela** — passagem estreita e redonda, que **balança mesmo sem graveto**. Inteiro na água
  rasa ou na correnteza, **boia** (dá para andar em cima) e a correnteza leva, uma célula por
  vez, até parar num objeto (uma pedra), encaixar entre margens ou afundar na água funda; se
  encalhar na margem ou sair do mapa, volta para o lugar. Só pesa em placa quando está em terra.
- **Tronco caído** com *pinguela*: atravessado sobre um vão, é passagem estreita (equilíbrio).
- **Esquilo** (e a toca): leva gravetos largados por perto (até `raio` m) para a porta da toca e
  guarda; um latido assusta — larga o que levava e se esconde por `tempo_escondido` s.
- **Cão vizinho**: late de volta quando ouve um latido e late de ciúme quando um cachorro com
  graveto passa perto (3 m); o latido dele alcança o que está perto dele.
- **Passarinho**: guarda o graveto ou (com *bloqueia passagem*) o caminho; um latido espanta. Com
  *volta depois* (s), volta para o mesmo lugar — pousado numa placa, é um contrapeso que vai e
  volta.
- **Dono dormindo** (`dormindo`, no painel do Dono): "Zzz" — só recebe o graveto depois de um
  latido (a validação avisa se ninguém pode latir).
- **Bichos que passeiam** (`scripts/objetos/bicho.gd`; em *Bichos* no editor): andam sozinhos
  até `raio` m de onde foram colocados, parando entre um passeio e outro. **Tartaruga** (nada
  devagar na superfície), **Peixe-cuspidor** (nada embaixo d'água; parado, sobe e cospe um jato),
  **Castor** (anda na terra e nada), **Texugo** (foge correndo quando o cachorro chega a 3 m) e
  **Urso** (grande, devagar, cheira o chão; tem colisão). Por enquanto só se movimentam — o papel
  de cada um na história ainda vai ser encaixado.
- **Som**: o latido é gerado por código (`scripts/som.gd`), com o tom pela altura da raça.

## Neve, fogo e o celeiro

- **Bioma Neve** (propriedade *Bioma* da fase): os mesmos tiles com texturas de inverno (grama
  coberta de neve, pedra nevada, mato nevado, terra gelada), céu frio, neve caindo, entorno
  branco e árvores e pedras com neve. Tiles próprios: **Neve fofa** (mais lento, e o cachorro
  demora a arrancar e a parar), **Monte de neve** (bloco que se cava com C ou derrete no fogo) e
  **Gelo** (desliza: solta a tecla e ele continua) e **Gelo liso** (azul, mais brilhante: pisou,
  o cachorro desliza em linha reta, sem controle, até bater em algo ou sair do gelo — um bloco
  empurrado também).
- **Frio** (propriedade *Frio* da fase): longe do fogo o **calor** cai (barra no canto de baixo)
  em *Segundos até gelar*, e mais rápido na água; com pouco calor o cachorro treme e anda mais
  devagar; gelado, volta para o último lugar quente. Esquentam: fogueira acesa (perto) e celeiro
  (dentro).
- **Fogueira**: um círculo de pedras que acende com `gravetos_para_acender` gravetos comuns —
  traga na boca e aperte **F** perto dela (ou largue o graveto junto dela). Acesa, esquenta,
  derrete a neve em volta (neve fofa vira terra, montes somem) e revela o que estava enterrado
  na neve; cada graveto a mais aumenta o raio (`raio_por_graveto`, até `raio_maximo`). O
  lendário não vai para o fogo. Acesa, também aciona a cor dela (dá para abrir um portão com a
  ferramenta Ligar) — ou fica sem ligação. Com *acende com fogo*, a pilha completa fica só
  montada: falta trazer fogo.
- **Graveto aceso**: um graveto comum com a ponta encostada numa fogueira acesa pega fogo. A
  chama derrete a neve em que encosta, acende uma fogueira *acende com fogo* e vai se acabando
  (`DURACAO_CHAMA` s; mais rápido na chuva e no vento). O lendário não pega fogo.
- **Vento forte** (em *Mecanismos*): uma biruta num poste e, à frente dela, um corredor
  (*largura* × *comprimento*) de vento que empurra o cachorro — fraco o tempo todo e, a cada
  *intervalo* s, uma **rajada** (*força da rajada*; acima de 3,5 m/s não dá para andar contra).
  A biruta levanta e os riscos aparecem um pouco antes, para dar tempo de se **abrigar** atrás
  de algo sólido (pedra, bloco, muro). O graveto atravessado na boca vira **vela** (empurra
  muito mais); no gelo liso a rajada faz deslizar. *Defasagem* tira ventos vizinhos de compasso.
- **Celeiro**: abrigo das ovelhas (como o Cercado): porta larga no lado +X, feno num canto,
  telhado com neve no bioma de neve. Com o cachorro perto, o telhado e a parte alta das paredes
  somem para dar para ver dentro. Uma ovelha que entra fica guardada; dentro é quente.
- **Ovelhas balem** ("Béé!", com som) de vez em quando quando estão longe do cachorro — é assim
  que se acha uma ovelha perdida num mapa grande. Neve fofa e água rasa atrasam as ovelhas também.

## Clima e chão molhado

- **Clima** (propriedade *Clima* da fase): *Do bioma* (neve no bioma que neva, tempo bom nos
  outros), *Tempo bom*, *Chuva* (pingos e respingos no chão, poças com anéis, chão molhado),
  *Neve*, *Ventania* (árvores e capim balançam, folhas voam) e *Tempestade* (chuva, vento, raios
  e trovões). É só visual e sonoro (`scripts/clima.gd`); o vento que empurra é o **Vento
  forte**, que também reforça o balanço das árvores perto dele. Os shaders leem os parâmetros
  globais `chuva` e `vento` (em `project.godot`).
- **Grama com poças** e **Lama**: tiles cosméticos por enquanto (as poças ganham pingos na
  chuva). No futuro, a lama e as poças sujam o cachorro.

## Regiões e biomas

- **Regiões** (`assets/regioes/*.tres`, recurso `Regiao`: nome, descrição, ordem, bioma
  sugerido e **raças compatíveis**) agrupam as fases no menu
  (**Regiões**). Cada fase diz a sua na propriedade *Região*. Hoje: **Floresta** (F01 a F33 da
  esteira; salsicha ou pug) e **Neve** (N01 a N10; salsicha ou border collie).
- **Raça antes de jogar**: na tela da região (e na tela *antes de jogar*, que abre no
  *Continuar*, ao chegar numa região nova e em *Trocar de raça* na pausa) o jogador escolhe a
  raça entre as `racas` da região; a escolha fica guardada por região e vale em todas as fases
  dela. A lista de fases marca ✓ verde as feitas com a raça escolhida e ✓ apagado as feitas com
  outra. Uma fase com **Sempre com esta raça** (`Fase.raca_fixa`, ex.: o rebanho N09, do Border
  Collie) ignora a escolha. Testando no editor, vale a raça da fase. Toda fase da região precisa
  ter solução com cada raça compatível. A ordem do jogo (continuar, próxima fase) é a das regiões e, dentro de
  cada uma, a do nome do arquivo. Para uma região nova, duplique um `.tres` e mude `id`, `nome`
  e `ordem`.
- **Biomas** (`scripts/biomas.gd`): Floresta e Neve. O bioma troca a biblioteca de tiles
  (`assets/tiles/tiles.tres`, `tiles_neve.tres` — mesmos IDs, materiais trocados em
  `Tiles.MATERIAIS_POR_BIOMA`), o céu e a luz, o chão e as árvores do entorno e se neva.

## Raças e pelagens

O cachorro é um modelo **voxel gerado por código** (`scripts/racas/cachorro_voxel.gd`) a partir
de dois dados:

- **Raça** (`assets/racas/*.tres`, recurso `Raca`): proporções (corpo, patas, cabeça, focinho),
  tipo de orelha (caída, em pé, dobrada) e de rabo (reto, enrolado, curto) e colisão. As
  raças não têm peso nem habilidades próprias: só o **tamanho** muda o jogo (por onde passa, o
  vão cavado sob a cerca, o tempo na portinhola). Hoje: salsicha, pug e border collie.
- **Pelagem** (recurso `Pelagem`, dentro da raça): cores do pelo, cabeça, orelhas, marcas
  (barriga/patas/focinho/sobrancelhas), máscara, manchas (malhado/merle) e pelo longo.

Para criar uma raça: duplique um `.tres` em `assets/racas/`, mude `id`, `nome` e as medidas no
inspetor do Godot — ela aparece sozinha no menu (Pelagens) e nas propriedades da fase; para
jogar com ela, acrescente o id em `racas` das regiões em que ela tem solução.
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
- **Empurra**: o graveto na boca empurra blocos e troncos; ao comprido, de longe.
- **Equilíbrio**: em passagens estreitas (tile *Tábua*), carga = peso × comprimento acima de 1,2
  faz o cachorro balançar; o balanço cresce com o quadrado da velocidade e é menor ao comprido.
  Com o centro do corpo fora da tábua, ele cai. Ajustes no grupo "Equilíbrio" de
  `scripts/dachshund.gd`.

## HUD "Coleira"

Peças gordinhas de fundo creme, contorno marrom-escuro e sombra dura, nas cores de uma coleira
(vermelho) e da plaquinha de nome (dourado). Títulos e teclas em **Lilita One**, textos em
**Nunito ExtraBold** (fontes livres, OFL, em `assets/fontes/` com as licenças). O estilo fica em
`scripts/ui/coleira.gd` (cores, caixas, pílulas, teclas, medidores e a plaquinha com o osso).

- **Objetivo** (cima, à esquerda): a plaquinha e o que falta ("Leve o graveto ao dono",
  "Ovelhas no celeiro: 1 / 2").
- **Controles** (baixo, à direita): só os que valem agora, cada um com a sua tecla.
- **Avisos** (cima, no meio): curtos numa faixa vermelha torta; compridos numa pílula creme.
- **Balão** em cima do cachorro para as falas curtas ("Brrr!", "Splash!").
- **Ação do F** (baixo, no meio), **Equilíbrio** e **Calor** (cima, à direita) em pílulas.
- **Fim da fase**: a plaquinha dourada cai girando, "Fase concluída!" e as opções com as teclas.

## Visual pixelado

- O 3D é renderizado em baixa resolução e ampliado sem filtro (`Viewport.scaling_3d_mode =
  NEAREST`); a interface continua nítida. Tudo no autoload `scripts/autoload/visual.gd`:
  a intensidade (linhas de pixel na vertical, padrão 240 — menor = pixels maiores) fica nas
  **Opções → Gráficos**.
- Contorno escuro nas silhuetas e realce claro nas quinas: `shaders/contorno_pixel.gdshader`
  (quad de tela cheia preso à câmera; força e limiares são `uniform`s).
- Materiais do mundo (`shaders/pixel_mundo.gdshader`): cor chapada + textura de pixels gerada
  pela posição no mundo (8 texels por metro). Cores em `assets/materiais/*.tres`.
- Use materiais opacos (ou com alpha scissor): o contorno lê a profundidade só do que é opaco.

## Criando fases

Cada fase é uma cena em `scenes/fases/` com:

```
Fase (scripts/fase.gd: nome, habilidades, bioma, clima)
├─ Terreno  GridMap (assets/tiles/tiles.tres), células de 1 m; o chão fica na camada -1
└─ Objetos  instâncias de scenes/objetos/*.tscn
```

**Pelo editor do jogo (F1)** — o jeito principal. Escolha um tile ou objeto na paleta à esquerda
e clique; o **Cursor** (Esc) não coloca nada: seleciona e arrasta objetos, mostra as
propriedades à direita e, arrastando no vazio, gira a vista (com Shift, arrasta). A visão (V) alterna entre **livre** e
**isométrica** (só no editor: o jogo é sempre em terceira pessoa). **Salvar** (Ctrl+S) grava por cima do arquivo da fase. Para criar uma fase nova:
**Nova** (parte de um modelo) ou abra uma fase existente, mude o nome e use **Salvar como** — o
arquivo novo leva o nome da fase (`Floresta 34 — A ponte` → `scenes/fases/floresta_34_a_ponte.tscn`).
As fases são jogadas na ordem das regiões e, dentro de cada região, pelo nome do arquivo — então
comece o nome pelo número ("Floresta 34", "Floresta 35"... ou "Neve 11", "Neve 12"...).
Num jogo exportado as fases salvas vão para `user://fases/`.

**Pelo editor do Godot** — também funciona: pinte o GridMap `Terreno` com a biblioteca de tiles e
arraste cenas de `scenes/objetos/` para dentro de `Objetos`.

Construindo rápido (ideias tiradas de Mario Maker, do Minecraft criativo e do Axiom — ver o
ROADMAP):

- **Ferramentas do terreno** na barra em cima da vista (teclas 1 a 5): **Pincel**, **Trocar**,
  **Linha**, **Retângulo** e **Balde**. Os atalhos valem com qualquer uma: Shift = linha, Ctrl =
  retângulo, Alt = balde.
- **Tamanho do pincel**: Ctrl + roda do mouse (ou [ e ]) — 1×1 até 9×9; colocar, apagar e trocar
  usam o pincel inteiro (um chão de grama num instante).
- **Linha com prévia**: Shift + clique marca o começo, a prévia vai até o mouse e outro clique
  confirma (segurando Shift, a próxima linha começa dali). Vale para tiles e para objetos (uma
  fila de árvores, pedras, cercas). Esc cancela.
- **Prévia translúcida** na cor do tile mostra o que vai ser colocado; em vermelho, o que vai ser
  apagado.
- **Ctrl + arrastar** com um objeto espalha cópias sorteadas (o "pincel de floresta").
- **Espaço + botão esquerdo** gira a vista em qualquer ferramenta.
- **Paleta**: busca no topo, seções que recolhem (clique no título) e **Recentes** com os últimos
  itens usados. Tudo tem ícone.
- **Sem texto por cima dos objetos**: o nome do que está sob o mouse aparece na barra de status.
  Paredes invisíveis e zonas aparecem translúcidas (só no editor).
- **G** é o conta-gotas. **F2 testa daqui**: o cachorro começa onde está o cursor. Precisa ser
  chão firme: na água funda ou no vazio o editor avisa e não testa.

Ao **Testar** o editor valida a fase (falta início, dono ou graveto; início sem chão...) e pede
confirmação se houver problema grave; ao salvar, mostra os avisos (placa de pedra sem nada pesado
na fase, frio sem fogueira...).

Nas propriedades da fase (nada selecionado) ficam a **região**, o **bioma**, o **objetivo**, a
**raça** do cachorro (a do teste no editor; pelo menu vale a escolhida entre as da região, a
não ser com **Sempre com esta raça**), as **habilidades** que a fase libera (pular, cavar, latir; pelo menu somam-se as das fases anteriores) — e o **frio**. Cada
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

### Câmera e textos

O jogo é sempre em **terceira pessoa** (a câmera atrás do cachorro, girada pelo mouse); a vista
isométrica existe só no editor, para montar a fase. As fases do jogo não explicam a solução com
texto (ver `docs/DESIGN.md`, "Textos e dicas"): a *Zona de dica* (texto mostrado quando o
cachorro entra nela) fica para as cenas de teste. A *Zona sem largar* marca onde largar o
graveto deixaria o cachorro sem saída.

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
  `aderencia`), *Monte de neve*, *Gelo* (`aderencia` baixa: desliza), *Gelo liso*
  (`deslizante`: desliza em linha reta até bater), *Grama com poças* e *Lama* (`lama`; por
  enquanto só a aparência). `derrete_em` diz no que o
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
scenes/parque/                área central do parque e os dias (gerados por ferramentas/gerar_parque.gd e gerar_dia_01.gd)
scenes/modulos/               módulos: trechos de fase para reusar (criados pelo editor)
scenes/objetos/               objetos que o editor coloca
scripts/jogo.gd               regras: pegar/largar graveto, vitória
scripts/fase.gd               raiz de uma fase (consultas: objetos, tiles, água)
scripts/biomas.gd             biomas: tiles, céu, luz, entorno, neve caindo
scripts/clima.gd              clima da fase: chuva, neve, ventania, tempestade
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

Camadas de física: 1 `mundo` (terreno), 2 `bordas` (paredes invisíveis; a câmera passa
por elas), 3 `objetos`, 4 `cachorro`.

## Valores fáceis de ajustar

| O quê | Onde |
|---|---|
| Quanto pixelado | Opções → Gráficos (padrão em `Opcoes.PADRAO`) |
| Contorno (cor, força, limiares) | `uniform`s em `shaders/contorno_pixel.gdshader` |
| Cores dos blocos | `assets/materiais/*.tres` (inspetor do Godot) |
| Velocidade do cachorro | `velocidade` em `scenes/dachshund.tscn` / `scripts/dachshund.gd` |
| Câmera (distância, FOV, foco das cenas) | exports de `scripts/camera_controller.gd` |
| Comprimento/peso do graveto | propriedades do Graveto no editor de fases |
| Altura do pulo, equilíbrio | exports de `scripts/dachshund.gd` (grupo "Equilíbrio") |
| Habilidades liberadas | propriedades da fase no editor (nada selecionado) |
| Alcance do latido | `ALCANCE_LATIDO` em `scripts/dachshund.gd` |
| Força da correnteza, lentidão da água rasa | `correnteza` / `lentidao` em `Tiles.definicoes()` |
| Tempo segurando para puxar | `DURACAO_PUXAR` em `scripts/dachshund.gd` |
| Medidas e cores de uma raça | `assets/racas/*.tres` (inspetor do Godot) |
| Medo e velocidade das ovelhas | constantes no topo de `scripts/objetos/ovelha.gd` |
| Frio (tempo até gelar) | "Segundos até gelar" nas propriedades da fase |
| Raio e gravetos da fogueira | propriedades da Fogueira no editor |
| Neve fofa e gelo (lentidão, aderência) | `lentidao` / `aderencia` em `Tiles.definicoes()` |
| Céu, luz e chão de cada bioma | `Biomas.dados()` em `scripts/biomas.gd` |
| Chuva, neve, vento e raios de cada clima | `dados()` em `scripts/clima.gd` |
| Força e ritmo do vento forte | propriedades do Vento forte no editor; abrigo em `scripts/objetos/vento.gd` |
| Duração da chama do graveto aceso | `DURACAO_CHAMA` em `scripts/graveto.gd` |
