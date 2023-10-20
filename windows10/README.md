# Rye installation scripts for Windows 10

## Usage

Execute this code in powershell.

```powershell
Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1" -O $env:temp\install_rye.ps1; Start-Process powershell ". '$env:temp\install_rye.ps1'; InstallRyeForUser; Pause" -Wait
```

To install Rye for all users, use the following code instead of the above code.

```powershell
Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1" -O $env:temp\install_rye.ps1; Start-Process powershell ". '$env:temp\install_rye.ps1'; InstallRyeForMachine; Pause" -Wait -Verb RunAs
```
