#Requires -Version 5.1
<#
  The Windows half of the post-merge hook. Called by .githooks/post-merge, which is what
  git actually runs -- git invokes hooks through a shell even on Windows, so the sh
  script is the entry point and this is where the work happens.

  Re-installs with -Prune, so a pull that deleted a rule takes its installed copy or
  dangling link with it.
#>

$ErrorActionPreference = 'Continue'

try {
    $hookDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent $hookDir
    $setup    = Join-Path $repoRoot 'setup.ps1'
    if (-not (Test-Path -LiteralPath $setup)) { exit 0 }

    # Called, not spawned: setup.ps1 resolves its source directory from its own path,
    # which the call operator sets correctly, and a second powershell.exe would cost a
    # quarter of a second for nothing.
    & $setup -Prune
} catch {
    # A failed re-install must never fail the merge. The pull already succeeded; the
    # worst case is that ~/.claude is one run out of date, which the next session fixes.
    Write-Output "post-merge: setup did not complete ($($_.Exception.Message))"
}

exit 0
