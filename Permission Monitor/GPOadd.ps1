function Set-SionTrackGPO {

    <#
    .SYNOPSIS 
        This function automates creating the required GPO settings for Permission Changes Monitor. 
    .DESCRIPTION
        Run this on the Domain Controller of the network containing the share you would like to monitor for permissions changes.
        
        This component creates a group "HCTG Permission Change Audit". 
        adds the computer containing the drive/share to be monitored 
        (as defined in the variable `$ENV:MonitoredHost`) to the group, 
        Imports the template GPO from the zip file to a new GPO, 
        and then links that GPO to the HCTG Permission Change Audit group.  
    
    .PARAMETER MonitoredHost
        The host you would like to add to the group the GPO is linked to. 
    
    .EXAMPLE
        Set-SionTrackGPO -MonitoredHost "Hostname Here"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $MonitoredHost
    )

    #Unpack Backup
    Expand-Archive -Path "GPO.zip"

    #Gather Information
    $DomainName = Get-ADDomain 
    $FullName = Get-ADComputer -Filter {Name -eq $MonitoredHost}

    #CREATE OUR PROTECTED GROUP
    New-ADGroup -Name "HCTG Permission Change Audit" -GroupCategory Security -GroupScope Global -DisplayName "HCTG Permission Change Audit" -Path $DomainName.ComputersContainer -Description "Members of this group are having file and object access audited"
    $GroupPath = Get-ADGroup -Identity "HCTG Permission Change Audit"

    #ADD PROTECTED COMPUTER TO GROUP
    Add-ADGroupMember -Identity $GroupPath.DistinguishedName -Members $FullName

    #CREATEGPO BY INPUT
    Import-GPO -BackupID 2C258DFF-4B10-4E7A-A083-A6642F38980F -Path "GPO\" -TargetName "HCTG Permission Change Audit" -Domain $DomainName.forest -CreateIfNeeded

    #SET PERMISSIONS FOR AUTHENTICATED USERS. READ BUT NOT APPLY
    Set-GPPermissions -Name "HCTG Permission Change Audit" -PermissionLevel none -TargetName "Authenticated Users" -TargetType Group
    Set-GPPermissions -Name "HCTG Permission Change Audit" -PermissionLevel Gporead -TargetName "Authenticated Users" -TargetType Group
    #SET PERMISSIONS FOR PROTECTED GROUP. READ AND APPLY
    Set-GPPermissions -Name "HCTG Permission Change Audit" -PermissionLevel Gporead -TargetName $GroupPath.Name -TargetType Group
    Set-GPPermissions -Name "HCTG Permission Change Audit" -PermissionLevel Gpoapply -TargetName $GroupPath.Name -TargetType Group

    #LINK TO DOMAIN
    New-GPLink -Name "HCTG Permission Change Audit" -Target $DomainName.DistinguishedName -enforced yes

}


Set-SionTrackGPO -MonitoredHost $ENV:MonitoredHost
