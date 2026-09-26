#!/usr/bin/env bash
# Joga todas as fases com as rotas de ferramentas/testes/rotas/ (sem janela) e mostra o resultado.
# Uso: ferramentas/testar_fases.sh [fase_02 ...]      (sem argumentos: todas)
# O Godot usado é $GODOT (padrão: "godot" no PATH).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ROTAS=ferramentas/testes/rotas
if [ $# -gt 0 ]; then nomes=("$@"); else nomes=($(ls "$ROTAS" | sed 's/\.txt$//')); fi

# Primeiro uma importação, para os recursos e as classes estarem em dia.
"$GODOT" --headless --path . --import > /dev/null 2>&1

falhas=0
for nome in "${nomes[@]}"; do
	inicio=$(date +%s)
	saida=$("$GODOT" --headless --path . --fixed-fps 60 \
		--script res://ferramentas/testes/roteiro.gd -- "@$ROTAS/$nome.txt" 2>&1)
	codigo=$?
	segundos=$(( $(date +%s) - inicio ))
	if [ $codigo -eq 0 ] && echo "$saida" | grep -q "RESULTADO: passou"; then
		echo "✓ $nome (${segundos}s)"
	else
		falhas=$((falhas + 1))
		echo "✗ $nome (${segundos}s)"
		echo "$saida" | grep -E "FALHOU|SCRIPT ERROR|ERROR: .*res://|RESULTADO" | head -20 | sed 's/^/    /'
	fi
done
[ $falhas -eq 0 ] && echo "Todas as fases passaram." || echo "$falhas fase(s) falharam."
exit $falhas
