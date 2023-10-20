# Rye installation scripts for Windows 10

## Usage

Execute this code in powershell.

```powershell
Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1" -O lib.ps1; Start-Process powershell ". '.\lib.ps1'; InstallRyeForUser; Pause" -Wait
```

To install Rye for all users, use the following code instead of the above code.

```powershell
Invoke-Webrequest "https://raw.githubusercontent.com/kzm4269/rye-installation-scripts/main/windows10/install_rye.ps1" -O lib.ps1; Start-Process powershell ". '.\lib.ps1'; InstallRyeForMachine; Pause" -Wait -Verb RunAs
```
