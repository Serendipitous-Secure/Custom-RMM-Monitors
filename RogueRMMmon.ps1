
$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force


$env:Programs = @(
    "SolarWinds RMM", 
    "NinjaRMM", 
    "ManageEngine Desktop Central", 
    "Atera", 
    "Auvik", 
    "RemotePC",
    "Paessler PRTG"
    "Continuum",
    "Comodo One",  
    "ConnectWise Automate", 
    "Kaseya VSA", 
    "ManageEngine ServiceDesk Plus"
    "Pulseway"
    "N-able RMM"
    "Barracuda RMM"
    "Itarian"
    "Domotx Pro"
)


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


function getGUID ($varMSISearch) {
    set-content "msi.vbs" -value 'Set installer = CreateObject("WindowsInstaller.Installer")
    On Error Resume Next'
    add-content "msi.vbs" -value "strSearchFor = `"$varMSISearch`""
    add-content "msi.vbs" -value 'For Each product In installer.ProductsEx("", "", 7)
       name = product.InstallProperty("ProductName")
       productcode = product.ProductCode
       If InStr(1, name, strSearchFor) > 0 then
        wscript.echo (productcode)
       End if
    Next'
    
    cscript /nologo msi.vbs
    remove-item msi.vbs
}




function Detect-NinjaRMM {
    
    $NinjaRMM = Get-InstalledPrograms -ProgramList @("NinjaRMM")

    if ($NinjaRMM) {

        Return $True

    } else {

        Return $False

    }
    
}


function Detect-SolarWindsRMM {

    if (test-path "$varProgramFiles\Advanced Monitoring Agent\unins000.exe") {
        Start-Process "$varProgramFiles\Advanced Monitoring Agent\unins000.exe" -ArgumentList '/silent'
        write-host "- Advanced Monitoring Agent uninstaller has been initiated."
        write-host "  Exiting..."
        exit
    }

    [array]$arrGUIDList = getGUID "Windows Agent"
    
    foreach ($iteration in $arrGUIDList) {
        
        if ((get-itemProperty "$varRegNode\Microsoft\Windows\CurrentVersion\Uninstall\$iteration" -Name Publisher -ErrorAction SilentlyContinue) -match "N-able Technologies") {
            Return $True
            Break
        }
    
    }

    Return $False

}


function Detect-Kaseya {
    
    if ($env:usrStopService -match 'true') {
        foreach ($process in ("KAUsrTsk","AgentMon","KaseyaEndpoint")) {
            Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
            if ($?) {$varString+="Process $process was found and killed. "}
        }
    } else {
        foreach ($process in ("KAUsrTsk","AgentMon","KaseyaEndpoint")) {
            Get-Process -Name $process -ErrorAction SilentlyContinue | Out-Null
            if ($?) {$varString+="Process $process is running in memory. "}
        }
    }
    
    #kill services
    if (get-service | ? {$_.DisplayName -match '^Kaseya' -and $_.Status -match 'Running'}) {
        if ($env:usrStopService -match 'true') {
            get-service | ? {$_.DisplayName -match '^Kaseya'} | % {stop-service -DisplayName "$($_.DisplayName)" -Force}
            start-sleep -seconds 10
            $varString+="Kaseya Services were found and killed."
        } else {
            $varString+="Kaseya Services are running."
        }
    }
    
    #alert
    if ($varString) {
        
        Return $true

    } else {

        Return $False

    }

}


function Detect-Atera {

    #processes :: kill all known atera processes, and alert if any attempt succeeded
    foreach ($process in ("AteraAgent","AgentPackageSTRemote")) {
        
        Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
        if ($?) {$varString+="Process $process was found and killed. "}
    
    }

    #services :: kill all known atera services, and alert if any attempt succeeded
    if (get-service | ? {$_.DisplayName -match '^AteraAgent$'}) {
    
        get-service | ? {$_.DisplayName -match '^AteraAgent$'} | % {stop-service -DisplayName "$($_.DisplayName)" -Force}
        $varString+="Atera services were found and killed. "
        start-sleep -seconds 10
    
    }
 
    if ($varString) {
 
        Return $True

    } else {

        Return $False

    }

}

function Detect-Continuum {
    
    $ITSupport = @("ITSupport") | Get-InstalledPrograms 
    $ITSPlatform = @("ITSplatform") | Get-InstalledPrograms
    
    if ( ($ITSupport.Count -ne 0) -or ($ITSPlatform.Count -ne 0) ){

        Return $True

    } else {

        Return $False

    }

}

function Generic-Detect {
    
    $List = Get-InstalledPrograms -ProgramList $env:Programs
    
    if ($List.Count -ne 0) {
       
        Return $True
    
    } else { 
    
        Return $False
    
    }

}

function Main {
    
    $Suspects = 0
    $Found = @()

    if (Detect-Continuum) {

        $Suspects ++
        $Found += "-Continuum agent has been detected"

    } elseif (Detect-Atera) {
        
        $Suspects ++
        $Found += "-Atera agent has been detected"

    } elseif (Detect-Kaseya) {
        
        $Suspects ++
        $Found += "-Kaseya agent has been detected"

    } elseif (Detect-NinjaRMM) {
        
        $Suspects ++
        $Found += "-NinjaRMM agent has been detected"

    } elseif (Generic-Detect) {
        
        $Suspects ++
        $Found += "-One of the following agents has been detected"
        $Found += $env:Programs

    }

    If ( $Suspects -ne 0 ) {

        Write-DRMMAlert "$ENV:COMPUTERNAME has one or more additional RMM agents in competition with Datto RMM. See diagnostic."
        Write-DRMMDiag $Found
        exit 1

    } else {

        Write-DRMMAlert "$ENV:COMPUTERNAME has NO additional RMM agents in competition with Datto RMM."
        exit 0 

    }

}

Main