#compose list of RDS servers
$RDSservers = get-rdserver -role RDS-RD-SERVER | Select-Object Server 
$RDStable = @{}

$UDFnum = 20
$UDFstring = "Custom"


#Create Table of RDS servers, their login/Drain states, and the time it was added to the broker in this state
foreach ($Server in $RDSservers) { 
    
    $ServerStates = @{ 
    TimeStamp = (`Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-SessionBroker/Operational" | Where-Object {($_.Id -match 776) -and ($_.Message -match $Server.Server)} | Select-Object TimeCreated ` )[0].TimeCreated
    State = (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace "root\CIMV2\terminalservices" -ComputerName $Server.server -Authentication PacketPrivacy -Impersonation Impersonate | Select-Object SessionBrokerDrainMode).SessionBrokerDrainMode
    }

    $RDStable.Add( $Server.Server , $ServerStates )

}


#Update UDF's to report on broker.
foreach ($Server in $RDStable.keys) {
    
    if ($RDStable[$Server].State -eq 0) {
        $StateWord = "Yes"
    }elseif (($RDStable[$Server].State -eq 1) -or ($RDStable[$Server].State -eq 2)) {
        $StateWord = "No"
    }else {
        $StateWord = "Unknown"
    }

    $UDF = $UDFstring+[string]$UDFnum 
    $ServerState = $Server+" Connection Allowed: "+$StateWord
    & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $UDF /t REG_SZ /d $ServerState /f
    $UDFnum += 1

} 


#Iterate Lists and remove from state list if drain mode is off(yes: Accepting connections). 
foreach ($Server in $RDSservers) {
    
    $DateComp = ( ( Get-Date ) - ( Get-Date $RDStable[$Server.server].TimeStamp ) )

    if ($RDStable[$Server.server].state -eq 0) {
        
        $RDStable.Remove($Server.server)

    } elseif ($DateComp.TotalSeconds -lt [int]$ENV:Duration ) {

        $RDStable.Remove($Server.server)

    }

}


#Outputs appropraitely depending upon devices remaining in state list.
if ( !( $RDStable.count -eq 0 ) ) {
            
    write-host '<-Start Result->'
    write-host "STATUS=This Broker has 1 or more RDS servers in Drain Mode exceeding $ENV:Duration seconds."
    write-host '<-End Result->'

    write-host '<-Start Diagnostic->'
    
    foreach ($Server in $RDStable.Keys) {
        write-host "-----------------------------"
        write-host "Server: " $Server
        write-host "Acepting Connections: " $RDStable[$Server].state
        write-host "Last State Change: " $RDStable[$Server].TimeStamp
    }
    
    write-host "-----------------------------"
    write-host '<-End Diagnostic->' 
  
    exit 1

} else {

	write-host '<-Start Result->'
 	write-host "STATUS=This Broker has no RDS servers in Drain Mode exceeding $ENV:Duration seconds."
    write-host '<-End Result->'

    exit 0

}
