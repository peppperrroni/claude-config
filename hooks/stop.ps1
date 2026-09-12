#Requires -Version 5.1
<#
  Global Stop hook. Reminds, at most once per session, that the tree is dirty and
  /handoff has not run.

  Stop fires at the end of every turn, not at the end of the session, so an unthrottled
  reminder would appear after every message on any dirty tree -- which is most of the
  working day, and is how a warning becomes wallpaper. Three stamps under
  ~/.claude/.claude-config-state/ decide:

    <key>.session   written by session-start
    <key>.handoff   written by hooks/handoff-done, which /handoff runs as its last step
    <key>.nagged    written here

  Reminder iff the tree is dirty AND neither .handoff nor .nagged is newer than
  .session. Missing .session means silence, not noise: it means the SessionStart hook is
  not wired, and half-wiring should fail quiet.

  Never blocks, never writes to the repository, never fails loudly.
#>

$ErrorActionPreference = 'SilentlyContinue'

try {
    $hooksDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
    $claudeHome = Split-Path -Parent $hooksDir
    $stateDir   = Join-Path $claudeHome '.claude-config-state'

    # Capture first, THEN check $LASTEXITCODE. Piping a native command into
    # Select-Object -First stops the pipeline early, and PowerShell reports that as
    # $LASTEXITCODE = -1 even when git succeeded -- so the guard rejected every repository.
    $out = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $root = (@($out) | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($root)) { exit 0 }
    $root = $root.Trim()

    $dirty = & git -C $root status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    if ([string]::IsNullOrWhiteSpace(($dirty | Out-String))) { exit 0 }

    # Must match session-start.ps1 and handoff-done.ps1 exactly. A hash rather than a
    # flattened path, because the flattened form ran the full path past Windows' 260
    # character limit and the stamp silently failed to write. See session-start.ps1.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))
    } finally { $sha.Dispose() }
    $key = ((($bytes | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16))

    $session = Join-Path $stateDir "$key.session"
    $handoff = Join-Path $stateDir "$key.handoff"
    $nagged  = Join-Path $stateDir "$key.nagged"

    if (-not (Test-Path -LiteralPath $session)) { exit 0 }
    $sessionAt = (Get-Item -LiteralPath $session).LastWriteTimeUtc

    if (Test-Path -LiteralPath $handoff) {
        if ((Get-Item -LiteralPath $handoff).LastWriteTimeUtc -gt $sessionAt) { exit 0 }
    }
    if (Test-Path -LiteralPath $nagged) {
        if ((Get-Item -LiteralPath $nagged).LastWriteTimeUtc -gt $sessionAt) { exit 0 }
    }

    Set-Content -LiteralPath $nagged -Value (Get-Date -Format 'o') -Encoding UTF8

    Write-Output 'Uncommitted changes in this repository, and /handoff has not run this session. Run /handoff before /clear, or the reasoning goes with the context.'
} catch { }

exit 0
