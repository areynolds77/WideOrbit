# WideOrbit
WideOrbit Powershell Module
##Installation
Powershell V3 or newer required
To install to your personal modules folder (e.g. ~\Documents\WindowsPowerShell\Modules), run:
```powershell
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/areynolds77/wideorbit/master/Install-WideOrbitPSModule.ps1')
```

OR 
Download the 'InstallWideOrbitPSModule.ps1' file and execute it.

Once you have executed the install script, you should see the WideOrbit module available for use--
```powershell
Get-Module -ListAvailable
```
## Functions

#### Get-MediaAsset
#### Get-ProblemCarts
#### Get-ScheduleByDate
#### Import-MediaAsset