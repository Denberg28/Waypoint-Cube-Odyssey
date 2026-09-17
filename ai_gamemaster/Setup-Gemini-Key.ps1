$ErrorActionPreference = "Stop"
Write-Host "This stores GEMINI_API_KEY as a Windows USER environment variable."
$secure = Read-Host "Paste your Gemini API key" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    if ([string]::IsNullOrWhiteSpace($plain)) { throw "API key was empty." }
    [Environment]::SetEnvironmentVariable("GEMINI_API_KEY", $plain, "User")
    $env:GEMINI_API_KEY = $plain
    Write-Host "GEMINI_API_KEY saved for your Windows user. Restart terminals opened before this command."
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $plain = $null
}
