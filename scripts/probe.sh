#!/usr/bin/env bash
# probe.sh — состояние голосового контура одним машиночитаемым блоком `имя=значение`.
#
# Ничего не меняет и не печатает значений ключей: только имена и факт наличия.
# Живой домен настроек Spokenly адресуется ПУТЁМ К ФАЙЛУ: бандл-id `app.spokenly`
# ведёт в старый sandbox-контейнер (приложение вышло из песочницы в 08.2026).

set -uo pipefail

PLIST="$HOME/Library/Preferences/app.spokenly.plist"
SERVICE="jadlis"
RULE_DESC="Tap right_option alone to trigger F18 (ElevenLabs TTS)"
KARABINER_JSON="$HOME/.config/karabiner/karabiner.json"
SPEAK="$HOME/.local/bin/speak.sh"

say() { printf '%s=%s\n' "$1" "$2"; }

# — приложение и его настройки —
if [ -d /Applications/Spokenly.app ]; then say spokenly_app yes; else say spokenly_app no; fi
if [ -f "$PLIST" ]; then say spokenly_plist yes; else say spokenly_plist no; fi
if pgrep -x Spokenly >/dev/null 2>&1; then say spokenly_running yes; else say spokenly_running no; fi

onboarding=unknown
model=unknown
replacements=0
providers=0
prompt_chars=0
if [ -f "$PLIST" ]; then
  onboarding=$(plutil -extract hasCompletedOnboarding raw -o - "$PLIST" 2>/dev/null || echo unknown)
  model=$(plutil -extract transcriptionModelID raw -o - "$PLIST" 2>/dev/null | base64 -d 2>/dev/null | tr -d '"' || echo unknown)
  [ -n "$model" ] || model=unknown
  counts=$(python3 - "$PLIST" <<'PY' 2>/dev/null || echo "0 0 0"
import json, plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
def env(key):
    raw = d.get(key)
    return json.loads(raw)["envelope"] if raw else None
wr = env("wordReplacements.v2")
ap = env("aiProviders.v1")
md = env("modes.v2")
prompt = md["items"][0]["value"].get("prompt", "") if md and md.get("items") else ""
print(len(wr["items"]) if wr else 0, len(ap["items"]) if ap else 0, len(prompt))
PY
)
  replacements=$(printf '%s' "$counts" | awk '{print $1+0}')
  providers=$(printf '%s' "$counts" | awk '{print $2+0}')
  prompt_chars=$(printf '%s' "$counts" | awk '{print $3+0}')
fi
say spokenly_onboarding "$onboarding"
say spokenly_transcription_model "$model"
say spokenly_word_replacements "$replacements"
say spokenly_ai_providers "$providers"
say spokenly_prompt_chars "$prompt_chars"

# — ключи: только имена, значения не печатаются и не сохраняются —
for name in ELEVENLABS_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY; do
  if security find-generic-password -s "$SERVICE" -a "$name" -w >/dev/null 2>&1; then
    say "key_$name" yes
  else
    say "key_$name" no
  fi
done

# — ветка озвучки (необязательная) —
if command -v play >/dev/null 2>&1; then say play_binary yes; else say play_binary no; fi
if [ -d /Applications/Karabiner-Elements.app ]; then say karabiner_app yes; else say karabiner_app no; fi
if [ -x "$SPEAK" ]; then say speak_sh executable
elif [ -f "$SPEAK" ]; then say speak_sh present_not_executable
else say speak_sh no; fi
if [ -f "$KARABINER_JSON" ] && grep -Fq "$RULE_DESC" "$KARABINER_JSON" 2>/dev/null; then
  say karabiner_rule yes
else
  say karabiner_rule no
fi

# — сводка: диктовка готова / озвучка готова —
dictation=no
if [ -d /Applications/Spokenly.app ] && [ "$model" = "elevenlabs-api" ] \
   && [ "$replacements" -ge 1 ] && [ "$providers" -ge 1 ] && [ "$prompt_chars" -ge 1 ]; then
  dictation=yes
fi
say dictation_ready "$dictation"
readaloud=no
if command -v play >/dev/null 2>&1 && [ -x "$SPEAK" ] \
   && [ -f "$KARABINER_JSON" ] && grep -Fq "$RULE_DESC" "$KARABINER_JSON" 2>/dev/null; then
  readaloud=yes
fi
say readaloud_ready "$readaloud"
