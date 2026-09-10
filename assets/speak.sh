#!/usr/bin/env bash
# speak.sh — озвучка буфера обмена голосом ElevenLabs, тумблером.
#
# Запуск: тап правого Option (правило Karabiner) или вручную из терминала.
# Первый вызов — читает буфер обмена вслух, второй — останавливает чтение.
#
# Ставится в ~/.local/bin/speak.sh (chmod +x). Ключ ElevenLabs берётся из Связки
# ключей macOS: service `jadlis`, account `ELEVENLABS_API_KEY` (стандарт Jadlis),
# запасной вариант — старая запись service `elevenlabs`, account = имя пользователя.
# Плеер `play` из пакета sox ищется по PATH (`brew install sox`).
#
# Плеер и ключ проверяются ДО платного запроса: нет чего-то — сообщение в лог,
# уведомление на экран и выход с ненулевым кодом, ни одного обращения к API.

set -euo pipefail

# ── Настройки (можно переопределить переменными окружения) ───────────
VOICE_ID="${SPEAK_VOICE_ID:-15CVCzDByBinCIoCblXo}"
MODEL_ID="${SPEAK_MODEL_ID:-eleven_v3}"
OUTPUT_FORMAT="pcm_24000"
MAX_CHARS="${SPEAK_MAX_CHARS:-5000}"

STABILITY=0.30
SIMILARITY=0.85
STYLE=0.0
SPEAKER_BOOST=true
SPEED=1.20   # максимум, который принимает ElevenLabs; выше — HTTP 400

PIDFILE="${TMPDIR:-/tmp}/jadlis_speak.pid"
LOGFILE="${SPEAK_LOG:-${TMPDIR:-/tmp}/jadlis-speak.log}"

# ── Логи и уведомления ───────────────────────────────────────────────
log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOGFILE"; }

notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"speak.sh\"" >/dev/null 2>&1 || true
}

fail() {
  log "ERROR: $1"
  notify "$1"
  exit 1
}

# ── Тумблер: если уже читает — остановить и выйти ────────────────────
if [ -f "$PIDFILE" ]; then
  OLD_PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    PGID=$(ps -o pgid= -p "$OLD_PID" 2>/dev/null | tr -d ' ')
    if [ -n "${PGID:-}" ]; then
      log "Stopping playback (PID=$OLD_PID, PGID=$PGID)"
      kill -- -"$PGID" 2>/dev/null || true
    else
      kill "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
    exit 0
  fi
  rm -f "$PIDFILE"   # осиротевший pid-файл
fi

cleanup() { rm -f "$PIDFILE"; }
trap cleanup EXIT INT TERM

# ── Предполётная проверка: плеер ─────────────────────────────────────
PLAY=$(command -v play 2>/dev/null || true)
[ -n "$PLAY" ] || fail "нет плеера play — поставь sox: brew install sox"

# ── Предполётная проверка: ключ ──────────────────────────────────────
API_KEY=$(security find-generic-password -s jadlis -a ELEVENLABS_API_KEY -w 2>/dev/null || true)
if [ -z "${API_KEY:-}" ]; then
  API_KEY=$(security find-generic-password -s elevenlabs -a "$USER" -w 2>/dev/null || true)
fi
[ -n "${API_KEY:-}" ] || fail "нет ключа ElevenLabs в Связке ключей (service jadlis, account ELEVENLABS_API_KEY)"

# ── Текст из буфера обмена ───────────────────────────────────────────
TEXT=$(pbpaste 2>/dev/null || true)
if [ -z "${TEXT//[[:space:]]/}" ]; then
  log "Empty clipboard, exiting"
  exit 0
fi

if [ "${#TEXT}" -gt "$MAX_CHARS" ]; then
  log "WARNING: text truncated from ${#TEXT} to $MAX_CHARS chars"
  TEXT="${TEXT:0:$MAX_CHARS}"
fi
log "Text length: ${#TEXT} chars"

# ── Тело запроса ─────────────────────────────────────────────────────
TEXT_ESCAPED=$(printf '%s' "$TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
PAYLOAD=$(cat <<JSON
{
  "text": $TEXT_ESCAPED,
  "model_id": "$MODEL_ID",
  "apply_text_normalization": "on",
  "voice_settings": {
    "stability": $STABILITY,
    "similarity_boost": $SIMILARITY,
    "style": $STYLE,
    "use_speaker_boost": $SPEAKER_BOOST,
    "speed": $SPEED
  }
}
JSON
)

# ── Поток и воспроизведение в отдельной группе процессов ─────────────
URL="https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}/stream?output_format=${OUTPUT_FORMAT}"
log "Starting TTS request"

(
  curl -s --no-buffer -X POST "$URL" \
    -H "xi-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null \
  | "$PLAY" -t raw -b 16 -e signed-integer -r 24000 -c 1 - 2>/dev/null
) &
BG_PID=$!
printf '%s\n' "$BG_PID" > "$PIDFILE"
log "Pipeline started (PID=$BG_PID)"

wait "$BG_PID" 2>/dev/null || true
log "Playback finished"
