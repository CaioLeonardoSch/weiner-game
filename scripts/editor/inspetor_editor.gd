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

const ROTULOS := {
	&"nome": "Nome",
	&"desvio_camera_3d": "Giro da câmera 3D (°)",
	&"visibilidade": "Visibilidade",
	&"comprimento": "Comprimento (m)",
	&"tamanho": "Tamanho (m)",
	&"position": "Posição",
	&"habilidades": "Habilidades do cachorro",
	&"peso": "Peso (1 = normal)",
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
		_campo(&"habilidades")
		_campo(&"desvio_camera_3d")
		_dica("Selecione um objeto (ferramenta Selecionar) para editar as propriedades dele.")


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
