# Exécute les deux scénarios de l'expérience 3 et affiche OK / ECHEC pour chaque contrôle.
# Prérequis : RabbitMQ et les deux consommateurs déployés et prêts.
$ErrorActionPreference = 'Continue'
$ns  = 'sandbox-mq'
$dir = $PSScriptRoot
$script:failures = 0

function Check([string]$label, [bool]$condition) {
    if ($condition) { Write-Host "OK     $label" -ForegroundColor Green }
    else            { Write-Host "ECHEC  $label" -ForegroundColor Red; $script:failures++ }
}

function Run-PublishJob([string]$file, [string]$job) {
    kubectl delete job $job -n $ns --ignore-not-found 2>&1 | Out-Null
    kubectl apply -f (Join-Path $dir $file) | Out-Null
    kubectl wait -n $ns --for=condition=complete "job/$job" --timeout=120s | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-QueueDepth([string]$queue) {
    $lines = kubectl exec -n $ns rabbitmq-0 -- rabbitmqctl list_queues name messages --quiet --no-table-headers
    foreach ($line in $lines) {
        $parts = $line -split '\s+'
        if ($parts[0] -eq $queue) { return [int]$parts[1] }
    }
    return -1
}

Write-Host "`n=== Scenario 1 : un evenement, deux consommateurs ===" -ForegroundColor Cyan
Check "publication de evt-001 confirmee par le broker" (Run-PublishJob '40-publish-job.yaml' 'publish-price-1')
Start-Sleep -Seconds 3
$notif = kubectl logs -n $ns deployment/consumer-notification -c consumer
$fraud = kubectl logs -n $ns deployment/consumer-fraud -c consumer
Check "notification a recu evt-001" ([bool]($notif | Select-String 'received evt-001'))
Check "fraud a recu evt-001"        ([bool]($fraud | Select-String 'received evt-001'))
Check "pas d'alerte fraude pour +20 %" (-not ($fraud | Select-String 'evt-001.*ALERT'))

Write-Host "`n=== Scenario 2 : resilience (consommateur fraud arrete) ===" -ForegroundColor Cyan
kubectl scale deployment/consumer-fraud -n $ns --replicas=0 | Out-Null
kubectl wait -n $ns --for=delete pod -l app=consumer-fraud --timeout=60s 2>&1 | Out-Null
Check "consommateur fraud arrete" (-not (kubectl get pods -n $ns -l app=consumer-fraud -o name))

Check "publication de evt-002 confirmee par le broker" (Run-PublishJob '50-publish-job-resilience.yaml' 'publish-price-2')
Start-Sleep -Seconds 3
$depth = Get-QueueDepth 'fraud.price-changed'
Check "evt-002 conserve dans la file fraud.price-changed (messages en attente : $depth)" ($depth -eq 1)
$notif = kubectl logs -n $ns deployment/consumer-notification -c consumer
Check "notification a recu evt-002 sans attendre fraud" ([bool]($notif | Select-String 'received evt-002'))

kubectl scale deployment/consumer-fraud -n $ns --replicas=1 | Out-Null
kubectl rollout status deployment/consumer-fraud -n $ns --timeout=180s | Out-Null
Start-Sleep -Seconds 3
$fraud = kubectl logs -n $ns deployment/consumer-fraud -c consumer
Check "fraud redemarre a recupere evt-002" ([bool]($fraud | Select-String 'received evt-002'))
Check "fraud a leve l'alerte (+150 % > 50 %)" ([bool]($fraud | Select-String 'evt-002.*ALERT'))
Check "file fraud.price-changed videe apres traitement" ((Get-QueueDepth 'fraud.price-changed') -eq 0)

Write-Host "`n=== Journaux des consommateurs ===" -ForegroundColor Cyan
kubectl logs -n $ns deployment/consumer-notification -c consumer
kubectl logs -n $ns deployment/consumer-fraud -c consumer

if ($script:failures -eq 0) { Write-Host "`nRESULTAT : tous les controles sont OK" -ForegroundColor Green }
else { Write-Host "`nRESULTAT : $($script:failures) controle(s) en echec" -ForegroundColor Red }
