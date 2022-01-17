function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    $messages
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

$DisksInWarning = @()
$VHDS = get-disk | Where-Object {$_.Location -match "UVHD"}
foreach($VHD in $VHDS){
$FilePath = [io.path]::GetFileNameWithoutExtension("$($VHD.Location)")
$Volume = $VHD | Get-Partition | Get-Volume
$Size = ($Volume.Size / 1024 /1024 / 1024)
if($Volume.SizeRemaining -lt $volume.Size * 0.10 ){
$UserSid = ($FilePath).TrimStart("UVHD-")
$User = cmd /c "wmic useraccount where sid='$UserSid' get name"
$DisksInWarning += "$User UPD Has less than 10% free space remaining. Path: $($VHD.Location), Current size is $([math]::Round($Size)) GB"}
}

If ($null -ne $DisksInWarning ){
    write-DRMMDiag $DisksInWarning
    write-DRRMAlert "UPD with low diskspace. Please check Diagnostic information."
    exit 1
}