param([string]$InstallDirectory)

$filelist = echo `
    WideOrbit.psd1 `
    WideOrbit.psm1 `
    Export-MediaAssets.ps1 `
    Get-AllRadioStations.ps1 `
    Get-MediaAsset.ps1 `
    Get-ProblemCarts.ps1 `
    Get-ScheduleByDate.ps1 `
    Import-MediaAsset.ps1 `
    SearchRadioStationContent.ps1 `
    Sync-WOPurge.ps1

if ('' -eq $InstallDirectory) {
    $personalModules = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowershell\Modules

    if(($env:PSModulePath -split ';') -notcontains $personalModules) {
        Write-Warning "personalModules is not in `$env:PSModulePath"
    }

    if(!(Test-Path $personalModules)) {
        Write-Warning "$personalModules does not exist."
    }

    $InstallDirectory = Join-Path -Path $personalModules -ChildPath WideOrbit
}

if (!(Test-Path $InstallDirectory)) {
    $null = mkdir $InstallDirectory
}

$wc = New-Object System.Net.WebClient
$filelist | ForEach-Object {
    $wc.DownloadFile("https://raw.github.com/areynolds77/wideorbit/master/$_","$InstallDirectory\$_")
}
    
