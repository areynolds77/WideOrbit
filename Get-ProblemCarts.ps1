Function Get-ProblemCarts {
    <#
        .SYNOPSIS
        The Get-ProblemCarts function is used to check a playlist for problematic media assets.
        .DESCRIPTION
        Get-ProblemCarts returns a list of problem media assets for a given playlist. (I.e. No audio loaded, date or time restrictions.)
        If no playlist is loaded, or there are no problem carts in the provided playlist that will be returned as well.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_radiostation
        The name of the Radio Station within WideOrbit whose playlist you wish to check.
        .PARAMETER wo_playlistdate
        The date of the playlist you wish to check. Must be in the form 'YYYY-MM-dd'. Pipeline values accepted.
        .EXAMPLE
        Get-MediaAsset -wo_ip 192.168.1.1 -wo_radiostation 'STAR 941A' -wo_playlistdate '2016-07-29'

        This is the most basic example. It will query the WideOrbit Central server with an IP of 192.168.1.1 for problematic media assets in the playlist loaded for July 29, 2016.
        .EXAMPLE
        ('2016-07-26','2016-07-27','2016-07-28') | Get-MediaAsset -wo_ip 192.168.1.1 -wo_radiostation | Out-GridView

        This will query the WideOrbit Central server for problematic media assets in the playlists for July 26, 27 and 28, and then output any resulting issues to a grid view. 
        .EXAMPLE
        Get-MediaAsset -wo_ip 192.168.1.1 -wo_radiostation 'STAR 941A' -wo_playlistdate '2016-07-29' -debug -verbose
        
        This will query the WideOrbit Central server for problematic media assets on July 29, 2016, but will also include all diagnostic messages. Useful for troubleshooting.
        .NOTES 
        Get-ProblemCarts will accept an array of playlist dates as a pipeline input, but they must all be for the same Radio Station. 
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
            HelpMessage = "The name of the media asset's category"
        )]
        [string]$wo_radiostation,
        [Parameter(
            Position = 2,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The four character media asset ID for the cart you wish to target."
        )]
        [ValidatePattern('^\d{4}\-\d{2}\-\d{2}$')]
        [string]$wo_playlistdate
    )
    Begin {
        $FunctionTime = [System.Diagnostics.Stopwatch]::StartNew()
        #region Misc. settings
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
            Write-Debug -Message "Provided WideOrbit category: $wo_radiostation"
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
    }
    Process {
        #Pad cartName
        Write-Debug -Message "Requesting problem carts from the playlist for: $wo_playlistdate"
        #Post Get-ProblemCarts Request
        $GPC_Body = '<?xml version="1.0" encoding="UTF-8"?><getProblemCartsRequest version="1"><clientId>{0}</clientId><radioStationName>{1}</radioStationName><date>{2}</date></getProblemCartsRequest>' -f $wo_clientID,$wo_radiostation,$wo_playlistdate
        $GPC_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $GPC_Body)
        if ($GPC_Reply.getProblemCartsReply.status -notmatch "Success") {
            $GPC_Error = $GPC_Reply.getProblemCartsReply.description
            Write-Warning "Request to retreive problem carts for the playlist on $wo_playlistdate has failed. Reason: $GPC_Error" 
        } elseif ($GPC_Reply.getProblemCartsReply.problemCarts -eq "") {
            $GPC_Output = "No problem carts found for playlists loaded on $wo_playlistdate"
            Write-Output $GPC_Output
        } else {
            $GPC_Output = $GPC_Reply.getProblemCartsReply.problemCarts.problemCart
            Write-Output $GPC_Output
        }
    }
    End {
        "Get-ProblemCarts completed in " + $FunctionTime.elapsed | Write-Debug
    }
}
