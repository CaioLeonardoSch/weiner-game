# Modelos voxel em texto

Cada arquivo `.txt` desta pasta descreve um modelo 3D em "pixel art": uma pilha de fatias
horizontais (camadas), de baixo para cima, desenhadas com letras. Use no jogo com o nó
`ModeloVoxel` (propriedade `arquivo`) — veja `scenes/objetos/dono.tscn`.

```
# Comentário: tudo depois de # é ignorado
voxel 0.125          # tamanho de cada voxel em metros (padrão 0.125 = 8 voxels por metro)
origem 3.5 0 1.5     # opcional: ponto (em voxels) que fica na origem do objeto;
                     # sem isso, o modelo fica de pé centralizado na origem
cor c 3a64c8         # letra → cor em hexadecimal
cor p f0c8a0

camada 0             # fatia y = 0 (vista de cima)
.cc.                 # cada linha é uma fileira em Z: a primeira é o fundo (−Z),
.cc.                 # a última é a frente (+Z, virada para a câmera isométrica);
                     # cada letra é um voxel em X (da esquerda para a direita); "." = vazio
camada 1-4           # "1-4" repete a mesma fatia nas camadas 1, 2, 3 e 4
cccc
cccc
```

Espaços dentro das linhas são ignorados (servem só para alinhar). Todas as camadas de um
modelo devem ter o mesmo número de fileiras.

Dicas:
- 8 voxels por metro é a mesma densidade dos texels do terreno: tudo fica com o mesmo "pixel".
- Faces encostadas em outro voxel não são desenhadas, e os cantos ganham sombra automática.
- As cores são multiplicadas pela iluminação; tons médios funcionam melhor que muito escuros.
- Ao exportar o jogo, inclua `*.txt` no filtro de arquivos não-recurso do preset de exportação.
