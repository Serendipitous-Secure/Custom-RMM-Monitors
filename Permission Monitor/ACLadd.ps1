function Set-PermissionAuditACL {
    
    <#
    .SYNOPSIS 
        This function enables the auditing of permission changes for a given file path as a variable passed by datto.
    .DESCRIPTION
        This function creates a file ACL rule that enables auditing of permission or ownership changes (Event ID 4670), and file deletions (EventID 4660).
    .PARAMETER PATH
        Paramter to indicate path you would like to monitor
    .EXAMPLE
    #>
    
    [CmdletBinding()]
    param (


        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                throw "File or folder does not exist"
            }
            return $true
        })]
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$Path,

        [ValidateSet("YES", "Y", "N", "NO")]
        [Parameter()]
        [String] $Inherit = "YES"

    )

    gpupdate.exe /force

    if ( ($Inherit -match "Y") -or ($Inherit -match "Yes") ) {
        
        $InheritFlag = "ContainerInherit,ObjectInherit"

    } else {

        $InheritFlag = "None"

    }

    if ($Path) {
        Write-Host "Checking that File Audit Status is Empty."
        $FileAuditStatus = Get-Acl $Path -Audit | Select-Object Path,AuditToString
    
        if ($FileAuditStatus.AuditToString -eq "") {
            Write-Host "File Audit Status is empty. Setting Audit Rules."
            $File_ACL = Get-Acl $Path
            $AccessRule = new-object system.Security.AccessControl.FileSystemAuditRule("everyone","delete,deletesubdirectoriesandfiles,changepermissions,takeownership", $InheritFlag, "None", "Success,Failure")
            $File_ACL.AddAuditRule($AccessRule)
            $File_ACL | Set-Acl $Path 
            
            Get-Acl $Path -Audit | Select-Object Path,AuditToString
        }
    
    }

    $FileAuditStatus = Get-Acl $Path -Audit | Select-Object Path,AuditToString
    
    if (!($FileAuditStatus.AuditToString -eq "")) {
        Write-Host "This Script was successful. Please set monitors for this device for security event ID 4670 for permission and ownership changes, and 4660 for file and folder deletions. "
        exit 0
    }elseif ($FileAuditStatus.AuditToString -eq "") {
        Write-Host "Audit rules were not applied to files."
        exit 1
    }
    
}

Set-PermissionAuditACL -Path $ENV:AuditPath -Inherit $ENV:Inherit

