#Requires -Version 5.1
<#
  Install this repository's Claude Code layer into ~/.claude.
  Symlinks by default, so editing the repository edits the live config.
  A symlink on Windows needs Administrator or Developer Mode; when it is refused
  this script copies instead and says so.

  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 [-Copy]
#>
[CmdletBinding()]
param([switch]$Copy)

$ErrorActionPreference = 'Stop'

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($env:CLAUDE_HOME) { $dest = $env:CLAUDE_HOME } else { $dest = Join-Path $HOME '.claude' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = New-Object System.Collections.ArrayList

function Add-Note([string]$Text) { [void]$report.Add($Text) }

New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'rules')  | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'skills') | Out-Null

# Find out once whether this account may create symlinks, rather than discovering
# it separately for every path and reporting a mix.
$symlinksUnavailable = $false
if ($Copy) {
    $mode = 'copy'
} else {
    $probe = Join-Path $dest ('.setup-symlink-probe.' + $PID)
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force -Recurse }
    try {
        New-Item -ItemType SymbolicLink -Path $probe -Value (Join-Path $src 'CLAUDE.md') -ErrorAction Stop | Out-Null
        $mode = 'link'
    } catch {
        $mode = 'copy'
        $symlinksUnavailable = $true
    }
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force -Recurse }
}

function Test-AlreadyLinked([string]$Source, [string]$Target) {
    if (-not (Test-Path -LiteralPath $Target)) { return $false }
    $item = Get-Item -LiteralPath $Target -Force
    if ($item.LinkType -ne 'SymbolicLink') { return $false }
    $current = $item.Target
    if ($current -is [array]) { $current = $current[0] }
    if (-not $current) { return $false }
    return ([System.IO.Path]::GetFullPath($current).TrimEnd('\') -eq
            [System.IO.Path]::GetFullPath($Source).TrimEnd('\'))
}

function Get-TreeFingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
    $parts = Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Path.Length).TrimStart('\') + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    if ($null -eq $parts) { $parts = @() }
    return ($parts -join '|')
}

function Test-SameContent([string]$Source, [string]$Target) {
    if (-not (Test-Path -LiteralPath $Target)) { return $false }
    if ((Get-Item -LiteralPath $Source -Force).PSIsContainer -ne
        (Get-Item -LiteralPath $Target -Force).PSIsContainer) { return $false }
    return ((Get-TreeFingerprint $Source) -eq (Get-TreeFingerprint $Target))
}

function Backup-Existing([string]$Target) {
    if (Test-Path -LiteralPath $Target) {
        $bak = "$Target.bak-$stamp"
        Move-Item -LiteralPath $Target -Destination $bak -Force
        Add-Note "  backed up   $bak"
    }
}

function Install-Path([string]$Source, [string]$Target) {
    if ($script:mode -eq 'link' -and (Test-AlreadyLinked $Source $Target)) {
        Add-Note "  unchanged   $Target  (link)"
        return
    }
    if ($script:mode -eq 'copy' -and (Test-Path -LiteralPath $Target)) {
        $existing = Get-Item -LiteralPath $Target -Force
        if ($existing.LinkType -ne 'SymbolicLink' -and (Test-SameContent $Source $Target)) {
            Add-Note "  unchanged   $Target  (copy)"
            return
        }
    }
    Backup-Existing $Target
    if ($script:mode -eq 'link') {
        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -ErrorAction Stop | Out-Null
        Add-Note "  link        $Target  ->  $Source"
    } else {
        Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
        Add-Note "  copy        $Target"
    }
}

Install-Path (Join-Path $src 'CLAUDE.md') (Join-Path $dest 'CLAUDE.md')

# Only *.md -- rules/README.txt is documentation for a human and is not a rule.
Get-ChildItem -LiteralPath (Join-Path $src 'rules') -Filter '*.md' -File | ForEach-Object {
    Install-Path $_.FullName (Join-Path (Join-Path $dest 'rules') $_.Name)
}

# One directory at a time: anything else already in ~/.claude/skills survives.
Get-ChildItem -LiteralPath (Join-Path $src 'skills') -Directory | ForEach-Object {
    Install-Path $_.FullName (Join-Path (Join-Path $dest 'skills') $_.Name)
}

Write-Output ''
Write-Output "Installed into $dest (mode: $mode)"
Write-Output ''
foreach ($line in $report) { Write-Output $line }

if ($symlinksUnavailable) {
    Write-Output ''
    Write-Output 'Symlinks were refused, so everything above was COPIED.'
    Write-Output 'Creating one on Windows needs Administrator or Developer Mode'
    Write-Output '(Settings > System > For developers > Developer Mode).'
    Write-Output 'A copy does not track edits to this repository -- re-run setup.ps1 after pulling.'
}

Write-Output ''
Write-Output 'Not installed:'
Write-Output '  rules/README.txt   documentation, not a rule -- a .md file there would load as one'
Write-Output ''
Write-Output 'settings.json was not touched, and this script will never touch it: it holds live'
Write-Output 'state -- enabled plugins, MCP servers, permission grants -- that a script has no'
Write-Output 'business merging. Add by hand if wanted, in ~/.claude/settings.json:'
Write-Output ''
Write-Output '  "tui": "fullscreen",'
Write-Output '  "autoUpdatesChannel": "latest"'
