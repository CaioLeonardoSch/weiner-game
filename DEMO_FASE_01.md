# Weiner Game — Demo Fase 01: "O Primeiro Graveto"

Instruções para implementar uma **demo experimental** da primeira fase no Godot.
Repositório: `CaioLeonardoSch/weiner-game`.

> **Revisão (2026-09-25) — visão isométrica no lugar da lateral.** Onde este documento fala em
> "modo 2D", "câmera lateral" e "trilho (`Path3D`)", vale o seguinte:
>
> - **Ida = modo isométrico:** câmera ortográfica fixa vista de frente e de cima (giro 0°,
>   inclinação −55°, câmera em +Z olhando −Z), movimento **livre em 8 direções** relativo à
>   tela. Não existe mais trilho.
> - **Segredo do túnel = oclusão + bloqueio:** desse ângulo as faces ±X ficam de perfil (bocas
>   do túnel e parede do barranco não aparecem), e as duas bocas ficam **tampadas por
>   folhagem** (nós do grupo `so_iso`, dentro do `CSGCombiner3D` do mato) com colisão. Ao pegar o
>   graveto as tampas somem — a nova perspectiva literalmente abre o caminho.
> - **Largar o graveto** (ação `largar_graveto`: E / botão B) volta para a isométrica e fecha o
>   túnel de novo; encostar no graveto pega de novo e volta para o 3D. Não dá para largar dentro
>   ou na boca do túnel (`ZonaSemLargar`), senão o cachorro ficaria preso entre as tampas.
> - **Transição:** ortográfica → perspectiva com FOV equivalente, depois órbita em volta do
>   cachorro (yaw, pitch, distância e FOV interpolados) até a terceira pessoa.
> - As invariantes da seção 4.2 sobre o 2D (raia z = 0, trilho) deixam de se aplicar; as do 3D
>   (barranco de mão única, mato só atravessável pelo túnel, borda frontal) continuam valendo.
>
> **Revisão (2026-09-26) — visual pixelado, fase em grade e editor.** A fase deixou de ser CSG
> montado à mão dentro de `fase_01.tscn`:
>
> - O jogo é `scenes/jogo.tscn` (regras em `scripts/jogo.gd`) e a fase é só conteúdo, em
>   `scenes/fases/fase_01.tscn`: terreno em grade (GridMap, blocos de 1 m) + objetos de
>   `scenes/objetos/`. Edite pelo editor de fases do jogo (F1) — ver README.
> - Layout mais linear: trilha de 3 m de largura cercada de mato, rampa (x 1–5) → barranco
>   (topo em y = 2, x 5–11) → queda → clareira do graveto (x 11–19); o mato com o túnel fica em
>   x 5–8, z −3…0. Floresta densa em volta; as árvores na frente da trilha são "só 3D".
> - Os grupos `so_iso`/`so_3d` viraram a propriedade **Visibilidade** de cada objeto (Sempre /
>   Só isométrico / Só 3D); as tampas do túnel são objetos *Tampa de folhagem* (só isométrico).
>   `ZonaSemLargar` e as bordas invisíveis viraram objetos (*Zona sem largar*, *Parede invisível*).
> - A câmera 3D, ao pegar o graveto, olha do cachorro para o dono (+ "Giro da câmera 3D" da fase).
> - A tabela 4.1 (formas CSG) e as coordenadas da seção 4 descrevem a versão antiga.

---

## 1. Objetivo da demo

Validar a mecânica central do jogo:

> **Toda vez que o cachorro pega o graveto na boca, a perspectiva muda de 2D (plataforma, visão lateral) para 3D (terceira pessoa).** A nova perspectiva revela coisas que antes não eram visíveis e abre (ou fecha) caminhos para voltar ao dono.

Nesta fase:

- **Ida (2D):** o cachorro anda um pouco reto, encontra um **mato** que bloqueia o caminho e precisa **dar a volta** por um caminho alternativo até o graveto.
- **Pegou o graveto → vira 3D.**
- **Volta (3D):** o jogador percebe que o caminho da ida era um **barranco** (uma descida de mão única, impossível de subir de volta) e que o **mato tem um buraco/túnel** por onde dá para passar com o graveto na boca, voltando direto ao dono.

## 2. Regras gerais (importante)

- **Nada de assets externos.** Sem modelos, texturas, sons ou fontes baixadas. Tudo com o que o Godot oferece de fábrica:
  - Geometria: nós **CSG** (`CSGBox3D`, `CSGCylinder3D`, `CSGSphere3D`, `CSGCombiner3D`) com `use_collision = true`.
  - Cores: `StandardMaterial3D` com `albedo_color` simples.
  - Ambiente: `WorldEnvironment` + `DirectionalLight3D` padrão.
  - UI: `Label` com a fonte padrão.
- **Godot 4.7**, **GDScript**. Usar o `project.godot` que já existe no repositório (Forward+, física Jolt) — não trocar renderizador nem motor de física nesta demo.
- É um protótipo: priorizar código simples e legível, sem arquitetura elaborada.
- Toda entrada deve passar por **ações do InputMap** (nunca teclas fixas no código), para facilitar adicionar controles de toque depois.
- Comentários e nomes de nós podem ser em português.

## 3. Ideia técnica central: o jogo é 3D o tempo todo

O "2D" é uma **ilusão de câmera**. O nível inteiro é construído em 3D desde o início:

- **Modo 2D:** câmera lateral, quase ortográfica, e o movimento do cachorro fica **preso a um trilho** (`Path3D`), no estilo *Klonoa* / 2.5D. O jogador só aperta esquerda/direita; o trilho pode curvar em profundidade (eixo Z) sem que o jogador perceba, porque a câmera está de lado.
- **Modo 3D:** a câmera vai para trás do cachorro (terceira pessoa) e o movimento fica **livre** no plano XZ.

Assim, o caminho de "dar a volta no mato" na ida é, na verdade, um trilho que sobe por uma encosta atrás do mato e termina num **degrau/queda**. De lado isso parece só "subir um morrinho e descer"; em 3D fica claro que é um barranco alto.

### Convenção de eixos

- **+X** = "para a direita" na tela do modo 2D (direção do graveto).
- **+Y** = para cima.
- **+Z** = na direção da câmera 2D (a câmera 2D fica em Z positivo olhando para −Z).
- Raia principal do modo 2D: **z = 0**.

## 4. Layout da fase

Coordenadas aproximadas em metros. Podem ser ajustadas, **desde que as invariantes da seção 4.2 continuem valendo.**

```
Vista de cima (X →, Z ↓ = em direção à câmera 2D)

 z=-8  ████████████████████████████████████████  (borda: árvores / parede)
       █                                      █
       █        [ENCOSTA / BARRANCO  y=2]     █
 z=-3.5█   rampa ↗══════════════════╗ queda   █
       █                            ║   ↓     █
       █               ┌──MATO──┐   ║         █
 z=-1.7█  DONO         │ túnel ═══════════→   █   (túnel só acessível em 3D)
 z=0   █  🐕 ─── raia 2D ─►│ (sólido)│        🦴 GRAVETO
 z=1.5 █               └────────┘             █
       ████████████████████████████████████████  (borda frontal: só visível em 3D)
       x=-2    x=3      x=6     x=9  x=10     x=14
```

### 4.1 Elementos

| Elemento | Forma sugerida | Posição / tamanho aproximado | Cor |
|---|---|---|---|
| Chão | `CSGBox3D` | x −3…15, z −8…2, topo em y = 0 | verde-escuro |
| Dono | `CSGCylinder3D` (corpo) + `CSGSphere3D` (cabeça) | x = −1, z = 0 | azul |
| Cachorro | `CharacterBody3D` com corpo em `CSGBox3D` alongado (≈0,9 × 0,35 × 0,3), cabeça em box menor, 4 patinhas em cilindros finos. Colisão: `CapsuleShape3D` deitada ou `BoxShape3D` | começa em x = 0,5, z = 0 | marrom |
| Marker "Boca" | `Marker3D` filho do cachorro, na frente da cabeça | — | — |
| Mato | `CSGCombiner3D` contendo um `CSGBox3D` (arbusto) **menos** um `CSGBox3D` em modo `OPERATION_SUBTRACTION` (o túnel) | arbusto: x 6…9, z −3,5…1,5, altura 1,5. Túnel: atravessa todo o eixo X, centrado em z ≈ −1,7, largura ≈ 0,9, altura ≈ 0,7 | verde-claro |
| Encosta / barranco | `CSGBox3D` (bloco) + rampa (`CSGBox3D` inclinado ou `CSGPolygon3D`) | bloco: x 3…10, z −8…−3,5, topo em y = 2. Rampa subindo de y = 0 para y = 2 entre x ≈ 1,5 e 3,5 | marrom-terra |
| Graveto | `Area3D` + `CSGCylinder3D` fino e deitado (≈0,06 de raio, 0,8 de comprimento) | x = 12, z = 0, y = 0,1 | marrom-claro/bege |
| Área do dono | `Area3D` com `BoxShape3D` | ao redor do dono, raio ≈ 1,5 | — |
| Árvores (floresta) | `CSGCylinder3D` (tronco) + `CSGSphere3D`/`CSGCylinder3D` cônico (copa) | fileira ao fundo (z ≈ −8) e fileira frontal (z ≈ +2) | marrom / verde |
| Bordas | `StaticBody3D` com `BoxShape3D` invisíveis | fecham o nível nos 4 lados | — |

### 4.2 Invariantes (o que PRECISA ser verdade)

1. **Modo 2D:** a raia z = 0 bate na face −X do mato em x = 6, que é **sólida** nessa altura. O cachorro não atravessa o mato no modo 2D.
2. **O túnel fica fora da raia 2D** (z ≈ −1,7) e suas aberturas estão nas faces ±X do mato, portanto **invisíveis pela câmera lateral**. Nada no modo 2D deve denunciar que o túnel existe.
3. **O trilho 2D** (`Path3D`) sai de z = 0, sobe a rampa, percorre o topo da encosta (z ≈ −4,5, y = 2) passando "por trás" do mato, e termina **na borda da encosta em x = 10**, onde o cachorro **cai** 2 m até o chão. Depois o trilho volta para z = 0 e chega ao graveto em x = 12. Pela câmera lateral isso deve parecer "subir um morrinho, passar por cima do mato e pular para baixo".
4. **A queda é de mão única.** A face da encosta em x = 10 tem 2 m de altura; o cachorro **não tem pulo** nesta demo (ou, se tiver, altura máxima < 1 m). Em 3D, não pode existir nenhum outro acesso à rampa pelo lado do graveto: a encosta encosta no mato (z = −3,5) e se estende até a borda de trás do nível (z = −8).
5. **Em 3D, o único caminho de volta é o túnel.** A fileira frontal de árvores/parede invisível em z ≈ +1,6 impede contornar o mato pela frente.
6. **O túnel comporta o cachorro com o graveto na boca** (se o graveto tiver colisão, ver seção 9).

## 5. Os dois modos

### 5.1 Modo 2D (ida)

**Câmera:**
- `Camera3D` em perspectiva com **FOV pequeno (≈ 12°)** e bem afastada (z ≈ +30), olhando para −Z. Isso imita uma câmera ortográfica e **permite animar suavemente para o modo 3D** (trocar `projection` de ortográfica para perspectiva não é animável; mudar FOV e posição é).
- Segue o cachorro só em X (e suavemente em Y), com leve suavização (`lerp`).

**Movimento (preso ao trilho):**
- Ações: `mover_esquerda` / `mover_direita` (A/D, setas, analógico esquerdo).
- A cada `_physics_process`:
  1. Pegar o offset mais próximo no trilho: `curve.get_closest_offset(posição_local)`.
  2. Calcular a tangente amostrando o trilho em `offset` e `offset + 0.1`; usar só o componente XZ normalizado.
  3. `velocity.xz = tangente_xz * input * VELOCIDADE`.
  4. Somar uma pequena **força de correção** puxando o cachorro de volta para o ponto do trilho (no plano XZ), para ele não "escorregar" para fora.
  5. Y é controlado pela gravidade normal + `move_and_slide()`. Assim a rampa e a queda funcionam naturalmente pela física.
- O modelo do cachorro gira para olhar na direção em que anda.

**Visibilidade:**
- Tudo que está no grupo **`so_3d`** fica invisível (`visible = false`) no modo 2D. Colocar nesse grupo a **fileira frontal de árvores** (senão ela tamparia a visão lateral) e qualquer detalhe que só deve aparecer em 3D.

### 5.2 Transição (ao pegar o graveto)

Disparada quando o cachorro entra na `Area3D` do graveto:

1. Congelar o input (≈ 1,2 s).
2. *Reparent* do graveto para o `Marker3D` "Boca" do cachorro (graveto de lado, atravessado na boca).
3. **Tween** da câmera, em paralelo:
   - `fov` de 12 → 70;
   - posição/rotação da posição lateral → posição de terceira pessoa atrás do cachorro, **olhando de volta para o dono (−X)**, para que a primeira coisa que o jogador veja seja o mato com o túnel e o barranco.
   - Usar `Tween.TRANS_SINE` / `EASE_IN_OUT`.
4. Fazer os nós do grupo `so_3d` aparecerem (pode ser só ligar `visible` no meio do tween).
5. Trocar o modo do cachorro para `LIVRE` e ativar o controle de câmera 3D.
6. (Opcional) Um `Label` rápido na tela: "Nova perspectiva!".

### 5.3 Modo 3D (volta)

**Câmera:** rig de terceira pessoa padrão:
```
CameraRig (Node3D, segue a posição do cachorro)
 └─ SpringArm3D (spring_length ≈ 4, colisão ligada, exclui o cachorro)
     └─ Camera3D
```
- Orbitar com mouse (capturado) ou analógico direito (`camera_esquerda/direita/cima/baixo`). Limitar o pitch.
- O SpringArm evita que a câmera atravesse a encosta e o mato.

**Movimento:** livre no plano XZ, **relativo à direção da câmera** (WASD / analógico esquerdo). Mesma velocidade e gravidade do modo 2D. Cachorro gira suavemente para a direção do movimento.

## 6. Fluxo e condição de vitória

1. Início: modo 2D, cachorro ao lado do dono.
2. Anda para a direita → mato bloqueia → trilho sobe a encosta → cai → graveto.
3. Pega o graveto → transição → modo 3D.
4. Volta pelo túnel do mato até o dono.
5. Entrou na `Area3D` do dono **com o graveto** → `Label` grande: **"Fase concluída! 🦴"** e "Pressione R para jogar de novo".
6. `reiniciar` (R / botão Start) recarrega a cena a qualquer momento.
7. Segurança: se `y < -10`, reposicionar o cachorro no último ponto seguro.

## 7. Input Map

| Ação | Teclado/Mouse | Controle |
|---|---|---|
| `mover_esquerda` | A, ← | analógico esq. |
| `mover_direita` | D, → | analógico esq. |
| `mover_frente` | W, ↑ | analógico esq. |
| `mover_tras` | S, ↓ | analógico esq. |
| `camera_*` | movimento do mouse | analógico dir. |
| `reiniciar` | R | Start |
| `liberar_mouse` | Esc | — |

No modo 2D só `mover_esquerda`/`mover_direita` têm efeito.

## 8. Estrutura sugerida

```
weiner-game/
├─ project.godot                 # cena principal = scenes/fase_01.tscn
├─ scenes/
│  ├─ fase_01.tscn               # nível (CSG) + Path3D do trilho + áreas
│  ├─ dachshund.tscn             # CharacterBody3D do cachorro
│  └─ graveto.tscn
└─ scripts/
   ├─ fase_01.gd                 # fluxo da fase, vitória, reinício, grupo so_3d
   ├─ dachshund.gd               # enum Modo { TRILHO, LIVRE }, movimento, pegar graveto
   ├─ camera_controller.gd       # câmera lateral, tween de transição, rig 3ª pessoa
   └─ graveto.gd                 # sinal "pego"
```

Preferir montar o nível **como nós na cena `.tscn`** (e não gerado por código), para que o Caio consiga abrir no editor e ajustar posições à mão.

Sinais sugeridos: `graveto.pego(cachorro)` → `fase_01` chama `camera_controller.transicionar_para_3d()` e `cachorro.set_modo(LIVRE)`.

## 9. Fora do escopo (não fazer agora)

- Assets de arte, som, música, animações de esqueleto.
- Controles de toque (só deixar tudo via InputMap).
- Menus, save, customização do cachorro, várias fases.
- **Colisão física do graveto** — nesta demo o graveto é só visual na boca. Deixar um `TODO` indicando que, no futuro, o graveto terá colisão própria e o túnel precisa ser largo o bastante para ele (isso vai virar mecânica de puzzle de espaço/ângulo).

## 10. Critérios de aceite (testar antes de dar como pronto)

- [ ] O projeto abre e roda no Godot 4.7 sem erros nem warnings no console.
- [ ] No modo 2D, a câmera é lateral e o cachorro só anda para esquerda/direita.
- [ ] No modo 2D, **é impossível atravessar o mato** e **o túnel não aparece** na tela.
- [ ] O trilho leva o cachorro pela encosta, ele cai do barranco e chega ao graveto sem travar.
- [ ] Ao pegar o graveto, a câmera faz uma transição suave para a 3ª pessoa, e o graveto aparece na boca.
- [ ] No modo 3D, a primeira visão mostra o mato com o buraco e o barranco.
- [ ] No modo 3D, **não dá para subir o barranco de volta** nem contornar o mato pela frente.
- [ ] Dá para atravessar o túnel com o graveto e chegar ao dono.
- [ ] Chegar ao dono com o graveto mostra "Fase concluída!"; R reinicia.
- [ ] Todas as entradas funcionam via InputMap.

Ao final, liste para o Caio: o que foi feito, os valores que ele pode ajustar facilmente (velocidade, FOV, duração do tween, tamanho do túnel, altura do barranco) e onde ficam.
