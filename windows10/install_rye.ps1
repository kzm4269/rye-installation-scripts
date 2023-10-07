. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\lib.ps1"

function Main() {
    $rye_version = "0.15.1"
    $rye_home = "$ENV:USERPROFILE\.rye"
    $env_target = "User"

    UninstallRye $env_target
    InstallRye $rye_version $rye_home $env_target

    LogMessage "Executing: rye self update"
    & rye self update

    LogMessage "Completed successfully"
}

Main
pause
