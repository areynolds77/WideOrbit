Function Get-MediaAsset {
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
            HelpMessage = "The name of the media asset's category"
        )]
        [ValidateLength(3,3)]
        [string]$wo_category,
        [Parameter(
            Position = 2,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "The four digit media asset ID number for the cart you wish to target."
        )]
        [ValidatePattern('^(\d|[A-Za-z]){0,4}$')]
        [string]$wo_cartName
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
            Write-Debug -Message "Provided WideOrbit category: $wo_category"
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
    }
    Process {
        #Pad cartName
        $wo_cartName = $wo_cartName.PadLeft(4,'0')
        Write-Debug -Message "Requesting metadata for cart: $wo_category\$wo_cartName"
        #Post Get-MediaAssetRequest
        $GMA_Body = '<?xml version="1.0" encoding="UTF-8"?><getMediaAssetRequest version="1"><clientId>{0}</clientId><category>{1}</category><cartName>{2}</cartName></getMediaAssetRequest>' -f $wo_clientID,$wo_category,$wo_cartName
        $GMA_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $GMA_Body)
        if ($GMA_Reply.getMediaAssetReply.status -notmatch "Success") {
            $GMA_Error = $GMA_Reply.getMediaAssetReply.description
            Write-Output "ERROR: Request to retreive Media Asset $wo_category\$wo_cartName has failed. Reason: $GMA_Error"
        }

        $cart = $GMA_Reply.getMediaAssetReply.MediaAsset 

        $Start_pattern = "\<timer millis\=\`"(\d*)`"\>Start"
        $Intro_pattern =  "\<timer millis\=\`"(\d*)`"\>Intro"
        $HookStart_pattern = "\<timer millis\=\`"(\d*)`"\>HookStart"
        $HookEnd_pattern = "\<timer millis\=\`"(\d*)`"\>HookEnd"
        $EOM_pattern =  "\<timer millis\=\`"(\d*)`"\>EOM"       
        $End_pattern =  "\<timer millis\=\`"(\d*)`"\>End"       

        

        $timer_intro = 
        $cart_object = New-Object -TypeName psobject
        $cart_object | Add-Member -MemberType NoteProperty -Name "cartName" -Value $cart.CartName
        $cart_object | Add-Member -MemberType NoteProperty -Name "category" -Value $cart.category
        $cart_object | Add-Member -MemberType NoteProperty -Name "speedAdjustment" -Value $cart.speedAdjustment
        $cart_object | Add-Member -MemberType NoteProperty -Name "location" -Value $cart.location
        $cart_object | Add-Member -MemberType NoteProperty -Name "desc1" -Value $cart.desc1
        $cart_object | Add-Member -MemberType NoteProperty -Name "desc2" -Value $cart.desc2
        $cart_object | Add-Member -MemberType NoteProperty -Name "desc3" -Value $cart.desc3
        $cart_object | Add-Member -MemberType NoteProperty -Name "year" -Value $cart.year
        $cart_object | Add-Member -MemberType NoteProperty -Name "ending" -Value $cart.ending
        $cart_object | Add-Member -MemberType NoteProperty -Name "length" -Value $cart.length
        $cart_object | Add-Member -MemberType NoteProperty -Name "startDateTime" -Value $cart.startDateTime
        $cart_object | Add-Member -MemberType NoteProperty -Name "killDateTime" -Value $cart.killDateTime
        $cart_object | Add-Member -MemberType NoteProperty -Name "assetType" -Value $cart.assetType
        $cart_object | Add-Member -MemberType NoteProperty -Name "nextToPlay" -Value $cart.nextToPlay
        $cart_object | Add-Member -MemberType NoteProperty -Name "timestamp" -Value $cart.timestamp
        $cart_object | Add-Member -MemberType NoteProperty -Name "created" -Value $cart.created
        $cart_object | Add-Member -MemberType NoteProperty -Name "prefix" -Value $cart.prefix
        $cart_object | Add-Member -MemberType NoteProperty -Name "fadeType" -Value $cart.fadeType
        $cart_object | Add-Member -MemberType NoteProperty -Name "audioMetadata" -Value $cart.audioMetadata
        $cart_object | Add-Member -MemberType NoteProperty -Name "gain" -Value $cart.gain
        $cart_object | Add-Member -MemberType NoteProperty -Name "radioStations" -Value $cart.radioStations
        $cart_object | Add-Member -MemberType NoteProperty -Name "playchase" -Value $cart.playchase

    }
    End {
        "Get-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug
    }
}
