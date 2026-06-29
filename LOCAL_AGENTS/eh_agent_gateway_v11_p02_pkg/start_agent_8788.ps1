$ErrorActionPreference = "Stop"

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PackageRoot

$EnvFile = Join-Path $PackageRoot ".env"
if (Test-Path -LiteralPath $EnvFile) {
  Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $Line = $_.Trim()
    if ($Line -and -not $Line.StartsWith("#") -and $Line.Contains("=")) {
      $Parts = $Line.Split("=", 2)
      $Name = $Parts[0].Trim()
      $Value = $Parts[1].Trim().Trim('"')
      [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    }
  }
}

Write-Host "==============================================="
Write-Host "EH Agent Gateway v11 P02-first rebuild"
Write-Host "LIVE FILL DISABLED"
Write-Host "SUBMIT DISABLED"
Write-Host "ROBOT BARAT NOT CONNECTED"
Write-Host "Host: 127.0.0.1"
Write-Host "Port: 8788"
Write-Host "==============================================="

$Activate = Join-Path $PackageRoot ".venv\Scripts\Activate.ps1"
if (-not (Test-Path -LiteralPath $Activate)) {
  throw "Virtual environment not found. Run .\install_requirements.ps1 first."
}

. $Activate
python -m uvicorn eh_agent_gateway_v11_p02:app --host 127.0.0.1 --port 8788
