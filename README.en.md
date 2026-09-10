[Русский](README.md) · English

# A paragraph-long thought hits the speed of your fingers — and reaches the agent half the length it was

You speak out loud, a second model strips the "uhh"s and the filler, and the finished text lands
in the field your cursor is in. Copied text is read back to you by a tap on a single key.

```
claude plugin marketplace add https://github.com/beCyborg/jadlis-hub
claude plugin install jadlis-voice@jadlis
```

After that one command — `/jadlis-voice` — and the agent walks you through the setup step by step.
This is the third step of the Jadlis route: voice comes after the agent itself is installed.

This is my workbench published as it is, not a product: whatever I stopped using, I removed.

## Before → after

| By hand | With an AI chat | With this plugin |
|---|---|---|
| **How a task reaches the agent.** You type — and cut the thought down to whatever length you can bear to type. | The chat has built-in dictation, but it writes what it hears: "uhh"s, repetitions and no commas. | You speak out loud and the text drops straight into the active field in `autoInsert` mode — the clipboard is not involved. |
| **What happens to the transcribed text.** You proofread and fix it yourself, one comma at a time. | You ask for the same clean-up in a separate message — and get a retelling instead of your own text. | A second model removes hesitations, false starts and filler and puts the punctuation in without rewriting the meaning: the prompt forbids it to cut more than a third of the words. |
| **The words transcription always gets wrong.** You fix "Cloud Code" into "Claude Code" by hand every single time. | You fix them by hand in the same place, only slower. | A dictionary of ten "heard → written" pairs fires before the clean-up; you add your own names and projects as you go. |
| **How the tool itself gets configured.** Twenty-five switches in somebody else's app, each one to be found and understood. | The chat tells you where things are, and you keep clicking yourself. | 25 settings, the corrector prompt and the replacement dictionary arrive in one import; the previous settings go into a backup. |
| **A long text you cannot face reading.** You read it with your eyes, or you do not read it at all. | You ask for a summary — and lose the original. | Copy it → tap right Option → listen to the whole original; tap again and it stops. |

## How it works

Speech goes through two cloud steps and comes back as text where your cursor is:

1. **Right Command** — press once and recording starts, press again and the text is in the field (`toggle`).
2. **Word replacements** — ten pairs fire before the clean-up.
3. **Transcription** — ElevenLabs `scribe_v2`: sound → letters, "uhh"s included.
4. **Clean-up** — Anthropic `claude-sonnet-5`; on a refusal the OpenAI `gpt-5.6-sol` fallback takes
   over, if a key for it is set.
5. **Insertion** — the finished text puts itself into the active field.

The optional second branch is read-aloud: a Karabiner rule catches a tap on right Option, `speak.sh`
takes the clipboard and reads it in an ElevenLabs voice, and `play` from the sox package puts the
sound out.

The full walkthrough is [docs/tier/README.en.md](docs/tier/README.en.md); the corrector prompt in
full is [docs/prompt.txt](docs/prompt.txt).

## Installing and the first run

The `/jadlis-voice` command walks seven steps, one action per turn and always with your permission:

1. **Probe** — what is already there: the app, the settings, the keys (names only), sox, Karabiner.
2. **The contour explained** — what transcription is, why a second model, what costs money.
3. **Keys one at a time** — a sign-up link, you create the key yourself and paste it hidden.
4. **`brew install --cask spokenly`** and the first launch by hand: grant Microphone and
   Accessibility. These are the only steps that cannot be done for you.
5. **The settings import** — with Spokenly closed, with a backup, then a live check: you dictate
   "Cloud Code" and "Claude Code" appears in the field.
6. **Read-aloud, if you want it** — sox, Karabiner-Elements, `speak.sh` and one right-Option rule.
7. **The wrap-up** — what changed and where to go next.

What you need: **macOS 13 (Ventura) or newer** — that is what the Spokenly cask requires; an
**ElevenLabs** key (transcription and read-aloud) and an **Anthropic API** key from the Console —
that is a separate account, a Claude subscription does not work here. Optional: an **OpenAI** key as
the clean-up fallback, and for read-aloud **sox** and **Karabiner-Elements**.

Keys live in the macOS Keychain (service `jadlis`, account = the key name) — the same standard as
`jadlis-search`. The value is typed hidden, never passed as a command-line argument and never shows
up in the agent's replies.

## Limits, cost, updating

**What it does not do.** It does not create accounts for you and does not fill in forms — it hands
you the link and you sign up. It does not translate, does not summarize and does not cut more than
a third of the words — this is a clean-up, not a rewrite. It does not work offline: the voice goes
to ElevenLabs and the text to Anthropic. It does not exist outside macOS. Spokenly also has an
iPhone app, but its setup there is its own and separate.

**What it does not touch.** Nothing but its own: the Spokenly settings (with a backup in
`~/Archive/`), one Keychain entry under service `jadlis`, the file `~/.local/bin/speak.sh` and
**one** rule in the Karabiner config — recognised by its description, so a second run makes no
duplicate. Other people's rules, profiles, keys and repositories stay as they were.

**What costs money.** Transcription is billed by the minute of recording, the clean-up by the volume
of text; on everyday dictation both sums are small. Pay-as-you-go, no subscription, but each
provider needs a minimum top-up. For exact figures see the pricing pages of ElevenLabs, Anthropic
and OpenAI — here they would go stale before you read them. The app itself is free on your own keys.

**About keys in somebody else's file.** Spokenly keeps its keys in its settings file in plain text —
it offers no Keychain path of its own. So do not forward
`~/Library/Preferences/app.spokenly.plist`, do not put it in a repo and do not let an agent read it.
The template in `assets/` holds placeholders where the keys go, and the substitution happens only on
your machine.

Spokenly is third-party freeware with an optional Pro subscription; its authors have nothing to do
with this plugin.

**Verified where I work:** my Mac, my keys. Where else this works — [уточнить].

**Terms of use.** There is no license: all rights reserved by the author. You may read it and use it
personally. Commercial use, republishing and bundling it into your own products — by arrangement
with me.

**Updating.** With a third-party marketplace, auto-update is off on your side: until you run the
first command you keep the version you installed.

```
claude plugin marketplace update jadlis
claude plugin update jadlis-voice@jadlis
claude plugin list
```

Reinstall, if something ended up crooked:

```
claude plugin uninstall jadlis-voice@jadlis --keep-data && claude plugin install jadlis-voice@jadlis
```
