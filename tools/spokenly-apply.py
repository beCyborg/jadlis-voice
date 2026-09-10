#!/usr/bin/env python3
"""spokenly-apply.py — recipient-side: import the Spokenly template with the recipient's keys.

Usage:
  python3 spokenly-apply.py --template assets/spokenly-template.plist            # keys from Keychain
  python3 spokenly-apply.py --template … --dry-run                                # print the plan only
  python3 spokenly-apply.py --template … --dry-run --print-template               # masked plist to stdout
  python3 spokenly-apply.py --template … --keys-from-live ~/Archive/spokenly.plist  # owner self-test

Keys are read from the macOS Keychain, generic passwords: service `jadlis`, account = key name
(ELEVENLABS_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY) — the same convention as jadlis-search's
secret.sh. OPENAI_API_KEY is optional: without it the OpenAI provider and the fallback are removed.
Spokenly must be closed. A backup `~/Archive/spokenly-<date>.plist` is written before the import;
rollback: `defaults import ~/Library/Preferences/app.spokenly.plist <backup>`.
After the import the tool reports whether `defaults import` merged or replaced the domain
(keys outside the template such as accessibilityGrantObserved / storedUserID survive → merge).

TEST-ONLY: `SPOKENLY_KEYS_JSON=/path/keys.json` replaces the Keychain lookup with a JSON map
{"ELEVENLABS_API_KEY": "...", ...}. It exists because `security` cannot be faked inside a sandboxed
test HOME; never use it for a real setup — a key in a file is a key that leaks.
`--print-template` writes the substituted plist to stdout with every key value masked as `***`,
so a test can assert the structure (e.g. that the OpenAI provider is gone) without seeing a value.
"""
from __future__ import annotations
import argparse, datetime, json, os, plistlib, subprocess, sys, tempfile
from pathlib import Path

# The bundle id `app.spokenly` resolves to the OLD sandbox container (frozen since the app left the
# sandbox, 2026-08); the live domain must be addressed by file path.
DOMAIN = str(Path.home() / "Library/Preferences/app.spokenly.plist")
PLACEHOLDERS = {"{{ELEVENLABS_API_KEY}}": "ELEVENLABS_API_KEY", "{{ANTHROPIC_API_KEY}}": "ANTHROPIC_API_KEY", "{{OPENAI_API_KEY}}": "OPENAI_API_KEY"}
OUTSIDE_KEYS = ("accessibilityGrantObserved", "app.spokenly.storedUserID", "SUHasLaunchedBefore", "MicrophoneDeviceService.devices")


def keychain(name: str) -> str | None:
    r = subprocess.run(["security", "find-generic-password", "-s", "jadlis", "-a", name, "-w"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def keys_from_env_file() -> dict | None:
    """TEST-ONLY override: SPOKENLY_KEYS_JSON=<file> replaces the Keychain lookup."""
    path = os.environ.get("SPOKENLY_KEYS_JSON")
    if not path:
        return None
    data = json.loads(open(path, encoding="utf-8").read())
    print(f"TEST-ONLY: keys taken from {path}, not from the Keychain", file=sys.stderr)
    return {n: (data.get(n) or None) for n in PLACEHOLDERS.values()}


def mask(tpl: dict, secrets: list) -> str:
    """The substituted plist as text with every key value replaced by ***.

    The JSON-in-Data fields are base64 in the XML, so masking has to happen on the
    decoded values BEFORE serialisation — a replace on the finished XML would miss them.
    """
    values = sorted((v for v in secrets if v), key=len, reverse=True)
    masked = {}
    for k, v in tpl.items():
        if isinstance(v, bytes):
            text = v.decode()
            for value in values:
                text = text.replace(value, "***")
            masked[k] = text.encode()
        else:
            masked[k] = v
    out = plistlib.dumps(masked, fmt=plistlib.FMT_XML).decode()
    for value in values:
        out = out.replace(value, "***")
    return out


def keys_from_live(path: str) -> dict:
    live = plistlib.load(open(path, "rb"))
    out = {"ELEVENLABS_API_KEY": json.loads(live["dictationCredential.elevenlabs-api.v1"])["envelope"]["value"]["key"]}
    for item in json.loads(live["aiProviders.v1"])["envelope"]["items"]:
        out[{"anthropic": "ANTHROPIC_API_KEY", "openai": "OPENAI_API_KEY"}[item["value"]["type"]]] = item["value"]["provider"]["key"]
    return out


def defaults_read() -> dict:
    r = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    return plistlib.loads(r.stdout) if r.returncode == 0 and r.stdout else {}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--keys-from-live")
    ap.add_argument("--print-template", action="store_true", help="masked plist to stdout, values as ***")
    a = ap.parse_args()
    if a.keys_from_live:
        keys = keys_from_live(a.keys_from_live)
    else:
        keys = keys_from_env_file() or {n: keychain(n) for n in PLACEHOLDERS.values()}
    missing = [n for n in ("ELEVENLABS_API_KEY", "ANTHROPIC_API_KEY") if not keys.get(n)]
    if missing:
        print("missing required keys in Keychain (service jadlis): " + ", ".join(missing), file=sys.stderr)
        return 2
    tpl = plistlib.load(open(a.template, "rb"))
    # substitute
    def sub(s: str) -> str:
        for ph, name in PLACEHOLDERS.items():
            if keys.get(name):
                s = s.replace(ph, keys[name])
        return s
    for k, v in list(tpl.items()):
        if isinstance(v, bytes):
            tpl[k] = sub(v.decode()).encode()
    if not keys.get("OPENAI_API_KEY"):
        prov = json.loads(tpl["aiProviders.v1"])
        prov["envelope"]["items"] = [i for i in prov["envelope"]["items"] if i["value"]["type"] != "openai"]
        tpl["aiProviders.v1"] = json.dumps(prov, ensure_ascii=False, separators=(",", ":")).encode()
        modes = json.loads(tpl["modes.v2"])
        for it in modes["envelope"]["items"]:
            it["value"].pop("fallbackAIProviderID", None)
        tpl["modes.v2"] = json.dumps(modes, ensure_ascii=False, separators=(",", ":")).encode()
        print("OPENAI_API_KEY absent → OpenAI provider and fallback removed")
    if a.dry_run:
        print(f"dry-run: would import {len(tpl)} keys into {DOMAIN}; keys present: {[n for n in keys if keys[n]]}")
        if a.print_template:
            sys.stdout.write(mask(tpl, list(keys.values())))
        return 0
    if a.print_template:
        sys.stdout.write(mask(tpl, list(keys.values())))
    if subprocess.run(["pgrep", "-x", "Spokenly"], capture_output=True).returncode == 0:
        print("Spokenly is running — quit it first (⌘Q), then rerun", file=sys.stderr)
        return 3
    before = defaults_read()
    outside_before = {k: before.get(k) for k in OUTSIDE_KEYS}
    backup = Path.home() / "Archive" / f"spokenly-{datetime.date.today():%Y-%m-%d}.plist"
    backup.parent.mkdir(exist_ok=True)
    subprocess.run(["defaults", "export", DOMAIN, str(backup)], check=True)
    with tempfile.NamedTemporaryFile(suffix=".plist", delete=False) as f:
        f.write(plistlib.dumps(tpl, fmt=plistlib.FMT_XML)); tmp = f.name
    subprocess.run(["defaults", "import", DOMAIN, tmp], check=True)
    Path(tmp).unlink()
    after = defaults_read()
    same = all(after.get(k) == tpl[k] for k in tpl)
    outside_after = {k: after.get(k) for k in OUTSIDE_KEYS}
    mode = "merge" if any(outside_before.get(k) is not None and outside_after.get(k) == outside_before.get(k) for k in OUTSIDE_KEYS) else "replace"
    print(f"imported {len(tpl)} keys; template keys match: {same}; defaults import mode: {mode}; backup: {backup}")
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main())
