$script = {
    param(
        [string]$rye_home,
        [string]$env_target,
        [string]$rye_version
    )
    $global:PSBoundParameters = $PSBoundParameters

    function Main() {
        $params = $global:PSBoundParameters
        if ($env_target.ToLower() -Eq "machine") {
            RequireAdmin
        }
        UninstallRye
        InstallRye $params["rye_version"] $params["rye_home"] $params["env_target"]
        LogMessage "Executing: rye self update"
        & rye self update
        LogMessage "Completed successfully"
    }

    function GetFunctionName([int]$stack_number = 1) {
        return [string]$(Get-PSCallStack)[$stack_number].FunctionName
    }

    function LogMessage([string]$message) {
        $function_name = GetFunctionName 2
        Write-Host "$(Get-Date -Format G): ${function_name}: ${message}" -ForegroundColor "Magenta"
    }

    function RequireAdmin() {
        $current_role = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if (!$current_role.IsInRole("Administrators")) {
            LogMessage "Restart this script as admin..."
            try {
                [System.Collections.ArrayList]$argument_list = "-File", "$PSCommandPath"
                $argument_list += $global:PSBoundParameters.Values
                Start-Process powershell.exe -ArgumentList $argument_list -Verb RunAs -Wait
            }
            catch [InvalidOperationException] {
                LogMessage "Canceled"
            }
            exit
        }
    }

    function RemovePathItem([string]$path, [string]$target) {
        [System.Collections.ArrayList]$items = $path -Split ";"
        [System.Collections.ArrayList]$targets = @()
        foreach ($item in $path -Split ";") {
            if ($item.TrimEnd('\').ToLower() -Eq $target.TrimEnd('\').ToLower()) {
                $targets += $item
            }
        }
        foreach ($item in $targets) {
            $items.Remove($item)
        }
        return $items -Join ";"
    }

    function UpdateEnvironmentVairbale([string]$name, [string]$value, [string]$target) {
        $old = [Environment]::GetEnvironmentVariable($name, $target)
        if ($old -Ne $value) {
            if ($target.ToLower() -Eq "machine") {
                RequireAdmin
            }
            [Environment]::SetEnvironmentVariable($name, $value, $target)
        }
    }

    function UninstallRye() {
        LogMessage "Start Rye uninstalltion"
        try {
            foreach ($env_target in "user", "machine") {
                # Find rye.exe by RYE_HOME
                $ENV:RYE_HOME = [Environment]::GetEnvironmentVariable("RYE_HOME", $env_target)
                if ($null -Ne $ENV:RYE_HOME) {        
                    LogMessage "Found RYE_HOME: $ENV:RYE_HOME"
                    $rye_exe_path = "$ENV:RYE_HOME\shims\rye.exe"

                    if (Test-Path $rye_exe_path) {
                        LogMessage "Found rye.exe: $rye_exe_path"
                        LogMessage "Executing: rye self uninstall"
                        & $rye_exe_path self uninstall -y
                    }

                    LogMessage "Updating environment variable: PATH"
                    $path = [Environment]::GetEnvironmentVariable("PATH", $env_target)
                    $path_new = RemovePathItem $path "$ENV:RYE_HOME\shims"
                    UpdateEnvironmentVairbale "PATH" $path_new $env_target

                    LogMessage "Removing environment variable: RYE_HOME"
                    UpdateEnvironmentVairbale "RYE_HOME" $null $env_target
                }

                # Find rye.exe by PATH
                $ENV:PATH = [Environment]::GetEnvironmentVariable("PATH", $env_target)
                $rye_exe_path = (Get-Command rye.exe 2>$null).Definition
                if ($null -Ne $rye_exe_path) {
                    LogMessage "Found rye.exe: $rye_exe_path"
                    $rye_shims_path = Split-Path -Parent $rye_exe_path
                    $rye_home = Split-Path -Parent $rye_shims_path

                    LogMessage "Updating environment variable: PATH"
                    $path = [Environment]::GetEnvironmentVariable("PATH", $env_target)
                    $path_new = RemovePathItem $path $rye_shims_path
                    UpdateEnvironmentVairbale "PATH" $path_new $env_target

                    if (Test-Path $rye_exe_path) {
                        LogMessage "Executing: rye self uninstall"
                        & $rye_exe_path self uninstall -y
                    }
                }
            }
        }
        finally {
            LogMessage "Rye uninstalltion completed"
        }
    }

    function InstallRye([string]$rye_version, [string]$rye_home, [string]$env_target) {
        LogMessage "Start Rye installtion (version: $rye_version, RYE_HOME: $rye_home, target: $env_target)"

        try {
            LogMessage "Updating environment variable: RYE_HOME"
            ${ENV:RYE_HOME} = $rye_home
            UpdateEnvironmentVairbale "RYE_HOME" $ENV:RYE_HOME $env_target

            LogMessage "Updating environment variable: PATH"
            $path = "$ENV:RYE_HOME\shims;" + [Environment]::GetEnvironmentVariable("PATH", $env_target)
            UpdateEnvironmentVairbale "PATH" $path $env_target

            ${ENV:PATH} = "$ENV:RYE_HOME\shims;" + [Environment]::GetEnvironmentVariable("PATH")

            LogMessage "Downloading Rye installer"
            $installer_url = "https://github.com/mitsuhiko/rye/releases/download/$rye_version/rye-x86_64-windows.exe"
            $installer_exe = ".\rye-x86_64-windows.exe"
            try {
                Invoke-WebRequest -UseBasicParsing -o $installer_exe $installer_url

                LogMessage "Executing Rye installer"
                & $installer_exe self install --yes
            }
            finally {
                if (Test-Path $installer_exe) {
                    Remove-Item $installer_exe
                }
            }
        }
        finally {
            LogMessage "Rye installtion completed"
        }
    }

    Main
}

if ($null -Eq $rye_home) {
    $rye_home = "$ENV:USERPROFILE\.rye"
}
if ($null -Eq $env_target) {
    $env_target = "user"
}
if ($null -Eq $rye_version) {
    $rye_version = "0.15.2"
}
$script_path = ".\tmp.ps1"
Write-Output "$script" > $script_path
try {
    & $script_path $rye_home $env_target $rye_version
}
finally {
    Remove-Item $script_path
}