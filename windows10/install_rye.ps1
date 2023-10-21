Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'


# Utils: Logging
# ---------------------------------------------------------------------------------------------------------------------

enum LogLevel {
    Verbose = 0
    Debug = 10
    Info = 20
    Warning = 30
    Error = 40
}
$script:LogLevel = [LogLevel]::Debug

function Get-LogLevel {
    return $script:LogLevel
}

function Set-LogLevel {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [LogLevel]
        $Level
    )
    $script:LogLevel = $Level
}

function Log {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [LogLevel]
        $Level,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string]
        $Message,
        
        [Parameter()]
        [System.Management.Automation.CallStackFrame]
        $CallStackFrame = $null
    )

    if ($Level -lt $script:LogLevel) {
        return
    }
    if ($null -eq $CallStackFrame) {
        $CallStackFrame = $(Get-PSCallStack)[1]
    }

    $LevelColor = switch ($Level) {
        Verbose { "Black" }
        Debug { "Blue" }
        Info { "White" }
        Warning { "Yellow" }
        Error { "Red" }
    }
    $Date = $(Get-Date -Format "yyyy-mm-dd hh:mm:ss.fff")
    $ScriptName = if ($null -eq $CallStackFrame.ScriptName) {
        "<No ScriptName>"
    }
    else {
        $(Split-Path -Leaf $CallStackFrame.ScriptName)
    }

    Write-Host -NoNewline $Date -ForegroundColor "Green"
    Write-Host -NoNewline " | "
    Write-Host -NoNewline ("{0,-8}" -f $Level.ToString().ToUpper()) -ForegroundColor $LevelColor
    Write-Host -NoNewline " | "
    Write-Host -NoNewline $ScriptName -ForegroundColor "Cyan"
    Write-Host -NoNewline ":"
    Write-Host -NoNewline $CallStackFrame.Location -ForegroundColor "Cyan"
    Write-Host -NoNewline " - "
    Write-Host -NoNewline $CallStackFrame.FunctionName -ForegroundColor "Cyan"
    Write-Host -NoNewline " - "
    Write-Host $Message -ForegroundColor $LevelColor
}

function LogException {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]
        $Message,
        
        [Parameter()]
        [LogLevel]
        $Level = [LogLevel]::Error,
        
        [Parameter()]
        [System.Management.Automation.CallStackFrame]
        $CallStackFrame = $null,

        [Parameter()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $CallStackFrame) {
        $CallStackFrame = $(Get-PSCallStack)[1]
    }
    if ($null -eq $ErrorRecord) {
        if (-not $global:Error) {
            Log $Level $Message -CallStackFrame $CallStackFrame
            return
        }

        $ErrorRecord = $global:Error[0]
    }
    $ExceptionName = $ErrorRecord.Exception.GetType().FullName

    $StackTraces = @(
        "$($ExceptionName): $ErrorRecord"
        $ErrorRecord.ScriptStackTrace
    )

    Log $Level "$Message`n$($StackTraces -join "`n")" -CallStackFrame $CallStackFrame
}


# Utils: Environment variables
# ---------------------------------------------------------------------------------------------------------------------

function UpdateEnvironmentVairbale() {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string]
        $Value,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.EnvironmentVariableTarget]
        $Target
    )

    $Old = [System.Environment]::GetEnvironmentVariable($Name, $Target)
    if ("$Old" -Ne "$Value") {
        Log Info "Update: $Name ($Target)"
        Log Debug "    Old: $Old"
        Log Debug "    New: $Value"
        [System.Environment]::SetEnvironmentVariable($Name, $Value, $Target)
    }
}

function RemovePathItem {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Path,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $Target
    )

    $Target = $Target.TrimEnd("/").ToLower()
    return ($Path -split ";" | Where-Object { $_.TrimEnd("/").ToLower() -ne $Target }) -join ";"
}


# Utils: etc
# ---------------------------------------------------------------------------------------------------------------------

function IsAdmin {
    [CmdletBinding(PositionalBinding = $false)]
    Param()

    $CurrentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $CurrentPrincipal.IsInRole("Administrators")
}

function ActivateDevelopperMode {
    [CmdletBinding(PositionalBinding = $false)]
    Param()

    $Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $Property = "AllowDevelopmentWithoutDevLicense"
    try {
        $Value = (Get-ItemProperty -Path Registry::$Key).$Property
    } catch [ItemNotFoundException] {
        $Value = $null
    }
    if (0 -eq [int]$Value) {
        Log Info "Update Registory::$Key, $Property"
        $Command = "reg add $Key /t REG_DWORD /f /v $Property /d 1"
        if (IsAdmin) {
            powershell $Command
        } else {
            Start-Process powershell $Command -Wait -Verb RunAs
        }
    }
}

# Rye
# ---------------------------------------------------------------------------------------------------------------------

function FindRye {    
    [CmdletBinding(PositionalBinding = $false)]
    Param()

    foreach ($EnvTarget in @("Process", "User", "Machine")) {
        $Path = [System.Environment]::GetEnvironmentVariable("Path", $EnvTarget)
        foreach ($PathItem in ($Path -split ";")) {
            $RyeExe = "$PathItem\rye.exe"
            if (Test-Path $RyeExe) {
                $RyeExe
            }
        }
    }
}


function InstallRye {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $RyeHome,

        [Parameter(Mandatory = $true)]
        [System.EnvironmentVariableTarget]
        $EnvTarget,

        [Parameter(Mandatory = $true)]
        [bool]
        $ForceInstall,

        [Parameter()]
        [string]
        $InstallerVersion = "0.15.2"
    )
    Log Debug "InstallerVersion = $InstallerVersion"
    Log Debug "RyeHome = $RyeHome"
    Log Debug "EnvTarget = $EnvTarget"
    Log Debug "ForceInstall = $ForceInstall"

    ActivateDevelopperMode
    if (-not $ForceInstall) {
        foreach ($RyeExe in (FindRye)) {
            Log Info "Already installed: $RyeExe"
            return
        }
    }

    $InstallerUrl = "https://github.com/mitsuhiko/rye/releases/download/$InstallerVersion/rye-x86_64-windows.exe"
    $InstallerExe = ".\rye-x86_64-windows.exe"
    $Installed = $false
    try {
        UpdateEnvironmentVairbale "RYE_HOME" $RyeHome Process

        Log Info "Downloading Rye installer"
        Invoke-WebRequest -UseBasicParsing -o $InstallerExe $InstallerUrl
        Log Info "Executing: rye self install"
        & $InstallerExe self install --yes
        Log Info "Executing: rye self update"
        & $InstallerExe self update

        foreach ($EnvTarget_ in @("Process", $EnvTarget)) {
            $Path = RemovePathItem ([System.Environment]::GetEnvironmentVariable("PATH", $EnvTarget_)) "$RyeHome\shims"
            UpdateEnvironmentVairbale "PATH" "$RyeHome\shims;$Path" $EnvTarget_
            UpdateEnvironmentVairbale "RYE_HOME" $RyeHome $EnvTarget_
        }

        $Installed = $true
    }
    finally {
        if (-not $Installed) {
            Log Error "Installation failed"

            if (Test-Path $InstallerExe) {
                Log Info "Executing: rye self uninstall"
                & $InstallerExe self uninstall --yes
                if ((Test-Path $RyeHome) -and -not (Test-Path "$RyeHome\*")) {
                    Remove-Item $RyeHome
                }
            }
        }

        Log Info "Deleting Rye installer"
        if (Test-Path $InstallerExe) {
            Remove-Item $InstallerExe
        }
    }
}

function InstallRyeForUser {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter()]
        [bool]
        $ForceInstall = $false
    )

    InstallRye -RyeHome "$Env:UserProfile\.rye" -EnvTarget User -ForceInstall $ForceInstall
}

function InstallRyeForMachine {
    [CmdletBinding(PositionalBinding = $false)]
    Param(
        [Parameter()]
        [bool]
        $ForceInstall = $false
    )

    InstallRye -RyeHome "C:\.rye" -EnvTarget Machine -ForceInstall $ForceInstall
}
