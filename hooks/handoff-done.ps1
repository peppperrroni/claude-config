#Requires -Version 5.1
<#
  Record that /handoff ran for the repository containing the working directory, so the
  Stop hook stops reminding for the rest of this session.

  It exists as a script rather than as a line in SKILL.md telling the model to touch a
  path because the path contains a derived key, and a key computed by hand in prose is a
  key that will one day be computed differently in the two places that have to agree.

  Run from the repository whose handoff just finished.
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
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'Not a git repository; nothing recorded.'
        exit 0
    }
    $root = (@($out) | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($root)) { exit 0 }
    $root = $root.Trim()

    # Must match session-start.ps1 and stop.ps1 exactly. A hash rather than a flattened
    # path, because the flattened form ran the full path past Windows' 260 character
    # limit and the stamp silently failed to write. See session-start.ps1.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))
    } finally { $sha.Dispose() }
    $key = ((($bytes | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16))

    if (-not (Test-Path -LiteralPath $stateDir)) {
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $stateDir "$key.handoff") `
                -Value (Get-Date -Format 'o') -Encoding UTF8

    Write-Output 'handoff recorded.'
} catch { }

exit 0
