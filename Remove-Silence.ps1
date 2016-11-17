Function Remove-Silence {
    <#
        .SYNOPSIS
        The Remove-Silence function is used to remove any audio before a Cue marker in a media asset.
        .DESCRIPTION
        Remove-MediaAsset returns deletes a provided media asset. If the media asset can not 
        be found, an error status is returned.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_category
        The name of the media asset's category. Should be exactly three characters.
        .PARAMETER wo_cartName
        The media asset ID number for the cart you wish to target. Accepts pipeline input. Maximum four characters.
        .EXAMPLE
        Remove-MediaAsset -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001

        This is the most basic example. It will delete cart COM/1001 from the WideOrbit Central Server at '192.168.1.1'.
        .EXAMPLE
        1001,1002,1003 | Remove-MediaAsset -wo_ip 192.168.1.1 -wo_category COM

        This will delete carts "COM/1001" , "COM/1002" , and "COM/1003" from the WideOrbit Central Server at '192.168.1.1'.
        .EXAMPLE
        Remove-MediaAsset -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001 -debug -verbose
        
        This will delete cart "COM/1001" , but will also include all diagnostic messages. Useful for troubleshooting.
        .NOTES 
        Remove-MediaAsset will accept an array of cartNames as a pipeline input, but they must all be in the same category.
        .LINK
        https://github.com/areynolds77/ETM-ATL-WO
    #>
    [CmdletBinding(
    SupportsShouldProcess=$true
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
            Write-Debug -Message "Provided WideOrbit CartName: $wo_cartName"
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
        #region Define regex patterns
        $cue_pattern = "\<timer millis\=\`"(\d*)`"\>Start"
        $intro_pattern =  "\<timer millis\=\`"(\d*)`"\>Intro"
        $eom_pattern =  "\<timer millis\=\`"(\d*)`"\>EOM"       
        #endregion
    }
    Process {
        #Pad cartName
        $wo_cartName = $wo_cartName.PadLeft(4,'0')

        #Get Media Asset Information
        $wo_cartData = Get-MediaAsset -wo_ip $wo_ip -wo_category $wo_category -wo_cartName $wo_cartName
        $wo_cartXML = $wo_cartData.OuterXml
        If ($wo_cartXML -ne $null) {
            $wo_cartXML -match $cue_pattern
            $cue_value = $Matches[1]
            #If cue value is >0, then create a new XML object, strip audio < cue point, and re-import to WideOrbit
            If ($cue_value -ne '0') {
                $cue_value_s = $cue_value / 1000 #WO stores timer values in milliseconds
                $matches = @() #Reset the built-in matches array 
                
                #Capture intro timer value
                $wo_cartXML -match $intro_pattern
                $intro_value = $matches[1]
                If ($intro_value -ne '0') {
                    $new_intro_value = $intro_value - $cue_value
                }
                $matches = @()

                #Capture EOM timer value
                $wo_cartXML -match $eom_pattern
                $eom_value = $matches[1]
                $new_eom_value = $eom_value - $cue_value
                $matches = @()

                #Set replacement text values
                $new_cue_text = "<timer millis=`"0`">Start"
                $new_intro_text = "<timer millis=`"$intro_value`">Intro"
                $new_eom_text = "<timer millis=`"$eom_value`">EOM"

                #Create new XML object for media asset 
                $new_wo_cartXML = $wo_cartXML -replace $cue_pattern , $new_cue_text
                $new_wo_cartXML = $wo_cartXML -replace $intro_pattern , $new_intro_text
                $new_wo_cartXML = $wo_cartXML -replace $eom_pattern , $new_eom_text

                #Strip audio before cue point and re-import to WideOrbit
                If ($PSCmdlet.ShouldProcess(($cue_value_s + "from " + $wo_cartName),"Trimming ")) {
                    $audio_path = "\\$wo_ip\AUDIO\$wo_category\SP$wo_cartName.wav"
                    $tmp_path_pre = "D:\Working Files\$wo_category$wo_cartName(PRE).wav"
                    $tmp_path_post = "D:\Working Files\$wo_category$wo_cartName.wav"
                    $import_path = "\\$wo_ip\IMPORT\Generic\$wo_category$wo_cartName.wav"
                    copy-item -path $audio_path -Destination $tmp_path
                    Start-Sleep 5
                    $ffmpeg = "D:\Utilities\ffmpeg\bin\ffmpeg.exe"

                    $cmdline = "$ffmpeg -ss $cue_value_s -i $tmp_path -acodec copy $tmp_path_post"
                    copy-item $tmp_path_post -Destination $import_path | Out-Null
                    Invoke-Expression -command $cmdline
                    Start-Sleep 20
                }
                #Update Media Asset Metadata
                If ($PSCmdlet.ShouldProcess(($wo_cartName),"Updating Media Asset Information for ")) {
                    $uri_body = '<?xml version="1.0" encoding="utf-8" standalone="yes"?><updateMediaAssetRequest version="1">{0}</updateMediaAssetRequest>' -f $new_wo_cartXML
                    Invoke-WebRequest -Uri $wo_uri -Method Post -ContentType "text/xml" -Body $uri_body
                }
            } else { 
                Write-Output "No cue point set--ignoring file"
            }
        } else {
            Write-Output "No data returned for cart $wo_category/$wo_cartName "
        }
    }
    End {
        "Remove-Silence completed in " + $FunctionTime.elapsed | Write-Debug
    }
}

