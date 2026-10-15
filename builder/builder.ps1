# Dev PC loop: take the oldest ready spec, build it with Claude Code (subscription), merge to main.
# Register with Task Scheduler (see docs/setup-dev-pc.md).

param(
    [int]$TimeoutMinutes = 60,
    [int]$MaxRunsPerDay = 12
)

. (Join-Path $PSScriptRoot '..\scripts\common.ps1')
$Role = 'builder'

$lock = Get-Lock $Role
if (-not $lock) { Write-Log $Role 'Another builder run is active. Exit.'; exit 0 }

function Finish-Spec {
    # Records the final status on main and pushes.
    param([string]$SpecPath, [string]$Status, [string]$Id)
    Invoke-Git checkout main | Out-Null
    Invoke-Git pull --rebase origin main | Out-Null
    Set-SpecStatus $SpecPath $Status
    Invoke-Git add -- $SpecPath | Out-Null
    Invoke-Git commit -m "spec: $Id -> $Status" | Out-Null
    Invoke-Git push origin main | Out-Null
}

try {
    if (Test-DailyCap $Role $MaxRunsPerDay) { Write-Log $Role 'Daily cap reached. Exit.'; exit 0 }

    Reset-Repo

    # We hold the lock, so any in-progress spec is left over from a crashed run.
    foreach ($stale in @(Get-Specs | Where-Object Status -eq 'in-progress')) {
        Write-Log $Role "Stale in-progress spec $($stale.Name) -> failed"
        Finish-Spec $stale.Path 'failed' $stale.Id
    }

    $spec = Get-Specs | Where-Object Status -eq 'ready' | Select-Object -First 1
    if (-not $spec) { Write-Log $Role 'No ready spec. Exit.'; exit 0 }
    Write-Log $Role "RUN-START $($spec.Name)"

    # Claim the spec so the planning PC sees it is being worked on.
    Set-SpecStatus $spec.Path 'in-progress'
    Invoke-Git add -- $spec.Path | Out-Null
    Invoke-Git commit -m "spec: $($spec.Id) -> in-progress" | Out-Null
    Invoke-Git push origin main | Out-Null

    $branch = "feat/$($spec.Id)"
    Invoke-Git checkout -B $branch | Out-Null

    $slug = [IO.Path]::GetFileNameWithoutExtension($spec.Name)
    $prompt = (Read-Utf8 (Join-Path $PSScriptRoot 'prompt.md')).
        Replace('{{SPEC_PATH}}', "specs/$($spec.Name)").
        Replace('{{APP_DIR}}', "apps/$slug").
        Replace('{{REPORT_PATH}}', "reports/$($spec.Id).md")

    # Permissions come from builder/claude-settings.json, applied only to this unattended run
    # (kept out of .claude/ so interactive sessions can still edit the pipeline scripts).
    $settings = Join-Path $PSScriptRoot 'claude-settings.json'
    $code = Invoke-WithTimeout -Command 'claude' `
        -Arguments @('-p', '--settings', "`"$settings`"", '--permission-mode', 'acceptEdits', '--output-format', 'text') `
        -PromptText $prompt -TimeoutMinutes $TimeoutMinutes -LogName "builder-$($spec.Id)"
    Write-Log $Role "claude exit code: $code"

    # Commit whatever Claude left uncommitted on the branch.
    Invoke-Git add -A -- apps reports | Out-Null
    $pending = Invoke-Git status --porcelain -- apps reports
    if ($pending) { Invoke-Git commit -m "feat($($spec.Id)): build output" | Out-Null }

    $report = Join-Path $RepoRoot "reports\$($spec.Id).md"
    $succeeded = ($code -eq 0) -and (Test-Path $report) -and ((Read-Utf8 $report) -match '(?m)^result:\s*success')

    if ($succeeded) {
        Invoke-Git checkout main | Out-Null
        Invoke-Git pull --rebase origin main | Out-Null
        Invoke-Git merge --no-ff $branch -m "merge: $($spec.Name)" | Out-Null
        Set-SpecStatus $spec.Path 'done'
        Invoke-Git add -- $spec.Path | Out-Null
        Invoke-Git commit -m "spec: $($spec.Id) -> done" | Out-Null
        Invoke-Git push origin main | Out-Null
        Invoke-Git branch -d $branch | Out-Null
        Write-Log $Role "DONE $($spec.Name)"
    }
    else {
        # Keep the branch on GitHub for inspection; mark the spec failed on main.
        Invoke-Git push -f origin $branch | Out-Null
        Finish-Spec $spec.Path 'failed' $spec.Id
        Write-Log $Role "FAILED $($spec.Name) (timeout=-1 or no success report). Branch pushed: $branch"
    }
}
catch {
    Write-Log $Role "ERROR: $_"
    exit 1
}
finally {
    # Stop app containers so failed or finished runs do not pile up.
    $ErrorActionPreference = 'Continue'
    if ($slug -and (Test-Path (Join-Path $RepoRoot "apps\$slug"))) {
        & docker compose --project-directory (Join-Path $RepoRoot "apps\$slug") down 2>&1 | Out-Null
    }
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
