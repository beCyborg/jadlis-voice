# Changelog — jadlis-voice

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).

## [1.1.0] — 2026-09-28 — чистка текста на Sonnet 5.5 / clean-up on Sonnet 5.5

### Для человека
- Диктовку теперь чистит Claude Sonnet 5.5 вместо Sonnet 5, по той же цене. На проверочном
  наборе из 38 трудных диктовок чистых результатов 22 вместо 14, самая длинная диктовка
  обрабатывается за 6 секунд вместо 25.
- Модель больше не выполняет просьбы из самой диктовки: «напиши это на английском» остаётся
  текстом для агента, а не превращается в перевод, и «Нет, я имел в виду» больше не выпадает.
- Уже настроенный Spokenly сам не меняется: выберите `claude-sonnet-5-5` в провайдере Anthropic
  в настройках Spokenly или повторите шаг импорта в `/jadlis-voice`.

### For agents
- Changed: `assets/spokenly-template.plist` — `aiProviders.v1`, провайдер `anthropic`: `model`
  `claude-sonnet-5` → `claude-sonnet-5-5`; `modes.v2`, «Режим по умолчанию»: `reasoningEffort`
  `default` → `low`. Остальные ключи не тронуты (сверка по полям с 1.0.0).
- Changed: id модели в `README.md`, `README.en.md`, `docs/tier/README.md`, `docs/tier/README.en.md`,
  `skills/jadlis-voice/SKILL.md`, `skills/jadlis-voice/references/keys-and-costs.md` (плюс строка
  `reasoningEffort`) и в `description` `.claude-plugin/plugin.json`.
- Refs: бенчмарк 2026-09-28 — 40 диктовок (38 в зачёте) из набора 2026-09-18, штатная обёртка
  Spokenly + промпт шаблона, вход без словаря замен: `claude-sonnet-5` по умолчанию 14/38
  (макс. 25,0 с), `claude-sonnet-5-5` по умолчанию 22/38 (8,1 с), с `effort: low` 22/38 (5,9 с).
  Контроль: `claude-sonnet-5` + промпт v4 lite + `low` = 35/38, как 2026-09-18.
- Migration: у установленных копий настройки Spokenly остаются прежними; шаблон применяется при
  следующем импорте (`tools/spokenly-apply.py`).

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
