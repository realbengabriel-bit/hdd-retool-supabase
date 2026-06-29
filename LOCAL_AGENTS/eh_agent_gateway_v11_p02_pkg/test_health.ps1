$ErrorActionPreference = "Stop"

$BaseUrl = "http://127.0.0.1:8788"

Write-Host "Testing EH Agent Gateway health only."
Write-Host "No mutating, dry-run, fill, submit, or package endpoint will be called."

Write-Host "GET /health"
Invoke-RestMethod -Method Get -Uri "$BaseUrl/health"

Write-Host "GET /version"
Invoke-RestMethod -Method Get -Uri "$BaseUrl/version"
