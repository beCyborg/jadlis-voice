#!/usr/bin/env bash
# keys.sh — ключи голосового контура в Связке ключей macOS (Keychain).
#
# Стандарт хранения тот же, что у плагина jadlis-search (scripts/secret.sh):
# generic password, service `jadlis`, account = имя ключа.
#   ELEVENLABS_API_KEY  — распознавание речи и озвучка (обязателен)
#   ANTHROPIC_API_KEY   — чистка распознанного текста (обязателен)
#   OPENAI_API_KEY      — резерв чистки (необязателен)
#
# ЗНАЧЕНИЯ КЛЮЧЕЙ НЕ ПЕЧАТАЮТСЯ НИКОГДА И НЕ ПЕРЕДАЮТСЯ АРГУМЕНТОМ.
# `set` читает значение со stdin или скрытым вводом с терминала.

set -uo pipefail

SERVICE="jadlis"
REQUIRED="ELEVENLABS_API_KEY ANTHROPIC_API_KEY"
OPTIONAL="OPENAI_API_KEY"
KNOWN="$REQUIRED $OPTIONAL"

err() { printf '%s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
keys.sh — ключи голосового контура в Связке ключей macOS.

  keys.sh check              какие ключи заведены (имена и длины, без значений)
  keys.sh set NAME           записать ключ: значение со stdin или скрытым вводом
  keys.sh has NAME           код возврата 0, если ключ есть (ничего не печатает)

NAME ∈ ELEVENLABS_API_KEY | ANTHROPIC_API_KEY | OPENAI_API_KEY

Примеры:
  bash scripts/keys.sh set ELEVENLABS_API_KEY          # спросит скрытым вводом
  pbpaste | bash scripts/keys.sh set ANTHROPIC_API_KEY # значение из буфера обмена
USAGE
}

need_security() {
  command -v security >/dev/null 2>&1 && return 0
  err "keys.sh: утилиты security нет — это не macOS"
  return 2
}

known_name() {
  case " $KNOWN " in *" $1 "*) return 0 ;; esac
  err "keys.sh: неизвестное имя ключа «$1» (ожидается одно из: $KNOWN)"
  return 2
}

read_key() { security find-generic-password -s "$SERVICE" -a "$1" -w 2>/dev/null; }

mode_has() {
  known_name "$1" || return 2
  need_security || return 2
  v=$(read_key "$1") || return 1
  [ -n "${v:-}" ]
}

mode_check() {
  need_security || return 2
  rc=0
  for key in $KNOWN; do
    case " $OPTIONAL " in *" $key "*) tag="необязательный" ;; *) tag="обязательный" ;; esac
    v=$(read_key "$key")
    if [ -n "${v:-}" ]; then
      printf '  %-20s есть, длина %s (%s)\n' "$key" "${#v}" "$tag"
    else
      printf '  %-20s НЕТ (%s)\n' "$key" "$tag"
      case " $REQUIRED " in *" $key "*) rc=1 ;; esac
    fi
    unset v
  done
  return $rc
}

mode_set() {
  key="$1"
  known_name "$key" || return 2
  need_security || return 2
  if [ -t 0 ]; then
    printf 'Вставь значение %s (ввод не отображается), затем Enter: ' "$key" >&2
    IFS= read -r -s value || true
    printf '\n' >&2
  else
    IFS= read -r value || true
  fi
  value=$(printf '%s' "${value:-}" | tr -d '[:space:]')
  if [ -z "$value" ]; then
    err "keys.sh set $key: пустое значение — ничего не записано"
    return 2
  fi
  if security add-generic-password -U -s "$SERVICE" -a "$key" -T /usr/bin/security \
       -w "$value" >/dev/null 2>&1; then
    printf 'OK: %s записан в Связку ключей (длина %s)\n' "$key" "${#value}"
    unset value
    return 0
  fi
  unset value
  err "FAIL: $key не записан (security add-generic-password вернул ошибку)"
  return 1
}

main() {
  [ $# -ge 1 ] || { usage >&2; exit 2; }
  case "$1" in
    check)     mode_check ;;
    set)       shift; [ $# -eq 1 ] || { usage >&2; exit 2; }; mode_set "$1" ;;
    has)       shift; [ $# -eq 1 ] || { usage >&2; exit 2; }; mode_has "$1" ;;
    -h|--help) usage ;;
    *)         usage >&2; exit 2 ;;
  esac
}

main "$@"
