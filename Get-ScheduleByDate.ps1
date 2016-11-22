Function Get-ScheduleByDate {
    <#
        .SYNOPSIS
        The Get-ScheduleByDate function is used to retrieve a schedule for a specific day..
        .DESCRIPTION
        Get-ScheduleByDate returns all of the objects within a days schedule, including playable entries, synch points, traffic merges etc.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_stationname
        The name of the radio station in WideOrbit.
        .PARAMETER wo_date
        The date you wish to check. Should be in the format YYYY-MM-dd.
        .EXAMPLE
        Get-SchedulebyDate -wo_ip 192.168.1.1 -wo_stationname ATLANTA-TX1 -wo_date 2016-11-01

        This is the most basic example. It will query the WideOrbit Central server with an IP of 192.168.1.1 for the schedule for November 1 2016.
        .EXAMPLE
        "2016-11-01","2016-11-02" | Get-SchedulebyDate -wo_ip 192.168.1.1 -wo_stationname ATLANTA-TX1

        This will query the WideOrbit Central Server for the schedules loaded to ATLANTA-TX1 on November 1, 2016 and November 2, 2016.
        .EXAMPLE
        Get-SchedulebyDate -wo_ip 192.168.1.1 -wo_stationname ATLANTA-TX1 -wo_date 2016-11-01 -debug

        This will query the WideOrbit Central server with an IP of 192.168.1.1 for the schedule for November 1 2016. It will also include all diagnostic messages. 
        Useful for troubleshooting. 
        .NOTES 
        Output is an xml object. Store it in a variable to manipulate the data within.
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
        [ValidatePattern('^(\d{4}\-\d{2}\-\d{2}$')]
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
            $wo_clientID = "$env:computername---$wo_clientID" 
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
        if ($GS_Reply.getScheduleByDateReply.status -notmatch "Success") {
            $GS_Error = $GS_Reply.getScheduleByDateReply.description
            Write-Output "ERROR: Request to retreive playlist for date: $wo_date from station: $wo_stationname has failed. Reason: $GS_Error"
        } else {
            $Out = $GS_Reply.GetScheduleByDateReply.schedule
            $Out
        }
    }
    End {
        "Get-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug

    }
}