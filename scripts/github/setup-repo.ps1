# One-time setup of the GitHub repository for Collector.shop.
# Prerequisites: git, GitHub CLI (gh) authenticated with "gh auth login".
# Run from the repository root: powershell -ExecutionPolicy Bypass -File scripts/github/setup-repo.ps1
$ErrorActionPreference = 'Continue'

$owner       = 'SimonBRS04'
$repo        = 'collector-shop'
$fullName    = "$owner/$repo"
$description = 'Repository du BLOC 3 - Individuel - 2026-2027'

function Step([string]$label) { Write-Host "`n==> $label" -ForegroundColor Cyan }
function Assert-Success([string]$label) {
    if ($LASTEXITCODE -ne 0) { Write-Host "ECHEC : $label" -ForegroundColor Red; exit 1 }
    Write-Host "OK    : $label" -ForegroundColor Green
}

Step 'Checking GitHub authentication'
gh auth status
Assert-Success 'gh is authenticated'

Step 'Removing placeholder files from folders that now have content'
foreach ($placeholder in @('.github/workflows/.gitkeep', 'docs/adr/.gitkeep', 'scripts/.gitkeep')) {
    if (Test-Path $placeholder) { Remove-Item $placeholder; Write-Host "removed $placeholder" }
}

Step 'Initial commit on main'
if (-not (Test-Path '.git')) {
    git init -b main
    Assert-Success 'git init'
}
git add .
git commit -m "feat: initial project structure, quality process and sandbox experiments"
Assert-Success 'initial commit'

Step 'Creating the public repository and pushing main'
gh repo create $fullName --public --description $description --source . --remote origin --push
Assert-Success "repository $fullName created"

Step 'Merge settings: squash only, PR title as commit message, delete merged branches'
gh repo edit $fullName --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge
Assert-Success 'merge strategy'
gh api -X PATCH "repos/$fullName" -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY | Out-Null
Assert-Success 'squash commit message = PR title'

Step 'Allowing GitHub Actions to open pull requests (needed by release-please)'
gh api -X PUT "repos/$fullName/actions/permissions/workflow" -f default_workflow_permissions=write -F can_approve_pull_request_reviews=false | Out-Null
Assert-Success 'workflow permissions'

Step 'Protecting main'
$protection = @{
    required_status_checks        = @{ strict = $true; contexts = @('Validate PR title') }
    enforce_admins                = $true
    required_pull_request_reviews = @{ required_approving_review_count = 0 }
    restrictions                  = $null
    required_linear_history       = $true
    allow_force_pushes            = $false
    allow_deletions               = $false
} | ConvertTo-Json -Depth 5
$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $protection -Encoding ascii
gh api -X PUT "repos/$fullName/branches/main/protection" --input $tmp | Out-Null
Assert-Success 'branch protection on main'
Remove-Item $tmp

Write-Host "`nRepository ready: https://github.com/$fullName" -ForegroundColor Green
