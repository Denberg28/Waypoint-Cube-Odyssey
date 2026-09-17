param(
    [string]$RepoName = "Waypoint-Cube-Odyssey",
    [ValidateSet("private","public")][string]$Visibility = "private"
)
$ErrorActionPreference = "Stop"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is required." }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required." }

gh auth status
if ($LASTEXITCODE -ne 0) { throw "Run: gh auth login" }

if (-not (Test-Path .git)) { git init -b main }
git add .
if (git status --porcelain) { git commit -m "feat: Waypoint v0.22 Gemini Beta Tester Council" }

$remote = $null
$remoteNames = @(git remote)
if ($LASTEXITCODE -ne 0) { throw "Could not inspect Git remotes." }
if ($remoteNames -contains "origin") {
    $remote = (git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Could not read the existing origin remote." }
}

if ([string]::IsNullOrWhiteSpace($remote)) {
    $visFlag = if ($Visibility -eq "public") { "--public" } else { "--private" }
    gh repo create $RepoName --source . --remote origin --push $visFlag
    if ($LASTEXITCODE -ne 0) { throw "GitHub repository creation failed." }
} else {
    git push -u origin main
}

git show-ref --verify --quiet refs/heads/ai-development
if ($LASTEXITCODE -ne 0) { git branch ai-development main }
git push -u origin ai-development

$secure = Read-Host "Gemini API key (stored only as a GitHub Actions secret)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $plain | gh secret set GEMINI_API_KEY
    if ($LASTEXITCODE -ne 0) { throw "Could not store GEMINI_API_KEY." }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $plain = $null
}

gh variable set AI_CYCLE_ENABLED --body "true"
gh variable set AI_MAX_DAILY_CYCLES --body "8"
gh variable set BETA_TESTER_ENABLED --body "true"
gh variable set BETA_MAX_DAILY_COUNCILS --body "2"

Write-Host ""
Write-Host "Waypoint AI Development Lab is ready."
Write-Host "Main branch: protected/manual development source"
Write-Host "AI branch: ai-development"
Write-Host "Streamlit entrypoint: streamlit_app.py"
Write-Host "Default GM budget: 8 successful development cycles/day"
Write-Host "Default beta budget: 2 councils/day x 6 tester agents = up to 12 beta calls/day"
Write-Host "Set AI_MAX_DAILY_CYCLES to 24 only if you intentionally want an hourly Gemini call all day."
