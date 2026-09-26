# Análise técnica — Pacote 1, opções, tela e exportação

Este documento levanta **tudo o que precisa mudar** para entregar:

1. o **menu de opções** (áudio, teclas, gráficos, tela);
2. a **tela dinâmica** (monitores largos como 3440 × 1440 sem esticar e sem bordas pretas);
3. a **exportação** do jogo num executável para compartilhar;
4. o **Pacote 1** do ROADMAP: o graveto vira ferramenta (gravetos comuns e lendário, placa de
   pressão e portão, graveto-ponte, mirante), com o **botão de ação (F)** e os **canais** como
   base.

Para cada item: o que existe hoje, o que muda, onde encaixa no código, riscos e decisões.
No fim, a ordem de execução (em PRs) e o que fica de fora.

---

## 0. Resumo

| Bloco | Tamanho | Depende de | Assets externos |
|---|---|---|---|
| Opções (autoload + telas) | médio | — | nenhum |
| Tela dinâmica + entorno automático | médio | Opções (modo de janela) | nenhum |
| HUD com teclas dinâmicas | pequeno | Opções (remapear teclas) | nenhum |
| Exportação (presets + CI) | pequeno/médio | testes no repositório | templates de exportação do Godot (baixados, fora do repositório) |
| Testes de fase no repositório | pequeno | — | nenhum |
| Botão de ação (F) | pequeno | — | nenhum |
| Canais | pequeno | — | nenhum |
| Placa de pressão + portão | médio | canais, peso por raça | nenhum |
| Gravetos comuns + lendário | médio/grande (mexe no `jogo.gd`) | refatoração dos objetivos | nenhum |
| Graveto vira ponte | médio | lendário/comuns, botão F | nenhum |
| Mirante | pequeno/médio | botão F, câmera | nenhum |
| Editor (canais, validação) | pequeno | canais | nenhum |
| Fases novas do Parque (06–09) | médio | tudo acima | nenhum |

**Nenhum asset externo é obrigatório.** Tudo continua gerado por código (voxels, tiles,
partículas). Os únicos binários de fora são os **templates de exportação do Godot**, que o
próprio editor baixa (ou a CI baixa) e que não entram no repositório. Opcionais: uma fonte pixel
(licença OFL) e, quando vier o áudio, sons CC0 ou gerados por código (ver seção 7).

---

## 1. Menu de opções

### Hoje
- Não há opções. O pixelado liga e desliga no F3 (autoload `Visual`, `LINHAS_ALVO = 240`
  fixo). Sensibilidade do mouse é um `@export` da câmera. Não há áudio nem barramentos de áudio.
- Teclas fixas no `project.godot`; os textos do HUD ("Q: virar graveto", "F + trás") estão
  escritos no código.

### O que entra
Autoload novo **`Opcoes`** (`scripts/autoload/opcoes.gd`), carregado antes de `Visual`:
- Guarda tudo em `user://opcoes.cfg` (separado do `progresso.cfg`).
- `aplicar()` na abertura e a cada mudança; sinal `mudou(chave)` para quem precisa reagir
  (câmera, `Visual`, sol da cena).

Tela **Opções** (menu principal e pausa), montada em código como o menu, com abas:

| Aba | Itens | Como aplica |
|---|---|---|
| **Tela** | Modo: janela / tela cheia (sem borda) / tela cheia exclusiva; tamanho da janela (720p, 900p, 1080p, 1440p, ou "maximizada"); monitor; VSync; limite de FPS (30, 60, 120, 144, sem limite); escala da interface (75–150%) | `DisplayServer.window_set_mode/size`, `Engine.max_fps`, `DisplayServer.window_set_vsync_mode`, `Window.content_scale_factor` |
| **Gráficos** | Pixelado: forte (180 linhas) / normal (240) / suave (320) / desligado; contorno liga/desliga; sombras: desligadas / baixa / alta; brilho | `Visual` lê `Opcoes`; sombras: grupo `sol` (a luz de `ambiente.tscn`) + `RenderingServer.directional_shadow_atlas_set_size`; brilho: `Environment.adjustment_brightness` |
| **Áudio** | Volume geral, música, efeitos, ambiente; mudo | Barramentos `Master`, `Musica`, `Efeitos`, `Ambiente` em `default_bus_layout.tres`; `AudioServer.set_bus_volume_db(linear_to_db(v))`. Fica pronto para quando houver som. |
| **Controles** | Lista das ações com a tecla atual; clicar e apertar a nova tecla; aviso de conflito; "restaurar padrão"; sensibilidade do mouse; inverter Y | `InputMap.action_erase_event/action_add_event`; salva os eventos com `var_to_str` no cfg; só teclado/mouse (o controle mantém o mapeamento de fábrica) |

Detalhes:
- **Quais ações se remapeiam:** andar (4), pular, cavar, latir, largar, virar o graveto, andar
  devagar, ação (F), reiniciar, pausa. As do editor ficam fixas por enquanto (são muitas e têm
  modificadores).
- **Renomear a ação `puxar` para `acao`** (tecla F) agora, antes de o remapeamento gravar
  nomes no `opcoes.cfg` dos jogadores. Mudar depois quebraria as configurações salvas.
- **Textos com teclas:** helper `Teclas.nome(acao) -> "Q"` (primeira tecla da ação, com
  `OS.get_keycode_string`). O HUD, as dicas e as Zonas de dica passam a usar isso. Nas Zonas de
  dica, o texto pode ter `{virar_graveto}`, trocado pela tecla atual.

---

## 2. Tela dinâmica: monitores largos sem esticar e sem bordas

### Hoje
- `stretch/mode = canvas_items`, `aspect = expand`, tamanho base 1152 × 648 (padrão do Godot).
  A janela abre em 1152 × 648, por isso "roda abaixo de 1920 × 1080".
- O 3D é desenhado com ~240 linhas (tamanho do pixel inteiro) e ampliado. A câmera isométrica é
  ortográfica, com **altura fixa** (11 m); numa tela mais larga ela mostra **mais mundo dos
  lados**, sem esticar. Isso já é o comportamento que você quer.
- O que falha no ultrawide:
  - a janela não abre no tamanho do monitor;
  - a interface gruda nas bordas: o menu fica na ponta esquerda e o HUD nos cantos;
  - o mundo "acaba" nas laterais: numa tela 21:9 a câmera mostra ~26 m de largura, e nas pontas
    das fases aparece o fim do chão.

### O que muda
1. **Janela:** padrão **tela cheia sem borda** na resolução nativa do monitor (3440 × 1440 no
   seu), com a opção de janela.
   - O tamanho base continua 1152 × 648: a interface escala com a **altura** da tela (em 1440p,
     2,2×), e a largura extra vira mundo.
   - A "escala da interface" nas opções multiplica isso.
2. **Área segura centralizada:** um `Control` **AreaSegura** limita menus, HUD, pausa e dicas a
   no máximo **16:9 no centro da tela** (em 3440 × 1440, uma faixa de 2560 px). Só o 3D ocupa a
   largura toda: o conteúdo fica centralizado e o mundo preenche as laterais, sem bordas pretas
   — "como nos FPS".
   - O editor de fases **não** usa a área segura: painéis nas bordas são melhores para editar.
3. **Entorno automático:** ao carregar uma fase, o jogo calcula a área usada pelo terreno e
   **gera em volta** um anel de chão e floresta de ~30 m.
   - Grama numa malha grande com o material pixel do mundo, e árvores voxel em `MultiMesh` (uma
     por variante: milhares de árvores quase de graça).
   - Não é salvo na fase: vale para todas, inclusive as que você criar.
   - As fases continuam com a floresta desenhada perto da trilha; o entorno só garante que nunca
     aparece o "fim do mundo", em qualquer largura de tela.
   - Na visão 3D o entorno também ajuda: o horizonte deixa de ser vazio.
   - *Onde encaixa:* nó `Entorno` (script novo) filho do `Jogo` e do menu (fundo); usa `Voxel`
     (as mesmas árvores) e as dimensões do `GridMap` (`get_used_cells`).
4. **Câmera isométrica:** a altura (11 m) fica igual para todos. Quem tem tela larga vê mais dos
   lados, uma vantagem aceitável num puzzle. Se incomodar, dá para limitar a largura visível (por
   exemplo a 21:9) e completar o resto com o entorno desfocado.

### Riscos
- Performance em 3440 × 1440: o 3D continua em ~240 linhas (~570 × 240 pixels internos), então o
  custo quase não muda. A interface nítida em alta resolução é barata.
- Menus e HUD precisam ser revistos um a um para usar a área segura (tamanhos fixos como
  `offset_right = 1136` no HUD).

---

## 3. Exportação: um executável para os amigos

### Dá para fazer — e testar aqui
- **Presets** (`export_presets.cfg`, no repositório):
  - **Windows** (`WeinerGame.exe`, um arquivo só, com o `.pck` embutido);
  - **Linux** (`WeinerGame.x86_64`);
  - **macOS** (universal, **sem assinatura**; o amigo precisa abrir com "clique direito → Abrir"
    — experimental).
- **Filtro de arquivos:** os modelos voxel em texto (`assets/voxel/*.txt`) não são "recursos"
  do Godot e **não entram no pacote por padrão**. O preset inclui `*.txt`; sem isso, o dono, o
  passarinho e o tronco sumiriam no jogo exportado. `ferramentas/` e `docs/` ficam de fora.
- **Pasta do usuário própria:** `application/config/use_custom_user_dir` com o nome
  `WeinerGame`. Progresso, opções e fases criadas no editor vão para
  `%APPDATA%\WeinerGame` (Windows) ou `~/.local/share/WeinerGame` (Linux), em vez de
  `…/Godot/app_userdata/Weiner-game`.
- **Editor dentro do jogo exportado:** já funciona. As fases salvas vão para `user://fases/`
  (`Fases.pasta_para_salvar`), e o `ResourceLoader.list_directory` que lista fases e raças
  funciona no jogo exportado.
- **Como você exporta:**
  - No editor do Godot: Projeto → Exportar → escolher Windows/Linux → Exportar Projeto. Na
    primeira vez, o Godot oferece baixar os templates (Editor → Gerenciar Templates de
    Exportação, ~1,3 GB).
  - Ou pela linha de comando: `godot --headless --export-release "Windows" build/WeinerGame.exe`
    (script `ferramentas/exportar.sh`).
- **CI (GitHub Actions):** um workflow que, a cada tag `v*` (ex.: `v0.1`) ou quando você mandar
  rodar, baixa o Godot e os templates (com cache), **roda os testes das fases** e exporta
  Windows e Linux. Os `.zip` saem como artefatos e, em tag, como **Release** no GitHub.
  - Se o repositório for privado, os amigos não veem a Release: aí é baixar o zip e mandar
    direto.

### Limites
- **Web (jogar no navegador) não dá** com o renderizador atual (Forward+). Exigiria o
  renderizador Compatibilidade, e o contorno pixel (que lê a profundidade) teria de ser refeito.
  Fica para depois.
- **Placas de vídeo antigas:** o Forward+ exige Vulkan ou Direct3D 12 (no Windows está D3D12).
  Um PC muito antigo pode não abrir. Vale testar nos amigos; se precisar, trocamos o driver do
  Windows para Vulkan ou avaliamos o Compatibilidade.
- **Assinatura:** executáveis Windows sem assinatura mostram o aviso do SmartScreen ("Executar
  assim mesmo"). Assinar exige certificado pago — fora de escopo.

---

## 4. Testes de fase no repositório

### Hoje
O roteiro que joga as fases com entradas simuladas (`roteiro.gd` + rotas) vive fora do
repositório, na minha área de rascunho. Foi com ele que achei os problemas das fases.

### O que muda
- `ferramentas/testes/roteiro.gd` (o intérprete: `apertar`, `esperar`, `eval`, `fase`...).
- `ferramentas/testes/rotas/fase_0X.txt`: a rota de cada fase, com a checagem final
  (`concluida`).
- `ferramentas/testar_fases.sh`: roda todas sem janela (`--headless`) e mostra ✓/✗.
- A CI roda isso antes de exportar: uma fase que ficou impossível não vira Release.
- Para você: ao mudar uma fase, rodar `ferramentas/testar_fases.sh` ou pedir que eu atualize a
  rota.
- As fases de pastoreio usam o piloto automático (ovelhas têm aleatoriedade).

---

## 5. Pacote 1 — o graveto vira ferramenta

### 5.1 Botão de ação (F)

**Hoje:** F só puxa bloco (`Input "puxar"`, segurado + andar para trás), com a lógica em
`dachshund.gd` (`_bloco_na_frente`, `_tentar_puxar`).

**Muda:**
- Métodos base novos em `ObjetoFase`:
  - `acao_da_boca(cachorro) -> String`: o nome da ação ("morder", "pegar"), ou vazio;
  - `executar_acao(cachorro)`.
- O cachorro procura o objeto **à frente do focinho**: o mais próximo até 1,2 m, dentro de 60°
  da direção em que olha, que tenha ação. Sem corpo físico, os objetos são achados por distância
  (o mirante, por exemplo, não tem colisão).
- **Apertar F** executa a ação. **Segurar F + andar para trás** continua puxando o bloco: o
  `Empurravel` responde "puxar" e o comportamento atual fica igual.
- O HUD mostra a ação disponível **perto do cachorro**: "F: morder o mirante", "F: pegar o
  graveto".
- Ação renomeada `puxar` → `acao` (ver Opções).

### 5.2 Canais

- Um **canal** é um nome (texto) que liga quem **aciona** (placa, e depois alavanca, pássaros no
  contrapeso) a quem **reage** (portão, e depois comporta, ponte levadiça, lanterna).
- *Onde encaixa:* `Fase` ganha um registro de canais (`definir_fonte(canal, fonte, ativo)` e
  `canal_ativo(canal)`) e o sinal `canal_mudou(canal, ativo)`.
- Um canal está ativo se **qualquer** fonte estiver ativa. Cada receptor tem "inverter" (ex.:
  portão que *fecha* quando a placa é pisada).
- **Legibilidade:** cada canal tem uma **cor** (8 cores bem distintas, pela ordem dos nomes na
  fase). A placa e o portão do mesmo canal usam a mesma cor, então o jogador vê o que abre o quê.
- **No editor:** o campo "Canal" aparece no painel. Linhas coloridas ligam as fontes aos
  receptores do mesmo canal (desenhadas na sobreposição, como a caixa dos objetos). A validação
  avisa canal sem receptor ou receptor sem fonte.

### 5.3 Placa de pressão

- Objeto **Placa**: laje de pedra de uma célula, com a borda na cor do canal.
  - Afunda uns centímetros quando está acionada.
  - Tem `canal` e `peso_minimo`.
- **Peso de cada coisa**, via `peso_na_placa()` nos objetos (grupo `pesos`):

  | O quê | Peso |
  |---|---|
  | cachorro | peso da raça: salsicha 1, border collie 1,5, pug 1,8 (campo novo `Raca.peso`) |
  | cachorro com graveto na boca | peso da raça + peso do graveto |
  | graveto largado | o peso dele (1 a 2) |
  | bloco de pedra | 3 |
  | ovelha | 1,5 |
  | passarinho | 0,3 |

- Por que por posição e não por `Area3D`:
  - a placa soma quem está **sobre a célula dela** (posição dentro da célula, altura perto do
    topo) a cada quadro de física;
  - funciona com gravetos (que não têm corpo) e com o bloco afundando;
  - é o mesmo tipo de consulta que o cercado já faz.
- **O dilema do ROADMAP sai de graça:** uma placa com `peso_minimo = 2` e o graveto lendário
  (peso 2) em cima.
  - O cachorro sozinho (1) não aciona.
  - Levar o graveto fecha o portão atrás do cachorro, a não ser que antes ele empurre o bloco
    (3) para a placa.
- Placas "só isométrico" ou "só 3D" já funcionam pela `visibilidade` (desativada, a placa não
  conta).

### 5.4 Portão

- Objeto **Portão**: grade de madeira de 1 a 3 células, com postes na cor do canal.
  - Aberto, desce para dentro do chão (animação curta) e perde a colisão.
- Propriedades:
  - `canal`;
  - `inverter`;
  - `travar_aberto`: uma vez aberto, fica aberto — bom para fases mais fáceis e para o
    tutorial.
- **Não fecha em cima de ninguém:** se algo estiver no vão (cachorro, bloco, ovelha, graveto),
  espera ficar livre.
- *Onde encaixa:* a colisão liga e desliga como no `definir_ativo`. Reage ao
  `Fase.canal_mudou`.

### 5.5 Gravetos comuns e o graveto lendário

A mudança que mais mexe no código.

**Hoje:** `jogo.gd` supõe **um** graveto (`graveto = fase.primeiro(Graveto)`), usado para:
- pegar;
- a mensagem de graveto grande;
- largar;
- a câmera olhando para o dono;
- a validação.

**Muda:**
- `Graveto.lendario` (padrão **verdadeiro**, para as fases atuais continuarem iguais).
  - Lendário: **dourado com brilho** (partículas voxel simples em código).
  - Comum: marrom.
- Objeto novo **"Graveto comum"** na paleta: a mesma cena, com `lendario = false`.
- `jogo.gd`:
  - liga **todos** os gravetos;
  - o graveto da vez é o que está na boca (`cachorro.graveto`);
  - **qualquer** graveto troca a perspectiva ao ser pego (é a regra do ROADMAP: todo graveto
    muda o ponto de vista);
  - o **dono só aceita o lendário**: com um comum na boca, ele diz "Esse não… quero o
    lendário!".
- Com a boca cheia, encostar em outro graveto não pega: aparece "E: largar este para pegar
  aquele".
- **Refatoração dos objetivos:** a lógica de cada objetivo sai do `jogo.gd` para classes
  próprias:
  - `scripts/objetivos/objetivo_graveto.gd` e `objetivo_pastoreio.gd`, com
    `preparar(jogo)`, `verificar()` e `requisitos()`;
  - o `jogo.gd` fica com câmera, perspectiva, HUD e o ciclo da fase;
  - facilita as próximas missões (guarda, filhotes, faro).
- **Validação do editor:** com mais de um graveto, exatamente **um** lendário.

### 5.6 O graveto vira ponte

- **Regra:** largar o graveto **ao comprido** apontando para um vão de **uma célula** (água ou
  buraco).
  - Se as **duas pontas** ficarem apoiadas em chão da mesma altura (≥ 0,3 m de apoio de cada
    lado), o graveto se encaixa como ponte.
  - O encaixe **alinha à grade** (giro múltiplo de 90°, centro no meio da célula) para não
    exigir mira.
  - Precisa de `comprimento ≥ 1,6 m`: o limite do graveto sobe para 3 m.
- **Como ponte:**
  - ganha uma colisão fina (corpo estático) para o cachorro andar em cima;
  - responde a `passagem_estreita_em` (o mesmo equilíbrio da *Tábua*): `Fase` passa a perguntar
    também aos objetos, não só aos tiles;
  - **não é pego ao encostar** (senão o cachorro o pegaria ao atravessar). Só com **F** perto
    de uma das pontas, estando no chão: "F: pegar o graveto".
- **Consequências de design:**
  - largar volta para a isométrica: as tampas "só isométrico" voltam, e aí **onde** fazer a
    ponte importa;
  - o graveto que é ponte não está na boca, então atravessar e depois recuperá-lo é o
    quebra-cabeça;
  - um graveto curto não vira ponte e cai na água: volta para onde foi largado, como já
    acontece.
- *Onde encaixa:*
  - no `jogo._tentar_largar_graveto` entra o teste das pontas (dois raios para baixo) antes do
    `_chao_embaixo`;
  - o `Graveto` ganha o estado `ponte` (chão / boca / ponte).

### 5.7 Mirante (graveto fincado)

- Objeto **Mirante**: um graveto fincado num toco, sempre na vertical (visual distinto do
  graveto comum).
- Na **isométrica**, sem graveto na boca, **F: morder o mirante**:
  - a câmera vai para o 3D, girando em volta do mirante (mouse ou analógico), um pouco mais
    alta;
  - **mostra a fase como ela ficará na volta**: os objetos "só isométrico" somem e os "só 3D"
    aparecem, **só no visual**, sem mexer na física, porque o cachorro fica parado;
  - é o jeito de o jogador **descobrir antes** que a ponte some, a pista que faltou na Fase 03;
  - F (ou Esc) solta, e a câmera volta à isométrica com o visual restaurado.
- *Onde encaixa:*
  - `CameraController` ganha um alvo opcional (hoje segue o cachorro);
  - `Fase` ganha `mostrar_visual(estado)`, que liga a visibilidade sem tocar em
    `process_mode`.
- Evolução (depois): girar a isométrica 90° no mirante.

### 5.8 Editor

Os objetos novos aparecem sozinhos na paleta (é assim que o catálogo funciona):
- Graveto comum;
- Placa;
- Portão;
- Mirante.

Falta:
- o campo **Canal** com sugestões dos canais já usados na fase;
- linhas coloridas entre fontes e receptores;
- validação: um lendário só, canais soltos, placa com `peso_minimo` que nada na fase alcança
  (aviso);
- **prévia de pesos**: ao selecionar uma placa, o painel mostra o peso de cada coisa que pode ir
  para ela.

### 5.9 Fases novas (região do Parque)

Fases curtas, cada uma ensinando uma mecânica. Você depois as alonga, como disse que vai fazer.

| Fase | Ensina | Resumo |
|---|---|---|
| **06 — O Portão** | placa + portão | Um portão fecha a trilha; empurrar o bloco para a placa abre. Na volta, o bloco ainda está lá. |
| **07 — A Chave e o Prêmio** | lendário na placa | O lendário está sobre a placa que segura o portão. Pegá-lo fecha o portão; é preciso trocar por um graveto comum pesado (ou pelo bloco) antes. |
| **08 — A Ponte de Graveto** | graveto-ponte + mirante | Um riacho sem ponte na volta; um graveto comum longo vira ponte. O mirante no começo mostra que a ponte da ida vai sumir. |
| **09 — O Passeio Completo** | tudo junto | Uma fase mais longa, combinando placa, ponte de graveto, pinguela e perspectiva. |

Cada fase nova ganha rota de teste e Zonas de dica onde for preciso.

---

## 6. Reformulações e melhorias no que existe

| Onde | O quê | Por quê |
|---|---|---|
| `jogo.gd` | objetivos em classes próprias; vários gravetos; HUD em cena/script próprio (`hud.gd`) com área segura | o arquivo passa de 400 linhas e junta coisas demais |
| `graveto.gd` | estados (chão, boca, ponte); `lendario`; pega só por F quando é ponte | lendário e ponte |
| `dachshund.gd` | ação F genérica (hoje só puxar); peso do cachorro (raça + graveto) | botão de ação e placa |
| `Raca` | campo `peso` (e, junto, a cápsula de colisão derivada das medidas: altura e raio) | placa; corrige o border collie alto passando em lugar baixo |
| `Fase` | registro de canais; `passagem_estreita_em` consulta objetos; `mostrar_visual`; requisitos vindos do objetivo | canais, ponte, mirante |
| `camera_controller.gd` | alvo opcional (mirante); sensibilidade e inverter Y das Opções | mirante, opções |
| `visual.gd` | intensidade do pixelado e contorno vindos das Opções | opções |
| `project.godot` | ação `puxar` → `acao`; janela padrão; pasta do usuário; barramentos de áudio | opções, exportação |
| HUD, dicas, Zona de dica | textos com a tecla atual (`Teclas.nome`) | teclas remapeáveis |
| Menu e pausa | botão Opções; área segura | opções, ultrawide |
| `ROADMAP.md` | atualizar a Etapa 9: o modelo já tem pivôs | está desatualizado |
| Testes | intérprete + rotas no repositório; script; CI | regressão automática |

---

## 7. Assets externos

| Item | Precisa? | Decisão |
|---|---|---|
| Templates de exportação do Godot 4.7.1 | **sim, para exportar** | baixados pelo editor ou pela CI; não entram no repositório |
| Fonte pixel (ex.: *Pixelify Sans*, *Silkscreen* — licença OFL) | não | combinaria com o visual; posso incluir (arquivo `.ttf` pequeno, licença livre) se você quiser |
| Sons (latido, passos, água, portão, placa, música) | não agora | o menu de áudio fica pronto. Para os sons, dois caminhos: **gerados por código** (no espírito "nada de assets externos", bom para efeitos simples) ou **pacotes CC0** (ex.: Kenney), melhores para música. Decidir quando chegarmos ao áudio. |
| Ícone do `.exe` | não | usa o `icon.svg` do projeto; embutir no `.exe` precisa do `rcedit` (opcional) |
| Modelos, texturas, partículas | não | tudo gerado por código, como hoje |

---

## 8. Riscos e decisões em aberto

1. **Todo graveto troca a perspectiva?** O ROADMAP diz que sim. Isso deixa as fases com vários
   gravetos bem dinâmicas, mas cada comum pego no caminho mexe nas tampas. Sigo o ROADMAP; se
   ficar confuso, uma propriedade `troca_perspectiva` no graveto comum resolve.
2. **Peso por raça:** os valores da tabela (5.3) são um ponto de partida. As placas das fases do
   Parque vão ser feitas para o salsicha (peso 1).
3. **A ponte de graveto e a física:** o cachorro (cápsula) andando numa barra fina depende do
   mesmo truque da Tábua (equilíbrio com queda determinística). Se ficar escorregadio, a ponte
   ganha uma colisão um pouco mais larga que o visual.
4. **Remapear teclas e o editor:** o editor mantém as teclas fixas. Se você remapear WASD para
   outra coisa, o editor continua em WASD.
5. **Área segura em 16:9:** em telas muito largas, os menus ficam no meio com mundo dos lados.
   Se preferir 21:9, é uma constante.
6. **Jogo exportado + editor:** os amigos também terão o editor (F1). Dá para esconder no jogo
   exportado com uma opção; por padrão deixo ligado, é divertido.

---

## 9. Ordem de execução (PRs)

1. **PR A — Opções e tela:** autoload `Opcoes`, tela de opções (menu e pausa), área segura,
   janela padrão, entorno automático, HUD com teclas dinâmicas, `puxar` → `acao`.
2. **PR B — Exportação e testes:** testes das fases no repositório, `export_presets.cfg`,
   pasta do usuário, `ferramentas/exportar.sh`, workflow da CI (testes + exportação +
   Release por tag). Testado aqui exportando Windows e Linux de verdade.
3. **PR C — Pacote 1, base:** botão F, canais, placa, portão, peso por raça (com a cápsula),
   gravetos comuns e lendário, refatoração dos objetivos, editor (canais, validação); Fases 06 e
   07.
4. **PR D — Pacote 1, ferramentas:** graveto-ponte, mirante; Fases 08 e 09; README e ROADMAP.

Cada PR sai com as fases antigas passando nos testes.

## 10. Fora deste pacote

- Troncos arrastáveis, tocas, portinhola, pássaros no contrapeso, comporta: Pacote 2.
- Regiões no menu.
- Áudio de verdade.
- Jogar no navegador.
- Remapear o controle (gamepad).
- Girar a isométrica no mirante.
