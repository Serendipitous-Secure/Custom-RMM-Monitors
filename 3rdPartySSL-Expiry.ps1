$Days = (Get-Date).AddDays($env:Days)

function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion

if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}

$CertsBound = get-webbinding | where-object { $_.Protocol -eq "https" }

$Diag = foreach ($Cert in $CertsBound) {
    $CertFile = Get-ChildItem -path "CERT:LocalMachine\$($Cert.CertificateStoreName)" | Where-Object -Property ThumbPrint -eq $cert.certificateHash
    if ( ($certfile.NotAfter -lt $Days) -and ($certfile.notbefore -ne $null) ) { 
        [PSCustomObject]@{
            Friendlyname = $certfile.FriendlyName
            SubjectName  = $Certfile.subject
            CreationDate = $Certfile.NotBefore
            ExpireDate   = $Certfile.NotAfter
            Issuer       = $CertFile.Issuer
            ThumbPrint   = $CertFile.Thumbprint
            HasPrivateKey = $CertFile.HasPrivateKey 
        }
        $certState = "unhealthy"
    }
}

if (!$certState) {
    write-DRMMAlert "Healthy - No expiring certificates found."
}
else {
    write-DRMMAlert "Unhealthy - Please consult the diagnostic text."
    write-DRMMDiag $Diag
    exit 1
}
