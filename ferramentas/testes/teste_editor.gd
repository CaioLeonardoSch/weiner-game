extends RefCounted
## Testes do editor modular (e do Editor de fases 2: pincel com tamanho, linha com prévia,
## ferramentas, recentes, ícones e volumes das paredes invisíveis) (rota ferramentas/testes/rotas/editor.txt): trecho (copiar, colar,
## girar, apagar, desfazer), balde, módulos (salvar e carregar), bioma, regiões e o "testar daqui"
## (F2) sem chão firme. Guarda o resultado em jogo.get_meta("editor_ok"). À parte, o editor aberto
## por alguns quadros com troncos-fantasma (abrir_com_tronco, fechar_editor).

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
	_editor_2(editor, checar)
	_testar_daqui(editor, checar)
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


## Pincel 3×3, linha de blocos (clique, clique), linha de objetos, teclas das ferramentas,
## recentes, ícones em todos os botões da paleta e o volume translúcido da parede invisível.
static func _editor_2(editor, checar: Callable) -> void:
	var terreno: GridMap = editor.terreno
	var fase: Fase = editor.fase
	editor._escolher_tile(Tiles.PEDRA)
	editor.tamanho_pincel = 3
	editor.celula_alvo = Vector3i(30, 0, 30)
	editor._comecar_pincel("colocar", 0)
	editor._terminar_pincel()
	var pedras := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if terreno.get_cell_item(Vector3i(30 + dx, 0, 30 + dz)) == Tiles.PEDRA:
				pedras += 1
	checar.call("pincel 3×3 coloca 9 blocos", pedras == 9)
	editor.undo.undo()
	checar.call("desfazer o pincel 3×3", terreno.get_cell_item(Vector3i(31, 0, 31)) == GridMap.INVALID_CELL_ITEM)

	editor.tamanho_pincel = 1
	editor.atingiu_bloco = false
	editor.celula_alvo = Vector3i(40, 0, 40)
	editor._clique_linha("colocar")
	checar.call("linha: o primeiro clique só marca o começo", editor.linha_ativa
		and terreno.get_cell_item(Vector3i(40, 0, 40)) == GridMap.INVALID_CELL_ITEM)
	editor.linha_fim = Vector3i(45, 0, 43)
	checar.call("linha: a prévia mostra 6 blocos", editor.celulas_da_linha().size() == 6
		and (editor.celulas_da_previa()[1] as Array).size() == 6)
	editor._confirmar_linha()
	var na_linha := 0
	for celula: Vector3i in [Vector3i(40, 0, 40), Vector3i(45, 0, 43), Vector3i(43, 0, 42)]:
		if terreno.get_cell_item(celula) == Tiles.PEDRA:
			na_linha += 1
	checar.call("linha: o segundo clique coloca", na_linha == 3 and not editor.linha_ativa)
	editor.undo.undo()
	checar.call("desfazer a linha (uma ação só)", terreno.get_cell_item(Vector3i(45, 0, 43)) == GridMap.INVALID_CELL_ITEM)

	var entrada: Dictionary = editor._catalogo.filter(func(c): return c.caminho.ends_with("pedra.tscn"))[0]
	editor._escolher_objeto(entrada)
	var antes := fase.todos(Pedra).size()
	editor.ponto_alvo = Vector3(50.5, 0, 50.5)
	editor._clique_linha_objetos()
	editor.ponto_alvo = Vector3(54.5, 0, 50.5)
	editor._continuar_linha_objetos()
	checar.call("linha de objetos: 5 fantasmas", editor.pontos_linha_objetos.size() == 5)
	editor._clique_linha_objetos()
	checar.call("linha de objetos: 5 pedras colocadas", fase.todos(Pedra).size() == antes + 5 and not editor.linha_ativa)
	checar.call("recentes: a pedra no topo", (Fases.estado_editor.get("recentes", []) as Array)[0] == entrada.caminho
		and not editor._secao_recentes.itens.is_empty())

	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.physical_keycode = KEY_4
	editor._tecla_de_ferramenta(tecla)
	checar.call("tecla 4: ferramenta Retângulo (e volta ao terreno)", editor.ferramenta == EditorFase.Ferramenta.RETANGULO
		and editor.modo == EditorFase.Modo.TERRENO)
	tecla.physical_keycode = KEY_BRACKETRIGHT
	editor._tecla_de_ferramenta(tecla)
	checar.call("] aumenta o pincel", editor.tamanho_pincel == 2)

	var sem_icone: PackedStringArray = []
	for botao in editor._botoes_paleta.get_buttons():
		if botao.icon == null:
			sem_icone.append(botao.text)
	checar.call("todos os botões da paleta têm ícone (%s)" % ", ".join(sem_icone), sem_icone.is_empty())

	var parede := fase.adicionar_objeto(load("res://scenes/objetos/parede_invisivel.tscn"), Vector3(60.5, 0, 60.5))
	checar.call("parede invisível aparece translúcida no editor", parede.get_node_or_null("VolumeEditor") != null)


## Testar daqui (F2): só em chão firme. Na água funda ou no vazio o cachorro cairia e voltaria ao
## próprio início sem parar ("Splash!" em laço); o editor recusa e avisa. (Nunca chama _testar num
## chão que serve: ele trocaria de cena no meio do teste.)
static func _testar_daqui(editor, checar: Callable) -> void:
	var terreno: GridMap = editor.terreno
	terreno.set_cell_item(Vector3i(70, -1, 80), Tiles.GRAMA)
	terreno.set_cell_item(Vector3i(72, -1, 80), Tiles.AGUA)
	terreno.set_cell_item(Vector3i(72, -2, 80), Tiles.GRAMA)
	terreno.set_cell_item(Vector3i(74, 0, 80), Tiles.TABUA)
	checar.call("F2: na grama serve", editor._motivo_sem_chao(Vector3(70.5, 0, 80.5)).is_empty())
	checar.call("F2: no alto, acima da grama, serve (cai até ela)", editor._motivo_sem_chao(Vector3(70.5, 3, 80.5)).is_empty())
	checar.call("F2: na tábua serve", editor._motivo_sem_chao(Vector3(74.5, 0, 80.5)).is_empty())
	var agua := Vector3(72.5, -1 + 0.85, 80.5)
	checar.call("F2: na água funda não serve", editor._motivo_sem_chao(agua).begins_with("Água funda"))
	checar.call("F2: no vazio não serve", editor._motivo_sem_chao(Vector3(76.5, 0, 80.5)).begins_with("Sem chão"))
	if not editor._motivo_sem_chao(agua).is_empty():
		editor.alvo_valido = true
		editor.ponto_livre = agua
		editor.ponto_alvo = agua
		editor._testar(true, true)
		checar.call("F2 na água: não testa e avisa", Fases.inicio_do_teste == null and editor.aviso.visible
			and (editor.aviso.text as String).begins_with("Água funda"))


## O editor aberto com o tronco escolhido e uma linha de troncos-fantasma, vivos por alguns quadros
## (a rota espera e chama fechar_editor). Fora de uma fase o tronco não tem onde assentar: antes,
## cada fantasma dava um SCRIPT ERROR (que reprova a rota).
static func abrir_com_tronco(jogo: Node) -> void:
	# Como Fases.editar: o editor abre do zero (o teste anterior deixou só os recentes).
	Fases.estado_editor = {}
	var editor = (load("res://scenes/editor/editor_fase.tscn") as PackedScene).instantiate()
	jogo.add_child(editor)
	editor._carregar(editor._fase_modelo("teste"))
	var entrada: Dictionary = editor._catalogo.filter(func(c): return c.caminho.ends_with("tronco_rolante.tscn"))[0]
	editor._escolher_objeto(entrada)
	editor.ponto_alvo = Vector3(0.5, 0, 0.5)
	editor._clique_linha_objetos()
	editor.ponto_alvo = Vector3(0.5, 0, 6.5)
	editor._continuar_linha_objetos()
	jogo.set_meta(&"editor", editor)


static func fechar_editor(jogo: Node) -> void:
	var editor = jogo.get_meta(&"editor")
	var fantasmas: Array = editor._fantasmas_linha
	var fora_da_fase := func(no: Node) -> bool: return not no.is_in_group(&"pesos") and not no.is_in_group(&"com_acao")
	jogo.set_meta(&"editor_tronco_ok", editor.fantasma is TroncoRolante and fantasmas.size() >= 2
		and fora_da_fase.call(editor.fantasma) and fantasmas.all(fora_da_fase))
	jogo.remove_child(editor)
	editor.free()
	jogo.remove_meta(&"editor")
