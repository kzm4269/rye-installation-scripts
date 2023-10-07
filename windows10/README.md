# Rye installer scripts for Windows 10

## Usage

Execute this code in powershell.

```powershell
$rye_home="$ENV:USERPROFILE\.rye"; $env_target="user"; (Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1").Content | Invoke-Expression
```

To install Rye for all users, use the following code instead of the above code.

```powershell
$rye_home="C:\.rye"; $env_target="machine"; (Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1").Content | Invoke-Expression
```
