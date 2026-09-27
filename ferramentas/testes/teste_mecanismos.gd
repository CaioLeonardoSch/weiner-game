extends RefCounted
## Testes dos mecanismos (rota ferramentas/testes/rotas/mecanismos.txt): regra OU / E dos portões
## e a ferramenta Ligar do editor. Guarda o resultado em jogo.get_meta("mecanismos_ok").

static func rodar(jogo: Node) -> String:
	var falhas: PackedStringArray = []
	var checar := func(nome: String, cond: bool) -> void:
		print(("  ok  " if cond else "  FALHOU  ") + nome)
		if not cond:
			falhas.append(nome)
	_regras(jogo, checar)
	_placas(jogo, checar)
	_ferramenta_ligar(jogo, checar)
	jogo.set_meta(&"mecanismos_ok", falhas.is_empty())
	return "mecanismos: %s" % ("tudo certo" if falhas.is_empty() else ", ".join(falhas))


## Duas placas da mesma cor, um portão com a regra E e outro com OU.
static func _regras(jogo: Node, checar: Callable) -> void:
	var fase = Fase.nova("teste")
	jogo.add_child(fase)
	var placa = load("res://scenes/objetos/placa.tscn")
	var portao = load("res://scenes/objetos/portao.tscn")
	var p1 = fase.adicionar_objeto(placa, Vector3(0.5, 0, 0.5), 0)
	var p2 = fase.adicionar_objeto(placa, Vector3(3.5, 0, 0.5), 0)
	var e = fase.adicionar_objeto(portao, Vector3(6.5, 0, 0.5), 0)
	e.regra = Portao.REGRA_TODAS
	var ou = fase.adicionar_objeto(portao, Vector3(9.5, 0, 0.5), 0)
	# Portões criados depois das placas conferem de novo (como no jogo, ao entrar na fase).
	e._quer_abrir = e._deve_abrir()
	ou._quer_abrir = ou._deve_abrir()
	checar.call("sem peso: E e OU fechados", not e._quer_abrir and not ou._quer_abrir)
	p1._mudar(true)
	checar.call("uma placa: E fechado, OU aberto", not e._quer_abrir and ou._quer_abrir)
	p2._mudar(true)
	checar.call("as duas: E aberto", e._quer_abrir and e.aberto)
	p1._mudar(false)
	checar.call("sai de uma: E quer fechar, OU segue aberto", not e._quer_abrir and ou._quer_abrir)
	jogo.remove_child(fase)
	fase.free()


## Placa de madeira: qualquer coisa aciona (um graveto largado). Placa de pedra: só o bloco.
static func _placas(jogo: Node, checar: Callable) -> void:
	var fase = Fase.nova("teste")
	jogo.add_child(fase)
	var madeira = fase.adicionar_objeto(load("res://scenes/objetos/placa.tscn"), Vector3(20.5, 0, 20.5), 0)
	var pedra = fase.adicionar_objeto(load("res://scenes/objetos/placa.tscn"), Vector3(23.5, 0, 20.5), 0)
	pedra.tipo = Placa.PEDRA
	checar.call("placas vazias não acionam", not madeira.acionada_por_algo() and not pedra.acionada_por_algo())
	var graveto = fase.adicionar_objeto(load("res://scenes/objetos/graveto_comum.tscn"), Vector3(20.5, 0.08, 20.5), 0)
	var outro = fase.adicionar_objeto(load("res://scenes/objetos/graveto_comum.tscn"), Vector3(23.5, 0.08, 20.5), 0)
	checar.call("graveto aciona a de madeira, não a de pedra", madeira.acionada_por_algo() and not pedra.acionada_por_algo())
	var bloco = fase.adicionar_objeto(load("res://scenes/objetos/bloco_empurravel.tscn"), Vector3(23.5, 0, 20.5), 0)
	checar.call("bloco aciona a de pedra", pedra.acionada_por_algo())
	jogo.remove_child(fase)
	fase.free()


## Coloca duas placas e um portão numa fase nova do editor e liga pela ferramenta.
static func _ferramenta_ligar(jogo: Node, checar: Callable) -> void:
	var editor = (load("res://scenes/editor/editor_fase.tscn") as PackedScene).instantiate()
	jogo.add_child(editor)
	editor._carregar(editor._fase_modelo("teste"))
	var catalogo := Catalogo.objetos()
	var colocar := func(final: String, x: float) -> ObjetoFase:
		editor._escolher_objeto(catalogo.filter(func(c): return c.caminho.ends_with(final))[0])
		editor.fantasma.position = Vector3(x, 0, -2.5)
		editor._colocar_objeto()
		return editor.selecionado
	var a: ObjetoFase = colocar.call("placa.tscn", 0.5)
	var b: ObjetoFase = colocar.call("placa.tscn", 2.5)
	var g: ObjetoFase = colocar.call("portao.tscn", 5.5)
	checar.call("peças novas vêm com cores livres", a.canal != b.canal and b.canal != g.canal and a.canal != g.canal)
	editor._escolher_ligar()
	editor._clique_ligar(a)
	editor._clique_ligar(g)
	checar.call("ligar placa → portão", a.canal == g.canal and editor.ligar_origem == null)
	editor._clique_ligar(b)
	editor._clique_ligar(g)
	checar.call("segunda placa entra no grupo do portão", b.canal == g.canal and a.canal == g.canal)
	checar.call("validação sem avisos", editor._avisos_de_mecanismos().is_empty())
	editor._clique_ligar(a)
	editor._clique_ligar(g)
	checar.call("clicar num par ligado desliga", a.canal != g.canal and a.canal == b.canal)
	checar.call("validação avisa as peças soltas", editor._avisos_de_mecanismos().size() == 2)
	editor.undo.undo()
	checar.call("desfazer religa", a.canal == g.canal)
	g.regra = Portao.REGRA_TODAS
	editor._isolar(b)
	checar.call("clique direito solta a peça", b.canal != a.canal)
	checar.call("validação avisa E com uma placa só", editor._avisos_de_mecanismos().size() == 2)
	jogo.remove_child(editor)
	editor.free()
