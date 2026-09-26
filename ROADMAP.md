# Próximas etapas

O que já existe: visual pixelado, trilha mais linear na Fase 01 com floresta em volta, pipeline
de assets (tiles gerados por código, modelos voxel em texto e procedurais, objetos que aparecem
sozinhos no editor), o editor de fases dentro do jogo (F1), o graveto com colisão, peso e
equilíbrio (etapa 3), habilidades por fase com o pulo (parte da etapa 4), cavar (5),
empurrar (6), latir e passarinhos (8), e as Fases 02 e 03.

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

## Etapa 4 — Movimento: pular, subir e descer níveis (em parte ✅)

- ✅ **Habilidades por fase**: `Fase.habilidades` (flags, no painel da fase no editor).
- ✅ **Pular** (Espaço): 0,65 m sem graveto — sobe meio bloco, não um bloco inteiro; o peso
  do graveto reduz a altura.
- **Nivelamentos**: faltam tiles de canto de rampa e escada — acrescentar em
  `Tiles.definicoes()` (sempre com ID novo no fim) e gerar a biblioteca de novo.
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
ficar rente ao chão e vira passagem. Ideias para depois:

- Tronco empurrável que rola e vira ponte sobre dois blocos de água.
- Empurrar com o graveto ao comprido (alcance maior) ou só sem graveto.
- Blocos que tampam túneis (abrir caminho empurrando) e placas de pressão.
- Puxar (para desfazer um empurrão errado sem reiniciar a fase).

## Etapa 7 — Riachos e água

- Já existe o tile `Água` (visual pixelado, sem colisão): cair nela devolve o cachorro ao último
  ponto seguro ("Splash!"). Próximos passos:
  - **Água rasa** (tile novo com leito a meio bloco): atravessável, mais lenta; graveto molhado
    pesa mais?
  - **Correnteza**: empurra o cachorro numa direção (variável por célula ou objeto "Corrente").
  - **Travessia**: tábua com equilíbrio (já existe), ponte larga (objeto *Ponte de madeira*,
    já existe), tronco empurrado, pedras de apoio (meio bloco + pulo).

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
