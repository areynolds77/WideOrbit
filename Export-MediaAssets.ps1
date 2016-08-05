Function Export-MediaAssets
{
    <#
        .SYNOPSIS 
        Purges expired media assets from WideOrbit according to a supplied WOTraffic purge file.
        .DESCRIPTION
        Deletes media assets from WideOrbit according to a supplied WOTraffic purge file. 
        Will export a csv data file listing deleted files. Files can be backed up before deletion.
        Supports common paramaters -verbose, -whatif, and -confirm.

        .PARAMETER wo_category
        The WideOrbit category code you wish to export media assets from.'

        .PARAMETER wo_ip
        The IP address of your WideOrbit Central server

        .PARAMETER wo_export_dir
        The directory to save the Exported audio in.

        .PARAMETER backup
        Include this flag to backup the selected media assets. 

        .PARAMETER allcarts
        Include this flag to backup ALL carts in the provided category.

        .EXAMPLE 
        PS C:\> Export-Media Assets -wo_category COM -wo_ip 192.168.1.1

        .EXAMPLE
        PS C:\> Sync-WOPurge -wo_category COM -wo_purgefile c:\WOTrafficPurgeFile.xlsx -wo_ip 192.168.1.1 -wo_export_dir c:\export -whatif
        This will output a list of every cart that would be deleted if the '-whatif' flag was excluded.
        Including the '-whatif' flag prevents the function from exporting a datafile, backing up any audio, or deleting any audio.

        .EXAMPLE 
        PS C:\> Sync-WOPurge -wo_category COM -wo_purgefile c:\WOTrafficPurgeFile.xlsx -wo_ip 192.168.1.1 -wo_export_dir c:\export -backup
        This will backup all audio files to the provided Export directory before deleting them (You will still be prompted before each cart is deleted).

        .NOTES
        In order to make use of the backup functionality, you must have read access to the WideOrbit Central server audio directory. 
        Non-standard file directory layouts are not supported--your top level audio directory MUST be shared, and must immediately contain the category audio folders.  

        .LINK
        https://github.com/areynolds77/wideorbit  

    #>
   
   [CmdletBinding(
       SupportsShouldProcess=$true
   )]
    param(
        [Parameter(
            Position = 0,
            Mandatory = $True,
            ValueFromPipeline = $True,
            HelpMessage='What WideOrbit category do your commercials exist in?'
        )]
        [ValidateLength(3,3)]
        [string]$wo_category,
        [Parameter(
            Position = 1,
            Mandatory = $True,
            HelpMessage ='IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported.'
        )]
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            ParameterSetName = 'Backup',
            Mandatory = $true,
            Position = 2,
            HelpMessage = 'Directory to store exported audio.'
        )]
        [ValidateScript({Test-Path $_ -pathType Container})]
        [string]$wo_exportdir,
        [Parameter(
            ParameterSetName = 'Backup',
            HelpMessage = 'Enable this if you wish to backup selected audio files.'
        )]
        [switch]$backup,
        [switch]$allcarts
    )  
    Begin {
        $FunctionTime = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "Beginning WideOrbit Media Asset Export..."
        #region Misc. settings + parameter cleanup
            if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {
                $DebugPreference = "Continue"
                Write-Debug -Message "Debug output active"
            } else {
                $DebugPreference = "SilentlyContinue"
            }
            #Strip tailing '\' from export directory. 
            if ($wo_exportdir -match '\\$') {
                $wo_exportdir = $wo_exportdir.Substring(0,$wo_exportdir.Length-1)
            }
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided input values"
            Write-Debug -Message "Provided WideOrbit Category: $wo_category"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Provided Audio Export directory: $wo_exportdir"
            Write-Debug -Message "Audio Backup enabled: $backup"
            Write-Debug -Message "Cart Selection enabled: $allcarts"
        #endregion
        #region Get Media Asset Metadata
            Write-Verbose "Requesting media asset information from WideOrbit Central Server for carts in $wo_category ..."
            $URI_SearchRadioStationContent = $wo_ip + "/ras/inventory"
            $MediaAssetInfoBody = '<?xml version="1.0" encoding="UTF-8"?><searchRadioStationContentRequest version="1"><clientId>clientId</clientId><authentication>admin</authentication><query>{0}/</query><start>0000</start><max>9999</max></searchRadioStationContentRequest>' -f $wo_category
            $MediaAssetInfoRet = [xml] (Invoke-WebRequest -Uri $URI_SearchRadioStationContent -Method Post -ContentType "text/xml" -Body $MediaAssetInfoBody)
        #endregion
        #region Create To Be Exported Array and export datafile
            Write-Debug -Message "Creating 'To Be Exported array'..." 
            if ($allcarts -eq $false) {
                $ToBeExported =  $MediaAssetInfoRet.searchRadioStationContentReply.cartObjects.cartObject  |  Out-GridView -PassThru -Title "Please select the media assets you wish to export" 
            } else {
                $ToBeExported =  $MediaAssetInfoRet.searchRadioStationContentReply.cartObjects.cartObject  
            }
        #endregion
    }
    Process{
        #Backup Audio
        if ($backup -eq $True) {
            $progresscount = 1
            foreach ($BackupCart in $ToBeExported) {
                if ($PSCmdlet.ShouldProcess(($wo_category + "/" + $BackupCart.cartName + " - " + $BackupCart.desc1),"Backing up media asset")) {
                    $sourcefile = $BackupCart.location -replace('^\\\\(.*)\\AUDIO',"\\$wo_ip\AUDIO$1")
                    $dstfile = $wo_exportdir + "\SP" +  $BackupCart.cartName + ".wav" #Modify this to change exported file names.
                    Write-Verbose -Message "Backing up source file: '$sourcefile to '$dstfile "
                    Write-Progress -Activity 'Backing up files' -Status 'Copying file $BackupCart' -PercentComplete ($progresscount/$ToBeExported.count * 100) 
                    Copy-Item $sourcefile -Destination $dstfile -Confirm:$False
                    $progresscount++
                }
            }
        }
    }
    End {
        Write-Verbose "Operation complete."
        "WideOrbit Asset export and removal completed in " + $FunctionTime.elapsed | Write-Verbose
        $ToBeExported
    }
}