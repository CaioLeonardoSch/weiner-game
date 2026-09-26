@tool
class_name Pelagem
extends Resource
## Uma pelagem (skin) de uma raça: só cores e o comprimento do pelo — o formato do corpo
## vem da `Raca`. Trocar de pelagem é trocar a paleta do modelo voxel.

@export var nome := "Pelagem"
## Cor principal do corpo.
@export var cor_pelo := Color("8c4a1f")
## Cabeça (a maioria das raças: igual ao pelo). Ex.: Jack Russell branco de cabeça marrom.
@export var cor_cabeca := Color("8c4a1f")
@export var cor_orelha := Color("5c2e12")
## Marcas: barriga, patas, peito, focinho e "sobrancelhas" (preto e fogo, tricolor...).
@export var cor_marcas := Color("a8622c")
## Quanto das marcas aparece (0 = nada; 1 = barriga, patas, peito e focinho; 2 = também
## as sobrancelhas e a ponta do rabo).
@export_range(0, 2) var marcas := 1
## Máscara do focinho (pug, malinois). Igual à cor da cabeça = sem máscara.
@export var cor_mascara := Color("8c4a1f")
## Malhado (arlequim/dapple): manchas espalhadas com esta cor.
@export var cor_manchas := Color("3a2414")
@export_range(0.0, 0.6) var manchas := 0.0
@export var pelo_longo := false
@export var cor_nariz := Color("1a1414")
