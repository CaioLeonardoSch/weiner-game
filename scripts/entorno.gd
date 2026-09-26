class_name Entorno
extends Node3D
## Chão e floresta gerados em volta da fase, na hora de jogar (não são salvos na fase).
##
## Em monitores largos a câmera isométrica mostra muito mundo dos lados; sem isto, apareceria
## o fim do chão. O entorno é uma moldura de grama em volta da área usada pelo terreno e árvores
## voxel em MultiMesh (milhares de árvores custam pouco): perto da fase, densas e com sombra;
## mais longe, esparsas e sem sombra. Não tem colisão — cercas e paredes invisíveis da fase já
## seguram o cachorro.

## Largura (m) da moldura em volta da fase.
const MARGEM := 36.0
## Faixa perto da fase: árvores mais juntas e com sombra.
const FAIXA_PERTO := 12.0
const ESPACO_PERTO := 2.1
const ESPACO_LONGE := 3.4
const MATERIAL_CHAO := preload("res://assets/materiais/grama.tres")


## Monta o entorno em volta do terreno da fase (retângulo das células usadas).
func montar(fase: Fase) -> void:
	for filho in get_children():
		filho.queue_free()
	var terreno := fase.terreno if fase.is_node_ready() else fase.get_node("Terreno") as GridMap
	var celulas := terreno.get_used_cells()
	if celulas.is_empty():
		return
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for celula in celulas:
		var mundo := terreno.to_global(terreno.map_to_local(celula))
		minimo = minimo.min(Vector2(mundo.x, mundo.z))
		maximo = maximo.max(Vector2(mundo.x, mundo.z))
	var celula_tamanho := terreno.cell_size
	var dentro := Rect2(minimo - Vector2(celula_tamanho.x, celula_tamanho.z) * 0.5,
		maximo - minimo + Vector2(celula_tamanho.x, celula_tamanho.z))
	var fora := dentro.grow(MARGEM)
	_chao(dentro, fora)
	_arvores(dentro, fora, hash(fase.nome))


## Quatro retângulos de grama em volta (sem cobrir a fase: por baixo dela há água e buracos).
func _chao(dentro: Rect2, fora: Rect2) -> void:
	var pedacos := [
		Rect2(fora.position.x, fora.position.y, fora.size.x, dentro.position.y - fora.position.y),
		Rect2(fora.position.x, dentro.end.y, fora.size.x, fora.end.y - dentro.end.y),
		Rect2(fora.position.x, dentro.position.y, dentro.position.x - fora.position.x, dentro.size.y),
		Rect2(dentro.end.x, dentro.position.y, fora.end.x - dentro.end.x, dentro.size.y),
	]
	for pedaco: Rect2 in pedacos:
		var plano := PlaneMesh.new()
		plano.size = pedaco.size
		var chao := MeshInstance3D.new()
		chao.mesh = plano
		chao.material_override = MATERIAL_CHAO
		chao.position = Vector3(pedaco.get_center().x, 0.0, pedaco.get_center().y)
		chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chao)


func _arvores(dentro: Rect2, fora: Rect2, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	# (tipo, variante, com sombra) → transforms
	var grupos := {}
	for passo_e_faixa in [[ESPACO_PERTO, true], [ESPACO_LONGE, false]]:
		var passo: float = passo_e_faixa[0]
		var perto: bool = passo_e_faixa[1]
		var x := fora.position.x
		while x < fora.end.x:
			var z := fora.position.y
			while z < fora.end.y:
				var ponto := Vector2(x, z) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)) * passo
				z += passo
				var distancia := _distancia_fora(dentro, ponto)
				# Deixa um respiro junto da fase (ela já tem as árvores dela na borda).
				if distancia < 0.8 or (perto and distancia > FAIXA_PERTO) or (not perto and distancia <= FAIXA_PERTO):
					continue
				var sorteio := rng.randf()
				var tipo := Voxel.TipoArvore.PINHEIRO if sorteio < 0.42 else (
					Voxel.TipoArvore.REDONDA if sorteio < 0.9 else Voxel.TipoArvore.ARBUSTO)
				var chave := [tipo, rng.randi_range(0, 7), perto]
				if not grupos.has(chave):
					grupos[chave] = []
				var escala := rng.randf_range(0.85, 1.25) * (1.0 if perto else 1.15)
				var base := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5).scaled(Vector3.ONE * escala)
				(grupos[chave] as Array).append(Transform3D(base, Vector3(ponto.x, 0.0, ponto.y)))
			x += passo
	for chave: Array in grupos:
		var lista: Array = grupos[chave]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = Voxel.arvore(chave[0], chave[1])
		multi.instance_count = lista.size()
		for i in lista.size():
			multi.set_instance_transform(i, lista[i])
		var instancia := MultiMeshInstance3D.new()
		instancia.multimesh = multi
		instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if chave[2] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instancia)


## Distância de um ponto (fora do retângulo) até ele; 0 se estiver dentro.
static func _distancia_fora(retangulo: Rect2, ponto: Vector2) -> float:
	var dx := maxf(maxf(retangulo.position.x - ponto.x, 0.0), ponto.x - retangulo.end.x)
	var dz := maxf(maxf(retangulo.position.y - ponto.y, 0.0), ponto.y - retangulo.end.y)
	return Vector2(dx, dz).length()
