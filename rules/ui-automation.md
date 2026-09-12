---
paths:
  - "**/e2e/**"
  - "**/*.e2e.*"
  - "**/*.uitest.*"
  - "**/scripts/drivers/**"
  - "**/check-ui*"
  - "**/check-hotkey*"
  - "**/smoke*.mjs"
---

# Synthesising keystrokes on Windows

Synthesise keys with `keybd_event` or `SendInput`, never with `SendKeys`.

`SendKeys` is not visible to the low-level input path.

The symptom, if it is used anyway: the same action works from the UI and the key binding
is registered without error, but the synthesised key does nothing.
