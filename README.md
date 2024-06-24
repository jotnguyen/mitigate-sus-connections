# Mitigate Sus Connections

A simple PowerShell script to sniff out suspicious connections.

## Running the Script

To run the `sus-connection-sniffer.ps1` script, follow these steps:

1. Open PowerShell as an administrator. This is necessary because the script interacts with network connections and processes, which require elevated permissions.
2. Set your PowerShell execution policy to a permissive value that allows script execution. You can do this by running `Set-ExecutionPolicy RemoteSigned` or `Set-ExecutionPolicy Bypass` in your PowerShell session. Be aware of the security implications of this action.
3. Navigate to the directory containing the `sus-connection-sniffer.ps1` script.
4. Execute the script by typing `.\sus-connection-sniffer.ps1` and pressing Enter.

## Description 

This PowerShell script performs the following tasks:
1. It defines the Quad9 and Google DNS server addresses as variables.
2. It defines a function called `Resolve-RemoteAddress` that attempts to resolve a provided remote IP address to a fully qualified domain name (FQDN) using Quad9 and Google DNS servers.
3. It defines a function called `Get-ResolvedConnections` that retrieves the active TCP connections in the Listen and Established states, resolves the remote address of each connection to an FQDN using the `Resolve-RemoteAddress` function, and returns a collection of custom objects representing the active TCP connections with resolved FQDN and process information.
4. It calls the `Get-ResolvedConnections` function and assigns the result to the `$resolvedConnections` variable.
5. It formats and displays the `$resolvedConnections` variable using the `Format-Table` cmdlet.
6. It generates 2-3 digit UUIDs for each connection in the `$resolvedConnections` variable and assigns the UUIDs along with the connection details to the `$connectionUUIDs` variable.
7. It displays the UUIDs, remote addresses, resolved FQDNs, and process names in a table using the `Format-Table` cmdlet.
8. It initializes an empty array called `$suspiciousConnections` and a variable called `$userInput` with a value of `$null`.
9. It enters a do-while loop that prompts the user to enter the UUID(s) of suspicious connections (separated by commas) or press Enter to continue.
10. If the user enters UUID(s), the script splits the input by commas, trims any whitespace, and adds the corresponding connections to the `$suspiciousConnections` array.
11. The loop continues until the user enters an empty string.
12. If there are any suspicious connections in the `$suspiciousConnections` array, the script displays them using the `Format-Table` cmdlet.
13. It prompts the user to confirm whether they want to remove these connections by entering 'Y' or 'N'.
14. If the user enters 'Y', the script iterates over each suspicious connection, checks if the connection still exists using the `Get-NetTCPConnection` cmdlet, and if found, disposes of the connection using the `Dispose()` method. It also displays a message indicating whether the connection was successfully disposed or not.

## TODOs

- **Handle No Resolved FQDN**: Modify the script to display `---` instead of the remote address if the FQDN cannot be resolved. This will make the output clearer in cases where DNS resolution fails.
- **Enhance Robustness for Unresolvable Addresses**: Implement additional error handling or alternative resolution methods to improve the script's ability to resolve addresses to FQDNs, even in challenging network environments.
- **Logging Enhancements**: Add functionality to log errors or unresolved addresses to a separate file for further analysis. This can help in diagnosing why certain addresses cannot be resolved and improve the script's overall robustness.

## License

This project is licensed under the MIT License. This means you are free to use, modify, and distribute this software, even for commercial purposes, provided you include the original copyright and permission notice in any copies or substantial portions of the software.

For more details, see the LICENSE file in this repository.