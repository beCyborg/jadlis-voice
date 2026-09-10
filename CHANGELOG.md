# Changelog — jadlis-voice

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).

## [1.0.0] — 2026-09-10 — первый выпуск: голосовой контур один в один / first release

### Для человека
- Одна команда `/jadlis-voice` ставит голосовой контур: диктовку Spokenly с распознаванием
  ElevenLabs `scribe_v2`, чисткой текста Anthropic `claude-sonnet-5`, необязательным резервом
  OpenAI `gpt-5.6-sol` и словарём из десяти замен.
- Настройки Spokenly (25 ключей, режим, промпт корректора, словарь) приезжают одним импортом;
  прежние уходят в резервную копию `~/Archive/spokenly-<дата>.plist`, импорт дополняет домен,
  а не затирает его.
- Ключи вводятся скрытым вводом и живут в Связке ключей macOS (service `jadlis`), а не в файлах.
- Необязательная ветка озвучки: тап правого Option читает буфер обмена голосом ElevenLabs,
  повторный тап останавливает. Плеер и ключ проверяются до платного запроса.
- Третий шаг маршрута Jadlis; следующий — `/search` (плагин `jadlis-search`).

### For agents
- Added: `.claude-plugin/plugin.json` — `jadlis-voice` 1.0.0, автор Be Cyborg, репозиторий
  `https://github.com/beCyborg/jadlis-voice`.
- Added: `skills/jadlis-voice/SKILL.md` — фронтматтер `name: jadlis-voice` (команда
  `/jadlis-voice`, полная форма `/jadlis-voice:jadlis-voice`), семь шагов, один шаг за ход;
  таблица ключей и цены вынесены в `references/keys-and-costs.md`.
- Added: `scripts/probe.sh` — машиночитаемая проба `имя=значение`, значений ключей не печатает;
  `scripts/keys.sh` — `set`/`check`/`has` поверх `security add-generic-password -U -s jadlis`;
  `scripts/apply-karabiner.py` — идемпотентный мёрж правила по `description`, создаёт минимальный
  `karabiner.json`, если Karabiner ещё не запускался.
- Added: `tools/spokenly-export.py` (сторона владельца, гейт на `sk_`/`sk-`), `tools/spokenly-apply.py`
  (сторона получателя: ключи из Связки, снятие OpenAI-провайдера и `fallbackAIProviderID` без
  `OPENAI_API_KEY`, отказ при живом Spokenly, бэкап, импорт по пути, отчёт merge/replace);
  тестовые флаги `SPOKENLY_KEYS_JSON` и `--print-template` (значения маскируются как `***`).
- Added: `assets/spokenly-template.plist` (25 ключей, плейсхолдеры вместо ключей),
  `assets/speak.sh` (плеер через `command -v play`, ключ по стандарту `jadlis` с откатом на
  legacy-запись `elevenlabs`, предполётные проверки до сетевого вызова),
  `assets/karabiner-rule.json` (`$HOME/.local/bin/speak.sh`, экспорт PATH сохранён).
- Added: `docs/tier/README.md` + `README.en.md` (переписанный тир-документ, без mermaid),
  `docs/prompt.txt` — тот же текст промпта, что внутри шаблона.
- Added: `README.md` + `README.en.md` (одинаковый набор H2, переключатель языка первой строкой),
  `.github/workflows/ci.yml` → `beCyborg/jadlis-hub/.github/workflows/plugin-ci.yml@main`
  (`mode: plugin`, `forbid-mermaid: true`), `.gitignore`.
- Note: живой домен настроек адресуется путём к файлу `~/Library/Preferences/app.spokenly.plist`;
  бандл-id `app.spokenly` ведёт в старый sandbox-контейнер и для этого приложения бесполезен.
