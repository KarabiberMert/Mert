#!/usr/bin/env bash
# Mac'te tek komutluk kapı: denetçiler → derleme → testler.
# İlk başarısızlıkta durur. Her düzeltmeden sonra yeniden çalıştır.
#
#   ./scripts/mac_kapi.sh                  denetçiler + derleme + testler
#   ./scripts/mac_kapi.sh --derle          denetçiler + derleme
#   ./scripts/mac_kapi.sh --sadece-denetci sadece denetçiler (Mac gerekmez)
#
# Simülatör adı tutmuyorsa:
#   DEST='platform=iOS Simulator,name=iPhone 15' ./scripts/mac_kapi.sh

set -uo pipefail
cd "$(dirname "$0")/.."

DEST="${DEST:-platform=iOS Simulator,name=iPhone 16 Pro Max}"
PROJE="NotOnMyShift.xcodeproj"
SEMA="NotOnMyShift"
KAYIT="build/kapi"
mkdir -p "$KAYIT"

adim()  { printf '\n\033[1m── %s\033[0m\n' "$1"; }
tamam() { printf '   \033[32m✓\033[0m %s\n' "$1"; }
hata()  { printf '   \033[31m✗\033[0m %s\n' "$1"; exit 1; }

# --- Denetçiler ----------------------------------------------------------

adim "Denetçiler"
./scripts/check_rules.sh          >/dev/null 2>&1 || hata "check_rules.sh — kural ihlali var, çıktıyı gör: ./scripts/check_rules.sh"
tamam "kod kuralları"
python3 scripts/check_localization.py >/dev/null || hata "check_localization.py — dil dosyaları tutmuyor"
tamam "dil dosyaları"
python3 scripts/lint_pbxproj.py   >/dev/null || hata "lint_pbxproj.py — proje dosyası bozuk"
tamam "proje dosyası"
python3 scripts/check_store_copy.py >/dev/null || hata "check_store_copy.py — mağaza metinleri sınırı aşıyor"
tamam "mağaza metinleri"

[ "${1:-}" = "--sadece-denetci" ] && { printf '\nDenetçiler temiz.\n'; exit 0; }

command -v xcodebuild >/dev/null || hata "xcodebuild yok — bu adım Mac gerektiriyor"

# --- Derleme -------------------------------------------------------------

adim "Derleme"
echo "   hedef: $DEST"
if ! xcodebuild -project "$PROJE" -scheme "$SEMA" -destination "$DEST" \
      build > "$KAYIT/derleme.log" 2>&1; then
    printf '\n'
    grep -E "error:" "$KAYIT/derleme.log" | head -30
    printf '\n'
    hata "derleme kaldı — tam kayıt: $KAYIT/derleme.log"
fi

# Uyarı sayısı: sadece bizim dosyalarımız. CLAUDE.md "uyarı bırakma" diyor.
UYARI=$(grep -E "warning:" "$KAYIT/derleme.log" | grep -c "NotOnMyShift" || true)
if [ "$UYARI" -gt 0 ]; then
    printf '\n'
    grep -E "warning:" "$KAYIT/derleme.log" | grep "NotOnMyShift" | head -20
    printf '\n'
    hata "$UYARI uyarı var — CLAUDE.md uyarı bırakmayı yasaklıyor"
fi
tamam "derleme temiz, uyarı yok"

[ "${1:-}" = "--derle" ] && { printf '\nDerleme geçti.\n'; exit 0; }

# --- Testler -------------------------------------------------------------

adim "Testler"
if ! xcodebuild -project "$PROJE" -scheme "$SEMA" -destination "$DEST" \
      test > "$KAYIT/test.log" 2>&1; then
    printf '\n'
    grep -E "error:|failed" "$KAYIT/test.log" | head -30
    printf '\n'
    hata "testler kaldı — tam kayıt: $KAYIT/test.log"
fi
GECEN=$(grep -cE "^Test Case .* passed" "$KAYIT/test.log" || true)
tamam "$GECEN test geçti"

printf '\n\033[32mKapı açık.\033[0m Denetçiler, derleme ve testler temiz.\n'
