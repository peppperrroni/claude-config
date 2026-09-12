#Requires -Version 5.1
# SessionStart hook: put STATE.md in front of a fresh context, so the first thing the
# model knows about this project is where the last session stopped.
#
# Silent when there is no STATE.md -- a project that keeps no state document should not
# be nagged on every session.

$ErrorActionPreference = 'Stop'

# Resolve from the script's own location, not the working directory: a hook is not
# guaranteed to run from the project root.
$hooks   = Split-Path -Parent $MyInvocation.MyCommand.Path
$root    = Split-Path -Parent (Split-Path -Parent $hooks)
$state   = Join-Path $root 'STATE.md'

if (-not (Test-Path -LiteralPath $state)) { exit 0 }

# -Encoding UTF8 is not optional: Windows PowerShell 5.1 reads a BOM-less file in the
# system ANSI codepage, which turns every non-ASCII character in STATE.md into mojibake.
$text = Get-Content -LiteralPath $state -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($text)) { exit 0 }

# ConvertTo-Json does the escaping. Hand-rolling it is how a stray quote in STATE.md
# turns into a hook that emits malformed JSON and is silently ignored.
$payload = @{
    hookSpecificOutput = @{
        hookEventName     = 'SessionStart'
        additionalContext = "STATE.md of this project, verbatim:`n`n$text"
    }
}

$payload | ConvertTo-Json -Depth 5 -Compress
