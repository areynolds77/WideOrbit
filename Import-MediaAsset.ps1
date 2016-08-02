Function Import-MediaAsset {
    <#
        .SYNOPSIS
        The Get-AllRadioStations function is used to obatin information about radio stations hosted on WideOrbit Central Server.
        .DESCRIPTION
        Get-AllRadioStations returns information about any radio stations hosted on a WideOrbit Central Server. If the -detailed flag is enabled, 
        the function will also return information about each category assigned to that workstation (and each categories individual properties), 
        as well as a list of workstations assigned to that radio station. If the -export flag is enabled, this data will be exported to a series of csv datafiles.
        .PARAMETER wo_ip 
        The IP address of your WideOrbit Central server
        .PARAMETER detailed
        Setting this flag will return a list of categories and workstations assigned to each radio station.
        .PARAMETER export
        Setting this flag will export a series of csv files containing information about the categories and workstations for each radio station.
        .EXAMPLE
        Get-AllRadiostations -wo_ip 192.168.1.1

        This is the most basic example. It will query the WideOrbit Central server with an IP of 192.168.1.1 for information about each radio station it hosts.
        .EXAMPLE
        Get-AllRadiostations -wo_ip 192.168.1.1 -detailed

        This will query the WideOrbit Central server for information about all hosted radio stations, and output tables listing each radio stations categories 
        (and their associated properties), as well each workstation assigned to the station.
        .EXAMPLE
        Get-AllRadioStation -wo_ip 192.168.1.1 -export -export_dir C:\Powershell
        
        This will export all information from the above example to a series of csv files located at 'C:\Powershell'
        .NOTES 
        
        .LINK
        https://github.com/areynolds77/ETM-ATL-WO
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'None'
    )]
    # Parameter help description
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            HelpMessage = "IP address of the WideOrbit Central Server you wish to target. FQDNs or hostnames are not supported."
        )]
        [ValidateScript({$_ -match [IPAddress]$_})]
        [string]$wo_ip,
        [Parameter(
            ParameterSetName = 'Export',
            Position = 1,
            Mandatory = $true,
            HelpMessage = "If exporting datafiles, enter a folder path to export to."
        )]
        [string]$export_dir,
        [Parameter(
            ParameterSetName = 'Export',
            HelpMessage = "Enable this if you wish to export csv files listing the categories and workstations for each radio station."
        )]
        [switch]$export,
        [Parameter(
            HelpMessage = "Enable this if you wish to view the categories and workstations for each workstation."
        )]
        [switch]$detailed
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
            $wo_uri = $wo_ip + "/ras/configuration"
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided Input values:"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Generated clientID: $wo_clientID"
            Write-Debug -Message "Detailed view enabled: $detailed"
            Write-Debug -Message "Export mode enabled: $export"
            Write-Debug -Message "Export directory: $export_dir"
        #endregion
    }
    Process {
        #Pad cartName
        Write-Debug -Message "Requesting all radio stations from WideOrbit Central Server located at $wo_ip"
        #Post Get-AllRadioStations Request
        $GRS_Body = '<?xml version="1.0" encoding="UTF-8"?><getAllRadioStationsRequest version="1"><clientId>{0}</clientId></getAllRadioStationsRequest>' -f $wo_clientID
        $GRS_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $GRS_Body)
        if ($GRS_Reply.getAllRadioStationsReply.status -notmatch "Success") {
            Write-Warning "Request to retreive radios stations from $wo_ip has failed." 
        } elseif ($GRS_Reply.getAllRadioStationsReply.radioStations -eq "") {
            Write-Output "No radio stations found on $wo_ip"
        } elseif ($GRS_Reply.getAllRadioStationsReply.radioStations.radioStation.stationName.Count -eq 1 ) {
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name RadioStation -Value $GRS_Reply.getAllRadioStationsReply.radioStations.radioStation
            $station_name = $Output.radioStation.stationName
                Write-Debug -Message "StationName: $station_name"
                Write-Debug -Message "Generating categories object"
                $categories = $Output.radioStation.categories.category
                Write-Debug -Message "Generating workstations object"
                $workstations = $Output.radioStation.workstations.workstation
                if ($detailed -eq $true) {
                     Write-Output "Categories assigned to $station_name"
                     $categories | Format-Table -AutoSize
                     Write-Output "Workstations assigned to $station_name"
                     $workstations | Format-Table -AutoSize
                }
                if ($export -eq $true) {
                    Write-Debug -Message "Exporting category & workstation datafiles..."
                    $categories | Export-Csv -Path "$export_dir\$station_name--Categories.csv" -NoTypeInformation
                    $workstations | Export-Csv -Path "$export_dir\$station_name--Workstations.csv"
                }
        } else {
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name RadioStation -Value $GRS_Reply.getAllRadioStationsReply.radioStations.radioStation
            "RadioStation Count: " + $Output.radioStation.Count | Write-Debug
            For ($i=0; $i -lt ($Output.radioStation.Count); $i++) {
                Write-Debug -Message "Loop Count: $i"
                $station_name = $Output.radioStation[$i].stationName
                Write-Debug -Message "StationName: $station_name"
                Write-Debug -Message "Generating categories object"
                $categories = $Output.radioStation[$i].categories.category
                Write-Debug -Message "Generating workstations object"
                $workstations = $Output.radioStation[$i].workstations.workstation
                if ($detailed -eq $true) {
                     Write-Output "Categories assigned to $station_name"
                     $categories | Format-Table -AutoSize  #Out-GridView -Title "$station_name Categories"
                     Write-Output "Workstations assigned to $station_name"
                     $workstations | Format-Table -AutoSize #Out-GridView -Title "$station_name Workstations"
                }
                if ($export -eq $true) {
                    Write-Debug -Message "Exporting category & workstation datafiles..."
                    $categories | Export-Csv -Path "$export_dir\$station_name--Categories.csv" -NoTypeInformation
                    $workstations | Export-Csv -Path "$export_dir\$station_name--Workstations.csv"
                }
            } 
        }
    }
    End {
        "Get-AllRadioStations completed in " + $FunctionTime.elapsed | Write-Debug
        If ($detailed -eq $false) {
            $Output.radioStation | Format-Table 
        }
    }
}

Get-AllRadioStations -wo_ip 172.21.44.14 -detailed