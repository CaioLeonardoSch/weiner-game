class_name Trecho
extends RefCounted
## Um pedaço de fase — os blocos do terreno e os objetos de um retângulo de colunas — para copiar,
## colar, girar e guardar como módulo (ver Modulos). É o que o editor usa no Ctrl+C / Ctrl+V e na
## paleta de módulos, e o que um gerador de mapas pode usar para montar fases com peças prontas:
##
##     var peca := Modulos.carregar("res://scenes/modulos/ponte_de_troncos.tscn")
##     peca.girado(1).aplicar_em(fase, Vector3i(10, 0, -4))
##
## Coordenadas: X e Z contam a partir do canto do retângulo (coluna 0 a largura-1, 0 a
## profundidade-1); Y é a camada de verdade (o chão fica na -1). Os objetos guardam a cena, o
## transform (posição relativa ao mesmo canto), a visibilidade e as propriedades do painel.
## O Início do cachorro (único na fase) fica de fora.

## Colunas em X e em Z.
var largura := 1
var profundidade := 1
## [Vector3i posição, int item, Basis orientação]
var celulas: Array = []
## {cena: String, transform: Transform3D, visibilidade: int, propriedades: Dictionary}
var objetos: Array[Dictionary] = []


## As colunas de `minimo` a `maximo` (inclusive, em X e Z) da fase.
static func da_fase(fase: Fase, minimo: Vector2i, maximo: Vector2i) -> Trecho:
	var trecho := Trecho.new()
	trecho.largura = maximo.x - minimo.x + 1
	trecho.profundidade = maximo.y - minimo.y + 1
	var terreno := fase.get_node(^"Terreno") as GridMap
	for celula in terreno.get_used_cells():
		if celula.x < minimo.x or celula.x > maximo.x or celula.z < minimo.y or celula.z > maximo.y:
			continue
		trecho.celulas.append([Vector3i(celula.x - minimo.x, celula.y, celula.z - minimo.y),
			terreno.get_cell_item(celula), terreno.get_cell_item_basis(celula)])
	var canto := Vector3(minimo.x, 0.0, minimo.y)
	for objeto in fase.get_node(^"Objetos").get_children():
		if not objeto is ObjetoFase or (objeto as ObjetoFase).unico_na_fase():
			continue
		var p := (objeto as ObjetoFase).position
		if p.x >= minimo.x and p.x < maximo.x + 1 and p.z >= minimo.y and p.z < maximo.y + 1:
			trecho.objetos.append(_dados_do_objeto(objeto, canto))
	return trecho


## A fase inteira (um módulo salvo é uma fase pequena): o retângulo de tudo o que ela tem.
static func da_fase_inteira(fase: Fase) -> Trecho:
	var terreno := fase.get_node(^"Terreno") as GridMap
	var minimo := Vector2i(1 << 30, 1 << 30)
	var maximo := -minimo
	for celula in terreno.get_used_cells():
		minimo = minimo.min(Vector2i(celula.x, celula.z))
		maximo = maximo.max(Vector2i(celula.x, celula.z))
	for objeto in fase.get_node(^"Objetos").get_children():
		if objeto is ObjetoFase:
			var coluna := Vector2i(floori((objeto as Node3D).position.x), floori((objeto as Node3D).position.z))
			minimo = minimo.min(coluna)
			maximo = maximo.max(coluna)
	if minimo.x > maximo.x:
		return Trecho.new()
	return da_fase(fase, minimo, maximo)


## Um objeto só (Ctrl+C com um objeto selecionado): a coluna dele.
static func do_objeto(objeto: ObjetoFase) -> Trecho:
	var trecho := Trecho.new()
	var canto := Vector3(floorf(objeto.position.x), 0.0, floorf(objeto.position.z))
	trecho.objetos.append(_dados_do_objeto(objeto, canto))
	return trecho


static func _dados_do_objeto(objeto: ObjetoFase, canto: Vector3) -> Dictionary:
	var propriedades := {}
	for nome in objeto.propriedades_editaveis():
		propriedades[nome] = objeto.get(nome)
	var transformacao := objeto.transform
	transformacao.origin -= canto
	return {cena = objeto.scene_file_path, transform = transformacao,
		visibilidade = objeto.visibilidade, propriedades = propriedades}


func vazio() -> bool:
	return celulas.is_empty() and objetos.is_empty()


## Camadas ocupadas (menor e maior Y); sem blocos, só a camada do chão para cima.
func camadas() -> Vector2i:
	if celulas.is_empty():
		return Vector2i(0, 0)
	var menor: int = celulas[0][0].y
	var maior: int = menor
	for dados in celulas:
		menor = mini(menor, dados[0].y)
		maior = maxi(maior, dados[0].y)
	return Vector2i(menor, maior)


## Uma cópia girada `quartos` × 90° (sentido anti-horário, visto de cima — o mesmo do Q no
## editor), em volta do centro do retângulo. Blocos giram de orientação; objetos, de giro.
func girado(quartos: int) -> Trecho:
	quartos = posmod(quartos, 4)
	var novo := Trecho.new()
	var impar := quartos % 2 == 1
	novo.largura = profundidade if impar else largura
	novo.profundidade = largura if impar else profundidade
	var giro := Basis(Vector3.UP, quartos * PI * 0.5)
	var centro := Vector3(largura * 0.5, 0.0, profundidade * 0.5)
	var centro_novo := Vector3(novo.largura * 0.5, 0.0, novo.profundidade * 0.5)
	for dados in celulas:
		var posicao: Vector3i = dados[0]
		var meio := Vector3(posicao.x + 0.5, 0.0, posicao.z + 0.5)
		var girado_ := centro_novo + giro * (meio - centro)
		novo.celulas.append([Vector3i(floori(girado_.x), posicao.y, floori(girado_.z)), dados[1],
			giro * (dados[2] as Basis)])
	for dados in objetos:
		var copia := dados.duplicate()
		var transformacao: Transform3D = dados.transform
		var origem := transformacao.origin
		var plano := centro_novo + giro * (Vector3(origem.x, 0.0, origem.z) - centro)
		copia.transform = Transform3D(giro * transformacao.basis, Vector3(plano.x, origem.y, plano.z))
		novo.objetos.append(copia)
	return novo


## Coloca o trecho na fase com o canto em `origem` (X, Z: coluna do canto; Y: camadas a somar).
## Blocos do trecho substituem os que estiverem lá; os vazios não apagam nada. Devolve o que
## mudou, para desfazer: {antes: [[celula, item, orientação]], depois: [...], objetos: [...]}.
func aplicar_em(fase: Fase, origem: Vector3i) -> Dictionary:
	var terreno := fase.get_node(^"Terreno") as GridMap
	var antes := []
	var depois := []
	for dados in celulas:
		var celula: Vector3i = dados[0] + origem
		var orientacao := terreno.get_orthogonal_index_from_basis(dados[2])
		antes.append([celula, terreno.get_cell_item(celula), terreno.get_cell_item_orientation(celula)])
		depois.append([celula, dados[1], orientacao])
		terreno.set_cell_item(celula, dados[1], orientacao)
	var criados: Array[ObjetoFase] = []
	var deslocamento := Vector3(origem)
	for dados in objetos:
		var cena := load(dados.cena) as PackedScene
		if cena == null:
			continue
		var objeto := fase.adicionar_objeto(cena, Vector3.ZERO)
		objeto.transform = (dados.transform as Transform3D).translated(deslocamento)
		objeto.visibilidade = dados.visibilidade
		for nome in dados.propriedades:
			objeto.set(nome, dados.propriedades[nome])
		criados.append(objeto)
	return {antes = antes, depois = depois, objetos = criados}


## Um nó 3D só para ver o trecho, com o canto na origem: os blocos numa GridMap sem colisão e os
## objetos parados. É a prévia da colagem no editor e a miniatura dos módulos na paleta.
func montar_previa(biblioteca: MeshLibrary) -> Node3D:
	var previa := Node3D.new()
	var grade := GridMap.new()
	grade.name = "Terreno"
	grade.mesh_library = biblioteca
	grade.cell_size = Vector3.ONE
	grade.collision_layer = 0
	grade.collision_mask = 0
	previa.add_child(grade)
	for dados in celulas:
		grade.set_cell_item(dados[0], dados[1], grade.get_orthogonal_index_from_basis(dados[2]))
	for dados in objetos:
		var cena := load(dados.cena) as PackedScene
		if cena == null:
			continue
		var objeto := cena.instantiate() as ObjetoFase
		objeto.process_mode = Node.PROCESS_MODE_DISABLED
		previa.add_child(objeto)
		objeto.transform = dados.transform
		for nome in dados.propriedades:
			objeto.set(nome, dados.propriedades[nome])
	return previa


## O trecho como uma fase pequena (para salvar como módulo), com o canto na origem.
func para_fase(nome: String, bioma := Biomas.FLORESTA) -> Fase:
	var fase := Fase.nova(nome)
	fase.bioma = bioma
	aplicar_em(fase, Vector3i.ZERO)
	return fase
