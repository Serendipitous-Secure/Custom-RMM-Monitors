#!PS

<#
evaluates logs at path "C:\Windows\System32\config\systemprofile\AppData\Local\Datto\Datto Windows Agent\logs\" to determine the last reboot time. 
If it is a weekend, the monitor reports healthy as long as a backup occurred last thing friday evening, or at any point saturday or suday. 
If it is at night, the monitor reports healthy as long as there was a backup between 1700 and 2400. 
and if its a weekday during work hours, the monitor reports healthy as long as there was a backup within the last 2 hours. 
#>


$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force


function Get-InstalledPrograms {

    <#
    .Synopsis
        This funcion retrieves installed programs. 
    .Description
        This function accepts an array of strings containing program names and queries the regisrty paths 
        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall 
        and HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall for their presence. Returns an array  
    .Parameter ProgramList
        The array containing strings you would like matched to program names to test for. This is done by matching, not requiring the exact name. Use caution. 
    .Example
        #ProgramList as parameter
            Get-UninstallString -ProgramList $ProgramList
        #ProgramList from stdin
            $ProgramList | Get-UninstallString
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, 
            ValueFromPipeline)]
        [array] $ProgramList
    )

    PROCESS {
        
        $Programs = @()

        forEach ( $Program in $ProgramList ){
            $Programs += Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, 
                HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall  |
                Get-ItemProperty |
                    Where-Object -FilterScript {($_.DisplayName -match $Program)} |
                        Select-Object -Property DisplayName
        }
          Write-Output $Programs
            
    }

}


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


function Main {
 
    $LOGDIR = "C:\Windows\System32\config\systemprofile\AppData\Local\Datto\Datto Windows Agent\logs\"

    if ( !(Get-InstalledPrograms -ProgramList @("Datto Windows Agent")) ){

        Write-DRMMAlert "Datto Windows Agent is not installed. Ending check with healthy status"
        & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "N/A" /f
        exit 0

    }

    #get list of logs
    $Logs = ` Get-ChildItem $LOGDIR | Sort-Object -Descending -Property LastWriteTime  `

    #Get most recent log containing successful backup entries.
    foreach ( $Log in $Logs ){
    
        $LogEntries = Get-Content -Path $Log.FullName | findstr /c:"Informing writers of successful backup."

        If ( $LogEntries.Count -ne 0 ){
        
            Write-Host "breaking"
            break
    
        }

    }

    #get last date
    if ( $LogEntries.count -ne 1 ) {
        
        $LatestEntry = Get-Date (($LogEntries[-1] -split '\[INFO:\]')[0].Trim())

    } else {

        $LatestEntry = Get-Date (($LogEntries -split '\[INFO:\]')[0].Trim())

    }

    #Current date
    $CurrentDate = Get-Date
    #Compare
    $DateComp = ( ( Get-Date ) - ( $LatestEntry ) )

    if ( $DateComp.TotalDays -le 5) {

        #If it is a weekend or early monday
        if ( ($CurrentDate.DayOfWeek -in @("Saturday", "Sunday")) -or ( ($CurrentDate.DayOfWeek -match "monday") -and ($CurrentDate.hour -le 6) ) ) { 
    
            #All good if the last backup was on a weekend
            if ($LatestEntry.DayOfWeek -in @("Saturday", "Sunday")){  
        
                #GOOD
                Write-DRMMAlert "This server has a recent backup for the weekend."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "TRUE" /f
                exit 0

            #All good if the last backup was in the evening friday
            } elseif ( ($LatestEntry.DayOfWeek -eq "Friday") -and ( ($LatestEntry.Hour -ge 17) -and ($LatestEntry.Hour -ge 24) ) ){ 

                #GOOD
                Write-DRMMAlert "This server has a recent backup for the weekend."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "TRUE" /f
                exit 0

            } else {
        
                #BAD
                Write-DRMMAlert "This server does NOT have a recent backup for the weekend."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "FALSE" /f
                exit 1
    
            }

        
        #If it is the evening after 6pm or before 8am the next day
        } elseif ( (($CurrentDate.hour -ge 18) -or ($CurrentDate.hour -lt 8)) -and ($DateComp.TotalDays -le 1 ) ) { 

            #All good if the last backup  was this evening as well.
            if ( ($LatestEntry.Hour -ge 17) -and ($LatestEntry.Hour -le 24) ) { 
        
                #GOOD
                Write-DRMMAlert "This server has a recent backup for the evening."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "TRUE" /f
                exit 0


            } else {

                #BAD
                Write-DRMMAlert "This server does NOT have a recent backup for the evening."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "FALSE" /f
                exit 1

            }

        #Must be at some point durring the work day, if not weekend or evening
        } else {

            if ( $DateComp.Totalhours -ge 2.5 ){
        
                #Bad
                Write-DRMMAlert "This server does NOT have a recent backup for the day."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "FALSE" /f
                exit 1

            } else {

                #GOOD
                Write-DRMMAlert "This server has a recent backup for the day."
                Write-DRMMDiag "Last Backup Time: $LatestEntry"
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "TRUE" /f
                exit 0

            }

        }

    } else {

        #BAD
        Write-DRMMAlert "This server does NOT have a recent backup for the last 5 days."
        Write-DRMMDiag "Last Backup Time: $LatestEntry"
        & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom17" /t REG_SZ /d "FALSE" /f
        exit 1

    }

}


Main