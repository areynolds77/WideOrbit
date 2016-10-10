Function Remove-MediaAsset {
    <#
        .SYNOPSIS
        The Remove-MediaAsset function is used to delete a provided media asset.
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
    }
    Process {
        #Pad cartName
        $wo_cartName = $wo_cartName.PadLeft(4,'0')
        #Post Remove-MediaAssetRequest
        $DeleteMediaAssetBody = @()
        $DeleteMediaAssetBody = '<?xml version="1.0" encoding="utf-8"?><deleteMediaAssetRequest version="1"><clientId>{0}</clientId><category>{1}</category><cartName>{2}</cartName></deleteMediaAssetRequest>' -f $wo_clientID,$wo_category,$wo_cartName
        $URI_DeleteMediaAsset = $wo_ip + "/ras/inventory"
        $DeleteCartMessage = "DELETING CART: " + $wo_category + "/" + $wo_cartName 
        Write-Output $DeleteCartMessage
        Write-Debug -Message "Delete Media Asset Body HTTP Request: '$DeleteMediaAssetBody"
        $DeleteMediaAssetRet = Invoke-WebRequest -Uri $URI_DeleteMediaAsset -Method Post -ContentType "text/xml" -Body $DeleteMediaAssetBody
        $DeleteMediaAssetRet | Write-Debug
        $DMA = [xml]($DeleteMediaAssetRet.Content)
        if ($DMA.deleteMediaAssetReply.status -notmatch "Success") {
            $DMA_ERROR = $DMA.deleteMediaAssetReply.description
            Write-Output "ERROR: Request to delete Media Asset $wo_category\$wo_cartName has failed. Reason: $DMA_ERROR"
        }
    }
    End {
        "Remove-MediaAsset completed in " + $FunctionTime.elapsed | Write-Debug
    }
}
