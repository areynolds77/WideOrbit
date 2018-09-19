Function Update-CampaignSpots {
    <#
        .SYNOPSIS
        The Update-CampaignSpots function is used to quickly set Title + Artist metadata for a large number of carts at once.
        .DESCRIPTION
        Update-CampaignSpots accepts a csv file containing the following fields: cartName,category,desc1,desc2,desc3. 
        .PARAMETER wo_ip 
        The IP address or FQDN of your WideOrbit Central server
        .PARAMETER wo_csvfile
        The path to a csv file containing metadata for WideOrbit media assets.
        .EXAMPLE
        Update-CampaignSpots -wo_ip 192.168.1.1 -wo_csvfile c:\carts.csv
        This is the most basic example.
        .NOTES 
        .LINK
        https://github.com/areynolds77/wideorbit
    #>
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact="High"
    )]
    # Parameter help description
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = "IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported."
        )]
        [string]$wo_ip,
        [Parameter(
            Position=1,
            Mandatory=$True,
            HelpMessage='Path to a csv file'
        )]
        [ValidateScript({Test-Path $_ -pathType Leaf -include *.csv*})]
        [string]$wo_csvfile
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
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
        
    }
    Process {
        $carts = Import-csv -Path $wo_csvfile
        foreach ($cart in $carts) {
            $oldcart = Get-MediaAsset -wo_ip $wo_ip -wo_category $cart.category -wo_cartName $cart.cartName
$UMA_Body = @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<updateMediaAssetRequest version="1">
<mediaAsset>
    <cartName>$($oldcart.cartName)</cartName>
    <category>$($oldcart.category)</category>
    <speedAdjustment>$($oldcart.speedAdjustment)</speedAdjustment>
    <location>$($oldcart.location)</location>
    <desc1>$($cart.desc1)</desc1>
    <desc2>$($cart.desc2)</desc2>
    <desc3>$($cart.desc3)</desc3>
    <year>$($oldcart.year)</year>
    <ending>$($oldcart.ending)</ending>
    <length>$($oldcart.length)</length>
    <timers>
    <timer millis="$($oldcart.timer_hookEnd)">HookEnd</timer>
    <timer millis="$($oldcart.timer_eom)">EOM</timer>
    <timer millis="$($oldcart.timer_start)">Start</timer>
    <timer millis="$($oldcart.timer_end)">End</timer>
    <timer millis="$($oldcart.timer_intro)">Intro</timer>
    <timer millis="$($oldcart.timer_hookEOM)">HookEOM</timer>
    <timer millis="$($oldcart.timer_hookStart)">HookStart</timer>
    </timers>
    <startDateTime>$($oldcart.startDateTime)</startDateTime>
    <killDateTime>$($oldcart.killDateTime)</killDateTime>
    <dowHours fri="$($oldcart.dow_fri)" mon="$($oldcart.dow_mon)" sat="$($oldcart.dow_sat)"
    sun="$($oldcart.dow_sun)" thu="$($oldcart.dow_thu)" tue="$($oldcart.dow_tue)" wed="$($oldcart.dow_wed)"/>
    <assetType>$($oldcart.assetType)</assetType>
    <nextToPlay>$($oldcart.nextToPlay)</nextToPlay>
    <prefix>$($oldcart.prefix)</prefix>
    <fadeType>$($oldcart.fadeType)</fadeType>
    <audioMetadata>$($oldcart.audioMetadata)</audioMetadata>
    <gain>$($oldcart.gain)</gain>
    <radioStations>$($oldcart.radioStations)</radioStations>
</mediaAsset>
</updateMediaAssetRequest>
"@
            $UMA_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $UMA_Body)
            $UMA_Reply | Write-Debug
            if ($UMA_Reply.updateMediaAssetReply.status -match "Success") {
                "Metadata for media asset $($cart.category)/$($cart.cartName) has been sucessfully updated."
            } else {
                "Metadata for media asset $($cart.category)/$($cart.cartName) has failed to update. Reason: $($UMA_Reply.updateMediaAssetReply.description)" | Write-Output
                "Exiting..." | Write-Output
                break

            }
        }
    }
    End {
        "Update-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug
    }
}