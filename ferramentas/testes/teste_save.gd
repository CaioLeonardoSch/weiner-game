extends RefCounted
## Testes do save do jogador (rota ferramentas/testes/rotas/save.txt): a pasta do save não
## mudou, as fases têm ids, e saves antigos (ferramentas/testes/saves/) continuam valendo.
## Tudo em memória: o save real não é lido nem gravado. Resultado em jogo.get_meta("save_ok").

static func rodar(jogo: Node) -> String:
	var falhas: PackedStringArray = []
	var checar := func(nome: String, cond: bool) -> void:
		print(("  ok  " if cond else "  FALHOU  ") + nome)
		if not cond:
			falhas.append(nome)
	var fases: Node = jogo.get_node(^"/root/Fases")
	var progresso_antes: ConfigFile = fases.progresso

	# A pasta do save é a mesma de sempre (mudar = o jogo novo não acha o progresso antigo).
	checar.call("pasta do save: WeinerGame", ProjectSettings.get_setting("application/config/use_custom_user_dir") == true
		and ProjectSettings.get_setting("application/config/custom_user_dir_name") == "WeinerGame")

	# Toda fase do projeto tem id próprio, e nenhum se repete.
	var ids := {}
	for caminho in fases.listar():
		if not caminho.begins_with("res://"):
			continue
		var id := str(fases.propriedade_da_fase(caminho, &"id", ""))
		checar.call("%s tem id" % caminho.get_file(), not id.is_empty())
		checar.call("id %s sem repetir" % id, not ids.has(id))
		ids[id] = true

	# Save do formato 1: as mesmas fases continuam concluídas e as pelagens ficam.
	var cfg := ConfigFile.new()
	checar.call("save de exemplo carregou", cfg.load("res://ferramentas/testes/saves/progresso_v1.cfg") == OK)
	checar.call("formato 1 → atual: migrou", fases.migrar(cfg))
	checar.call("versão gravada", int(cfg.get_value("save", "versao", 0)) == fases.VERSAO_PROGRESSO)
	fases.progresso = cfg
	# (As fases antigas não existem mais: confere os ids gravados.)
	var concluidas: PackedStringArray = cfg.get_value("fases", "concluidas", PackedStringArray())
	for numero in ["01", "02", "05"]:
		checar.call("fase_%s continua concluída" % numero, "fase_%s" % numero in concluidas)
	checar.call("fase_03 continua não concluída", not "fase_03" in concluidas)
	checar.call("pelagens ficaram", cfg.get_value("pelagens", "salsicha", -1) == 2
		and cfg.get_value("pelagens", "border_collie", -1) == 1)
	checar.call("migrar de novo não muda nada", not fases.migrar(cfg))

	# Fase que trocou de id (IDS_RENOMEADOS): o ✓ vai junto.
	checar.call("id renomeado leva o ✓", fases.migrar(cfg, {"fase_02": "fase_02_nova"})
		and "fase_02_nova" in cfg.get_value("fases", "concluidas") and not "fase_02" in cfg.get_value("fases", "concluidas"))

	# Save de uma versão mais nova do jogo: fica como está.
	var futuro := ConfigFile.new()
	futuro.set_value("save", "versao", 99)
	futuro.set_value("fases", "concluidas", PackedStringArray(["x"]))
	futuro.set_value("regioes", "parque", true)
	var texto := futuro.encode_to_text()
	checar.call("save mais novo não é mexido", not fases.migrar(futuro) and futuro.encode_to_text() == texto)

	fases.progresso = progresso_antes
	jogo.set_meta(&"save_ok", falhas.is_empty())
	return "save: %s" % ("tudo certo" if falhas.is_empty() else ", ".join(falhas))
