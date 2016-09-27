Function Sync-WOPurge
{
    <#
        .SYNOPSIS 
        Purges expired media assets from WideOrbit according to a supplied WOTraffic purge file.
        .DESCRIPTION
        Deletes media assets from WideOrbit according to a supplied WOTraffic purge file. 
        Will export a csv data file listing deleted files. Files can be backed up before deletion.
        Supports common paramaters -verbose, -whatif, and -confirm.

        .PARAMETER wo_category
        The WideOrbit category code your commercials exist in. Typicall 'COM'

        .PARAMETER wo_purgefile
        The path to the WOTraffic purge file. Should be in xlsx format with Media Asset ID's in Column G.

        .PARAMETER wo_ip
        The IP address of your WideOrbit Central server

        .PARAMETER wo_backup
        Backup media assets before deletion? Include to backup audio. 

        .PARAMETER wo_export_dir
        The directory to save the Deleted Files csv in. Audio will be saved here as well.

        .EXAMPLE 
        PS C:\> Sync-WOPurge -wo_category COM -wo_purgefile c:\WOTrafficPurgeFile.xlsx -wo_ip 192.168.1.1 -wo_export_dir c:\export

        This will purge all of the carts listed in the supplied WOTraffic Purge File from the category COM. 
        Before deleting the audio files, it will export a CSV file to C:\export that lists all of the carts to be deleted, and all of their metadata (excluding timers and daypart restrictions)
        You will be prompted before deleting any files.

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
        https://github.com/areynolds77/ETM-ATL-WO 

    #>
   
   [CmdletBinding(
       SupportsShouldProcess=$true,
       ConfirmImpact="High"
   )]
    param(
        [Parameter(
            Position=0,
            Mandatory=$True,
            HelpMessage='What WideOrbit category do your commercials exist in?'
        )]
        [ValidateLength(3,3)]
        [string]$wo_category,
        [Parameter(
            Position=1,
            Mandatory=$True,
            HelpMessage='Path to the WOTraffic purge file'
        )]
        [ValidateScript({Test-Path $_ -pathType Leaf -include *.xls*})]
        [string]$wo_purgefile,
        [Parameter(
            Position=2,
            Mandatory=$True,
            HelpMessage='IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported.'
        )]
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            Position=3,
            Mandatory=$True,
            HelpMessage='Directory to export Delete verification report. Audio will also be exported to this dir'
        )]
        [ValidateScript({Test-Path $_ -pathType Container})]
        [string]$wo_exportdir,
        [switch]$wo_backup
    )
        
    Begin {
        $FunctionTime = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Output "Beginning WideOrbit Purge File sync..."
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
        #region Function Definitions
            Function OpenExcelBook($FileName) {
                $Excel = New-Object -ComObject Excel.Application
                Return $Excel.workbooks.open($FileName)
                Write-Debug -Message "Opening Excel Book $FileName "
            }
            Function ReadCellData($Workbook,$Cell) {
                $Worksheet = $Workbook.Activesheet
                Return $Worksheet.Range($Cell).text
            }
            Function CloseExcelBook($Workbook) {
                $Workbook.close()
                Write-Debug -message "Closing Excel Book $Workbook "
            }
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided input values"
            Write-Debug -Message "Provided WideOrbit Category: $wo_category"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Provided WideOrbit Traffic Purge file: $wo_purgefile"
            Write-Debug -Message "Provided Export directory: $wo_exportdir"
            Write-Debug -Message "Audio Backup enabled: $wo_backup"
        #endregion
        #region Import Purge file data
            #Import carts from Purge file into $PurgeCarts array
            Write-Verbose -Message "Importing media asset numbers from supplied WOTraffic purge file..."
            $PurgeFile = OpenExcelBook($wo_purgefile)
            $Row = 2
            $PurgeCarts = New-Object System.Collections.ArrayList
            Do {
                $PurgeCarts += ReadCellData -Workbook $PurgeFile -Cell "G$ROW"
                $Row = $Row + 1
                "Importing cart number: " + $PurgeCarts[-1] | Write-Debug
            } until ($PurgeCarts[-1] -eq "")
            $PurgeCarts = $PurgeCarts[0..($PurgeCarts.Count -2)] #Remove last entry (which is empty)
            $PurgeCarts = $PurgeCarts.Split('-')
            $PurgeCarts = $PurgeCarts.padLeft(4,'0')
            $PurgeCarts = $PurgeCarts | Where-Object {$_ -ne "0ATL"}
            CloseExcelBook($PurgeFile)            
        #endregion
        #region Get Media Asset Metadata
            Write-Verbose "Requesting media asset information from WideOrbit Central Server for carts in $wo_category ..."
            $URI_SearchRadioStationContent = $wo_ip + "/ras/inventory"
            $MediaAssetInfoBody = '<?xml version="1.0" encoding="UTF-8"?><searchRadioStationContentRequest version="1"><clientId>clientId</clientId><authentication>admin</authentication><query>{0}/</query><start>0000</start><max>9999</max></searchRadioStationContentRequest>' -f $wo_category
            $MediaAssetInfoRet = [xml] (Invoke-WebRequest -Uri $URI_SearchRadioStationContent -Method Post -ContentType "text/xml" -Body $MediaAssetInfoBody)
        #endregion
        #region Create To Be Deleted Array and export datafile
            Write-Debug -Message "Creating 'To Be Deleted array'..." 
            $ExportFile = $wo_exportdir + "\WO - Deleted Files - " + $(Get-Date -f 'yyyy-MM-dd') + ".csv" 
            $ToBeDeleted =  $MediaAssetInfoRet.searchRadioStationContentReply.cartObjects.cartObject | Where-Object cartName -in $PurgeCarts
            $ToBeDeleted | Export-Csv -Path $ExportFile -NoTypeInformation 
            Write-Verbose -Message "CSV Datafile exported to '$ExportFile"
        #endregion
    }
    Process{
        #Backup Audio
        if ($wo_backup -eq $True) {
            foreach ($BackupCart in $ToBeDeleted) {
                    $sourcefile = $BackupCart.location -replace('^\\\\(.*)\\AUDIO',"\\$wo_ip\AUDIO$1")
                    $dstfile = $wo_exportdir + "\SP" +  $BackupCart.cartName + ".wav" #Modify this to change exported file names.
                    Write-Verbose -Message "Backing up source file: '$sourcefile to '$dstfile "
                    Copy-Item $sourcefile -Destination $dstfile -Confirm:$False
            }
        }
        foreach ($DeletedCart in $ToBeDeleted) {
            if ($PSCmdlet.ShouldProcess(($wo_category + "/" + $DeletedCart.cartName + " - " + $DeletedCart.desc1),"Deleting cart")){
                #Delete Audio
                $DeleteMediaAssetBody = @()
                $DeleteMediaAssetBody = '<?xml version="1.0" encoding="utf-8"?><deleteMediaAssetRequest version="1"><clientId>WO-DeleteScript</clientId><category>{0}</category><cartName>{1}</cartName></deleteMediaAssetRequest>' -f $wo_category, $DeletedCart.cartName
                $URI_DeleteMediaAsset = $wo_ip + "/ras/inventory"
                $DeleteCartMessage = "DELETING CART: " + $DeletedCart.cartName + " - " + $DeletedCart.desc1
                Write-Output $DeleteCartMessage
                Write-Debug -Message "Delete Media Asset Body HTTP Request: '$DeleteMediaAssetBody"
                $DeleteMediaAssetRet = Invoke-WebRequest -Uri $URI_DeleteMediaAsset -Method Post -ContentType "text/xml" -Body $DeleteMediaAssetBody
                $DeleteMediaAssetRet | Write-Debug
            }
        }
    }
    End {
        Write-Output "Operation complete."
        "WideOrbit Purge File synchronization completed in " + $FunctionTime.elapsed | Write-Verbose  
    }
}