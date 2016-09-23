[CmdletBinding(DefaultParameterSetName = 'None')]
param()

Trace-VstsEnteringInvocation $MyInvocation

# load dependent script
. "$PSScriptRoot\FindSqlPackagePath.ps1"

$connectionString = Get-VstsInput -Name "connectionString" -Require
$dacpacName = Get-VstsInput -Name "dacpacName" -Require
$dacpacPath = Get-VstsInput -Name "dacpacPath" -Require
 
function Find-File {
    param(
        [string]$Path,
        [string]$FilePattern
    )

    Write-Verbose -Verbose "Searching for $FilePattern in $Path"

    $files = Find-VstsFiles -LiteralDirectory $Path -LegacyPattern $FilePattern

    if ($files -eq $null -or $files.GetType().Name -ne "String") {
        $count = 0

        if ($files -ne $null) {
            $count = $files.length
        }

        Write-Warning "Found $count matching files in folder. Expected a single file."

        $null
    } else {
        return $files
    }
}

function Create-Command {
    param(
        [string]$connectionString,
        [string]$sqlPackagePath,
        [string]$targetDacpac
    )

    $targetDacpac = Resolve-Path -Path $targetDacpac

    Write-Verbose "Generating command: source = $targetDacpac, target = $connectionString"

    $commandArgs = "/a:{0} /sf:`"$targetDacpac`" /tcs:`"$connectionString`" /p:BlockOnPossibleDataLoss=False"

    $runArgs = $commandArgs -f "Publish"
    $runCommand = "`"$sqlPackagePath`" $runArgs"
    $runCommand

    Run-Command -command $runCommand
}

function Run-Command {
    param(
        [string][Parameter(Mandatory=$true)] $command
    )

    try
	{
        if ($psversiontable.PSVersion.Major -le 4)
        {
           cmd.exe /c "`"$command`""
        }
        else
        {
           cmd.exe /c "$command"
        }
    }
	catch [System.Exception]
    {
        Write-Verbose $_.Exception
        throw $_.Exception
    }
}

#
# Main script
#
$sqlPackagePath = Get-SqlPackageOnTargetMachine

Write-Verbose -Verbose "Using sqlPackage path $sqlPackagePath"

$targetDacpac = Find-File -Path $dacpacPath -FilePattern "$dacpacName.dacpac"

if ($targetDacpac -ne $null) {
    Write-Verbose -Verbose "Found target dacpac $($targetDacpac)"

    Create-Command -ConnectionString $connectionString -SqlPackagePath $sqlPackagePath -TargetDacpac $targetDacpac
}

Trace-VstsLeavingInvocation $MyInvocation