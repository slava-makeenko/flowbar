#!/bin/sh
# Литерал цвета или размера вне FlowbarDesignSystem — дефект. Регламент §6.
#
# Компилятор такое не ловит: `Color.white.opacity(0.05)` и `.frame(width: 44)` — валидный
# Swift где угодно. Проверка механическая и намеренно узкая: ловит построение цвета и
# числа в геометрических модификаторах, а не любое число в коде.

set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

# Путь к репозиторию может содержать пробелы, поэтому каталоги не собираются в строку,
# а перебираются по одному.
scan() {
  directory="$1"
  pattern="$2"
  [ -d "$directory" ] || return 0
  grep -rnE "$pattern" "$directory" 2>/dev/null | grep -vE ':[[:space:]]*//' || true
}

collect() {
  pattern="$1"
  scan "$root/Sources/FlowbarUI" "$pattern"
  scan "$root/Sources/FlowbarPresentation" "$pattern"
  scan "$root/App" "$pattern"
}

report() {
  title="$1"
  found="$2"
  if [ -n "$found" ]; then
    echo "$title:" >&2
    echo "$found" | sed "s|$root/||" | sed 's/^/  /' >&2
    status=1
  fi
}

colors="$(collect '(Color|NSColor)\(|Color\.(white|black|red|green|blue|gray|orange|yellow)')"
report "литералы цвета вне DesignSystem" "$colors"

# Ноль не токен, а утверждение «без отступа», поэтому цифра должна быть значащей:
# `spacing: 0` пропускается, `spacing: 10` — нет.
sizes="$(collect '\.(frame|padding|cornerRadius|offset)\([^)]*[1-9]|spacing: *[0-9]*[1-9]')"
report "литералы размера вне DesignSystem" "$sizes"

[ "$status" -eq 0 ] && echo "токены: чисто"
exit "$status"
