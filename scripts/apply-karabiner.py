#!/usr/bin/env python3
"""apply-karabiner.py — вносит правило «тап правого Option → speak.sh» в конфиг Karabiner-Elements.

Использование:
  python3 scripts/apply-karabiner.py --rule assets/karabiner-rule.json
  python3 scripts/apply-karabiner.py --rule … --dry-run
  python3 scripts/apply-karabiner.py --rule … --remove

Идемпотентно: правило опознаётся по полю `description`. Повторный запуск заменяет
существующее правило на актуальное, а не добавляет второе.

Конфиг — `$HOME/.config/karabiner/karabiner.json`. Если Karabiner ещё ни разу не
запускался и файла нет, создаётся минимальный валидный конфиг с одним профилем:
Karabiner-Elements ждёт `profiles[0].complex_modifications.rules` — список правил
лежит внутри выбранного профиля, а не в корне файла.

Перед записью делается резервная копия `karabiner.json.bak-<дата>` рядом с конфигом.
Karabiner перечитывает файл сам; если приложение открыто, правило появляется сразу.
"""
from __future__ import annotations

import argparse
import datetime
import json
import shutil
import sys
from pathlib import Path

CONFIG = Path.home() / ".config" / "karabiner" / "karabiner.json"

MINIMAL_PROFILE = {
    "name": "Default profile",
    "selected": True,
    "complex_modifications": {"rules": []},
    "virtual_hid_keyboard": {"keyboard_type_v2": "ansi"},
}


def load_config(path: Path) -> tuple[dict, bool]:
    """Читает конфиг; возвращает (данные, создан_ли_он_сейчас)."""
    if not path.exists():
        return {"profiles": [json.loads(json.dumps(MINIMAL_PROFILE))]}, True
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: ожидался объект JSON, получен {type(data).__name__}")
    return data, False


def target_profile(data: dict) -> dict:
    """Выбранный профиль (или первый, или созданный)."""
    profiles = data.setdefault("profiles", [])
    if not profiles:
        profiles.append(json.loads(json.dumps(MINIMAL_PROFILE)))
    for p in profiles:
        if p.get("selected"):
            break
    else:
        p = profiles[0]
    cm = p.setdefault("complex_modifications", {})
    cm.setdefault("rules", [])
    return p


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", required=True, help="путь к assets/karabiner-rule.json")
    ap.add_argument("--config", default=str(CONFIG))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--remove", action="store_true", help="убрать правило по description")
    a = ap.parse_args()

    rule = json.loads(Path(a.rule).read_text(encoding="utf-8"))
    desc = rule.get("description")
    if not desc:
        print("правило без поля description — опознать его нечем", file=sys.stderr)
        return 2

    path = Path(a.config)
    data, created = load_config(path)
    profile = target_profile(data)
    rules = profile["complex_modifications"]["rules"]

    matches = [i for i, r in enumerate(rules) if r.get("description") == desc]
    if a.remove:
        if not matches:
            print(f"правила «{desc}» в конфиге нет — ничего не менял")
            return 0
        for i in reversed(matches):
            rules.pop(i)
        action = f"убрано правил: {len(matches)}"
    elif matches:
        for i in reversed(matches[1:]):   # схлопываем дубли, если они уже были
            rules.pop(i)
        rules[matches[0]] = rule
        action = "правило обновлено (было ровно там же)"
    else:
        rules.append(rule)
        action = "правило добавлено"

    same_count = sum(1 for r in rules if r.get("description") == desc)
    if a.dry_run:
        print(f"dry-run: {action}; правил с этим описанием станет {same_count}; файл {path} не тронут")
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    if not created and path.exists():
        backup = path.with_suffix(f".json.bak-{datetime.date.today():%Y-%m-%d}")
        shutil.copy2(path, backup)
        print(f"резервная копия: {backup}")
    path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{'создан конфиг' if created else 'обновлён конфиг'}: {path}")
    print(f"{action}; правил профиля «{profile.get('name')}»: {len(rules)}, с этим описанием: {same_count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
