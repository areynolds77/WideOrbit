Function Search-RadioStationContent {
    <#
        .SYNOPSIS
        The Search-RadioStationContent function is used to search the WideOrbit Central Server for a specific media asset..
        .DESCRIPTION
        Search-RadioStationContent mimics the functionality of Audio Finder, but with a few key benefits--you can see more than 500 results at a time, and you are able to see all metadata fields.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_stationname
        The name of the radio station you wish to query.
        .PARAMETER wo_query
        What you wish to search for. Supports the same syntax as Audio Finder (i.e. Category searchs, result sorting). Defaultss to search everything.
        .PARAMETER wo_user
        The user you wish to search as. Defaults to 'admin'
        .PARAMETER wo_maxresults
        The maximum number of results you wish to return. Defaults to 500, supports a maximum of 10,000.
        .EXAMPLE
        Search-RadioStationContent -wo_ip 192.168.1.1 -wo_stationname 'STAR941A' 

        This is the most basic example. It will return the first 500 media assets distributed to radio station 'STAR941A'.
        .EXAMPLE
        Search-RadioStationContent -wo_ip 192.168.1.1 -wo_stationname 'STAR941A' -wo_query "COM/ KROGER sort:Title" -wo_maxresults 10

        This will return the first 5000 media assets in the COM category with the string 'KROGER' in any of the descriptive fields, and will sort the results alphabetically by Title. 
        It will only return the first 10 results.

        .EXAMPLE
        Search-RadioStationContent -wo_ip 192.168.1.1 -wo_stationname 'STAR941A' -wo_query "COM/ KROGER sort:Title" -wo_maxresults 10 -wo_user 'intern'
        
        This will return the same media assets as the above example, but only if the 'intern' user has access to them.
        .NOTES 

        .LINK
        https://github.com/areynolds77/WideOrbit
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
        [ValidateNotNullOrEmpty()]
        [string]$wo_stationname,
        [Parameter(
            Position = 2,
            HelpMessage = "Your search query--uses same syntax as audio finder."
        )]
        [ValidateNotNull()]
        [string]$wo_query = "",
        [Parameter(
            Position = 3,
            HelpMessage = "The user you wish to search as--defaults to 'admin' "
        )]
        [string]$wo_user = "admin",
        [Parameter(
            Position = 4,
            HelpMessage = "The maximum number of results to return--defaults to '500' , maximum of 10,000. "
        )]
        [ValidateRange(1,10000)]
        [int]$wo_maxresults = 500
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
            $ReturnedResults = $Search_Reply.searchRadioStationContentReply.cartObjects.cartObject.count
            Write-Debug -Message "Search returned a total of $ReturnedResults assets out of a possible $TotalResults results."
            $Out = $Search_Reply.searchRadioStationContentReply.cartObjects
            $Out
        }
    }
    End {
        "Search completed in " + $FunctionTime.elapsed | Write-Debug

    }
}