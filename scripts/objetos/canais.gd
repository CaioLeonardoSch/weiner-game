class_name Canais
## Canais ligam quem aciona (placa de pressão; depois alavancas, pássaros no contrapeso) a quem
## reage (portão; depois comporta, ponte levadiça...). Cada canal é uma COR: a placa azul abre
## o portão azul — o jogador vê o que liga com o quê sem precisar de explicação.
## O estado dos canais de uma fase fica na própria Fase (`definir_fonte`, `canal_ativo`).

const LISTA := [
	["Amarelo", Color("f2c94c")],
	["Azul", Color("4a90e2")],
	["Vermelho", Color("e0564a")],
	["Verde", Color("6cc24a")],
	["Roxo", Color("a66be0")],
	["Laranja", Color("f2994a")],
	["Ciano", Color("4ad0d0")],
	["Rosa", Color("f07fb4")],
]
## Para @export_enum dos objetos (placa, portão...).
const NOMES_ENUM := "Amarelo,Azul,Vermelho,Verde,Roxo,Laranja,Ciano,Rosa"


static func cor(canal: int) -> Color:
	return LISTA[clampi(canal, 0, LISTA.size() - 1)][1]


static func nome(canal: int) -> String:
	return LISTA[clampi(canal, 0, LISTA.size() - 1)][0]
