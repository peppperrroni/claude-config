---
paths:
  - "**/*.ps1"
---

# Which PowerShell is present

Check rather than assume:

    pwsh -NoProfile -ExecutionPolicy Bypass -File <script>.ps1

`pwsh` (PowerShell 7) is a separate install and is absent on many machines. Test with
`Get-Command pwsh` and fall back to `powershell` (Windows PowerShell 5.1), which is
always there. The flags are the same.
