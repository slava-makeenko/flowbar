#!/bin/sh
# Проверяет, что слои не импортируют запрещённое.
#
# Компилятор этого не ловит. SPM ограничивает только межтаргетные зависимости:
# `import FlowbarData` в Domain падает, а `import AppKit` собирается — системные
# фреймворки доступны любому таргету независимо от объявленных зависимостей.
# Обоснование и замер — ADR-0007.
#
# Список разрешённого, а не запрещённого: новый системный фреймворк должен
# споткнуться о проверку, а не проскользнуть мимо неё.

set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

check_layer() {
  layer="$1"
  allowed="$2"
  directory="$root/Sources/$layer"

  [ -d "$directory" ] || return 0

  found="$(
    grep -rhoE '^import +[A-Za-z_][A-Za-z0-9_]*' "$directory" 2>/dev/null |
      sed -E 's/^import +//' | sort -u | grep -vxE "$allowed" || true
  )"

  if [ -n "$found" ]; then
    echo "$layer импортирует запрещённое:" >&2
    echo "$found" | sed 's/^/  /' >&2
    status=1
  fi
}

check_layer FlowbarDomain 'Foundation'
check_layer FlowbarPresentation 'Foundation|Observation|FlowbarDomain'
check_layer FlowbarTestSupport 'Foundation|FlowbarDomain'

[ "$status" -eq 0 ] && echo "границы слоёв: чисто"
exit "$status"
