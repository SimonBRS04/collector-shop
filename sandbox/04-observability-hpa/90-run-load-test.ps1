# Lance le test de charge k6 et suit le HPA toutes les 10 secondes.
# Affiche ensuite le résumé k6 et les contrôles OK / ECHEC.
$ErrorActionPreference = 'Continue'
$ns  = 'sandbox-obs'
$job = 'k6-load-test'
$script:failures = 0

function Check([string]$label, [bool]$condition) {
    if ($condition) { Write-Host "OK     $label" -ForegroundColor Green }
    else            { Write-Host "ECHEC  $label" -ForegroundColor Red; $script:failures++ }
}

kubectl delete job $job -n $ns --ignore-not-found 2>&1 | Out-Null
kubectl apply -f (Join-Path $PSScriptRoot '50-k6-job.yaml') | Out-Null
Write-Host "Test de charge lance (environ 3 min 30). Suivi du HPA :" -ForegroundColor Cyan
Write-Host ("{0,-10} {1,-10} {2,-10} {3}" -f 'heure', 'pods', 'souhaites', 'CPU moyen / cible 50 %')

$maxReplicas = 1
$start = Get-Date
do {
    Start-Sleep -Seconds 10
    $hpa = kubectl get hpa load-api -n $ns -o "jsonpath={.status.currentReplicas} {.status.desiredReplicas} {.status.currentMetrics[0].resource.current.averageUtilization}"
    $parts = "$hpa" -split ' '
    $current = [int]$parts[0]
    if ($current -gt $maxReplicas) { $maxReplicas = $current }
    Write-Host ("{0,-10} {1,-10} {2,-10} {3} %" -f (Get-Date -Format 'HH:mm:ss'), $parts[0], $parts[1], $parts[2])
    $status = kubectl get job $job -n $ns -o "jsonpath={.status.succeeded}{.status.failed}"
} while (-not $status -and ((Get-Date) - $start).TotalMinutes -lt 8)

Write-Host ""
$summary = kubectl logs -n $ns "job/$job"
$summary | Select-String -Pattern '===|requetes|debit|p95|erreur' | ForEach-Object { Write-Host $_.Line }

Write-Host "`n=== Controles ===" -ForegroundColor Cyan
Check "le test k6 s'est execute jusqu'au bout" ([bool]$status)
Check "le HPA a augmente le nombre de pods (maximum observe : $maxReplicas)" ($maxReplicas -gt 1)
Check "taux d'erreur sous le seuil de 1 %" ([bool]($summary | Select-String "seuil 1 % : respecte"))
$p95Ok = [bool]($summary | Select-String "seuil 500 ms : respecte")
if ($p95Ok) { Write-Host "OK     p95 sous le seuil de 500 ms" -ForegroundColor Green }
else { Write-Host "INFO   p95 au-dessus de 500 ms : axe d'amelioration a documenter (indicateur 5)" -ForegroundColor Yellow }

Write-Host "`nRetour a 1 pod attendu environ 1 a 2 minutes apres la fin de la charge : kubectl get hpa -n $ns -w"
if ($script:failures -eq 0) { Write-Host "RESULTAT : controles OK" -ForegroundColor Green }
else { Write-Host "RESULTAT : $($script:failures) controle(s) en echec" -ForegroundColor Red }
