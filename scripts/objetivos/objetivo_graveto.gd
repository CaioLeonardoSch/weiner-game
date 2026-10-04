class_name ObjetivoGraveto
extends Objetivo
## Trazer o graveto lendário ao dono. Gravetos comuns podem ser pegos e levados (são
## ferramentas), mas o dono só aceita o lendário.

var dono: Dono


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	_falta(fase, Dono, "o Dono", lista)
	if _lendarios(fase).is_empty():
		lista.append("o Graveto lendário")
	return lista


func avisos(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	var lendarios := _lendarios(fase).size()
	if lendarios > 1:
		lista.append("Há %d gravetos lendários — o dono aceita qualquer um deles." % lendarios)
	if fase.todos(Dono).size() > 1:
		lista.append("Há mais de um Dono — só o primeiro vale.")
	var dono_da_fase := fase.primeiro(Dono) as Dono
	if dono_da_fase and dono_da_fase.dormindo and not fase.tem_habilidade(Fase.HABILIDADE_LATIR) \
			and fase.todos(CaoVizinho).is_empty():
		lista.append("O dono está dormindo, mas ninguém late para acordar ele (Latir desligado).")
	return lista


func preparar(novo_jogo: Node) -> void:
	super(novo_jogo)
	jogo.contador.text = "Ache o graveto dourado"
	dono = jogo.fase.primeiro(Dono) as Dono
	dono.cachorro_chegou.connect(func(corpo: Node3D) -> void:
		if corpo == jogo.cachorro:
			_conferir())
	# Acordou com o cachorro já do lado, graveto na boca.
	dono.acordou.connect(func() -> void:
		if dono.contem(jogo.cachorro):
			_conferir())


func ao_pegar_graveto(pego: Graveto) -> void:
	if pego.lendario:
		jogo.contador.text = "Leve o graveto ao dono"
		# Um dia do parque: o dono assobia, chamando para ir embora.
		var fases := jogo.get_node_or_null(^"/root/Fases")
		if fases and fases.do_parque and not pego.get_meta(&"assobiou", false):
			pego.set_meta(&"assobiou", true)
			Som.assobio(jogo)
	# Pegou (de novo) já do lado do dono.
	if dono.contem(jogo.cachorro):
		_conferir()


func _conferir() -> void:
	var cachorro: Dachshund = jogo.cachorro
	if not cachorro.tem_graveto or jogo.concluida:
		return
	if dono.dormindo:
		jogo.mostrar_aviso("Zzz... O dono está dormindo. Um latido acorda ele — mas com o graveto na boca não dá para latir.", 3.5)
	elif cachorro.graveto.lendario:
		jogo.concluir()
	else:
		jogo.mostrar_aviso("Esse não! O dono quer o graveto lendário — o dourado.")


static func _lendarios(fase: Fase) -> Array:
	return fase.todos(Graveto).filter(func(g: ObjetoFase) -> bool: return (g as Graveto).lendario)
