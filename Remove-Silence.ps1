Function Remove-CueAudio {
    <#
        .SYNOPSIS
        The Remove-CueAudio function is used to remove any audio before a Cue marker in a media asset.
        .DESCRIPTION
        Remove-CueAudio is used to remove audio before cue markers in WideOrbit media asset files. This function will query a WO Central Server for information about
        a specified media asset, and then check to see if there is a cue marker specified. If there is a cue marker, the function will copy the media asset to a temporary
        folder and use ffmpeg to remove any audio before the cue marker. The file will then be re-imported into WideOrbit, after which the function update the media asset
        metadata with the correct timer markers. 
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER wo_category
        The name of the media asset's category. Should be exactly three characters.
        .PARAMETER wo_cartName
        The media asset ID number for the cart you wish to target. Accepts pipeline input. Maximum four characters.
        .PARAMETER wo_tmp_folder
        The directory to use for storing audio files while they are being processed. 
        .PARAMETER wo_import_folder
        The directory to use for re-importing audio files. See the notes for configuring the appropriate AMAI rule.
        .PARAMETER ffmpeg_exe
        The path to the ffmpeg executable.
        .EXAMPLE
        Remove-CueAudio -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001 -wo_tmp_folder D:\TMP_FILES -wo_import_folder D:\IMPORT -ffmpeg "D:\ffmpeg\bin\ffmpeg.exe" -WhatIf
        
        This will check all carts between COM/1000 and COM/2000 for cue markers. It will output which files would be modified, but will NOT make any changes.

        Run this first. :)
        .EXAMPLE
        Remove-CueAudio -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001 -wo_tmp_folder D:\TMP_FILES -wo_import_folder D:\IMPORT -ffmpeg "D:\ffmpeg\bin\ffmpeg.exe"

        This is the most basic example. It will check COM/1001 to see if there is a cue marker present. If there is, any audio before the cue marker will be removed, and the file re-imported.
        .EXAMPLE
        1001,1002,1003 | Remove-CueAudio -wo_ip 192.168.1.1 -wo_category COM -wo_tmp_folder D:\TMP_FILES -wo_import_folder D:\IMPORT -ffmpeg "D:\ffmpeg\bin\ffmpeg.exe"

        This will check carts "COM/1001" , "COM/1002" , and "COM/1003" for cue markers. If there is a cue marker, any audio before the cue marker will be removed, and the file re-imported.
        .EXAMPLE
        1000..2000 | Remove-CueAudio -wo_ip 192.168.1.1 -wo_category COM -wo_tmp_folder D:\TMP_FILES -wo_import_folder D:\IMPORT -ffmpeg "D:\ffmpeg\bin\ffmpeg.exe"
        
        This will check all carts between COM/1000 and COM/2000 for cue markers. If there is a cue marker, any audio before the cue marker will be removed, and the file re-imported.
        .EXAMPLE
        Remove-CueAudio -wo_ip 192.168.1.1 -wo_category COM -wo_cartName 1001 -wo_tmp_folder D:\TMP_FILES -wo_import_folder D:\IMPORT -ffmpeg "D:\ffmpeg\bin\ffmpeg.exe" -debug
        
        This is the most basic example. It will check COM/1001 to see if there is a cue marker present. If there is, any audio before the cue marker will be removed, and the file re-imported.

        It will also enable debugging log messages. Useful for troubleshooting.
        .NOTES 
        This script must be run on a computer that has access to the AUDIO and IMPORT directories of the specified WideOrbit Central Server.

        The specified Import directory must have the following rule configured:
        "If File Name Is valid Media Asset number" then "Send to $stations" 
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
        [string]$wo_cartName,
        [Parameter(
            Position = 3,
            Mandatory = $true,
            HelpMessage = "The directory to use for storing audio files while they are being processed."
        )]
        [ValidateScript({Test-Path $_ -pathType Container})]
        [string]$wo_tmp_folder,
        [Parameter(
            Position = 4,
            Mandatory = $true,
            HelpMessage = "The directory to use for re-importing audio files. See the notes for configuring the appropriate AMAI rule."
        )]
        [ValidateScript({Test-Path $_ -pathType Container})]        
        [string]$wo_import_folder,
        [Parameter(
            Position = 5,
            Mandatory = $true,
            HelpMessage = "The path to the ffmpeg executable."
        )]
    [ValidateScript({Test-Path $_ -PathType leaf })]        
        [string]$ffmpeg_exe
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
            $wo_cartXML -match $cue_pattern | Out-Null
            $cue_value = $Matches[1]
            #If cue value is >0, then create a new XML object, strip audio < cue point, and re-import to WideOrbit
            If ($cue_value -ne '0') {
                $cue_value_s = $cue_value / 1000 #WO stores timer values in milliseconds
                $matches = @() #Reset the built-in matches array 
                
                #Capture intro timer value
                    $wo_cartXML -match $intro_pattern | Out-Null
                    $intro_value = $matches[1]
                    If ($intro_value -ne '0') {
                        $new_intro_value = $intro_value - $cue_value
                    }
                    $matches = @()

                #Capture EOM timer value
                    $wo_cartXML -match $eom_pattern | Out-Null
                    $eom_value = $matches[1]
                    $new_eom_value = $eom_value - $cue_value
                    $matches = @()

                #Set replacement text values
                    $new_cue_text = "<timer millis=`"0`">Start"
                    $new_intro_text = "<timer millis=`"$new_intro_value`">Intro"
                    $new_eom_text = "<timer millis=`"$new_eom_value`">EOM"

                #Create new XML object for media asset 
                    $new_wo_cartXML = $wo_cartXML
                    $new_wo_cartXML = $new_wo_cartXML -replace $cue_pattern , $new_cue_text
                    $new_wo_cartXML = $new_wo_cartXML -replace $intro_pattern , $new_intro_text
                    $new_wo_cartXML = $new_wo_cartXML -replace $eom_pattern , $new_eom_text

                #Debug Values
                    Write-Debug "Current Cue Value(ms): $cue_value"
                    Write-Debug "Current Intro Value (ms): $intro_value"
                    Write-Debug "New Intro Value (ms): $new_intro_value"
                    Write-Debug "Current EOM Value (ms): $eom_value"
                    Write-Debug "New EOM Value (ms): $new_eom_value"
                    Write-Debug ""
                    Write-Debug ""
                    Write-Debug "Old XML Metadata: "
                    Write-Debug $wo_cartXML.ToString()
                    Write-Debug ""
                    Write-Debug ""
                    Write-Debug "Updated XML Metadata: "
                    Write-Debug $new_wo_cartXML.ToString()


                #Strip audio before cue point and re-import to WideOrbit
                If ($PSCmdlet.ShouldProcess(($wo_category + "/" + $wo_cartName),"Trimming $cue_value_s seconds of audio ")) {
                    #Set File Paths
                        $audio_path = "\\$wo_ip\AUDIO\$wo_category\SP$wo_cartName.wav"
                        $tmp_path_pre = "$wo_tmp_folder\$wo_category$wo_cartName PRE.wav"
                        $tmp_path_post = "$wo_tmp_folder\$wo_category$wo_cartName.wav"
                        $import_path = "$wo_import_folder\$wo_category$wo_cartName.wav"
                    #Copy audio file to temp folder and strip audio < cue point
                        copy-item -path $audio_path -Destination $tmp_path_pre -Confirm:$false  | Out-Null
                        Write-Output "Copying $wo_category/$wo_cartName to working directory $wo_tmp_folder"
                        #Start-Sleep 5
                        Write-Output "Removing $cue_value_s seconds of audio from the beginning of $wo_category/$wo_cartName" 
                        $cmdline = "$ffmpeg_exe -ss $cue_value_s -i `"$tmp_path_pre`" -acodec copy `"$tmp_path_post`""
                        Invoke-Expression -command $cmdline 2>&1 | out-null
                        Write-Output "Copying $wo_category/$wo_cartName to import directory $import_path"
                        move-item $tmp_path_post -Destination $import_path -Confirm:$false | Out-Null
                        Write-Output "Waiting on WideOrbit to import file"
                        Start-Sleep 20 #Wait for file copy to complete before updating metadata
                }
                #Update Media Asset Metadata
                If ($PSCmdlet.ShouldProcess(($wo_category + "/" + $wo_cartName),"Updating Media Asset Information ")) {
                    $uri_body = '<?xml version="1.0" encoding="utf-8" standalone="yes"?><updateMediaAssetRequest version="1">{0}</updateMediaAssetRequest>' -f $new_wo_cartXML
                    Write-Output "Updating metadata for $wo_category/$wo_cartName"
                    Invoke-WebRequest -Uri $wo_uri -Method Post -ContentType "text/xml" -Body $uri_body -OutVariable webrequest 2>&1 | out-null
                    
                }
            } else { 
                Write-Output "No cue point set--ignoring file $wo_category/$wo_cartName"
            }
        } else {
            Write-Output "No data returned for cart $wo_category/$wo_cartName "
        }
    }
    End {
        "Remove-Silence completed in " + $FunctionTime.elapsed | Write-Debug
    }
}

