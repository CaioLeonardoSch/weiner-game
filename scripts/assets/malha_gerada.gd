@tool
class_name MalhaGerada
extends MeshInstance3D
## MeshInstance3D cuja malha é gerada por código (modelos voxel).
## A malha nunca é gravada na cena: ela é refeita ao carregar, a partir dos parâmetros.


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE
