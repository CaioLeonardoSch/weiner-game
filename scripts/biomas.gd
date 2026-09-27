@tool
class_name Biomas
## Biomas: o "clima" de uma fase (`Fase.bioma`). O bioma escolhe a biblioteca de tiles (mesmos
## tiles, outras texturas — ver Tiles.MATERIAIS_POR_BIOMA), o céu e a luz, o chão e as árvores
## do entorno e se neva. Objetos que mudam com o bioma (árvores e pedras com neve, o montinho
## do graveto enterrado...) usam `ObjetoFase.bioma_da_fase()` e `ao_mudar_bioma()`.
##
## Para um bioma novo: uma constante, o nome em NOMES (e em `Fase.bioma`), os dados em `dados()`
## e, se trocar materiais dos tiles, uma biblioteca em Tiles.BIBLIOTECAS/MATERIAIS_POR_BIOMA.

const FLORESTA := 0
const NEVE := 1
const NOMES := ["Floresta", "Neve"]

## Cores da neve que cobre árvores, pedras e montinhos.
const CORES_NEVE := [Color("f4f7fb"), Color("e8eef6"), Color("dde6f1")]


## Céu, luz e entorno de cada bioma.
static func dados(bioma: int) -> Dictionary:
	match bioma:
		NEVE:
			return {
				chao = "res://assets/materiais/neve.tres",
				ceu_topo = Color(0.55, 0.65, 0.78), ceu_horizonte = Color(0.86, 0.89, 0.94),
				luz = Color(0.92, 0.95, 1.0), energia_luz = 0.95, nevando = true,
			}
		_:
			return {
				chao = "res://assets/materiais/grama.tres",
				ceu_topo = Color(0.32, 0.52, 0.85), ceu_horizonte = Color(0.72, 0.82, 0.92),
				luz = Color(1, 1, 1), energia_luz = 1.0, nevando = false,
			}


## Aplica o céu e a luz do bioma numa instância de scenes/ambiente.tscn (o ambiente é copiado:
## o recurso da cena é compartilhado e não pode ficar com o céu de outra fase).
static func aplicar_ambiente(ambiente: Node, bioma: int) -> void:
	if ambiente == null:
		return
	var d := dados(bioma)
	var mundo := ambiente.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if mundo and mundo.environment:
		mundo.environment = mundo.environment.duplicate(true)
		var ceu := mundo.environment.sky.sky_material as ProceduralSkyMaterial
		if ceu:
			ceu.sky_top_color = d.ceu_topo
			ceu.sky_horizon_color = d.ceu_horizonte
			ceu.ground_horizon_color = d.ceu_horizonte
	var sol := ambiente.get_node_or_null(^"Sol") as DirectionalLight3D
	if sol:
		sol.light_color = d.luz
		sol.light_energy = d.energia_luz


## Flocos de neve caindo numa caixa de 44 m em volta de onde for posta (quem cria move a caixa
## junto com a câmera). Flocos em coordenadas do mundo: andar não arrasta a neve junto.
static func criar_neve_caindo() -> CPUParticles3D:
	var neve := CPUParticles3D.new()
	neve.name = "NeveCaindo"
	var floco := BoxMesh.new()
	floco.size = Vector3.ONE * 0.06
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.97, 0.98, 1.0)
	floco.material = material
	neve.mesh = floco
	neve.amount = 1400
	neve.lifetime = 9.0
	neve.preprocess = 9.0
	neve.local_coords = false
	neve.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	neve.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	neve.direction = Vector3(0.25, -1.0, 0.1)
	neve.spread = 12.0
	neve.gravity = Vector3(0.0, -0.4, 0.0)
	neve.initial_velocity_min = 1.0
	neve.initial_velocity_max = 1.6
	neve.scale_amount_min = 0.6
	neve.scale_amount_max = 1.3
	neve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	neve.position = Vector3.UP * 12.0
	return neve
