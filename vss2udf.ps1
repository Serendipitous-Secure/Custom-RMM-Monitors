
$SettingsTally = 0

#check vssadmin service running
$VSSstart = sc.exe qc vss | findstr "START_TYPE"

if ( $VSSstart -match "DEMAND_START" ){
    $SettingsTally ++
    $StartStatus = "VSS Startup Settings: Manual"
}else{ 
    $StartStatus = "VSS Startup Settings: Not Set To Manual. Remediation Attempted."
    sc.exe config vss start= demand
}

#check for recent shadow coppies
$VSScopies = vssadmin list shadows | findstr "ApplicationRollback"

if ( $VSScopies -match "Type: ApplicationRollback"){
    $SettingsTally ++
    $CopiesStatus = 'VSS Shadows: Agent HAS current "ApplicationRollback" Shadows'
}else{ 
    $CopiesStatus = "VSS Shadows: This agent does NOT appear to have current shadow coppies."
    vssadmin Add ShadowStorage /For=C: /On=C: /MaxSize=10%
}

#check for 10% setting
$VSSstorage = vssadmin list shadowstorage | findstr "Maximum"

if ( $VSSstorage -match "(10%)"){
    $SettingsTally ++
    $StorageStatus = "VSS Capacity: Agent's VSS Capacity is set to the optimal and default 10%"
}else{ 
    $StorageStatus = "VSS Capacity: Agent's VSS Capacity is not optimal. Remediation Attempted."
    vssadmin Resize ShadowStorage /For=C: /On=C: /MaxSize=10% 
}

#do logic
if ($SettingsTally -ne 3) {

    #set UDF
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom28" /t REG_SZ /d "False" /f

    #generate alert
	write-host '<-Start Result->'
 	write-host "STATUS=VSS settings are not optimal for SentinelOne Rollback."
 	write-host '<-End Result->'

    write-host '<-Start Diagnostic->'
    write-host "The settings for vss snapshots ARE NOT optimal."
    write-host "---------------------------------------------"
    write-host $StartStatus
    write-host $VSSstart
    Write-Host "-----------------------"
    Write-Host $CopiesStatus
    Write-Host $VSScopies
    Write-Host "-----------------------"
    Write-Host $StorageStatus
    Write-Host $VSSstorage
    write-host "---------------------------------------------"
    write-host '<-End Diagnostic->'
    exit 1

}else{

    #set UDF
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom28" /t REG_SZ /d "True" /f

    #generate alert
	write-host '<-Start Result->'
    write-host "STATUS=VSS settings are optimal for SentinelOne Rollback." 
    write-host '<-End Result->'

    write-host '<-Start Diagnostic->'
    write-host "The settings for vss snapshots ARE optimal."
    write-host "---------------------------------------------"
    write-host $StartStatus
    Write-Host $CopiesStatus
    Write-Host $StorageStatus
    write-host "---------------------------------------------"
    write-host '<-End Diagnostic->'
    exit 0

}
