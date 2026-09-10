[Русский](README.md) · English

# The "Voice" tier — what stands behind the plugin

A reference page: what the voice contour is made of and why it is made that way.
The `/jadlis-voice` command sets it up — you are not meant to walk this page by hand.

## Why

Nobody types a long prompt by hand — the thought breaks mid-sentence.

- Problem: the more it costs to say something, the shorter the task you give the agent — and the worse the result.
- What it does: speech → clean text with punctuation, no hesitations, no filler, meaning untouched.
- Why this step comes third: everything after it is a conversation with an agent. Voice makes that conversation cheap.

## What it looks like

Speech goes through two cloud steps and comes back as text in the field your cursor is in:

1. **Speech into the mic** — press right Command, talk, press it again.
2. **Word replacements** — ten "heard → written" pairs fire before the clean-up (`beforeAI`).
3. **Transcription** — ElevenLabs `scribe_v2` turns sound into letters, "uhh"s included.
4. **Clean-up** — Anthropic `claude-sonnet-5` strips the filler and puts the commas in; on a refusal
   the OpenAI `gpt-5.6-sol` fallback takes over, if its key is set.
5. **Clean text in the active field** — `autoInsert` mode, no clipboard involved.

<details>
<summary>Before / after example (synthetic)</summary>

**Before — raw STT output:**

> so like I want you to uhh look at our notes folder and, you know, find every file that has no heading, and basically maaake a list, I mean just a list, don't change anything yet

**After — what lands in the field:**

> I want you to look at our notes folder and find every file that has no heading, and make a list. Just a list, don't change anything yet.

Meaning, tone and the "yet" survive; the hesitations, "like", "basically" and the stretched vowel are gone.

</details>

The second, optional branch is read-aloud: copy some text, tap right Option, listen; tap again and
it stops. Karabiner-Elements holds the key-interception rule, `speak.sh` reads it out through
ElevenLabs, and `play` from the sox package puts the sound out.

## What is inside the plugin

| File | What it is |
|---|---|
| `assets/spokenly-template.plist` | 25 Spokenly settings with placeholders instead of keys: mode, hotkey, clean-up prompt, replacement dictionary |
| `docs/prompt.txt` | the same corrector prompt as a separate file — so it can be read with your eyes |
| `tools/spokenly-apply.py` | substitutes the keys from the Keychain and imports the template into the live settings domain |
| `tools/spokenly-export.py` | the reverse operation for the owner: live settings → a key-free template |
| `assets/speak.sh` · `assets/karabiner-rule.json` | the read-aloud branch: the script and the right-Option rule |

The live settings domain is addressed **by file path**, `~/Library/Preferences/app.spokenly.plist`:
the bundle id `app.spokenly` leads to the old sandbox container, the app left the sandbox in 08.2026.
A `defaults import` by path **merges** into the domain — microphones, granted permissions and
Spokenly's own service keys all survive the import.

## How you use it

The hotkey is the single button you press every day.

1. **A long task for the agent.** Cursor in the Claude Code input → right Command → say the whole
   context out loud → read it over → send.
2. **A thought on the move.** Cursor in a note → right Command → the text arrives already edited.
3. **STT keeps mishearing a word.** Add a "heard → written" pair in Word Replacements. That is how
   the dictionary grows: your projects, your tools, your names.
4. **A long text you cannot face reading.** Copy it → tap right Option → listen.

Done means: dictate two sentences full of "like" and "uhh" — the hesitations are gone, the meaning
is intact.

## Limits and cost

Two paid accounts are required and a third is optional; every key is your own.

- **Pay-as-you-go** everywhere: ElevenLabs, Anthropic, OpenAI. No subscription, but each needs a
  minimum top-up. For exact prices, see the providers' pricing pages.
- **Spokenly stores its keys in plain text inside its settings file.** Never forward that file,
  never put it in a repo, never let an agent read it. This is the exception to the shared standard
  (the macOS Keychain): Spokenly offers no Keychain path of its own.
- **Everything goes to the cloud:** speech to ElevenLabs, text to Anthropic (OpenAI as fallback).
  This route does not work offline; do not dictate anything you cannot send out.
- **macOS only.** Spokenly also exists on the iPhone, but the setup there is its own and separate.
- **What it does not do:** no translation, no summarizing, no cutting more than a third of the
  words. Misheard names are fixed only by the replacement dictionary.

Spokenly is third-party freeware with an optional Pro subscription; its authors have nothing to do
with this plugin.
