Function Get-AllRadioStations {
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
        [string]$wo_ip
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
            $wo_uri = $wo_ip + "/ras/configuration"
        #endregion
        #region Debug Input Values
            Write-Debug -Message "Provided Input values:"
            Write-Debug -Message "Provided WideOrbit Central Server IP Address: $wo_ip"
            Write-Debug -Message "Generated clientID: $wo_clientID"
        #endregion
    }
    Process {
        Write-Debug -Message "Requesting all radio stations from WideOrbit Central Server located at $wo_ip"
        #Post Get-AllRadioStations Request
        $GRS_Body = '<?xml version="1.0" encoding="UTF-8"?><getAllRadioStationsRequest version="1"><clientId>{0}</clientId></getAllRadioStationsRequest>' -f $wo_clientID
        $GRS_Reply = [xml](Invoke-WebRequest -Uri $wo_uri -Method POST -ContentType "text/xml" -Body $GRS_Body)
        if ($GRS_Reply.getAllRadioStationsReply.status -notmatch "Success") {
            Write-Error "Request to retreive radios stations from $wo_ip has failed." -ErrorAction Stop 
        } elseif ($GRS_Reply.getAllRadioStationsReply.radioStations -eq "") {
            Write-Error "No radio stations found on $wo_ip" -ErrorAction Stop
        }
    }
    End {
        $Out = $GRS_Reply.getAllRadioStationsReply.radioStations.radioStation
        $Out
        "Get-AllRadioStations completed in " + $FunctionTime.elapsed | Write-Debug
    }
}