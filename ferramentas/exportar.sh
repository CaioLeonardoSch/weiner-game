#!/usr/bin/env bash
# Exporta o jogo para Windows, Linux e macOS em build/ e gera um .zip de cada um.
# Uso: ferramentas/exportar.sh [Windows|Linux|macOS ...]   (sem argumentos: todos)
# Precisa dos templates de exportação do Godot (no editor: Editor → Gerenciar Templates de
# Exportação → Baixar). O Godot usado é $GODOT (padrão: "godot" no PATH).
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSAO=$(grep -m1 '^config/version=' project.godot | cut -d'"' -f2)
if [ $# -gt 0 ]; then alvos=("$@"); else alvos=(Windows Linux macOS); fi

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
for alvo in "${alvos[@]}"; do
	case "$alvo" in
		Windows) pasta=build/windows; arquivo=WeinerGame.exe ;;
		Linux) pasta=build/linux; arquivo=WeinerGame.x86_64 ;;
		macOS) pasta=build/macos; arquivo=WeinerGame.zip ;;
		*) echo "Alvo desconhecido: $alvo"; exit 1 ;;
	esac
	rm -rf "$pasta" && mkdir -p "$pasta"
	echo "Exportando $alvo..."
	"$GODOT" --headless --path . --export-release "$alvo" "$pasta/$arquivo" 2>&1 \
		| grep -E "^(ERROR|WARNING)" -A1 | grep -v "^$" || true
	[ -f "$pasta/$arquivo" ] || { echo "Falhou: $pasta/$arquivo não foi criado"; exit 1; }
	if [ "$alvo" = macOS ]; then
		mv "$pasta/$arquivo" "build/WeinerGame-$VERSAO-macos.zip"
	else
		(cd "$pasta" && zip -q -r "../WeinerGame-$VERSAO-$(echo "$alvo" | tr 'A-Z' 'a-z').zip" .)
	fi
done
echo "Pronto:"
ls -lh build/*.zip
