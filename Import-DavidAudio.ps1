Function Import-DavidAudio
{
    <#
        .SYNOPSIS 
        Imports DAViD Audio files into WideOrbit.
        .DESCRIPTION
        Retreives a list of all the media assets in a provided WideOrbit category, and outputs their respective metadata.
        The user can also choose to backup the selected media assets to a provided folders. 

        .PARAMETER source_dir
        The WideOrbit category code you wish to export media assets from.

        .PARAMETER wo_ip
        The IP address of your WideOrbit Central server

        .PARAMETER wo_import_dir
        The directory to save the Exported audio in.

        .EXAMPLE 
        PS C:\> Export-Media Assets -wo_category COM -wo_ip 192.168.1.1

        This will retreive every media asset in the COM category, prompt the user to select which of the media assets to export, 
        and then output a list of every selected media asset, and their respective metadata.

        .EXAMPLE
        PS C:\> Export-MediaAssets -wo_category COM -wo_ip 192.168.1.1 -allcarts
        
        This will retreive every media asset in the COM category and then output a list of every media asset and its respective metadata.
        You will not be prompted to select individual media assets.

        .EXAMPLE 
        PS C:\> Export-MediaAssets -wo_category COM -wo_ip 192.168.1.1 -backup -wo_export_dir 'c:\export'
        This will retreive every media asset in the COM category, prompt the user to select which of the media assets to export, 
        and then output a list of every selected media asset, and their respective metadata. 
        
         Each selected media asset will also be copied to 'c:\export'

         .EXAMPLE
         PS C:\> Export-MediaAssets -wo_category COM -wo_ip 192.168.1.1 -allcarts | Export-Csv -path 'c:\export\Exported Media Assets.csv'

         This would create a csv datafile containing every media asset in the COM category, and its respective metadata.

         .EXAMPLE
         PS C:\> COM,ENG | Export-MediaAssets -wo_ip 192.168.1.1 -allcarts | Export-Csv -path 'c:\export\Exported Media Assets.csv'

         This would create a csv datafile containing every media asset in both the COM and ENG categories, as well as their respective metadata.

        .NOTES
        In order to make use of the backup functionality, you must have read access to the WideOrbit Central server audio directory. 
        Non-standard file directory layouts are not supported--your top level audio directory MUST be shared, and must immediately contain the category audio folders. 

        I.e. '\\192.168.1.1\AUDIO' is an acceptable directory, '\\192.168.1.1\WideOrbitAudio' is not.  

        .LINK
        https://github.com/areynolds77/wideorbit  

    #>
   
   [CmdletBinding(
       SupportsShouldProcess=$true,
       DefaultParameterSetName = 'None'
   )]
    param(
        [Parameter(
            Position = 0,
            Mandatory = $True,
            ValueFromPipeline = $True,
            HelpMessage='Directory to import audio from'
        )]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$source_dir,
        [Parameter(
            Position = 1,
            Mandatory = $True,
            HelpMessage ='IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported.'
        )]
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            Mandatory = $true,
            Position = 2,
            HelpMessage = 'WideOrbit Import directory.'
        )]
        [ValidateScript({Test-Path $_ -pathType Container})]
        [string]$wo_import_dir
    )  
    Begin {
        $FunctionTime = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "Beginning DAViD Audio Import Process..."
        #region Misc. settings + parameter cleanup
            if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {
                $DebugPreference = "Continue"
                Write-Debug -Message "Debug output active"
            } else {
                $DebugPreference = "SilentlyContinue"
            }
            #Strip tailing '\' from DAViD directory. 
            if ($source_dir -match '\\$') {
                $source_dir = $source_dir.Substring(0,$source_dir.Length-1)
            }
            #Strip tailing '\' from import directory. 
            if ($wo_import_dir -match '\\$') {
                $wo_import_dir = $wo_import_dir.Substring(0,$wo_import_dir.Length-1)
            }
            #Generate unique clientID:
            $wo_clientID = [guid]::NewGuid()
            $wo_clientID = "$env:computername---$wo_clientID" 
            #Set URI
            $wo_uri = $wo_ip + "/ras/inventory"
            #Get-Date
            $date = Get-Date -Format dd-MM-yyyy
        #endregion
        
    }
    Process{
        #region Debug Input Values
            Write-Debug -Message "Provided input values"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Provided DAViD Audio directory:  $source_dir"
            Write-Debug -Message "Provided WideOrbit Import directory: $wo_exportdir"
        #endregion
        #region Get all metadata files
            $david_files = Get-ChildItem $source_dir -Filter *.dbx

            foreach ($file in $david_files) {
                $david_metadata = Get-Content $file
                $david_metadata = [xml]$david_metadata

                $wo_category = 'UND'
                $wo_cartName = $david_metadata.ENTRIES.ENTRY.MOTIVE
                $wo_title = $david_metadata.ENTRIES.ENTRY.Title
                $wo_artist = $david_metadata.ENTRIES.ENTRY.CREATOR

                $file = $file -match '.*\.' 
                $audio_file = $matches[0] + 'wav'
                
                Move-Item $source_dir\$audio_file -Destination $wo_import_dir\SP$wo_cartName`.wav
                While (Test-Path $wo_import_dir\SP$wo_cartName`.wav) {
                    Start-Sleep -s 1
                }

$UMA_Body = @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<updateMediaAssetRequest version="1">
<mediaAsset>
    <cartName>$($wo_cartName)</cartName>
    <category>$($wo_category)</category>
    <speedAdjustment>10000</speedAdjustment>
    <location>\\dev-wamu-host\audio\und\SP$($wo_cartName).wav</location>
    <desc1>$($wo_title)</desc1>
    <desc2>$($wo_artist)</desc2>
    <desc3></desc3>
    <year></year>
    <ending></ending>
    <timers>
    <timer millis="$($cart.timer_eom)">EOM</timer>
    <timer millis="$($cart.timer_start)">Start</timer>
    </timers>
    <radioStations>DEV-WAMU</radioStations>
</mediaAsset>
</updateMediaAssetRequest>
"@

                $UMA_Reply= [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $UMA_Body)
                $UMA_Reply | Write-Debug
            }
    }
    End {
        Write-Verbose "Operation complete."
        "WideOrbit Asset export and removal completed in " + $FunctionTime.elapsed | Write-Verbose
    }
}