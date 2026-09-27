extends RefCounted
## Testes do editor modular (rota ferramentas/testes/rotas/editor.txt): trecho (copiar, colar,
## girar, apagar, desfazer), balde, módulos (salvar e carregar), bioma e regiões. Guarda o
## resultado em jogo.get_meta("editor_ok").

const PASTA_TESTE := "user://teste_modulos/"


static func rodar(jogo: Node) -> String:
	var falhas: PackedStringArray = []
	var checar := func(nome: String, cond: bool) -> void:
		print(("  ok  " if cond else "  FALHOU  ") + nome)
		if not cond:
			falhas.append(nome)
	var editor = (load("res://scenes/editor/editor_fase.tscn") as PackedScene).instantiate()
	jogo.add_child(editor)
	editor._carregar(editor._fase_modelo("teste"))
	_trecho(editor, checar)
	_giro(checar)
	_balde(editor, checar)
	_modulos(editor, checar)
	_bioma(editor, checar)
	_regioes(checar)
	jogo.remove_child(editor)
	editor.free()
	jogo.set_meta(&"editor_ok", falhas.is_empty())
	return "editor: %s" % ("tudo certo" if falhas.is_empty() else ", ".join(falhas))


## Marca um trecho com chão e uma árvore, copia, cola mais à frente, desfaz; apaga e desfaz.
static func _trecho(editor, checar: Callable) -> void:
	var terreno: GridMap = editor.terreno
	var fase: Fase = editor.fase
	var arvore := fase.adicionar_objeto(load("res://scenes/objetos/arvore.tscn"), Vector3(1.5, 0, 1.5))
	terreno.set_cell_item(Vector3i(0, 0, 0), Tiles.PEDRA)
	editor._escolher_trecho()
	editor.trecho_inicio = Vector2i(0, 0)
	editor.trecho_fim = Vector2i(2, 2)
	editor._marcar_trecho(true)
	checar.call("trecho marcado: camadas -1 a 0", editor.camadas_trecho == Vector2i(-1, 0))
	editor._copiar()
	var copiado: Trecho = Fases.area_transferencia
	checar.call("copiou 3×3 com 10 blocos e a árvore",
		copiado.largura == 3 and copiado.profundidade == 3 and copiado.celulas.size() == 10 and copiado.objetos.size() == 1)
	var objetos_antes: int = fase.lista_objetos().size()
	editor._comecar_colagem(copiado)
	checar.call("colar entra no modo Colar com prévia", editor.modo == EditorFase.Modo.COLAR and editor._previa != null)
	editor.origem_colagem = Vector3i(20, 0, 20)
	editor._colar_aqui()
	checar.call("colou o bloco de pedra", terreno.get_cell_item(Vector3i(20, 0, 20)) == Tiles.PEDRA)
	checar.call("colou o chão", terreno.get_cell_item(Vector3i(22, -1, 22)) == Tiles.GRAMA)
	var copias := fase.todos(Arvore).filter(func(a: ObjetoFase) -> bool: return a.position.distance_to(Vector3(21.5, 0, 21.5)) < 0.01)
	checar.call("colou a árvore no lugar certo", copias.size() == 1 and (copias[0] as Arvore).variante == (arvore as Arvore).variante)
	editor.undo.undo()
	checar.call("desfazer tira a colagem", terreno.get_cell_item(Vector3i(20, 0, 20)) == GridMap.INVALID_CELL_ITEM
		and fase.lista_objetos().size() == objetos_antes)
	editor._escolher_trecho()
	editor.trecho_inicio = Vector2i(0, 0)
	editor.trecho_fim = Vector2i(2, 2)
	editor._marcar_trecho(true)
	editor._apagar_trecho()
	checar.call("apagar trecho: blocos e árvore somem", terreno.get_cell_item(Vector3i(1, -1, 1)) == GridMap.INVALID_CELL_ITEM
		and not arvore.is_inside_tree())
	editor.undo.undo()
	checar.call("desfazer devolve", terreno.get_cell_item(Vector3i(1, -1, 1)) == Tiles.GRAMA and arvore.is_inside_tree())
	editor._sair_do_trecho()


## Girar um trecho 3×1 com uma rampa (sobe para +X) e um objeto na ponta.
static func _giro(checar: Callable) -> void:
	var trecho := Trecho.new()
	trecho.largura = 3
	trecho.profundidade = 1
	trecho.celulas = [[Vector3i(2, 0, 0), Tiles.RAMPA_BAIXA, Basis.IDENTITY]]
	trecho.objetos = [{cena = "res://scenes/objetos/pedra.tscn", transform = Transform3D(Basis.IDENTITY, Vector3(2.5, 0, 0.5)),
		visibilidade = 0, propriedades = {}}]
	var girado := trecho.girado(1)
	checar.call("girado 90°: 1×3", girado.largura == 1 and girado.profundidade == 3)
	# +X vira -Z: a ponta (x = 2) vai para z = 0.
	checar.call("girado 90°: a rampa vai para a ponta de cima", girado.celulas[0][0] == Vector3i(0, 0, 0))
	var base: Basis = girado.celulas[0][2]
	checar.call("girado 90°: a rampa passa a subir para -Z", base.x.is_equal_approx(Vector3(0, 0, -1)))
	var pedra: Transform3D = girado.objetos[0].transform
	checar.call("girado 90°: o objeto acompanha", pedra.origin.is_equal_approx(Vector3(0.5, 0, 0.5)))
	var volta := trecho.girado(4)
	checar.call("4 giros = sem giro", volta.celulas[0][0] == Vector3i(2, 0, 0) and volta.largura == 3)


## Balde: troca o gramado inteiro do modelo por neve fofa; desfazer volta.
static func _balde(editor, checar: Callable) -> void:
	var terreno: GridMap = editor.terreno
	var gramas := terreno.get_used_cells_by_item(Tiles.GRAMA).size()
	editor._escolher_tile(Tiles.NEVE_FOFA)
	editor.atingiu_bloco = true
	editor.celula_atingida = Vector3i(0, -1, 0)
	editor._balde()
	checar.call("balde trocou o gramado todo", terreno.get_used_cells_by_item(Tiles.NEVE_FOFA).size() == gramas
		and terreno.get_used_cells_by_item(Tiles.GRAMA).is_empty())
	editor.undo.undo()
	checar.call("desfazer o balde", terreno.get_used_cells_by_item(Tiles.GRAMA).size() == gramas)


## Salva um trecho como módulo (numa pasta de teste) e carrega de volta.
static func _modulos(editor, checar: Callable) -> void:
	var trecho := Trecho.da_fase(editor.fase, Vector2i(-2, -2), Vector2i(3, 1))
	var caminho := Modulos.salvar(trecho, "Módulo de teste", "modulo_teste", Biomas.NEVE, PASTA_TESTE)
	checar.call("módulo salvo", not caminho.is_empty() and FileAccess.file_exists(caminho))
	var lido := Modulos.carregar(caminho)
	checar.call("módulo carregado igual", lido != null and lido.celulas.size() == trecho.celulas.size()
		and lido.objetos.size() == trecho.objetos.size() and lido.largura == trecho.largura)
	checar.call("nome do módulo", Modulos.nome(caminho) == "Módulo de teste")
	DirAccess.remove_absolute(caminho)
	DirAccess.remove_absolute(PASTA_TESTE)


## Trocar o bioma troca a biblioteca de tiles e o céu; desfazer volta.
static func _bioma(editor, checar: Callable) -> void:
	editor._alterar_propriedade(editor.fase, &"bioma", Biomas.NEVE)
	editor._on_versao_mudou()
	checar.call("bioma neve: biblioteca da neve", editor.terreno.mesh_library.resource_path == Tiles.BIBLIOTECAS[Biomas.NEVE])
	checar.call("bioma neve: céu aplicado", editor._bioma_aplicado == Biomas.NEVE)
	var arvore: Arvore = editor.fase.primeiro(Arvore)
	checar.call("árvore com neve", arvore.get_node("Visual").mesh == Voxel.arvore(arvore.tipo, arvore.variante, true))
	editor.undo.undo()
	checar.call("desfazer volta para a floresta", editor.terreno.mesh_library.resource_path == Tiles.BIBLIOTECAS[Biomas.FLORESTA])


static func _regioes(checar: Callable) -> void:
	checar.call("regiões floresta e neve", Regioes.ids() == PackedStringArray(["floresta", "neve"]))
	var lista := Fases.listar()
	checar.call("fases da floresta em ordem", Fases.fases_da_regiao(&"floresta").size() == lista.size()
		and lista[0].get_file() == "fase_01.tscn")
