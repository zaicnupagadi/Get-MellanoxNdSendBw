function Get-MellanoxNdSendBw {
    param (
        [String]$ClusterName
    )

    $RptCollection = @()
    $ClusterNodes = (Get-Cluster -Name $ClusterName | Get-ClusterNode)
    ForEach ($ClusterNode in $ClusterNodes) {
 
        $RDMAInterfaces = (Invoke-Command -ComputerName $ClusterNode.name -ScriptBlock {Get-NetAdapterrdma | ? {$_.Enabled -match "true"}|Get-NetAdapter | Get-NetIPAddress | ? {$_.IPAddress -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"} })
 
        ForEach ($RDMAInterface in $RDMAInterfaces) {
 
            $rptObj = New-Object PSObject
            $rptObj| Add-Member NoteProperty -Name "ClusterNodeName" -value $ClusterNode.name
            $rptObj| Add-Member NoteProperty -Name "Interface" -value $RDMAInterface.ipaddress
            $RptCollection += $rptObj
        }
    }
 
    ForEach ($a in $RptCollection) {
        Write-host "SERVER"
        $a.ClusterNodeName
        Write-host "CLIENTS"
        $Clients = $RptCollection.ClusterNodeName | select -uniq
        ForEach ($b in $Clients) {
            if ($b -ne $a.ClusterNodeName) {
                #Write-host $a.ClusterNodeName $b $a.Interface
                $CurrentServer = $a.ClusterNodeName
                $CurrentClient = $b
                $IP = $a.Interface
                $server = (Invoke-Command -ComputerName $CurrentServer -ScriptBlock { & 'c:\program files\mellanox\mlnx_VPI\IB\TOOLS\nd_send_bw.exe' -S $using:IP} -AsJob)
                $client = (Invoke-Command -ComputerName $CurrentClient -ScriptBlock { & 'c:\program files\mellanox\mlnx_VPI\IB\TOOLS\nd_send_bw.exe' -C $using:IP} -AsJob)
                while ($server.state -notmatch "Completed") {
                    start-sleep 5
                }
                $output = Receive-Job $client.name -ErrorVariable RemoteErr -Wait:$true
                [string]$ConnStatus = [string]$RemoteErr + [string]$output
                if ($ConnStatus -notmatch "c00000b5") {
                    Write-Host "Connection $CurrentServer to $CurrentClient on NIC $IP is OK"
                }
                else {
                    Write-Host "Connection $CurrentServer to $CurrentClient on NIC $IP is BROKEN."
                }
            }
        }
        write-host "###"
    }
}