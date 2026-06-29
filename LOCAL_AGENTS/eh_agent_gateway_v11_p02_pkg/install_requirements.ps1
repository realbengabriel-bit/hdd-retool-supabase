$ErrorActionPreference = "Stop"

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PackageRoot

if (-not (Test-Path -LiteralPath ".venv")) {
  Write-Host "Creating Python virtual environment..."
  python -m venv .venv
}

$Activate = Join-Path $PackageRoot ".venv\Scripts\Activate.ps1"
if (-not (Test-Path -LiteralPath $Activate)) {
  throw "Virtual environment activation script not found: $Activate"
}

. $Activate

python -m pip install --upgrade pip
python -m pip install -r requirements.txt

Write-Host "Requirements installed for eh_agent_gateway_v11_p02."
Write-Host "Safety reminder: this package does not enable live fill or submit."
