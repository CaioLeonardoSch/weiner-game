@tool
class_name Raca
extends Resource
## Uma raça de cachorro como dado: proporções do modelo voxel, pelagens (skins), velocidade
## e habilidades próprias. As raças ficam em assets/racas/*.tres (edite no inspetor do Godot)
## e a fase escolhe a raça (propriedade "Raça" da fase no editor).
##
## Medidas em voxels de 1/16 m. O cachorro olha para +X; Y é para cima.

enum Orelha { CAIDA, EM_PE, DOBRADA }
enum Rabo { RETO, ENROLADO, CURTO }

@export var id := &"salsicha"
@export var nome := "Salsicha"
@export_multiline var descricao := ""

@export_group("Corpo")
@export_range(6, 20) var comprimento_corpo := 14
@export_range(3, 9) var altura_corpo := 5
## Ímpar fica simétrico em volta do centro.
@export_range(3, 9) var largura_corpo := 5
@export_range(2, 10) var altura_pata := 4
@export_range(1, 3) var grossura_pata := 2

@export_group("Cabeça")
## Comprimento (X), altura (Y) e largura (Z) da cabeça.
@export var cabeca := Vector3i(5, 5, 5)
## Quanto a cabeça fica acima do topo do corpo (pode ser negativo).
@export_range(-3, 6) var altura_pescoco := 1
@export_range(0, 6) var comprimento_focinho := 3
@export var orelha := Orelha.CAIDA
@export_range(1, 8) var tamanho_orelha := 4

@export_group("Rabo")
@export var rabo := Rabo.RETO
@export_range(1, 10) var comprimento_rabo := 5
## Ângulo do rabo reto acima da horizontal (graus; negativo = para baixo).
@export_range(-60, 80) var angulo_rabo := 35.0

@export_group("Jogo")
## Multiplica a velocidade do cachorro.
@export_range(0.5, 2.0) var fator_velocidade := 1.0
## Peso numa placa de pressão (salsicha = 1). Raças gordinhas seguram placas mais pesadas.
@export_range(0.5, 3.0, 0.1) var peso := 1.0
## Cápsula de colisão do corpo (m): a altura decide por onde a raça passa (túneis, frestas).
@export_range(0.15, 0.6, 0.01) var raio_colisao := 0.28
@export_range(0.4, 1.4, 0.05) var altura_colisao := 0.6
## Habilidades que a raça sempre tem, somadas às que a fase libera (mesmos bits de Fase).
@export_flags("Pular", "Cavar", "Latir") var habilidades_nativas := 0
@export var pelagens: Array[Pelagem] = []


## Tamanho de um voxel do modelo, em metros.
const VOXEL := 1.0 / 16.0


func pelagem(indice: int) -> Pelagem:
	if pelagens.is_empty():
		return Pelagem.new()
	return pelagens[clampi(indice, 0, pelagens.size() - 1)]
