$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
. 'C:\Program Files\Microsoft\Exchange Server\V14\bin\RemoteExchange.ps1'
Connect-ExchangeServer -auto


function write-DRMMDiag ( $messages ) {
    write-host  '<-Start Diagnostic->'
    $messages
    write-host '<-End Diagnostic->'
} 


function write-DRMMAlert ( $message ) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}


$Queues = Get-queue
$FullQueues = @()
$Alert = 0


foreach ( $Queue in $Queues ) {
    
    if ( $Queues.MessageCount -ge [int]$ENV:Threshold ) {
    
        $Alert ++
        $FullQueues += $Queue
    
    }

}

if ( $Alert -ge 1 ) {

    write-DRMMAlert "There are $Alert Queues reaching the set threshold of $ENV:Threshold"    
    write-DRMMDiag $FullQueues
    exit 1

} else {

    write-DRMMAlert "There are NO Queues reaching the set threshold of $ENV:Threshold"    
    exit 0 

}
