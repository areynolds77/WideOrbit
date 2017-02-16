# WideOrbit
WideOrbit Powershell Module

This is a collection of Powershell functions used to interact with the WideOrbit API. Most of the functions (right now) are geared towards bulk metadata/inventory management.

##Installation
Powershell V3 or newer required
To install to your personal modules folder (e.g. ~\Documents\WindowsPowerShell\Modules), run:
```powershell
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/areynolds77/WideOrbit/master/Install.ps1')
```

OR 
Download the 'Install.ps1' file and execute it.

Once you have executed the install script, you should see the WideOrbit module available for use--
```powershell
Get-Module -ListAvailable
```

## General Help:
All commands support the following standard flags
-whatif
-Confirm
-Debug
-Verbose

All commands also have documentation built-in. If you want to see more information about how a particular funciton works, 
simply type:
```powershell
Get-Help $function
i.e.
Get-Help Export-MediaAssets 
```

## Functions
#### Export-MediaAssets
Retreives a list of all the media assets in a provided WideOrbit category, and outputs their respective metadata.
The user can also choose to backup the selected media assets to a provided folders. 
#### Get-MediaAsset
Get-MediaAsset returns all metadata about a selected media asset. If the media asset can not be found, an error status is returned.
#### Get-AllRadioStations
Get-AllRadioStations returns information about any radio stations hosted on a WideOrbit Central Server. If the -detailed flag is enabled, 
the function will also return information about each category assigned to that workstation (and each categories individual properties), 
as well as a list of workstations assigned to that radio station. If the -export flag is enabled, this data will be exported to a series of csv datafiles.
#### Get-ScheduleByDate
Get-ScheduleByDate returns all of the objects within a days schedule, including playable entries, synch points, traffic merges etc.
#### Remove-CueAudio
Remove-CueAudio is used to remove audio before cue markers in WideOrbit media asset files. This function will query a WO Central Server for information about
a specified media asset, and then check to see if there is a cue marker specified. If there is a cue marker, the function will copy the media asset to a temporary
folder and use ffmpeg to remove any audio before the cue marker. The file will then be re-imported into WideOrbit, after which the function update the media asset
metadata with the correct timer markers. 
#### Remove-MediaAsset
Remove-MediaAsset returns deletes a provided media asset. If the media asset can not be found, an error status is returned.
#### Search-RadioStationContent
Search-RadioStationContent mimics the functionality of Audio Finder, but with a few key benefits--you can see more than 500 results at a time, and you are able to see all metadata fields.
#### Synch-WOPurge
 Deletes media assets from WideOrbit according to a supplied WOTraffic purge file. Will export a csv data file listing deleted files. Files can be backed up before deletion. 
 Supports common paramaters -verbose, -whatif, and -confirm.

## To-Do
* Flesh out documentation + add examples
* Add examples of chained functions (i.e. Import-Csv MediaAssets.csv | Remove-MediaAsset)
* Only some of the functions are returning output as an object--all function outputs should be objects
* Synch-WOPurge should work on any input object--right now MediaAssets must be in the G column, would be nice if it could detect the appropriate column
* Imporve verbose/debug logging--there should be a standard set of messages
* Add Update-MediaAsset
* How to: access & edit DoW/timer values
