# Define Quad9 and Google DNS server addresses
$DebugPreference = "Continue"
$quad9IPv4 = "149.112.112.112"
$quad9IPv6 = "2620:fe::9"
$googleIPv4 = "8.8.8.8"

function Resolve-RemoteAddress {
    <#
    .SYNOPSIS
    Resolves the provided remote IP address to a fully qualified domain name (FQDN) using Quad9 and Google DNS servers.

    .DESCRIPTION
    The Resolve-RemoteAddress function attempts to resolve the provided remote IP address to an FQDN using the Quad9 DNS server. If the resolution fails, it tries using the Google DNS server. If both attempts fail, it returns the original IP address.

    .PARAMETER RemoteAddress
    The IP address to resolve.

    .PARAMETER Quad9IPv4
    The IPv4 address of the Quad9 DNS server (default: 149.112.112.112).

    .PARAMETER Quad9IPv6
    The IPv6 address of the Quad9 DNS server (default: 2620:fe::9).

    .PARAMETER GoogleIPv4
    The IPv4 address of the Google DNS server (default: 8.8.8.8).

    .OUTPUTS
    System.String. The resolved FQDN or the original IP address if the resolution fails.

    .EXAMPLE
    Resolve-RemoteAddress -RemoteAddress "8.8.8.8"
    Resolves the IP address "8.8.8.8" to an FQDN.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteAddress,
        [string]$Quad9IPv4 = "149.112.112.112",
        [string]$Quad9IPv6 = "2620:fe::9",
        [string]$GoogleIPv4 = "8.8.8.8"
    )

    try {
        # Use Quad9 DNS server to resolve FQDN
        Write-Debug "Attempting to resolve $RemoteAddress using Quad9 DNS server ($Quad9IPv4)"
        $resolvedFQDN = (Resolve-DnsName -Name $RemoteAddress -Server $Quad9IPv4 -ErrorAction Stop).NameHost
        Write-Debug "Resolved $RemoteAddress to $resolvedFQDN using Quad9 DNS server"
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Debug "Failed to resolve $RemoteAddress using Quad9 DNS server ($Quad9IPv4). $errorMessage"
        try {
            Write-Debug "Trying to resolve $RemoteAddress using Google DNS server ($GoogleIPv4)"
            $resolvedFQDN = (Resolve-DnsName -Name $RemoteAddress -Server $GoogleIPv4 -ErrorAction Stop).NameHost
            Write-Debug "Resolved $RemoteAddress to $resolvedFQDN using Google DNS server"
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Debug "Failed to resolve $RemoteAddress using Google DNS server ($GoogleIPv4). $errorMessage"
            Write-Debug "Using IP address instead."
            $resolvedFQDN = $RemoteAddress
        }
    }

    return $resolvedFQDN
}

function Get-ResolvedConnections {
    <#
    .SYNOPSIS
    Gets the active TCP connections with resolved FQDN.

    .DESCRIPTION
    The Get-ResolvedConnections function retrieves the active TCP connections in the Listen and Established states. It then resolves the remote address of each connection to an FQDN using the Resolve-RemoteAddress function. The function returns a collection of custom objects containing connection details, including the resolved FQDN and the process name associated with the connection.

    .OUTPUTS
    System.Management.Automation.PSCustomObject. A collection of custom objects representing the active TCP connections with resolved FQDN and process information.

    .EXAMPLE
    Get-ResolvedConnections
    Retrieves the active TCP connections with resolved FQDN and process information.
    #>
    $connections = Get-NetTCPConnection -State Listen, Established

    $resolvedConnections = $connections | ForEach-Object {
        $remoteAddress = $_.RemoteAddress
        $localPort = $_.LocalPort
        $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $processName = $process.ProcessName

        if ($remoteAddress) {
            $resolvedFQDN = Resolve-RemoteAddress -RemoteAddress $remoteAddress
            [PSCustomObject]@{
                LocalAddress  = $_.LocalAddress
                LocalPort     = $localPort
                RemoteAddress = $remoteAddress
                RemotePort    = $_.RemotePort
                State         = $_.State
                ResolvedFQDN  = $resolvedFQDN
                ProcessName   = $processName
            }
        }
    }
    
    # Output to log
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $resolvedConnections | Export-Csv -Path "network_connections_$timestamp.csv" -NoTypeInformation

    return $resolvedConnections
}

$resolvedConnections = Get-ResolvedConnections
$resolvedConnections | Format-Table

# Generate 2-3 digit UUIDs for each connection
$connectionUUIDs = $resolvedConnections | ForEach-Object {
    $uuid = (New-Guid).Guid.Substring(0, 3)
    [PSCustomObject]@{
        UUID       = $uuid
        Connection = $_
    }
}

# Display UUIDs in a table
Write-Host "Connection UUIDs:"
$connectionUUIDs | Select-Object UUID, @{Name='RemoteAddress';Expression={$_.Connection.RemoteAddress}}, @{Name='ResolvedFQDN';Expression={$_.Connection.ResolvedFQDN}}, @{Name='ProcessName';Expression={$_.Connection.ProcessName}} | Format-Table

$suspiciousConnections = @()
$userInput = $null

do {
    Write-Host "Enter the UUID(s) of suspicious connections (separated by commas), or press Enter to continue:"
    $userInput = Read-Host

    if ($userInput) {
        $uuids = $userInput.Split(',').Trim()
        $suspiciousConnections += $connectionUUIDs | Where-Object { $uuids -contains $_.UUID } | Select-Object -ExpandProperty Connection
    }
} until ($userInput -eq '')

if ($suspiciousConnections.Count -gt 0) {
    Write-Host "Suspicious connections:"
    $suspiciousConnections | Format-Table

    Write-Host "Do you want to remove these connections? (Y/N)"
    $response = Read-Host

    if ($response.ToLower() -eq 'y') {
        foreach ($conn in $suspiciousConnections) {
             $connection = Get-NetTCPConnection -RemoteAddress $conn.RemoteAddress -RemotePort $conn.RemotePort
             if ($connection) {
                 $connection.Dispose()
                 Write-Host "Disposed connection to $($conn.RemoteAddress):$($conn.RemotePort)"
             } else {
                 Write-Host "Connection to $($conn.RemoteAddress):$($conn.RemotePort) not found."
             }
        }
    }
}

