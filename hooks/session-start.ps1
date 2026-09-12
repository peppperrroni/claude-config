#Requires -Version 5.1
<#
  Global SessionStart hook. Installed into ~/.claude/hooks/ and wired once, machine-wide,
  in ~/.claude/settings.json -- so a new project needs no hook wiring of its own.

  Two jobs:
    1. kick off a background pull of the claude-config repository, so the layer keeps
       itself current without a manual `git pull` before every session;
    2. put the current project's STATE.md in front of the fresh context, or say that
       there is none.

  Silent outside a git repository: an ad-hoc session in a scratch directory is not a
  project and should not be told about documents it has no use for.

  Never fails loudly. Every path ends in exit 0.
#>

$ErrorActionPreference = 'SilentlyContinue'

# ~/.claude, derived from this script's own location rather than $HOME: the installer
# honours $CLAUDE_HOME, and a hook that ignored it would read another tree's state.
$hooksDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeHome = Split-Path -Parent $hooksDir
$sourceFile = Join-Path $claudeHome '.claude-config-source'
$stateDir   = Join-Path $claudeHome '.claude-config-state'

# A hash, not a flattened path. The readable version -- lowercase the path and replace
# every non-alphanumeric -- produced a 120-character filename, which under a state
# directory that is itself deep pushed the whole path past Windows' 260-character limit;
# Set-Content then threw into a silent catch and the stamp was never written. Sixteen hex
# characters cannot do that at any depth.
function Get-RepoKey([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant()))
    } finally { $sha.Dispose() }
    return ((($bytes | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16))
}

# --- 1. background pull ------------------------------------------------------

try {
    if (Test-Path -LiteralPath $sourceFile) {
        $repo = (Get-Content -LiteralPath $sourceFile -Raw -Encoding UTF8).Trim()
        $pull = Join-Path $hooksDir 'pull.ps1'
        if ($repo -and (Test-Path -LiteralPath $pull)) {
            # Detached and hidden. Never waited on: see the measurement in pull.ps1.
            # Its stdio must not be inherited, or this hook's own output stays open and
            # Claude Code waits for a pull it was never supposed to wait for.
            Start-Process -FilePath 'powershell' `
                -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                                '-File', $pull, '-Repo', $repo) `
                -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        }
    }
} catch { }

# --- 2. project state -------------------------------------------------------

try {
    # Capture first, THEN check $LASTEXITCODE. Piping a native command into
    # Select-Object -First stops the pipeline early, and PowerShell reports that as
    # $LASTEXITCODE = -1 even when git succeeded -- so the guard rejected every repository.
    $out = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $root = (@($out) | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($root)) { exit 0 }
    $root = $root.Trim()

    # Stamp the session. stop.ps1 compares against this to remind at most once per
    # session, and stays silent entirely when the stamp is missing -- which is what
    # makes wiring only half of this block fail quiet instead of nagging every turn.
    try {
        if (-not (Test-Path -LiteralPath $stateDir)) {
            New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        }
        $key = Get-RepoKey $root
        Set-Content -LiteralPath (Join-Path $stateDir "$key.session") `
                    -Value (Get-Date -Format 'o') -Encoding UTF8
    } catch { }

    $state = Join-Path $root 'STATE.md'
    $text = $null
    if (Test-Path -LiteralPath $state) {
        # -Encoding UTF8 is not optional: Windows PowerShell 5.1 reads a BOM-less file in
        # the system ANSI codepage, which turns every non-ASCII character into mojibake.
        $text = Get-Content -LiteralPath $state -Raw -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        $context = 'No state documents in this project; /init-project creates them.'
    } else {
        $context = "STATE.md of this project, verbatim:`n`n$text"
    }

    # ConvertTo-Json does the escaping. Hand-rolling it is how a stray quote in STATE.md
    # turns into a hook that emits malformed JSON and is silently ignored.
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = $context
        }
    }
    $payload | ConvertTo-Json -Depth 5 -Compress
} catch { }

exit 0
