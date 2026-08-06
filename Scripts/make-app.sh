#!/bin/sh
# Собирает Flowbar.app из бинарника SPM. ADR-0006: Xcode-проекта в репозитории нет.
# Использование: Scripts/make-app.sh [debug|release]

set -eu

configuration="${1:-debug}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$root/build/Flowbar.app"

swift build --package-path "$root" -c "$configuration"
bin="$(swift build --package-path "$root" -c "$configuration" --show-bin-path)"

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"

cp "$bin/Flowbar" "$bundle/Contents/MacOS/Flowbar"
cp "$root/App/Resources/Info.plist" "$bundle/Contents/Info.plist"

if ls "$root/App/Resources/Fonts"/*.ttf >/dev/null 2>&1; then
  mkdir -p "$bundle/Contents/Resources/Fonts"
  cp "$root/App/Resources/Fonts"/*.ttf "$bundle/Contents/Resources/Fonts/"
else
  echo "ВНИМАНИЕ: InterVariable.ttf не найден в App/Resources/Fonts." >&2
  echo "Интерфейс наберётся системным шрифтом — это не то, что в макете (спека §5)." >&2
fi

# Локальная подпись ad-hoc: без неё песочница не включится и приложение не запустится.
codesign --force --sign - \
  --entitlements "$root/App/Resources/Flowbar.entitlements" \
  "$bundle"

echo "готово: $bundle"
