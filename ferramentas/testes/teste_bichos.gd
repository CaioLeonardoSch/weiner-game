extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/bichos.txt: montam cenas pequenas dentro de uma
## fase (dono dormindo, cão vizinho, esquilo) e guardam referências em metadados do jogo.


static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0) -> ObjetoFase:
	return jogo.fase.adicionar_objeto(load("res://scenes/objetos/%s.tscn" % nome), posicao, yaw)


## Dono dormindo; um cão vizinho a 4 m do dono (fora do alcance do cachorro) e um passarinho
## perto do vizinho.
static func preparar_vizinho(jogo: Node) -> String:
	var dono: Dono = jogo.fase.primeiro(Dono)
	dono.dormindo = true
	var vizinho := _colocar(jogo, "cao_vizinho", dono.global_position + Vector3(4.0, 0, 0))
	# Longe do cachorro (> 5 m), perto do vizinho (< 5 m): só o latido dele alcança.
	var passaro := _colocar(jogo, "passaro", vizinho.global_position + Vector3(3.5, 0, -1.5))
	jogo.set_meta(&"dono", dono)
	jogo.set_meta(&"vizinho", vizinho)
	jogo.set_meta(&"passaro", passaro)
	return "dono %s, vizinho %s" % [dono.global_position, vizinho.global_position]


## Late de onde o cachorro está (sem precisar da habilidade na fase).
static func latir_aqui(jogo: Node) -> String:
	jogo.fase.espalhar_latido(jogo.cachorro.global_position, jogo.cachorro)
	return "latiu em %s" % jogo.cachorro.global_position


## Esquilo com a toca a 3 m de um graveto comum largado.
static func preparar_esquilo(jogo: Node) -> String:
	var graveto := _colocar(jogo, "graveto_comum", Vector3(4.5, 0.08, -1.5)) as Graveto
	var esquilo := _colocar(jogo, "esquilo", Vector3(4.5, 0, -4.5)) as Esquilo
	jogo.set_meta(&"esquilo", esquilo)
	jogo.set_meta(&"graveto", graveto)
	return "esquilo %s, graveto %s" % [esquilo.global_position, graveto.global_position]



## Um graveto comum direto na boca (sem a troca de câmera).
static func graveto_na_boca(jogo: Node) -> String:
	var graveto := _colocar(jogo, "graveto_comum", jogo.cachorro.global_position) as Graveto
	graveto.ja_pego = true
	jogo.cachorro.pegar_graveto(graveto)
	return "graveto na boca"
