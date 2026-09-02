#!/usr/bin/env bash
# docs/claude-code-prompt.md içindeki pazarlığa kapalı kuralları tarar.
# Derleyicinin yerini tutmaz; sadece kolay kaçan ihlalleri yakalar.
#
#   ./scripts/check_rules.sh
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

# Yorum satırlarını ve doc yorumlarını ayıklayarak tarar.
scan() {
  local description=$1 pattern=$2
  shift 2
  local hits=""
  while IFS= read -r -d '' file; do
    local found
    found=$(grep -nE "$pattern" "$file" | grep -vE '^[0-9]+:[[:space:]]*(//|\*)' || true)
    [ -n "$found" ] && hits+="$(echo "$found" | sed "s|^|  $file:|")"$'\n'
  done < <(find "$@" -name '*.swift' -print0)

  if [ -n "$hits" ]; then
    echo "IHLAL — $description"
    printf '%s' "$hits"
    fail=1
  else
    echo "tamam  — $description"
  fi
}

echo "Kod kuralları"
scan "SpriteKit kullanılmamalı"                  '^import SpriteKit'          NotOnMyShift NotOnMyShiftTests
scan "Ekonomi Timer.publish üstüne kurulmamalı"  'Timer\.publish'             NotOnMyShift NotOnMyShiftTests
scan "Force unwrap olmamalı"                     '[A-Za-z0-9_)\]]!([ ,)\.]|$)' NotOnMyShift
scan "force try / force cast olmamalı"           '\btry!|\bas!'               NotOnMyShift
scan "fatalError bırakılmamalı"                  'fatalError\('               NotOnMyShift
scan "Motor saf kalmalı: saat, dosya, kalıcılık yok" \
     '\bDate\(\)|\bTimer\b|UserDefaults|FileManager|Bundle\.' NotOnMyShift/Engine
scan "Motor UI bilmemeli"                        '^import (SwiftUI|UIKit)'    NotOnMyShift/Engine NotOnMyShift/Models

echo
echo "Denge sayıları koda gömülmemeli (Views içinde çıplak sayı arıyoruz)"
hardcoded=$(find NotOnMyShift/Views -name '*.swift' -exec \
  grep -nE '(cost|price|rate|capacity|seconds|revenue)[A-Za-z]*[[:space:]]*=[[:space:]]*[0-9]' {} + 2>/dev/null || true)
if [ -n "$hardcoded" ]; then
  echo "IHLAL — View içinde denge sayısı:"; echo "$hardcoded" | sed 's/^/  /'; fail=1
else
  echo "tamam  — View'larda denge sayısı yok"
fi

echo
echo "Kullanılan modüller (üçüncü parti olmamalı):"
grep -rhE '^import ' NotOnMyShift NotOnMyShiftTests --include='*.swift' | sort -u | sed 's/^/  /'

echo
if [ "$fail" -ne 0 ]; then
  echo "Kural ihlali var."
  exit 1
fi
echo "Tüm kurallar geçti."
