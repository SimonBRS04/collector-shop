# Génère le mot de passe administrateur de Grafana dans un Secret Kubernetes (rien dans Git).
$ErrorActionPreference = 'Continue'
$ns = 'monitoring'
$name = 'grafana-admin'

kubectl get secret $name -n $ns 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Le secret $name existe deja : conserve."
    exit 0
}

$password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
kubectl create secret generic $name -n $ns "--from-literal=admin-user=admin" "--from-literal=admin-password=$password"
Write-Host "Secret $name cree."
