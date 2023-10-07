. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\lib.ps1"

function Main() {
    $env_target = "User"
    UninstallRye $env_target
}

Main
pause
