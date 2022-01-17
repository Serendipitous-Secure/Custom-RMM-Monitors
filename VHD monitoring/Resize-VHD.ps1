$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


<#
.Synopsis
This script extend size of VHDX file and resize the disk partition to Max
#>

function myResize-VHD {

    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [alias(“Path”)]
        [string]$vhdxFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [alias(“Size”)]
        [int64]$vhdxNewSize

    )



    begin{
        try {
            Mount-VHD -Path $vhdxFile -ErrorAction Stop
        }
        catch {
            Write-Error “File $vhdxFile is busy”
        Break
        }

        $vhdx = Get-VHD -Path $vhdxFile

        if ($vhdx.Size / 1GB -ge $vhdxNewSize){
            
            Write-Warning “File $vhdxFile already have this size!”
            Write-Warning ($vhdx.Size / 1GB) "GB"
            $vhdx | Dismount-VHD
            Break
        
        }
    }

    process{

        $vhdxNewSize = ($vhdxNewSize * 1kb * 1kb * 1kb)

        Write-Host "`n"
        Write-Host "============================================================"
        Write-Host "resizing VHD"
        Write-Host "============================================================"
        Write-Host "`n"

        Dismount-VHD -Path $vhdxFile

        Hyper-V\Resize-VHD -Path $vhdxFile -SizeBytes ([int64]$vhdxNewSize)

        $DriveLetter = (Mount-VHD -Path $vhdxFile -PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
        
        #Mount-VHD -Path $vhdxFile -DriveLetter "G" 
        $size = (Get-PartitionSupportedSize -DriveLetter $DriveLetter)
        Resize-Partition -DriveLetter $DriveLetter -Size $size.SizeMax
    
    }

    end{
    
        Dismount-VHD -Path $vhdxFile
    
    }

}

myResize-VHD -vhdxFile $ENV:vhdxFile -vhdxNewSize $ENV:vhdxNewSize
