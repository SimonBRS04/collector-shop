# Définit les mots de passe des utilisateurs de test à partir du Secret Kubernetes (via l'outil kcadm de Keycloak).
$ErrorActionPreference = 'Stop'
$ns = 'sandbox-auth'

function Get-SecretValue([string]$key) {
    $b64 = kubectl get secret sandbox-auth-secrets -n $ns -o "jsonpath={.data.$key}"
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
}

$admin  = Get-SecretValue 'keycloak-admin-password'
$seller = Get-SecretValue 'seller-password'
$buyer  = Get-SecretValue 'buyer-password'
$kcadm  = '/opt/keycloak/bin/kcadm.sh'
$cfg    = '--config', '/tmp/kcadm.config'

kubectl exec -n $ns deploy/keycloak -- $kcadm config credentials --server http://localhost:8080 --realm master --user admin --password $admin @cfg
kubectl exec -n $ns deploy/keycloak -- $kcadm set-password -r collector-sandbox --username seller-test --new-password $seller @cfg
kubectl exec -n $ns deploy/keycloak -- $kcadm set-password -r collector-sandbox --username buyer-test --new-password $buyer @cfg
Write-Host "Mots de passe des utilisateurs de test definis."
