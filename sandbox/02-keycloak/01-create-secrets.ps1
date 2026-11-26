# Génère des mots de passe aléatoires et les stocke dans un Secret Kubernetes.
# Aucun mot de passe n'est écrit dans le dépôt Git.
$ErrorActionPreference = 'Stop'
$ns = 'sandbox-auth'
$name = 'sandbox-auth-secrets'

# Vérifie si le secret existe déjà (sans interrompre le script si kubectl renvoie une erreur)
$ErrorActionPreference = 'Continue'
kubectl get secret $name -n $ns 2>&1 | Out-Null
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'
if ($exists) {
    Write-Host "Le secret $name existe deja : conserve (PostgreSQL est initialise avec ce mot de passe)."
    exit 0
}

function New-RandomPassword {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
}

$pg     = New-RandomPassword
$admin  = New-RandomPassword
$seller = New-RandomPassword
$buyer  = New-RandomPassword

kubectl create secret generic $name -n $ns `
    "--from-literal=postgres-password=$pg" `
    "--from-literal=keycloak-admin-password=$admin" `
    "--from-literal=seller-password=$seller" `
    "--from-literal=buyer-password=$buyer"
Write-Host "Secret $name cree."
