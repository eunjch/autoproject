# Planning PC loop: research trends with Codex CLI (ChatGPT subscription) and push one new spec.
# Register with Task Scheduler (see docs/setup-planning-pc.md).

param(
    [int]$MaxReady = 2,          # skip when this many specs are still waiting for the dev PC
    [int]$TimeoutMinutes = 30,
    [int]$MaxRunsPerDay = 4
)

. (Join-Path $PSScriptRoot '..\scripts\common.ps1')
$Role = 'planner'
$SectionRequirements = '(?m)^## \uAE30\uB2A5 \uC694\uAD6C\uC0AC\uD56D'  # requirements heading
$SectionDone = '(?m)^## \uC644\uB8CC \uAE30\uC900'  # done-criteria heading

$lock = Get-Lock $Role
if (-not $lock) { Write-Log $Role 'Another planner run is active. Exit.'; exit 0 }

try {
    if (Test-DailyCap $Role $MaxRunsPerDay) { Write-Log $Role 'Daily cap reached. Exit.'; exit 0 }
    Write-Log $Role 'RUN-START'

    Reset-Repo

    $specs = @(Get-Specs)
    $ready = @($specs | Where-Object Status -eq 'ready').Count
    if ($ready -ge $MaxReady) { Write-Log $Role "$ready specs still ready. Exit."; exit 0 }

    $nextId = '{0:D4}' -f ($(if ($specs.Count) { [int]$specs[-1].Id } else { 0 }) + 1)
    $existing = ($specs | ForEach-Object { '- ' + $_.Name + ' (' + $_.Status + ')' }) -join "`n"
    if (-not $existing) { $existing = '(none yet)' }

    $prompt = (Read-Utf8 (Join-Path $PSScriptRoot 'prompt.md')).
        Replace('{{NEXT_ID}}', $nextId).
        Replace('{{TODAY}}', (Get-Date -Format 'yyyy-MM-dd')).
        Replace('{{EXISTING_SPECS}}', $existing)

    # --full-auto: workspace-write sandbox, no approval prompts. Web search is enabled via config.
    $code = Invoke-WithTimeout -Command 'codex' `
        -Arguments @('exec', '--full-auto', '-c', 'tools.web_search=true', '-') `
        -PromptText $prompt -TimeoutMinutes $TimeoutMinutes -LogName "planner-$nextId"
    Write-Log $Role "codex exit code: $code"

    # Accept exactly one new spec with the expected id; discard every other change.
    $new = @(Get-ChildItem (Join-Path $RepoRoot 'specs') -Filter "$nextId-*.md")
    $valid = $false
    if ($code -eq 0 -and $new.Count -eq 1) {
        $text = Read-Utf8 $new[0].FullName
        # Required headings from specs/_template.md, escaped to keep this file ASCII.
        $valid = ($text -match "(?m)^id:\s*$nextId") -and ($text -match '(?m)^status:\s*ready') -and
                 ($text -match $SectionRequirements) -and ($text -match $SectionDone)
    }

    if (-not $valid) {
        Write-Log $Role 'Spec missing or invalid. Discarding changes.'
        Invoke-Git reset --hard | Out-Null
        Invoke-Git clean -fd | Out-Null
        exit 1
    }

    Invoke-Git reset | Out-Null
    Invoke-Git add -- $new[0].FullName | Out-Null
    Invoke-Git commit -m "spec: add $($new[0].Name)" | Out-Null
    Invoke-Git checkout -- . | Out-Null   # drop any stray edits outside the new spec
    Invoke-Git clean -fd | Out-Null
    Invoke-Git push origin main | Out-Null
    Write-Log $Role "Pushed $($new[0].Name)"
}
catch {
    Write-Log $Role "ERROR: $_"
    exit 1
}
finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
