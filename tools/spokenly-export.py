#!/usr/bin/env python3
"""spokenly-export.py — owner-side: turn the live Spokenly preferences into a key-free template.

Usage: python3 tools/spokenly-export.py [--out assets/spokenly-template.plist]

Reads ~/Library/Preferences/app.spokenly.plist (the live, non-sandboxed domain), keeps only the
settings that describe the dictation contour, replaces every API key with a placeholder and
writes an XML plist. Gate: the output must not contain any live key value or `sk_`/`sk-`.

Placeholders: {{ELEVENLABS_API_KEY}}  {{ANTHROPIC_API_KEY}}  {{OPENAI_API_KEY}}
"""
from __future__ import annotations
import argparse, json, plistlib, re, sys
from pathlib import Path

LIVE = Path.home() / "Library/Preferences/app.spokenly.plist"

# Scalars copied as-is.
KEEP_SCALARS = {
    "settingsVersion", "hasCompletedOnboarding", "onboarding.didClickFinish", "isFirstLaunch",
    "textTypingMode", "muteWhileRecording", "pauseMediaWhileRecording", "vadTrimEnabled",
    "useSystemDefaultMicrophone", "showInStatusBar", "enableSendWithReturnKey", "enableMCP",
    "hideGetIOSApp", "hideCodexIntegration", "hideCursorIntegration", "hideNoAudioSignalAlert",
    "hideSilentMicrophoneError",
}
# JSON-in-Data fields copied (with key substitution / envelope reset).
KEEP_JSON = {
    "modes.v2", "aiProviders.v1", "dictationCredential.elevenlabs-api.v1",
    "modelSettings.elevenlabs-api.v1", "wordReplacements.v2", "transcriptionModelID",
    "fileTranscriptionVoiceModelID", "appleTranscriptionLocale",
}
PROVIDER_PLACEHOLDER = {"anthropic": "{{ANTHROPIC_API_KEY}}", "openai": "{{OPENAI_API_KEY}}"}


def reset_envelope(obj):
    if isinstance(obj, dict):
        if "dirty" in obj:
            obj["dirty"] = False
        if "serverVersion" in obj:
            obj["serverVersion"] = 0
    return obj


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/spokenly-template.plist")
    ap.add_argument("--live", default=str(LIVE))
    a = ap.parse_args()
    live = plistlib.load(open(a.live, "rb"))
    secrets: list[str] = []
    out: dict = {}
    for k in KEEP_SCALARS:
        if k in live:
            out[k] = live[k]
    for k in KEEP_JSON:
        if k not in live:
            continue
        j = json.loads(live[k])
        if k == "aiProviders.v1":
            for item in j["envelope"]["items"]:
                prov = item["value"]["provider"]
                secrets.append(prov["key"])
                prov["key"] = PROVIDER_PLACEHOLDER[item["value"]["type"]]
        elif k == "dictationCredential.elevenlabs-api.v1":
            secrets.append(j["envelope"]["value"]["key"])
            j["envelope"]["value"]["key"] = "{{ELEVENLABS_API_KEY}}"
        reset_envelope(j)
        out[k] = json.dumps(j, ensure_ascii=False, separators=(",", ":")).encode()
    data = plistlib.dumps(out, fmt=plistlib.FMT_XML)
    text = data.decode()
    for s in secrets:
        if s and s in text:
            print("GATE: live key value leaked into the template", file=sys.stderr)
            return 1
    if re.search(r"sk[_-][A-Za-z0-9]{6,}", text):
        print("GATE: sk_/sk- pattern in the template", file=sys.stderr)
        return 1
    # b64 blobs in <data> could hide a key: decode-check them too
    for k, v in out.items():
        if isinstance(v, bytes) and any(s and s in v.decode() for s in secrets):
            print(f"GATE: key inside {k}", file=sys.stderr)
            return 1
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_bytes(data)
    print(f"template written: {a.out} ({len(out)} keys, {len(secrets)} keys replaced by placeholders)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
