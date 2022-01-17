
function Update-UDF {

    <#
    .Synopsis
        This Function updates a Hash Table of UDFs to the desired values.
    .Description
        This Function takes a Hash Table of UDFs to the desired values, by setting these values in the registry.
    .Parameter UDFtable
        A Hash Table of desired UDF keys and values.
    .Example
        #Update as parameter
        Update-UDF -UDFtable $myUDFtable
        #update through pipe
        $myUDFtable | Update-UDF 
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, 
            ValueFromPipeline)]
        [hashtable] $UDFtable
    )

    PROCESS {
        Write-Progress "Attempting to update the following UDF fields"
        Write-Progress $UDFtable
        foreach ($Key in $UDFtable.Keys){
            try {
                & REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $Key /t REG_SZ /d $UDFtable.$Key /f
            } catch {Write-Progress "Unable to Update one or more UDF's. Error is likely on" Write-Progress $UDF.Name}
        }
    }
}


function Test-ForGPO {
    
    [CmdletBinding()]
    param (

        [Parameter()]
        [string]
        $GPOname

    )
    
    
    try {
        Get-GPO -Name $GPOname -ErrorAction Stop
        Write-Host "GPO $GPOname is present."
        return $true
    }
    catch {
        Write-Host "GPO $GPOname is NOT present."
        return $false
    }
    

}


function Publish-Monitor {

    [CmdletBinding()]
    param (

        [Parameter()]
        [string]
        $Status,

        # Parameter help description
        [Parameter()]
        [string]
        $Diagnostic

    )

    write-host '<-Start Result->'
    write-host $Status
    write-host '<-End Result->'

    if ($Disagnostic) {
        
        write-host '<-Start Diagnostic->'
        write-host $Diagnostic
        write-host '<-End Diagnostic->'

    }

}


function main {

    # [CmdletBinding()]
    # param (
    #     [Parameter()]
    #     [string]
    #     $GPOname,

    #     [Parameter()]
    #     [string]
    #     $UpdateUDF,

    #     [Parameter()]
    #     [switch]
    #     $AsMonitor
    # )
 
    $GPOname = "Datto RMM agent install by immediate scheduled task"

    if (!(Test-ForGPO -GPOname $GPOname)) {

        Publish-Monitor -Status "STATUS = ABSENT" 

        Update-UDF -UDFtable @{ Custom19 = " Datto GPO is not present" }

        exit 1

    }else{

        Publish-Monitor -Status "STATUS = PRESENT"

        Update-UDF -UDFtable @{ Custom19 = " Datto GPO is present" }

        exit 0

    }

}

Main
