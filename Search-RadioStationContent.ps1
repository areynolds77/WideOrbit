Function Search-RadioStationContent {
    <#
        .SYNOPSIS
        The Get-MediaAsset function is used to obatin information about a provided media asset.
        .DESCRIPTION
        Get-MediaAsset returns all metadata about a selected media asset. If the media asset can not 
        be found, an error status is returned.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_category
        The name of the media asset's category. Should be exactly three characters.
        .PARAMETER wo_cartName
        The media asset ID number for the cart you wish to target. Accepts pipeline input. Maximum four characters.
        .EXAMPLE
        Get-MediaAsset -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001

        This is the most basic example. It will query the WideOrbit Central server with an IP of 192.168.1.1 for information about cart COM/1001.
        .EXAMPLE
        1001,1002,1003 | Get-MediaAsset -wo_ip 192.168.1.1 -wo_category COM | Out-GridView

        This will query the WideOrbit Central server for information about carts COM/1001, COM/1002, and COM/1003 and then pipe the output to a grid view.
        .EXAMPLE
        Get-MediaAsset -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001 -debug -verbose
        
        This will query the WideOrbit Central server for information about cart COM/1001, but will also include all diagnostic messages. Useful for troubleshooting.
        .NOTES 
        Get-MediaAsset will accept an array of cartNames as a pipeline input, but they must all be in the same category. 
        Timers and Daypart restriction values are not yet supported.
        .LINK
        https://github.com/areynolds77/ETM-ATL-WO
    #>
    [CmdletBinding(
    )]
    # Parameter help description
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = "IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported."
        )]
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            Position = 1,
            Mandatory = $true,
            HelpMessage = "The WideOrbit name of the radio station you wish to target"
        )]
        [string]$wo_stationname,
        [Parameter(
            Position = 2,
            HelpMessage = "Your search query--uses same syntax as audio finder."
        )]
        [string]$wo_query,
        [Parameter(
            Position = 3,
            HelpMessage = "The user you wish to search as--defaults to 'admin' "
        )]
        [string]$wo_user,
        [Parameter(
            Position = 4,
            HelpMessage = "The maximum number of results to return--defaults to '500' , maximum of 10,000. "
        )]
        [ValidateRange(1,10000)]
        [int]$wo_maxresults
    )
    Begin {
        $FunctionTime = [System.Diagnostics.Stopwatch]::StartNew()
        #region Misc. settings + parameter cleanup
            #Set debug preference
            if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {
                $DebugPreference = "Continue"
                Write-Debug -Message "Debug output active"
            } else {
                $DebugPreference = "SilentlyContinue"
            }
            #Generate unique clientID:
            $wo_clientID = [guid]::NewGuid()
            $wo_clientID = "$env:computername---$wo_clientID" 
            #Set URI 
            $wo_uri = $wo_ip + "/ras/inventory"
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided Input values:"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Provided WideOrbit Radio Station: $wo_stationname"
            Write-Debug -Message "Provided WideOrbit User: $wo_user"
            Write-Debug -Message "Provided search query: $wo_query"
            Write-Debug -Message "Returning a maximum of $wo_maxresults results."
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
    }
    Process {
        #Post Get-MediaAssetRequest
        $Search_Body = '<?xml version="1.0" encoding="UTF-8"?><searchRadioStationContentRequest version="1"><clientId>{0}</clientId><authentication>{1}</authentication><radioStation>{2}</radioStation><query>{3}</query><start>0</start><max>{4}</max></searchRadioStationContentRequest>' -f $wo_clientID , $wo_user , $wo_stationname , $wo_query , $wo_maxresults 
        $Search_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method Post -ContentType "text/xml" -Body $Search_Body)
        if ($Search_Reply.searchRadioStationContentReply.status -notmatch "Success") {
            $Search_Error = $Search_Reply.searchRadioStationContentReply.description
            Write-Output "ERROR: Request to search for audio with query: $wo_query from station: $wo_stationname has failed. Reason: $Search_Error"
        } else {
            $TotalResults = $Search_Reply.searchRadioStationContentReply.totalResults
            Write-Debug -Message "Search returned a total of $TotalResults results."
            $Out = $Search_Reply.searchRadioStationContentReply.cartObjects
            $Out
        }
    }
    End {
        "Search completed in " + $FunctionTime.elapsed | Write-Debug

    }
}