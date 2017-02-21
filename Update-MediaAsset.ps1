Function Update-MediaAsset {
    <#
        .SYNOPSIS
        The Update-MediaAsset function is used to update or modify the metadata for a provided media asset.
        .DESCRIPTION
        Update-MediaAsset accepts a csv file containing metadata for . If the media asset can not 
        be found, an error status is returned.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER $wo_csvfile
        The path to a csv file containing metadata for WideOrbit media assets.
        .PARAMETER compare
        Enable this switch to compare the old and new metadata before updating. 
        .EXAMPLE
        Update-MediaAsset -wo_ip 192.168.1.1 -wo_csvfile c:\carts.csv

        This is the most basic example.
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
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            Position=1,
            Mandatory=$True,
            HelpMessage='Path to a csv file'
        )]
        [ValidateScript({Test-Path $_ -pathType Leaf -include *.csv*})]
        [string]$wo_csvfile,
        [switch]$compare
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
        #region Regex Patterns
            $Start_pattern = "\<timer millis\=\`"(\d*)`"\>Start"
            $Intro_pattern =  "\<timer millis\=\`"(\d*)`"\>Intro"
            $HookStart_pattern = "\<timer millis\=\`"(\d*)`"\>HookStart"
            $HookEnd_pattern = "\<timer millis\=\`"(\d*)`"\>HookEnd"
            $EOM_pattern =  "\<timer millis\=\`"(\d*)`"\>EOM"       
            $End_pattern =  "\<timer millis\=\`"(\d*)`"\>End"
            $dow_sun_pattern = "sun\=\`"(\d*)\`""
            $dow_mon_pattern = "mon\=\`"(\d*)\`"" 
            $dow_tue_pattern = "tue\=\`"(\d*)\`"" 
            $dow_wed_pattern = "wed\=\`"(\d*)\`"" 
            $dow_thu_pattern = "thu\=\`"(\d*)\`"" 
            $dow_fri_pattern = "fri\=\`"(\d*)\`"" 
            $dow_sat_pattern = "sat\=\`"(\d*)\`"" 
        #endregion
        #region Internal Functions
            function Compare-ObjectsSideBySide ($lhs, $rhs) {
                $lhsMembers = $lhs | Get-Member -MemberType NoteProperty, Property | Select-Object -ExpandProperty Name
                $rhsMembers = $rhs | Get-Member -MemberType NoteProperty, Property | Select-Object -ExpandProperty Name
                $combinedMembers = ($lhsMembers + $rhsMembers) | Sort-Object -Unique


                $combinedMembers | ForEach-Object {
                $properties = @{
                    'Property' = $_;
                }

                if ($lhsMembers.Contains($_)) {
                    $properties['Old'] = $lhs | Select-Object -ExpandProperty $_;
                }

                if ($rhsMembers.Contains($_)) {
                    $properties['New'] = $rhs | Select-Object -ExpandProperty $_;
                }

                New-Object PSObject -Property $properties
                }
            }
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
            if ($compare -eq $true) { 
                Compare-ObjectsSideBySide -lhs $oldcart -rhs $cart | Out-GridView -Title "Comparing Metadata for cart $($cart.cartName)" 
            }
            if ($PSCmdlet.ShouldProcess(($cart.category + "/" + $cart.cartName),"Updating metadata for cart")){
                Write-Verbose "Updating metadata for $($cart.category)/$($cart.cartName)"
$UMA_Body = @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<updateMediaAssetRequest version="1">
<mediaAsset>
    <cartName>$($cart.cartName)</cartName>
    <category>$($cart.category)</category>
    <speedAdjustment>$($cart.speedAdjustment)</speedAdjustment>
    <location>$($cart.location)</location>
    <desc1>$($cart.desc1)</desc1>
    <desc2>$($cart.desc2)</desc2>
    <desc3>$($cart.desc3)</desc3>
    <year>$($cart.year)</year>
    <ending>$($cart.ending)</ending>
    <length>$($cart.length)</length>
    <timers>
    <timer millis="$($cart.timer_hookEnd)">HookEnd</timer>
    <timer millis="$($cart.timer_eom)">EOM</timer>
    <timer millis="$($cart.timer_start)">Start</timer>
    <timer millis="$($cart.timer_end)">End</timer>
    <timer millis="$($cart.timer_intro)">Intro</timer>
    <timer millis="$($cart.timer_hookEOM)">HookEOM</timer>
    <timer millis="$($cart.timer_hookStart)">HookStart</timer>
    </timers>
    <startDateTime>$($cart.startDateTime)</startDateTime>
    <killDateTime>$($cart.killDateTime)</killDateTime>
    <dowHours fri="$($cart.dow_fri)" mon="$($cart.dow_mon)" sat="$($cart.dow_sat)"
    sun="$($cart.dow_sun)" thu="$($cart.dow_thu)" tue="$($cart.dow_tue)" wed="$($cart.dow_wed)"/>
    <assetType>$($cart.assetType)</assetType>
    <nextToPlay>$($cart.nextToPlay)</nextToPlay>
    <prefix>$($cart.prefix)</prefix>
    <fadeType>$($cart.fadeType)</fadeType>
    <audioMetadata>$($cart.audioMetadata)</audioMetadata>
    <gain>$($cart.gain)</gain>
    <radioStations>$($cart.radioStations)</radioStations>
    <playchase>$($cart.playchase)</playchase>
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
    }
    End {
        "Update-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug
    }
}
