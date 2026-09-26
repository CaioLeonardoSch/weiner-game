class_name CachorroVoxel
## Gera o modelo voxel de um cachorro a partir de uma `Raca` (formato) e uma `Pelagem` (cores).
##
## O modelo sai em partes separadas (corpo, cabeça, orelhas, rabo, quatro patas), cada uma com
## um pivô, para o `ModeloCachorro` animar (andar, abanar o rabo, balançar as orelhas).
## Coordenadas em voxels (Raca.VOXEL m): o cachorro olha para +X, Y para cima, e o centro em Z
## fica em z = 0,5 (larguras ímpares, simétricas em volta dele).

const PARTES := [&"corpo", &"cabeca", &"orelha_e", &"orelha_d", &"rabo", &"pata_fe", &"pata_fd", &"pata_te", &"pata_td"]


## Devolve {partes = {nome: {voxels: {Vector3i: Color}, pivo: Vector3}}, boca: Vector3}
## (pivô e boca em voxels).
static func gerar(raca: Raca, pelagem: Pelagem, semente := 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var partes := {}
	for nome in PARTES:
		partes[nome] = {voxels = {}, pivo = Vector3.ZERO}

	var comprimento := raca.comprimento_corpo
	var altura := raca.altura_corpo
	var largura := _impar(raca.largura_corpo)
	var pata := raca.altura_pata
	var grossura := raca.grossura_pata
	var x0 := -comprimento / 2
	var x1 := x0 + comprimento - 1
	var z0 := -(largura - 1) / 2
	var z1 := (largura - 1) / 2
	var y0 := pata
	var y1 := pata + altura - 1
	var marcas := pelagem.marcas

	# --- Corpo: caixa com as quinas das pontas chanfradas.
	var corpo: Dictionary = partes.corpo.voxels
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				var ponta := x == x0 or x == x1
				var lado := z == z0 or z == z1
				if ponta and lado and (y == y1 or y == y0):
					continue
				var cor := pelagem.cor_pelo
				if marcas >= 1 and ((y == y0 and not lado) or (x == x1 and y <= y0 + 1)):
					cor = pelagem.cor_marcas
				corpo[Vector3i(x, y, z)] = _manchado(cor, pelagem, rng)
	if pelagem.pelo_longo:
		# Franja embaixo da barriga e no peito.
		for x in range(x0 + 2, x1 - 1):
			for z in [z0, z1]:
				corpo[Vector3i(x, y0 - 1, z)] = _variar(pelagem.cor_pelo.darkened(0.08), rng)
			if rng.randf() < 0.6:
				corpo[Vector3i(x, y0 - 1, rng.randi_range(z0 + 1, z1 - 1))] = _variar(pelagem.cor_pelo.darkened(0.05), rng)
		for z in range(z0 + 1, z1):
			corpo[Vector3i(x1 + 1, y0, z)] = _variar(pelagem.cor_marcas if marcas >= 1 else pelagem.cor_pelo, rng)
	partes.corpo.pivo = Vector3(0, y0, 0.5)

	# --- Patas.
	var patas := {
		pata_fe = [x1 - grossura, z0], pata_fd = [x1 - grossura, z1 - grossura + 1],
		pata_te = [x0 + 1, z0], pata_td = [x0 + 1, z1 - grossura + 1],
	}
	for nome: StringName in patas:
		var canto: Array = patas[nome]
		var voxels: Dictionary = partes[nome].voxels
		for x in range(canto[0], canto[0] + grossura):
			for z in range(canto[1], canto[1] + grossura):
				for y in range(0, pata):
					var cor := pelagem.cor_pelo
					if marcas >= 1 and y <= maxi(pata / 3, 1) - 1:
						cor = pelagem.cor_marcas
					voxels[Vector3i(x, y, z)] = _variar(cor, rng)
		partes[nome].pivo = Vector3(canto[0] + grossura * 0.5, pata, canto[1] + grossura * 0.5)

	# --- Cabeça, focinho, olhos e nariz.
	var cabeca: Dictionary = partes.cabeca.voxels
	var hx := raca.cabeca.x
	var hy := raca.cabeca.y
	var hz := _impar(raca.cabeca.z)
	var xh0 := x1 - 1
	var xh1 := xh0 + hx - 1
	var yh1 := y1 + raca.altura_pescoco
	var yh0 := yh1 - hy + 1
	var zh0 := -(hz - 1) / 2
	var zh1 := (hz - 1) / 2
	var tem_mascara := not pelagem.cor_mascara.is_equal_approx(pelagem.cor_cabeca)
	for x in range(xh0, xh1 + 1):
		for y in range(yh0, yh1 + 1):
			for z in range(zh0, zh1 + 1):
				var borda_x := x == xh0 or x == xh1
				var borda_z := z == zh0 or z == zh1
				if borda_x and borda_z and y == yh1:
					continue
				var cor := pelagem.cor_cabeca
				if tem_mascara and x >= xh1 - 1 and y <= yh0 + hy / 2:
					cor = pelagem.cor_mascara
				cabeca[Vector3i(x, y, z)] = _manchado(cor, pelagem, rng)
	var olho_y := yh1 - 1
	for z in [zh0, zh1]:
		cabeca[Vector3i(xh1, olho_y, z)] = Color("141010")
		if marcas >= 2:
			cabeca[Vector3i(xh1, olho_y + 1, z)] = _variar(pelagem.cor_marcas, rng)
	var focinho := raca.comprimento_focinho
	var largura_focinho := _impar(maxi(hz - 2, 1))
	var altura_focinho := maxi(2, hy * 2 / 5)
	var zf0 := -(largura_focinho - 1) / 2
	var xs1 := xh1 + focinho
	for x in range(xh1 + 1, xs1 + 1):
		for y in range(yh0, yh0 + altura_focinho):
			for z in range(zf0, zf0 + largura_focinho):
				var cor := pelagem.cor_mascara if tem_mascara else (pelagem.cor_marcas if marcas >= 1 else pelagem.cor_cabeca)
				cabeca[Vector3i(x, y, z)] = _variar(cor, rng)
	var nariz_y := yh0 + altura_focinho - 1 if focinho > 0 else yh0 + 1
	cabeca[Vector3i(xs1 if focinho > 0 else xh1 + 1, nariz_y, 0)] = pelagem.cor_nariz
	partes.cabeca.pivo = Vector3(xh0 + 0.5, yh0 + 1, 0.5)
	var boca := Vector3(xs1 + 1 - 1.2, yh0 + 1.8, 0.5)

	# --- Orelhas.
	var tamanho_orelha := raca.tamanho_orelha + (2 if pelagem.pelo_longo and raca.orelha == Raca.Orelha.CAIDA else 0)
	for lado: int in [-1, 1]:
		var nome := &"orelha_e" if lado < 0 else &"orelha_d"
		var voxels: Dictionary = partes[nome].voxels
		var z_borda: int = zh0 if lado < 0 else zh1
		match raca.orelha:
			Raca.Orelha.CAIDA:
				var z: int = z_borda + lado
				var comprimento_orelha := mini(3, hx - 1) + (1 if pelagem.pelo_longo else 0)
				for x in range(xh0 + 1, xh0 + 1 + comprimento_orelha):
					for y in range(yh1 - tamanho_orelha + 1, yh1 + 1):
						# Ponta arredondada embaixo.
						if y == yh1 - tamanho_orelha + 1 and (x == xh0 + 1 or x == xh0 + comprimento_orelha):
							continue
						voxels[Vector3i(x, y, z)] = _manchado(pelagem.cor_orelha, pelagem, rng)
				partes[nome].pivo = Vector3(xh0 + 1 + comprimento_orelha * 0.5, yh1 + 1, z + 0.5)
			Raca.Orelha.EM_PE:
				for k in tamanho_orelha:
					var espessura := 2 if k < (tamanho_orelha + 1) / 2 else 1
					for w in espessura:
						var z: int = z_borda - lado * w
						voxels[Vector3i(xh0 + 1, yh1 + 1 + k, z)] = _variar(pelagem.cor_orelha, rng)
						if k == 0:
							voxels[Vector3i(xh0 + 2, yh1 + 1, z)] = _variar(pelagem.cor_orelha, rng)
				partes[nome].pivo = Vector3(xh0 + 1.5, yh1 + 1, z_borda + 0.5)
			Raca.Orelha.DOBRADA:
				for w in 2:
					var z: int = z_borda - lado * w
					voxels[Vector3i(xh0 + 1, yh1 + 1, z)] = _variar(pelagem.cor_orelha, rng)
					voxels[Vector3i(xh0 + 2, yh1 + 1, z)] = _variar(pelagem.cor_orelha, rng)
				voxels[Vector3i(xh0 + 3, yh1, z_borda)] = _variar(pelagem.cor_orelha, rng)
				if tamanho_orelha >= 3:
					voxels[Vector3i(xh0 + 3, yh1 - 1, z_borda)] = _variar(pelagem.cor_orelha, rng)
				partes[nome].pivo = Vector3(xh0 + 2, yh1 + 1, z_borda + 0.5)

	# --- Rabo.
	var rabo: Dictionary = partes.rabo.voxels
	var base := Vector3(x0 - 0.5, y1 - 0.5, 0.5)
	var pontos: Array[Vector3] = []
	match raca.rabo:
		Raca.Rabo.RETO:
			var angulo := deg_to_rad(raca.angulo_rabo)
			var direcao := Vector3(-cos(angulo), sin(angulo), 0)
			var t := 0.0
			while t < raca.comprimento_rabo:
				pontos.append(base + direcao * t)
				t += 0.6
		Raca.Rabo.ENROLADO:
			var raio := maxf(raca.comprimento_rabo / 3.0, 1.5)
			var centro := Vector3(x0 + 0.5, y1 + raio, 0.5)
			var theta := PI * 1.1
			while theta > -PI * 0.35:
				pontos.append(centro + Vector3(cos(theta), sin(theta), 0) * raio)
				theta -= 0.25
		Raca.Rabo.CURTO:
			for t in raca.comprimento_rabo:
				pontos.append(base + Vector3(-0.6, 0.8, 0) * t)
	var celulas: Array[Vector3i] = []
	for p in pontos:
		var celula := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if celula not in celulas:
			celulas.append(celula)
	for i in celulas.size():
		var ponta := i >= celulas.size() - 2
		var cor := pelagem.cor_marcas if ponta and marcas >= 2 else pelagem.cor_pelo
		rabo[celulas[i]] = _manchado(cor, pelagem, rng)
		if pelagem.pelo_longo and i >= 1:
			var franja := celulas[i] + Vector3i.DOWN
			if not rabo.has(franja):
				rabo[franja] = _variar(pelagem.cor_pelo.darkened(0.06), rng)
	partes.rabo.pivo = base

	# Faces coincidentes de partes diferentes piscariam (z-fighting): cada célula fica numa
	# parte só. A cabeça ganha do corpo; o corpo ganha das outras.
	for celula in cabeca:
		corpo.erase(celula)
	for nome in [&"orelha_e", &"orelha_d", &"rabo"]:
		var voxels: Dictionary = partes[nome].voxels
		for celula in voxels.keys():
			if corpo.has(celula) or cabeca.has(celula):
				voxels.erase(celula)

	return {partes = partes, boca = boca}


static func _impar(n: int) -> int:
	return n if n % 2 == 1 else n + 1


## Pequena variação de brilho por voxel, para o pelo não ficar chapado.
static func _variar(cor: Color, rng: RandomNumberGenerator) -> Color:
	var fator := rng.randf_range(-0.045, 0.045)
	return cor.lightened(fator) if fator > 0.0 else cor.darkened(-fator)


static func _manchado(cor: Color, pelagem: Pelagem, rng: RandomNumberGenerator) -> Color:
	if pelagem.manchas > 0.0 and rng.randf() < pelagem.manchas:
		return _variar(pelagem.cor_manchas, rng)
	return _variar(cor, rng)
