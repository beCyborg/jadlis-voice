#!/usr/bin/env bash
# speak.sh — озвучка текста голосом ElevenLabs, тумблером.
#
# Запуск: тап правого Option (правило Karabiner) или вручную из терминала.
#   speak.sh              — читает буфер обмена; повторный запуск останавливает чтение
#   speak.sh --file PATH  — читает текст из файла; повторный запуск останавливает чтение
#   speak.sh --stop       — только остановить чтение, новое не запускать
#
# Голос и модель — как у владельца: Eleven v4, голос Nikolay, темп ×1.25. v3 и v4 параметр
# speed игнорируют, поэтому темп задаётся на воспроизведении (sox tempo, без смены высоты).
# Если в тексте есть блок «🔊 Голосом» (стиль ответа Jadlis Voice), читается только он.
# Перед отправкой текст чистится: разметка, ссылки, код и эмодзи не читаются вслух,
# теги эмоций Eleven v4 вида [warm] остаются, теги-звуки вида [applause] убираются.
#
# Ставится в ~/.local/bin/speak.sh (chmod +x). Ключ ElevenLabs берётся из Связки
# ключей macOS: service `jadlis`, account `ELEVENLABS_API_KEY` (стандарт Jadlis),
# запасной вариант — старая запись service `elevenlabs`, account = имя пользователя.
# Плеер `play` из пакета sox ищется по PATH (`brew install sox`).
#
# Плеер и ключ проверяются ДО платного запроса: нет чего-то — сообщение в лог,
# уведомление на экран и выход с ненулевым кодом, ни одного обращения к API.

set -uo pipefail

# ── Настройки (можно переопределить переменными окружения) ───────────
VOICE_ID="${SPEAK_VOICE_ID:-3EuKHIEZbSzrHGNmdYsx}"   # Nikolay, выбран вслепую на слух
MODEL_ID="${SPEAK_MODEL_ID:-eleven_v4}"
TEMPO="${SPEAK_TEMPO:-1.25}"
LANGUAGE="${SPEAK_LANGUAGE:-ru}"   # без него ответ, начатый английским словом, читается с акцентом
OUTPUT_FORMAT="pcm_24000"
STABILITY=0.0
SIMILARITY=0.85
SEED=4242

PIDFILE="${TMPDIR:-/tmp}/jadlis_speak.pid"
LOGFILE="${SPEAK_LOG:-${TMPDIR:-/tmp}/jadlis-speak.log}"
MODE="${1:-}"

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
    MY_PGID=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
    # группа общая с вызывающим (агент, терминал) — бьём только сам конвейер, не всю группу
    if [ -n "${PGID:-}" ] && [ "$PGID" != "$MY_PGID" ]; then
      log "Stopping playback (PID=$OLD_PID, PGID=$PGID)"
      kill -- -"$PGID" 2>/dev/null || true
    else
      log "Stopping playback (PID=$OLD_PID, shared group)"
      kill_tree() {
        local child
        for child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$child"; done
        kill "$1" 2>/dev/null || true
      }
      kill_tree "$OLD_PID"
    fi
    rm -f "$PIDFILE"
    exit 0
  fi
  rm -f "$PIDFILE"   # осиротевший pid-файл
fi

[ "$MODE" = "--stop" ] && exit 0

TEXT_FILE=""
if [ "$MODE" = "--file" ]; then
  TEXT_FILE="${2:-}"
  [ -n "$TEXT_FILE" ] && [ -r "$TEXT_FILE" ] || fail "--file: не читается файл '$TEXT_FILE'"
elif [ -n "$MODE" ]; then
  fail "неизвестный аргумент '$MODE'"
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/jadlis-speak.XXXXXX")
cleanup() { rm -f "$PIDFILE"; rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 143' TERM INT

# ── Предполётная проверка: плеер ─────────────────────────────────────
PLAY=$(command -v play 2>/dev/null || true)
[ -n "$PLAY" ] || fail "нет плеера play — поставь sox: brew install sox"

# ── Предполётная проверка: ключ ──────────────────────────────────────
API_KEY=$(security find-generic-password -s jadlis -a ELEVENLABS_API_KEY -w 2>/dev/null || true)
if [ -z "${API_KEY:-}" ]; then
  API_KEY=$(security find-generic-password -s elevenlabs -a "$USER" -w 2>/dev/null || true)
fi
[ -n "${API_KEY:-}" ] || fail "нет ключа ElevenLabs в Связке ключей (service jadlis, account ELEVENLABS_API_KEY)"

# ── Текст: файл или буфер обмена ─────────────────────────────────────
if [ -n "$TEXT_FILE" ]; then
  cp -- "$TEXT_FILE" "$WORK/in.txt"
  SOURCE="file $TEXT_FILE"
else
  pbpaste > "$WORK/in.txt" 2>/dev/null || true
  SOURCE="clipboard"
fi

# ── Чистка и нарезка: одна строка JSON на запрос ─────────────────────
# Исходник Python — только ASCII (кириллица через \u): системный python3 на длинной
# кириллице в исходнике может упасть ещё до запуска.
read -r -d '' CLEANER <<'PY'
import json, re, sys

src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
model, voice_settings, extra = sys.argv[2], json.loads(sys.argv[3]), json.loads(sys.argv[4])

# 1. Jadlis Voice: only the voice block is read when the answer has one.
MARK = "\u0433\u043e\u043b\u043e\u0441\u043e\u043c"  # "голосом"
lines = src.split("\n")
for i, line in enumerate(lines):
    bare = re.sub(r"[#>*_\s:\U0001F50A\uFE0F]", "", line).lower()
    if bare == MARK:
        src = "\n".join(lines[i + 1:])
        break

# 2. Block-level markdown.
src = re.sub(r"```.*?(```|$)", " ", src, flags=re.S)           # code blocks are not spoken
src = re.sub(r"<[^>\n]+>", " ", src)                            # html
src = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", src)             # images -> alt
src = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", src)              # links -> text
src = re.sub(r"\[\[([^\]|]+\|)?([^\]]+)\]\]", r"\2", src)       # wikilinks -> name
src = re.sub(r"\[!\s*[\w-]+\s*\][+-]?", " ", src)              # callout markers
src = re.sub(r"\b[a-z][a-z0-9+.-]*://\S+|www\.\S+", " ", src, flags=re.I)  # bare urls

ENDS = ".!?\u2026:"
pieces = []
for line in src.split("\n"):
    s = line.strip()
    if not s or re.fullmatch(r"[-*_=|: ]{3,}", s):
        continue
    s = re.sub(r"^(>\s*)+", "", s)
    s = re.sub(r"^#+\s*", "", s)
    s = re.sub(r"^([-*+]|\d+[.)])\s+", "", s)
    if s.startswith("|"):
        s = ", ".join(c.strip() for c in s.strip("|").split("|") if c.strip())
    s = s.strip()
    if not s:
        continue
    if s[-1] in ",;":
        s = s[:-1] + "."
    elif s[-1] not in ENDS:
        s += "."
    pieces.append(s)
text = " ".join(pieces)

# 3. Characters. Arrows and dashes carry meaning, so they are spoken.
for a, b in (("\u2192", ", \u0437\u0430\u0442\u0435\u043c "), ("\u27f6", ", \u0437\u0430\u0442\u0435\u043c "),
             ("\u2191", " \u0440\u043e\u0441\u0442 "), ("\u2193", " \u0441\u043d\u0438\u0436\u0435\u043d\u0438\u0435 "),
             ("\u2190", ", "), ("\u2014", ", "), ("\u2013", ", "),
             ("%", " \u043f\u0440\u043e\u0446\u0435\u043d\u0442\u043e\u0432")):
    text = text.replace(a, b)
text = re.sub(r"(?<=\s)[-\u2212]+(?=\s)", ",", text)

# 4. Audio tags: v4 performs [warm], [calm, measured]; a tag naming a sound is played as one.
SOUND = set("applause clapping claps cheering crowd audience gunshot gunshots explosion explosions bang "
            "rain thunder wind storm waves ocean water fire crackling music song sings singing melody hums "
            "humming drums guitar piano phone ringing rings doorbell bell bells knock knocks knocking door "
            "footsteps typing keyboard clock ticking beep beeps siren alarm car engine horn glass dog barking "
            "barks cat meows birds chirping fart burp static noise ambience ambient background sfx sound effect".split())

def tag(m):
    inner = m.group(1).strip()
    words = re.findall(r"[A-Za-z]+", inner)
    if any(w.lower() in SOUND for w in words):
        return " "
    parts = [p.split() for p in inner.split(",")]
    ok = (model.startswith("eleven_v4") and 1 <= len(parts) <= 4 and len(inner) <= 48
          and all(1 <= len(p) <= 4 for p in parts)
          and all(len(w) >= 2 and w != w.upper() for p in parts for w in p))
    return "\ue000" + ", ".join(" ".join(p) for p in parts).lower() + "\ue001" if ok else " " + inner + " "

text = re.sub(r"\[\s*([A-Za-z][A-Za-z ,-]{1,63})\s*\]", tag, text)
text = re.sub(r"[*#|`~\[\]]", "", text).replace("_", " ")
text = re.sub("[\u200d\ufe0e\ufe0f\u20e3\u2190-\u21ff\u2300-\u23ff\u2460-\u24ff\u25a0-\u27bf\u2b00-\u2bff"
              "\U0001F000-\U0001FAFF]", "", text)
text = text.replace("\ue000", "[").replace("\ue001", "]")
text = re.sub(r"\s+", " ", text)
text = re.sub(r"\s+([,.;:!?\u2026])", r"\1", text)
text = re.sub(r",(\s*,)+", ",", text)
text = re.sub(r"[,;:]\s*([.!?\u2026])", r"\1", text)
text = re.sub(r"([.!?\u2026])\s*,", r"\1", text)
text = re.sub(r"\.\.+", ".", text)
text = re.sub(r"^[\s,;:.]+", "", text).strip()

# 5. Chunks at sentence ends: eleven_v4 takes 10 000 characters per request, others 5 000.
limit = 10000 if model == "eleven_v4" else 5000
target = limit - 500
chunks, cur = [], ""
for sent in re.split(r"(?<=[.!?\u2026])\s+", text):
    while len(sent) > limit:
        chunks.append(sent[:target]); sent = sent[target:]
    if cur and len(cur) + 1 + len(sent) > target:
        chunks.append(cur); cur = sent
    else:
        cur = (cur + " " + sent).strip()
if cur:
    chunks.append(cur)

for c in chunks:
    payload = {"text": c, "model_id": model, "voice_settings": voice_settings}
    payload.update(extra)
    print(json.dumps(payload, ensure_ascii=False))
PY

VOICE_SETTINGS="{\"stability\": $STABILITY, \"similarity_boost\": $SIMILARITY}"
case "$MODEL_ID" in
  eleven_v4*) ;;
  *) VOICE_SETTINGS="{\"stability\": 0.5, \"similarity_boost\": $SIMILARITY, \"style\": 0, \"use_speaker_boost\": true}" ;;
esac
EXTRA="{\"seed\": $SEED, \"apply_text_normalization\": \"on\", \"language_code\": \"$LANGUAGE\"}"

python3 -c "$CLEANER" "$WORK/in.txt" "$MODEL_ID" "$VOICE_SETTINGS" "$EXTRA" > "$WORK/payloads.jsonl" 2>>"$LOGFILE" \
  || fail "не удалось подготовить текст — подробности в $LOGFILE"

if [ ! -s "$WORK/payloads.jsonl" ]; then
  log "Empty text ($SOURCE), exiting"
  exit 0
fi
log "Text from $SOURCE: $(wc -c < "$WORK/in.txt" | tr -d ' ') bytes, $(wc -l < "$WORK/payloads.jsonl" | tr -d ' ') request(s)"

# ── Поток и воспроизведение в отдельной группе процессов ─────────────
URL="https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}/stream?output_format=${OUTPUT_FORMAT}"
log "Starting TTS request"

(
  while IFS= read -r payload; do
    curl -s --no-buffer -X POST "$URL" \
      -H "xi-api-key: $API_KEY" \
      -H "Content-Type: application/json" \
      --data-binary "$payload" 2>/dev/null
  done < "$WORK/payloads.jsonl" \
  | "$PLAY" -q -t raw -b 16 -e signed-integer -r 24000 -c 1 - tempo "$TEMPO" 2>/dev/null
) &
BG_PID=$!
printf '%s\n' "$BG_PID" > "$PIDFILE"
log "Pipeline started (PID=$BG_PID)"

wait "$BG_PID" 2>/dev/null || true
log "Playback finished"
