# Shared helpers for planner.ps1 / builder.ps1 (Windows PowerShell 5.1 compatible).
# Keep this file ASCII-only: PS 5.1 reads BOM-less .ps1 files as ANSI.

$ErrorActionPreference = 'Stop'

# Pipe/redirect text to native tools as UTF-8 so Korean prompts survive.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LogDir = Join-Path $RepoRoot 'logs'
New-Item -ItemType Directory -Force $LogDir | Out-Null

function Write-Log {
    param([string]$Role, [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Role, $Message
    Write-Host $line
    $file = Join-Path $LogDir ('{0}-{1}.log' -f $Role, (Get-Date -Format 'yyyyMMdd'))
    [System.IO.File]::AppendAllText($file, $line + "`r`n", $Utf8NoBom)
}

function Invoke-Git {
    # Runs git in the repo and throws on failure. git writes progress to stderr, which
    # PS 5.1 turns into terminating errors under 'Stop', so relax it for this call only.
    $ErrorActionPreference = 'Continue'
    $out = & git -C $RepoRoot @args 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed: $out" }
    return $out
}

function Reset-Repo {
    # Recovers from a crashed run: drop leftovers, return to an up-to-date main.
    # The clone on each PC is dedicated to the pipeline, so local edits are not kept.
    Invoke-Git reset --hard | Out-Null
    Invoke-Git clean -fd | Out-Null
    Invoke-Git checkout main | Out-Null
    Invoke-Git reset --hard origin/main | Out-Null
    Invoke-Git pull --rebase origin main | Out-Null
}

function Read-Utf8 { param([string]$Path) [System.IO.File]::ReadAllText($Path, $Utf8NoBom) }
function Write-Utf8 { param([string]$Path, [string]$Text) [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom) }

function Get-Specs {
    # Returns spec files (specs/NNNN-*.md) with parsed id and status, oldest id first.
    Get-ChildItem (Join-Path $RepoRoot 'specs') -Filter '*.md' |
        Where-Object { $_.Name -match '^\d{4}-' } |
        Sort-Object Name |
        ForEach-Object {
            $text = Read-Utf8 $_.FullName
            $status = if ($text -match '(?m)^status:\s*(\S+)') { $Matches[1] } else { 'unknown' }
            [pscustomobject]@{ Id = $_.Name.Substring(0, 4); Path = $_.FullName; Name = $_.Name; Status = $status }
        }
}

function Set-SpecStatus {
    param([string]$Path, [string]$Status)
    $text = Read-Utf8 $Path
    Write-Utf8 $Path ([regex]::Replace($text, '(?m)^status:\s*\S+', "status: $Status", 1))
}

function Test-DailyCap {
    # True when the role already ran $Max times today (counted by RUN-START markers).
    param([string]$Role, [int]$Max)
    $file = Join-Path $LogDir ('{0}-{1}.log' -f $Role, (Get-Date -Format 'yyyyMMdd'))
    if (-not (Test-Path $file)) { return $false }
    $count = @(Select-String -Path $file -Pattern 'RUN-START' -SimpleMatch).Count
    return $count -ge $Max
}

function Invoke-WithTimeout {
    # Runs a CLI through cmd.exe (works for .exe and npm .cmd shims), feeding
    # $PromptText on stdin. Kills the whole process tree after $TimeoutMinutes.
    # Returns the exit code, or -1 on timeout.
    param([string]$Command, [string[]]$Arguments, [string]$PromptText, [int]$TimeoutMinutes, [string]$LogName)
    $promptFile = Join-Path $LogDir "$LogName.prompt.txt"
    $outFile = Join-Path $LogDir "$LogName.out.txt"
    $errFile = Join-Path $LogDir "$LogName.err.txt"
    Write-Utf8 $promptFile $PromptText
    $argLine = '/c chcp 65001 >nul & ' + $Command + ' ' + ($Arguments -join ' ')
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $argLine -WorkingDirectory $RepoRoot `
        -RedirectStandardInput $promptFile -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
        -NoNewWindow -PassThru
    $null = $p.Handle  # cache the handle, otherwise PS 5.1 reports an empty ExitCode
    if (-not $p.WaitForExit($TimeoutMinutes * 60 * 1000)) {
        & taskkill /T /F /PID $p.Id | Out-Null
        return -1
    }
    return $p.ExitCode
}

function Get-Lock {
    # Simple per-machine lock so overlapping scheduled runs exit immediately.
    param([string]$Role)
    $lock = Join-Path $LogDir "$Role.lock"
    if (Test-Path $lock) {
        $age = (Get-Date) - (Get-Item $lock).LastWriteTime
        if ($age.TotalHours -lt 3) { return $null }  # stale locks (crash) expire after 3h
        Remove-Item $lock -Force
    }
    Set-Content -Path $lock -Value $PID
    return $lock
}
