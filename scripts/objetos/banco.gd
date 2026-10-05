@tool
class_name Banco
extends ObjetoFase
## Banco de praça do parque (olha para +Z). O dono senta nele (Dono `sentado`, posto na origem
## do banco e com o mesmo giro) enquanto o cachorro brinca.


func nome_no_editor() -> String:
	return "Banco"


func categoria_no_editor() -> String:
	return "Parque"


## Onde o dono fica de pé, ao lado do banco, antes de sentar e depois de levantar (global).
func lugar_em_pe() -> Vector3:
	return to_global(Vector3(0.5, 0.0, 1.0))
