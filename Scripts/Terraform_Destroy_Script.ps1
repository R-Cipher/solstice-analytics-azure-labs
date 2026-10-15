$root = "C:\Users\ROMY\Documents\AZ-104 Labs\Solstice-Analytics-Labs"
$labs = @(
  @{ Folder = "Lab-05-Monitoring";            Args = @() },
  @{ Folder = "Lab-04-Virtual-Networking";    Args = @() },
  @{ Folder = "Lab-03-Compute";               Args = @("-var=deploy_batch_job=true") },
  @{ Folder = "Lab-02-Storage";               Args = @() },
  @{ Folder = "Lab-01-Identity & Governance"; Args = @() }
)
foreach ($lab in $labs) {
  Push-Location (Join-Path $root "$($lab.Folder)\Terraform")
  try {
    terraform destroy @($lab.Args)
    if ($LASTEXITCODE -ne 0) { Write-Host "Stopped at $($lab.Folder)"; break }
  } finally { Pop-Location }
}