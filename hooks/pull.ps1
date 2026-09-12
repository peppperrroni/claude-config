#Requires -Version 5.1
<#
  Pull the claude-config repository, quietly, with a hard timeout.

  Launched detached by session-start.ps1 and never waited on, because a synchronous
  pull measured 1.1-1.25s against a warm network -- paid at the start of every single
  session, to deliver a change that is almost never there. The timeout still matters:
  detached is not the same as abandoned, and a hung git would otherwise sit there.

  Silent in every failure mode by construction: offline, conflict, no git, no repo,
  detached HEAD, credentials prompt. --ff-only is what makes that safe -- it declines
  rather than merging, so an unpushed local commit is never resolved behind my back.
#>
param([string]$Repo)

$ErrorActionPreference = 'SilentlyContinue'

try {
    if ([string]::IsNullOrWhiteSpace($Repo)) { exit 0 }
    if (-not (Test-Path -LiteralPath $Repo)) { exit 0 }
    # .git is a directory in a normal clone and a file in a worktree; both are fine.
    if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) { exit 0 }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { exit 0 }

    $p = Start-Process -FilePath $git.Source `
                       -ArgumentList @('-C', $Repo, 'pull', '--ff-only', '-q') `
                       -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
    if ($null -eq $p) { exit 0 }

    # GIT_TERMINAL_PROMPT would be the belt to this braces, but it has to be set in the
    # child's environment, and -WindowStyle Hidden already means a prompt can never be
    # answered. The timeout collects it either way.
    if (-not $p.WaitForExit(3000)) {
        try { $p.Kill() } catch { }
    }
} catch { }

exit 0
