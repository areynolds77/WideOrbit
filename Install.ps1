param([string]$InstallDirectory)

$filelist = Write-Output `
    WideOrbit.psd1 `
    WideOrbit.psm1 `
    Export-MediaAssets.ps1 `
    Get-AllRadioStations.ps1 `
    Get-MediaAsset.ps1 `
    Get-ScheduleByDate.ps1 `
    Remove-CueAudio.ps1 `
    Remove-MediaAsset.ps1 `
    Search-RadioStationContent.ps1 `
    Sync-WOPurge.ps1 `
    Update-MediaAsset.ps1 `
    Update-CampaignSpots.ps1

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
    
