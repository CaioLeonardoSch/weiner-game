class_name InspetorEditor
extends VBoxContainer
## Painel da direita do editor: propriedades do objeto selecionado (ou da fase, quando
## nada está selecionado). Os controles são montados a partir do tipo de cada variável
## @export, então objetos novos ganham painel sem código extra — basta listar as
## variáveis em `propriedades_editaveis()`.
## As mudanças não são aplicadas aqui: saem pelo sinal para o editor (que registra o desfazer).

signal propriedade_alterada(alvo: Object, propriedade: StringName, valor: Variant)
signal pedido_apagar
signal pedido_duplicar
signal pedido_copiar
signal pedido_recortar
signal pedido_apagar_trecho
signal pedido_salvar_modulo(nome: String)

const ROTULOS := {
	&"nome": "Nome",
	&"desvio_camera_3d": "Giro da câmera 3D (°)",
	&"visibilidade": "Visibilidade",
	&"comprimento": "Comprimento (m)",
	&"tamanho": "Tamanho (m)",
	&"position": "Posição",
	&"habilidades": "Habilidades do cachorro",
	&"raca": "Raça do cachorro",
	&"raca_fixa": "Sempre com esta raça",
	&"objetivo": "Objetivo",
	&"peso": "Peso (1 = normal)",
	&"regiao": "Região",
	&"bioma": "Bioma (texturas, céu, entorno)",
	&"frio": "Frio (o cachorro precisa se esquentar)",
	&"tempo_de_frio": "Segundos até gelar",
}
const NOMES_VISIBILIDADE := ["Sempre", "Só isométrico", "Só 3D"]

var _alvo: Object
## propriedade → Callable que recebe o valor atual e atualiza o controle (sem emitir sinal).
var _atualizadores := {}


func mostrar(alvo: Object) -> void:
	_alvo = alvo
	_atualizadores.clear()
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	if alvo == null:
		return

	if alvo is ObjetoFase:
		var objeto := alvo as ObjetoFase
		_titulo(objeto.nome_no_editor())
		_campo(&"visibilidade")
		_campo(&"position")
		_campo_giro()
		_campo_escala()
		for propriedade in objeto.propriedades_editaveis():
			_campo(propriedade)
		add_child(HSeparator.new())
		var botoes := HBoxContainer.new()
		var duplicar := Button.new()
		duplicar.text = "Duplicar (Ctrl+D)"
		duplicar.pressed.connect(pedido_duplicar.emit)
		botoes.add_child(duplicar)
		var apagar := Button.new()
		apagar.text = "Apagar (Del)"
		apagar.pressed.connect(pedido_apagar.emit)
		botoes.add_child(apagar)
		add_child(botoes)
		_dica("Legenda: ◆ rosa = só isométrico, ◆ azul = só 3D.")
	elif alvo is Fase:
		_titulo("Fase")
		_campo(&"nome")
		_campo(&"regiao")
		_campo(&"bioma")
		_campo(&"objetivo")
		_campo(&"raca")
		_campo(&"raca_fixa")
		_dica_raca_no_menu(alvo as Fase)
		_campo(&"habilidades")
		_campo(&"desvio_camera_3d")
		_campo(&"frio")
		if (alvo as Fase).frio:
			_campo(&"tempo_de_frio")
			_dica("Esquentam: Fogueira acesa (perto do fogo) e Celeiro (dentro).")
		_dica("Selecione um objeto (ferramenta Selecionar) para editar as propriedades dele.")


## Painel da ferramenta Trecho: tamanho do retângulo marcado e o que dá para fazer com ele.
## `info` vazio: nada marcado ainda.
func mostrar_trecho(info: Dictionary) -> void:
	mostrar(null)
	_titulo("Trecho")
	if info.is_empty():
		_dica("Arraste no mapa para marcar um retângulo. Entram os blocos de todas as camadas e os objetos de dentro.")
		_dica("Depois: Ctrl+C copia, Ctrl+X recorta, Del apaga, e aqui dá para salvar como módulo.")
		_dica("Ctrl+V cola o que foi copiado (também em outra fase); os módulos ficam no fim da paleta.")
		return
	_dica("%d × %d colunas — %d blocos, %d objetos" % [info.largura, info.profundidade, info.blocos, info.objetos])
	var linha := HBoxContainer.new()
	for acao in [["Copiar", pedido_copiar], ["Recortar", pedido_recortar], ["Apagar", pedido_apagar_trecho]]:
		var botao := Button.new()
		botao.text = acao[0]
		botao.pressed.connect((acao[1] as Signal).emit)
		linha.add_child(botao)
	add_child(linha)
	add_child(HSeparator.new())
	var rotulo := Label.new()
	rotulo.text = "Salvar como módulo"
	add_child(rotulo)
	var nome := LineEdit.new()
	nome.placeholder_text = "Nome do módulo (ex.: Ponte de troncos)"
	add_child(nome)
	var salvar := Button.new()
	salvar.text = "Salvar módulo"
	salvar.pressed.connect(func() -> void: pedido_salvar_modulo.emit(nome.text))
	nome.text_submitted.connect(func(texto: String) -> void: pedido_salvar_modulo.emit(texto))
	add_child(salvar)
	_dica("O módulo vai para scenes/modulos/ e aparece na paleta (Módulos): clique para colar, em qualquer fase.")


## Painel enquanto cola (Ctrl+V ou um módulo).
func mostrar_colagem(info: Dictionary) -> void:
	mostrar(null)
	_titulo("Colar" + (": " + info.modulo if not info.modulo.is_empty() else ""))
	_dica("%d × %d colunas — %d blocos, %d objetos" % [info.largura, info.profundidade, info.blocos, info.objetos])
	_dica("Clique cola (e continua colando). Q / E gira 90°. PgUp / PgDn sobe ou desce. Esc ou clique direito sai.")
	_dica("Blocos colados substituem os que estiverem no lugar; onde o trecho não tem bloco, nada muda. Mecanismos colados mantêm a cor (ficam ligados aos da mesma cor).")


## Atualiza os valores mostrados (depois de desfazer, arrastar etc.).
func atualizar_valores() -> void:
	if _alvo == null or not is_instance_valid(_alvo):
		return
	for propriedade in _atualizadores:
		_atualizadores[propriedade].call()


func _titulo(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", 18)
	add_child(rotulo)


func _dica(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	rotulo.add_theme_font_size_override("font_size", 12)
	add_child(rotulo)


func _rotulo(propriedade: StringName) -> void:
	var rotulo := Label.new()
	rotulo.text = ROTULOS.get(propriedade, String(propriedade).capitalize())
	add_child(rotulo)


func _info(propriedade: StringName) -> Dictionary:
	for info in _alvo.get_property_list():
		if info.name == propriedade:
			return info
	return {}


func _emitir(propriedade: StringName, valor: Variant) -> void:
	propriedade_alterada.emit(_alvo, propriedade, valor)


func _campo(propriedade: StringName) -> void:
	var info := _info(propriedade)
	if info.is_empty():
		return
	_rotulo(propriedade)
	var tipo: int = info.type
	var hint: int = info.hint
	var texto_hint: String = info.hint_string

	if tipo == TYPE_INT and hint == PROPERTY_HINT_FLAGS:
		var marcas: Array[CheckBox] = []
		for i in texto_hint.split(",").size():
			var marca := CheckBox.new()
			marca.text = texto_hint.split(",")[i].get_slice(":", 0)
			var bit := 1 << i
			marca.toggled.connect(func(ligado: bool) -> void:
				var valor: int = _alvo.get(propriedade)
				_emitir(propriedade, (valor | bit) if ligado else (valor & ~bit)))
			marcas.append(marca)
			add_child(marca)
		_atualizadores[propriedade] = func() -> void:
			var valor: int = _alvo.get(propriedade)
			for i in marcas.size():
				marcas[i].set_pressed_no_signal(valor & (1 << i) != 0)
	elif tipo == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var opcoes := OptionButton.new()
		var nomes := texto_hint.split(",")
		for i in nomes.size():
			var nome := nomes[i].get_slice(":", 0)
			if propriedade == &"visibilidade" and i < NOMES_VISIBILIDADE.size():
				nome = NOMES_VISIBILIDADE[i]
			opcoes.add_item(nome, int(nomes[i].get_slice(":", 1)) if ":" in nomes[i] else i)
		opcoes.item_selected.connect(func(indice: int) -> void: _emitir(propriedade, opcoes.get_item_id(indice)))
		_atualizadores[propriedade] = func() -> void: opcoes.select(opcoes.get_item_index(_alvo.get(propriedade)))
		add_child(opcoes)
	elif (tipo == TYPE_STRING or tipo == TYPE_STRING_NAME) and hint == PROPERTY_HINT_ENUM:
		# Lista de textos (ex.: ids das raças): o valor é o próprio texto.
		var opcoes := OptionButton.new()
		var textos := texto_hint.split(",")
		for texto in textos:
			opcoes.add_item(_nome_de_opcao(propriedade, texto))
		opcoes.item_selected.connect(func(indice: int) -> void:
			var valor: Variant = StringName(textos[indice]) if tipo == TYPE_STRING_NAME else textos[indice]
			_emitir(propriedade, valor))
		_atualizadores[propriedade] = func() -> void: opcoes.select(textos.find(String(_alvo.get(propriedade))))
		add_child(opcoes)
	elif tipo == TYPE_INT or tipo == TYPE_FLOAT:
		var caixa := _spin(texto_hint if hint == PROPERTY_HINT_RANGE else "", tipo == TYPE_INT)
		caixa.value_changed.connect(func(valor: float) -> void:
			_emitir(propriedade, int(valor) if tipo == TYPE_INT else valor))
		_atualizadores[propriedade] = func() -> void: caixa.set_value_no_signal(_alvo.get(propriedade))
		add_child(caixa)
	elif tipo == TYPE_BOOL:
		var marca := CheckBox.new()
		marca.toggled.connect(func(valor: bool) -> void: _emitir(propriedade, valor))
		_atualizadores[propriedade] = func() -> void: marca.set_pressed_no_signal(_alvo.get(propriedade))
		add_child(marca)
	elif tipo == TYPE_STRING:
		var campo := LineEdit.new()
		campo.text_submitted.connect(func(valor: String) -> void: _emitir(propriedade, valor))
		campo.focus_exited.connect(func() -> void:
			if campo.text != _alvo.get(propriedade):
				_emitir(propriedade, campo.text))
		_atualizadores[propriedade] = func() -> void:
			if not campo.has_focus():
				campo.text = _alvo.get(propriedade)
		add_child(campo)
	elif tipo == TYPE_VECTOR3:
		var linha := HBoxContainer.new()
		var caixas: Array[SpinBox] = []
		for eixo in 3:
			var caixa := _spin("", false)
			caixa.step = 0.05
			caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			caixa.value_changed.connect(func(valor: float) -> void:
				var vetor: Vector3 = _alvo.get(propriedade)
				vetor[eixo] = valor
				_emitir(propriedade, vetor))
			caixas.append(caixa)
			linha.add_child(caixa)
		_atualizadores[propriedade] = func() -> void:
			var vetor: Vector3 = _alvo.get(propriedade)
			for eixo in 3:
				caixas[eixo].set_value_no_signal(vetor[eixo])
		add_child(linha)
	_atualizadores[propriedade].call()


## Jogando pelo menu, a raça é a que o jogador escolheu entre as da região (se não for fixa).
func _dica_raca_no_menu(fase: Fase) -> void:
	var regiao := Regioes.por_id(fase.regiao)
	if fase.raca_fixa or regiao == null:
		return
	var nomes := regiao.racas_compativeis().map(func(r: Raca) -> String: return r.nome)
	_dica("No menu, o jogador escolhe: %s (raças da região). Teste com cada uma." % ", ".join(nomes))



func _nome_de_opcao(propriedade: StringName, texto: String) -> String:
	if propriedade == &"regiao":
		var regiao := Regioes.por_id(StringName(texto))
		return regiao.nome if regiao else texto
	if propriedade == &"raca":
		var raca := Racas.por_id(StringName(texto))
		if raca and raca.id == StringName(texto):
			return raca.nome
	return texto


func _campo_giro() -> void:
	_rotulo(&"Giro (°)")
	var caixa := _spin("-180,180,1", false)
	caixa.value_changed.connect(func(valor: float) -> void:
		var giro: Vector3 = _alvo.rotation
		giro.y = deg_to_rad(valor)
		_emitir(&"rotation", giro))
	_atualizadores[&"rotation"] = func() -> void: caixa.set_value_no_signal(roundf(rad_to_deg(_alvo.rotation.y)))
	_atualizadores[&"rotation"].call()
	add_child(caixa)


func _campo_escala() -> void:
	_rotulo(&"Escala")
	var caixa := _spin("0.1,5,0.05", false)
	caixa.value_changed.connect(func(valor: float) -> void: _emitir(&"scale", Vector3.ONE * valor))
	_atualizadores[&"scale"] = func() -> void: caixa.set_value_no_signal(_alvo.scale.x)
	_atualizadores[&"scale"].call()
	add_child(caixa)


func _spin(faixa: String, inteiro: bool) -> SpinBox:
	var caixa := SpinBox.new()
	caixa.min_value = -1000.0
	caixa.max_value = 1000.0
	caixa.step = 1.0 if inteiro else 0.05
	if not faixa.is_empty():
		var partes := faixa.split(",")
		caixa.min_value = partes[0].to_float()
		caixa.max_value = partes[1].to_float()
		if partes.size() > 2 and partes[2].is_valid_float():
			caixa.step = partes[2].to_float()
	caixa.select_all_on_focus = true
	return caixa
