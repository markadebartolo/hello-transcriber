<img src="hello/Assets.xcassets/AppIcon.appiconset/hello-128@1x.png" width="88" height="88" alt="Hello’s blue waveform app icon">

# Hello Transcriber

Hello is an open-source macOS menu bar app that turns speech into text in the app you’re using. Click
where you want to type, hold **Control + Option**, speak, and release. Hello inserts the finished
transcript into the original field when it can verify the destination, or copies it to your clipboard if
the field is unavailable.

**[Download Hello for macOS](https://github.com/markadebartolo/hello-transcriber/releases/latest)**

Requires **macOS 14.2 or later**, an Intel or Apple silicon Mac, and your own OpenAI API key. The
download is Developer ID signed and notarized by Apple. OpenAI API usage is billed to your account.

## What you can do

- **Dictate where you type.** Use the same shortcut in supported fields across apps. Hello preserves the
  surrounding text when replacing a selection. In ChatGPT desktop, it adds spacing and conservative
  sentence punctuation when you append another dictation to a draft.
- **See words as you speak.** A small floating waveform shows mic activity. With Apple Speech permission
  and on-device recognition support, it shows up to three provisional words while you hold the shortcut.
- **Remember how you spell names.** Turn on **Personal Spellings** to review corrections and save the
  ones you want applied to future dictation.
- **Fill a form in one take.** Optional **Form Filling** maps spoken answers to empty fields, then lets
  you review what was filled before you submit.
- **See your activity.** The dashboard shows your word and dictation counts for the last seven days.
  Hello stores the totals locally without keeping a transcript history.

## Get started

1. Download the ZIP from the [latest release](https://github.com/markadebartolo/hello-transcriber/releases/latest).
   To verify it, download `SHA256SUMS` from the same release, put both files in the same directory,
   and run `shasum -a 256 -c SHA256SUMS`.
2. Unzip the download in Finder, drag **Hello.app** into **Applications**, and open it.
3. In **Overview → Permissions**, follow the setup prompts. In **Dictation**, enter your OpenAI API key
   and choose **Save key**. The key needs access to the audio transcription endpoint. An OpenAI key
   already saved for Form Filling works here too.
4. Click inside a text field. Hold **Control + Option** while you speak, then release. Press **Escape**
   or choose **Cancel** to stop a dictation in progress.

Closing the dashboard leaves Hello in the menu bar. Choose **Open Dashboard** from the waveform menu to
reopen it. Use **Check for Updates…** to check the signed Sparkle feed, or turn on **Automatic update
checks** in the dashboard.

### Permissions

| macOS permission | What Hello uses it for |
| --- | --- |
| **Microphone** | Records while you hold the dictation shortcut. |
| **Accessibility** | Checks the original field and selection and inserts into supported fields. |
| **Speech Recognition** | Provides optional on-device live captions and a possible fallback if OpenAI fails. |
| **Input Monitoring** | Helps the global shortcut work on systems that require it. |
| **Screen Recording** | Allows an active-window screenshot when you use optional Form Filling. |

If you denied a permission, use Hello’s setup button to open the corresponding pane in **System Settings
→ Privacy & Security**. Return to Hello after changing the grant. macOS may ask you to reopen Hello.

## Dictation and the clipboard

Hello sends the completed recording to OpenAI’s `gpt-transcribe` model after you release the shortcut.
Live captions come from Apple Speech on your Mac and can change as you speak. If OpenAI fails, Hello
explains why and can use a completed local result when one is available. The final transcript may take a
moment after release.

If focus or the selection changes, or the field is unsupported or secure, Hello leaves the field alone
and shows **Copied to clipboard.** If the app accepted an insertion that Hello can’t confirm, it shows
**Check text field** and keeps the transcript available in **Overview**. You can copy it there after
checking the field. Hello never presses Return, Send, or Submit.

Use **Copy** to copy the last transcript and **Clear** to remove it from Hello. **Copy original** is
available when a spelling correction or punctuation suggestion changed the text. Clearing Hello leaves
the system clipboard as it is.

### Optional punctuation review

On a supported Mac with **macOS 26 or later** and an available Apple Intelligence model, turn on
**Dictation → Preview punctuation cleanup** to review local punctuation suggestions. This pauses
automatic insertion and copies the transcript without the suggested punctuation. Review the suggestion in
Hello before copying it.

### Personal spellings

In **Personal Spellings**, turn on **Use spelling memory**. After an automatic insertion, correct a
spelling in the same field within 10 seconds. Pause for about two seconds, then return to Hello and
choose **Remember spelling** or **Ignore**. Approved spellings apply to future dictation on this Mac. You
can remove a pair or choose **Clear saved spellings**.

## Form Filling

1. Under **Form Filling**, choose **OpenAI**, **Anthropic**, or **OpenRouter** and save a key for that
   provider. OpenAI form requests also need access to the Responses endpoint.
2. Choose **Allow form filling screenshots** and approve the macOS Screen Recording permission. Turn on
   **Send window to [provider] and fill empty fields**. Form Filling turns off when you switch providers
   or restart Hello.
3. Open a form with empty text fields and dictate the labels and answers. Try “First name Maya, last name
   Chen, city Boston.” You can leave the fields unfocused.

Hello fills visible, empty, writable text fields it can match reliably. It preserves existing values. If
it can’t match the answers, it copies the transcript and may show individual suggestions with **Copy
value**. Review the form before submitting. Some sites autosave as fields change.

Form Filling sends the transcript, eligible field labels and positions, and one screenshot of the active
window to your chosen provider. The screenshot can include other visible content. Use a window you’re
comfortable sharing. Dictation still uses your saved OpenAI key for audio when you choose Anthropic or
OpenRouter for forms.

| Form provider | Model in Hello 0.1.2 |
| --- | --- |
| OpenAI | `gpt-4.1-mini` |
| Anthropic | `claude-sonnet-4-5` |
| OpenRouter | `openai/gpt-4.1-mini` |

Choose the **AI provider** to change the form model. Model selection is fixed within each provider in
this release.

## Privacy

Hello keeps API keys in macOS Keychain and sends microphone audio to OpenAI for transcription. The audio
request contains neither the destination draft nor a screenshot. Apple Speech previews, approved
spellings, and activity totals stay on your Mac. Form Filling is the separate opt-in that shares an
active-window screenshot. See the [privacy guide](PRIVACY.md) for data handling, clipboard behavior, and
provider controls.

## Source, testing, and contributions

- [Release notes and downloads](https://github.com/markadebartolo/hello-transcriber/releases/latest) · [What was tested on each build](VALIDATION.md)
- [Build from source and contribute](CONTRIBUTING.md) · [Maintainer release
  procedure](hello/RELEASING.md)
- [Source provenance](SOURCE_PROVENANCE.json) · [Integration changes](MODIFICATIONS.md) · [MIT
  license](LICENSE) · [Third-party notices](NOTICES.md)

Hello includes a scoped set of dictation modules from Dorsal. The waveform mark
is measured from the word “hello” spoken by the local macOS Samantha voice.
[Waveform source and renderer](hello/brand/README.md)
