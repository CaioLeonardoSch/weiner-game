# Conceito de Jogo: Salsicha em Busca do Graveto Lendário

## Premissa
Um jogo de puzzle 3D em que o jogador controla um cachorro salsicha (Dachshund) que percorre cenários diferentes em busca de gravetos lendários. Cada fase é dividida em duas partes:

1. **Ida** — o cachorro precisa chegar até o graveto, explorando o cenário.
2. **Volta** — o cachorro precisa retornar até o dono carregando o graveto na boca, agora enfrentando o cenário com uma restrição física adicional.

A dificuldade aumenta progressivamente a cada fase.

## Mecânica central
- Movimento livre em 3D (não é baseado em grid).
- O graveto tem **colisão própria** — não é só o corpo do cachorro que precisa caber pelos espaços, o graveto (que se estende para fora da boca) também precisa.
- Diferentes **tamanhos e formatos de gravetos** mudam a lógica do puzzle:
  - Gravetos compridos dificultam curvas fechadas e corredores estreitos.
  - Gravetos em formato T ou Y podem exigir um ângulo específico de transporte, ou giros antes de passar por certos obstáculos.
  - O peso do graveto pode afetar velocidade e capacidade de pulo na volta.
- **Assimetria entre ida e volta**: o caminho livre da ida pode não ser viável na volta por causa da colisão do graveto — esse é o núcleo do desafio de puzzle.

## Obstáculos de cenário (fase inicial de brainstorm)
- Água
- Buracos
- Troncos caídos
- (lista em aberto, a expandir por bioma/fase)

## Personalização
- Cor da pelagem
- Tipo de pelagem
- Roupinhas
- Cosméticos não interferem na lógica do puzzle — mantém a jogabilidade limpa e previsível.

## Perguntas em aberto
- Progressão de dificuldade: por tamanho/formato de graveto, por complexidade de cenário, ou ambos?
- Cada bioma terá seu próprio conjunto de obstáculos ou eles se combinam progressivamente?
- Existe um limite de tentativas/tempo por fase, ou é puzzle livre (sem pressão)?
- Câmera: livre, fixa isométrica, ou acompanhando por trás do cachorro?

## Próximos passos (quando fizer sentido)
- Esboçar a primeira fase completa (ida + volta) para validar se a mecânica de colisão do graveto funciona no papel.
- Definir o motor/engine (provavelmente Godot 4, como os demais projetos).

## Notas de design (revisão inicial)

Pontos levantados na primeira discussão do conceito, antes de qualquer prototipagem:

- **Julgar clearance em 3D livre é difícil.** De trás do cachorro, a ponta do graveto some
  da visão numa curva fechada — sem leitura clara, vira frustração, não puzzle. Câmera
  acompanhando por trás com distância dinâmica (afasta conforme o graveto cresce) tende a
  funcionar melhor que isométrica fixa.
- **Gravetos em T/Y "exigir ângulo específico" não emerge sozinho de movimento livre.**
  Precisa de mecânica explícita pra girar/orientar o graveto (ex.: segurar botão pra inclinar
  a cabeça), senão vira sorte de colisão física em vez de decisão do jogador.
- **Sem timer.** Puzzle livre, sem pressão, favorece o "pensar antes de tentar" que é o ponto
  forte do conceito — timer entra em conflito direto com isso.
- **Progressão**: acoplar tamanho/formato do graveto **junto** com a complexidade do cenário
  por fase, em vez de eixos independentes — ensina uma peça de gramática nova por vez, depois
  combina. Biomas com obstáculo próprio, acumulando fase a fase, é o padrão que costuma
  funcionar (tipo Mario/Portal).
