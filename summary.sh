#!/usr/bin/env bash
set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
_reset=`tput sgr0`

echo "$(whoami)@$(hostname):"
echo ""

shopt -s nullglob
for filename in "$HOME"/.lightweight-healthcheck/*.log; do
	if tail -n 1 "$filename" | grep -c -v "| OK" >/dev/null ; then
		status=$(tail -n 1 "$filename" | awk '{print $NF}')
		at=$(tail -n 1 "$filename" | cut -d ' ' -f 1-3)
		echo -e "${red}$(basename "$filename" .log): $status${_reset}  (since $at)"
	else
		echo -e "$(basename "$filename" .log): ${green}OK${_reset}"
	fi
done
shopt -u nullglob
