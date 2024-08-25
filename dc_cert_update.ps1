# update certificate on Domain Controllers

# Checks 636 port
# Removes old certificate
# Installs new pfx certificate
# Checks LDAPS connection

$pfx_path = "\\mydomain\SYSVOL\mydomain\Certs\wildcard.mydomain.pfx"
$dc_list_path = "\\mydomain\SYSVOL\mydomain\Certs\dcs.txt"
$domain = "mydomain"
if (-Not ((Test-Path $dc_list_path) -And (Test-Path $pfx_path))) {Write-Host "Files not found."; break}

$dc_list = Get-Content -Path $dc_list_path
$pfx_pass = ConvertTo-SecureString "" -AsPlainText -Force;
$current_year = (get-date).year

ForEach ($dc in $dc_list) {
    $dc = $dc.trim()
    Write-Host $dc
    if ((Test-NetConnection -ComputerName $dc -Port 636).TcpTestSucceeded) {
        Write-Host "Port 636 is reachable"
        Invoke-Command -ComputerName $dc -ScriptBlock {
        $current_cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match "\*.$using:domain" -and $_.NotBefore.Year -lt $using:current_year}
        If ($current_cert) {
            Write-Host "Removing old certificates..."
            $current_cert | Remove-Item -WhatIf
            $current_cert | Remove-Item
        }
        Write-Host "Installing pfx certificate..."
        Import-PfxCertificate -FilePath $using:pfx_path -CertStoreLocation Cert:\LocalMachine\My -Password $using:pfx_pass | Out-Null
        }
        $connection = [ADSI]"LDAP://$($dc):636"
        if ($connection.Path) {"LDAPS ok"} else {"LDAPS failed"}

    } else {"Port 636 failed, skipping"}
    ""
}
