function Write-DRMMAlert ($message) {

    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'

}

function Write-DRMMDiag ($messages) {

    write-host  '<-Start Diagnostic->'
    $messages
    write-host '<-End Diagnostic->'

} 

$Services = get-service | where {$_.Name -match "SAAZ"}

if ( $Services.count -gt 0 ){

     Write-DRMMAlert "$ENV:COMPUTERNAME has one or more SAAZ services present. See diagnostic."
     Write-DRMMDiag $Services
     exit 1

} else {

     Write-DRMMAlert "$ENV:COMPUTERNAME has NO SAAZ services present."
     exit 0 

}
