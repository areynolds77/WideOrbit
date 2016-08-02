Function Get-ScheduleByDate {
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
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The date of the playlist you wish to request. Should be in the form 'YYYY-MM-dd' ."
        )]
        #[ValidatePattern('^(\d{4}\-\d{2}\-\d{2}$')]
        [string]$wo_date
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
            #Set URI 
            $wo_uri = $wo_ip + "/ras/playlist"
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided Input values:"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Provided WideOrbit Radio Station: $wo_stationname"
            Write-Debug -Message "Provided playlist date: $wo_date"
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
    }
    Process {
        #Pad cartName
        Write-Debug -Message "Requesting playlist for date: $wo_date from station: $wo_stationname"
        #Post Get-MediaAssetRequest
        $GS_Body = '<?xml version="1.0" encoding="UTF-8"?><getScheduleByDateRequest version="1"><clientId>{0}</clientId><radioStationName>{1}</radioStationName><date>{2}</date></getScheduleByDateRequest>' -f $wo_clientID, $wo_stationname, $wo_date
        $GS_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method Post -ContentType "text/xml" -Body $GS_Body)
        #if ($GS_Reply.getScheduleByDateRequestReply.status -notmatch "Success") {
        #    $GS_Error = $GS_Reply.getScheduleByDateRequestReply.description
        #    Write-Output "ERROR: Request to retreive playlist for date: $wo_date from station: $wo_stationname has failed. Reason: $GS_Error"
        #}


       
       
        
        
    }
    End {
        "Get-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug
    }
}

Get-ScheduleByDate -wo_ip 172.21.44.252 -wo_stationname 'ATLANTA-TX2' -wo_date '2016-07-30' -Debug