#Requires -Version 5.1
<#
  Install this repository's Claude Code layer into ~/.claude.
  Symlinks by default, so editing the repository edits the live config.
  A symlink on Windows needs Administrator or Developer Mode; when it is refused
  this script copies instead and says so.

  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 [-Copy] [-Prune]

    -Copy   install copies instead of symlinks. Copies do not track edits to this
            repository -- re-run setup.ps1 after pulling.
    -Prune  delete entries this installer wrote earlier that no longer exist in the
            source. Without it, stale entries are only reported.

  Installs into $env:CLAUDE_HOME if set, otherwise ~/.claude.
  Never writes settings.json.
#>
[CmdletBinding()]
param([switch]$Copy, [switch]$Prune)

$ErrorActionPreference = 'Stop'

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($env:CLAUDE_HOME) { $dest = $env:CLAUDE_HOME } else { $dest = Join-Path $HOME '.claude' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = New-Object System.Collections.ArrayList

function Add-Note([string]$Text) { [void]$report.Add($Text) }

New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'rules')  | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'skills') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'hooks')  | Out-Null

$dest = (Get-Item -LiteralPath $dest -Force).FullName
$manifestPath = Join-Path $dest '.claude-config-manifest'
$sourceFile   = Join-Path $dest '.claude-config-source'

# Paths that prune must refuse even if a hand-edited manifest names them. Nothing
# here is ever installed, so a manifest entry naming one is corruption, not a record.
$protected = @('settings.json', 'settings.local.json', '.credentials.json',
               '.claude-config-manifest', '.claude-config-source')

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

# ---------------------------------------------------------------------------
# Manifest. Entries are paths relative to $dest, forward-slashed, and identical
# to the path relative to $src -- the two trees mirror each other, so one entry
# locates both. setup.sh reads and writes the same file, hence forward slashes,
# LF, and no BOM.
# ---------------------------------------------------------------------------

function Test-SafeEntry([string]$Entry) {
    if ([string]::IsNullOrWhiteSpace($Entry)) { return $false }
    if ($Entry -match '^[/\\]') { return $false }        # absolute
    if ($Entry -match '^[A-Za-z]:') { return $false }     # drive-qualified
    if (($Entry -split '/') -contains '..') { return $false }
    if ($protected -contains $Entry) { return $false }
    return $true
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $manifestPath)) { return @() }
    return @(Get-Content -LiteralPath $manifestPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and -not $_.StartsWith('#') })
}

function Write-Manifest([string[]]$Entries) {
    $lines = @('# Written by claude-config setup. -Prune / --prune reads this to find',
               '# entries that no longer exist in the source. Do not edit by hand.')
    $lines += @($Entries | Sort-Object -Unique)
    $text = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($manifestPath, $text,
        (New-Object System.Text.UTF8Encoding($false)))
}

# Test-Path follows a symlink, so it answers $false for one whose target is gone --
# and a dangling link is exactly what a pull that deleted a rule leaves behind in link
# mode. Falling back to a listing of the parent directory sees the name itself.
# (Verified here only for a junction, where Test-Path already answers $true; creating a
# real symlink to test needs Developer Mode. The fallback is correct either way.)
function Test-PathOrLink([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return $true }
    $parent = Split-Path -Parent $Path
    if (-not $parent -or -not (Test-Path -LiteralPath $parent)) { return $false }
    $leaf = Split-Path -Leaf $Path
    return (@(Get-ChildItem -LiteralPath $parent -Force |
              Where-Object { $_.Name -eq $leaf }).Count -gt 0)
}

function Remove-Installed([string]$Target) {
    $item = $null
    try { $item = Get-Item -LiteralPath $Target -Force } catch { }
    if ($null -eq $item) {
        # A dangling link Get-Item will not open. Delete the name, whichever kind it is.
        try { [System.IO.File]::Delete($Target) } catch { [System.IO.Directory]::Delete($Target, $false) }
        return
    }
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        # Delete the link, never through it. Remove-Item -Recurse on a directory
        # symlink or junction can empty the *target* in Windows PowerShell;
        # Directory.Delete($path, $false) removes only the reparse point.
        if ($item.PSIsContainer) { [System.IO.Directory]::Delete($Target, $false) }
        else { [System.IO.File]::Delete($Target) }
    } elseif ($item.PSIsContainer) {
        Remove-Item -LiteralPath $Target -Recurse -Force
    } else {
        Remove-Item -LiteralPath $Target -Force
    }
}

$installedEntries = New-Object System.Collections.ArrayList

function Install-Entry([string]$Relative) {
    $rel = $Relative.Replace('/', '\')
    Install-Path (Join-Path $src $rel) (Join-Path $dest $rel)
    [void]$installedEntries.Add($Relative)
}

Install-Entry 'CLAUDE.md'

# Only *.md -- rules/README.txt is documentation for a human and is not a rule.
Get-ChildItem -LiteralPath (Join-Path $src 'rules') -Filter '*.md' -File | ForEach-Object {
    Install-Entry ('rules/' + $_.Name)
}

# One directory at a time: anything else already in ~/.claude/skills survives.
Get-ChildItem -LiteralPath (Join-Path $src 'skills') -Directory | ForEach-Object {
    Install-Entry ('skills/' + $_.Name)
}

# Hooks. Both platforms' scripts are installed on both platforms: they are small, and a
# machine that installs only its own half cannot be diagnosed by running the other one.
Get-ChildItem -LiteralPath (Join-Path $src 'hooks') -File | ForEach-Object {
    Install-Entry ('hooks/' + $_.Name)
}

# Where the hooks find the repository to pull. Written rather than compiled in, because
# the clone lives wherever it was cloned and this script is the only thing that knows.
[System.IO.File]::WriteAllText($sourceFile, $src + "`n",
    (New-Object System.Text.UTF8Encoding($false)))

# ---------------------------------------------------------------------------
# Stale entries. The manifest is the union of what was installed before and what
# was installed just now: rewriting it with only the current set would erase the
# record of the very entries prune exists to find.
# ---------------------------------------------------------------------------

$tracked = @(@(Read-Manifest) + @($installedEntries.ToArray()) |
             Where-Object { Test-SafeEntry $_ } | Sort-Object -Unique)

$keep  = New-Object System.Collections.ArrayList
$stale = New-Object System.Collections.ArrayList

foreach ($entry in $tracked) {
    $rel = $entry.Replace('/', '\')
    if (Test-Path -LiteralPath (Join-Path $src $rel)) { [void]$keep.Add($entry); continue }

    $target = Join-Path $dest $rel
    # Already gone -- deleted by hand, or pruned by an earlier run: nothing to clean, and
    # no reason to keep reporting it. Dropping it here is what stops a pruned entry from
    # being rediscovered as stale on every later run.
    if (-not (Test-PathOrLink $target)) { continue }

    # Never act outside $dest, whatever the manifest says.
    $full = [System.IO.Path]::GetFullPath($target)
    if (-not $full.StartsWith($dest.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Add-Note "  skipped     $entry  (resolves outside $dest)"
        continue
    }
    [void]$stale.Add($entry)
}

foreach ($entry in $stale) {
    $target = Join-Path $dest $entry.Replace('/', '\')
    if ($Prune) {
        Remove-Installed $target
        Add-Note "  pruned      $target"
    } else {
        [void]$keep.Add($entry)
        Add-Note "  stale       $target  (gone from source; -Prune removes it)"
    }
}

Write-Manifest $keep.ToArray()

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

if ($stale.Count -gt 0 -and -not $Prune) {
    Write-Output ''
    Write-Output 'Stale entries above were installed by an earlier run and are gone from the'
    Write-Output 'source. Re-run with -Prune to delete them. Nothing outside the manifest is'
    Write-Output 'ever considered, so skills linked here from elsewhere are not at risk.'
}

Write-Output ''
Write-Output 'Not installed:'
Write-Output '  rules/README.txt   documentation, not a rule -- a .md file there would load as one'
Write-Output '  templates/         copied into a project by /init-project; see README'

# ---------------------------------------------------------------------------
# git hooks in the source repository, so a pull re-installs itself.
# ---------------------------------------------------------------------------

$hooksPathSet = $false
try {
    if (Test-Path -LiteralPath (Join-Path $src '.git')) {
        $current = (& git -C $src config --get core.hooksPath 2>$null | Select-Object -First 1)
        if ($current -ne '.githooks') {
            & git -C $src config core.hooksPath .githooks 2>$null | Out-Null
            $current = (& git -C $src config --get core.hooksPath 2>$null | Select-Object -First 1)
        }
        $hooksPathSet = ($current -eq '.githooks')
    }
} catch { }

Write-Output ''
if ($hooksPathSet) {
    Write-Output 'git config core.hooksPath = .githooks  (set in the source repository)'
    Write-Output '  A pull now re-runs this installer with -Prune, so the live config follows the'
    Write-Output '  tree without a second command. It also means .git/hooks is bypassed in this'
    Write-Output '  repository -- nothing of mine lives there, but that is the trade.'
} else {
    Write-Output 'git config core.hooksPath was NOT set (source is not a git repository, or git'
    Write-Output '  is unavailable). Re-run setup after every pull; see README section 4.'
}

# ---------------------------------------------------------------------------
# The one block to paste. Built here rather than documented in the README because
# it carries absolute paths, which are a fact about this machine.
# ---------------------------------------------------------------------------

$ssCmd   = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' +
           (Join-Path $dest 'hooks\session-start.ps1') + '"'
$stopCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' +
           (Join-Path $dest 'hooks\stop.ps1') + '"'

# ConvertTo-Json on the two strings alone, not on the whole object: it escapes the
# backslashes correctly, and Windows PowerShell 5.1's whole-object indentation aligns
# every value under the widest key, which nobody can read or diff.
$ssJson   = $ssCmd   | ConvertTo-Json
$stopJson = $stopCmd | ConvertTo-Json

Write-Output ''
Write-Output 'settings.json was not touched, and this script will never touch it: it holds live'
Write-Output 'state -- enabled plugins, MCP servers, permission grants -- that a script has no'
Write-Output 'business merging. Paste this into ~/.claude/settings.json by hand, merging the'
Write-Output '"hooks" key if the file already has one:'
Write-Output ''
Write-Output '  {'
Write-Output '    "hooks": {'
Write-Output '      "SessionStart": ['
Write-Output '        {'
Write-Output '          "hooks": ['
Write-Output ('            { "type": "command", "command": ' + $ssJson + ' }')
Write-Output '          ]'
Write-Output '        }'
Write-Output '      ],'
Write-Output '      "Stop": ['
Write-Output '        {'
Write-Output '          "hooks": ['
Write-Output ('            { "type": "command", "command": ' + $stopJson + ' }')
Write-Output '          ]'
Write-Output '        }'
Write-Output '      ]'
Write-Output '    }'
Write-Output '  }'
Write-Output ''
Write-Output 'SessionStart pulls this repository in the background and shows the project'
Write-Output 'STATE.md. Stop reminds, once per session, that the tree is dirty and /handoff'
Write-Output 'has not run. Wire both or neither: the Stop reminder stays silent unless'
Write-Output 'SessionStart has stamped the session.'
Write-Output ''
Write-Output 'Worth having in the same file, unrelated to hooks:'
Write-Output ''
Write-Output '  "tui": "fullscreen",'
Write-Output '  "autoUpdatesChannel": "latest"'
