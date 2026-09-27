@tool
class_name Regiao
extends Resource
## Uma região do jogo: agrupa fases com um tema e uma pequena história (ver ROADMAP, "Regiões e
## história"). As regiões ficam em assets/regioes/*.tres; cada fase diz a sua (`Fase.regiao`,
## no painel da fase do editor) e o menu mostra as fases agrupadas, na `ordem` das regiões.

@export var id := &"floresta"
@export var nome := "Floresta"
@export_multiline var descricao := ""
## Posição da região no menu (e na sequência "próxima fase").
@export var ordem := 0
## Bioma sugerido para as fases novas da região (ver Biomas).
@export_enum("Floresta", "Neve") var bioma := 0
