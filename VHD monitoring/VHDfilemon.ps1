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

$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRMMAlert "Unsupported OS. Only Server 2012R2 / Windows 8.1 and up are supported."
    exit 1
}

$VHDfull = @() 
$VHDPath = $ENV:VHDpath
$VHDXFiles = get-childitem $VHDPath -Filter "*.vhd*" -Recurse
if (!(get-module 'hyper-v' -ListAvailable)) { Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell }

if (!$VHDXFiles) {  write-DRMMAlert "No VHD(x) files found. Please change the path to a location that stores VHD(x) files." ; exit 1 }

$VHDInfo = foreach ($VHD in $VHDXFiles) {
    $info = get-vhd -path $VHD.FullName
    [PSCustomObject]@{
        MaxSize        = ($info.Size / 1gb)
        CurrentVHDSize = ($info.FileSize / 1gb)
        MinimumSize    = ($info.MinimumSize / 1gb)
        VHDPath        = $info.path
        Type           = $info.vhdtype
        PercentageFull   = ($info.filesize / $info.Size * 100 )
    }
}
 

foreach ($VHD in $VHDInfo) {

    if ($VHD.percentagefull -ge [int]$ENV:Threshold) {
      
        $VHDfull += $VHD

    }

}


if ($VHDfull.count -ne 0){

    write-DRMMAlert "Unhealthy - There are 1 or more VHDX files nearing their maximum capacity."
    write-DRMMdiag $VHDfull
    exit 1

}else{

    write-DRMMAlert "Healthy"
    exit 0

}


# $UserSid = ($FilePath).TrimStart("UVHD-")
# $User = cmd /c "wmic useraccount where sid='$UserSid' get name"