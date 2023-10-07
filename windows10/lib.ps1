
function GetFunctionName ([int]$stack_number = 1) {
    return [string]$(Get-PSCallStack)[$stack_number].FunctionName
}

function LogMessage ([string]$message) {
    $function_name = GetFunctionName 2
    Write-Host "$(Get-Date -Format G): ${function_name}: ${message}" -ForegroundColor "Magenta"
}

function RequireAdmin() {
    $current_role = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (!$current_role.IsInRole("Administrators")) {
        LogMessage "Restart this script as admin..."
        Start-Process powershell.exe "-File `"$PSCommandPath`"" -Verb RunAs -Wait
        exit
    }
}

function ScriptDirectoryPath() {
    return Split-Path -Parent $MyInvocation.MyCommand.Path
}

function UninstallRye([string]$env_target) {
    LogMessage "Start Rye uninstalltion (target: $env_target)"
    try {
        # Find rye.exe by RYE_HOME
        $ENV:RYE_HOME = [Environment]::GetEnvironmentVariable("RYE_HOME", $env_target)
        if ($ENV:RYE_HOME -Ne $null) {        
            LogMessage "Found RYE_HOME: $ENV:RYE_HOME"
            $rye_exe_path = "$ENV:RYE_HOME\shims\rye.exe"

            if (Test-Path $rye_exe_path) {
                LogMessage "Found rye.exe: $rye_exe_path"
                LogMessage "Executing: rye self uninstall"
                & $rye_exe_path self uninstall -y
            }

            LogMessage "Updating environment variable: PATH"
            $path = [Environment]::GetEnvironmentVariable("PATH", $env_target)
            $path_new = ""
            foreach ($p in $path -Split ";") {
                if (($p.TrimEnd('\') -Ne "$ENV:RYE_HOME\shims") -And ($p -Ne "")) {
                    $path_new += "$p;"
                }
            }
            [Environment]::SetEnvironmentVariable("PATH", $path_new, $env_target)

            LogMessage "Removing environment variable: RYE_HOME"
            [Environment]::SetEnvironmentVariable("RYE_HOME", "", $env_target)
        }

        # Find rye.exe by PATH
        $ENV:PATH = [Environment]::GetEnvironmentVariable("PATH", $env_target)
        $rye_exe_path = (Get-Command rye.exe 2>$null).Definition
        if ($rye_exe_path -Ne $null) {
            LogMessage "Found rye.exe: $rye_exe_path"
            $rye_shims_path = Split-Path -Parent $rye_exe_path
            $rye_home = Split-Path -Parent $rye_shims_path

            LogMessage "Updating environment variable: PATH"
            $path = [Environment]::GetEnvironmentVariable("PATH", $env_target)
            $path_new = ""
            foreach ($p in $path -Split ";") {
                if (($p.TrimEnd('\') -Ne "$rye_shims_path") -And ($p -Ne "")) {
                    $path_new += "$p;"
                }
            }
            [Environment]::SetEnvironmentVariable("PATH", $path_new, $env_target)

            if (Test-Path $rye_exe_path) {
                LogMessage "Executing: rye self uninstall"
                & $rye_exe_path self uninstall -y
            }
        }
    } finally {
        LogMessage "Rye uninstalltion completed"
    }
}

function InstallRye([string]$rye_version, [string]$rye_home, [string]$env_target) {
    LogMessage "Start Rye installtion (version: $rye_version, RYE_HOME: $rye_home, target: $env_target)"

    try {
        LogMessage "Updating environment variable: RYE_HOME"
        ${ENV:RYE_HOME} = $rye_home
        [Environment]::SetEnvironmentVariable("RYE_HOME", $ENV:RYE_HOME, $env_target)

        LogMessage "Updating environment variable: PATH"
        [Environment]::SetEnvironmentVariable(
            "PATH",
            "$ENV:RYE_HOME\shims;" + [Environment]::GetEnvironmentVariable("PATH", $env_target),
            $env_target
        )
        ${ENV:PATH} = "$ENV:RYE_HOME\shims;" + [Environment]::GetEnvironmentVariable("PATH")

        LogMessage "Downloading Rye installer"
        $installer_url = "https://github.com/mitsuhiko/rye/releases/download/$rye_version/rye-x86_64-windows.exe"
        $installer_exe = ".\rye-x86_64-windows.exe"
        curl -UseBasicParsing -o $installer_exe $installer_url

        LogMessage "Executing Rye installer"
        & $installer_exe self install --yes
    } finally {
        LogMessage "Rye installtion completed"
    }
}
