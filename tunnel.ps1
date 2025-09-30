# --- Script Parameters Definition ---
# Defines the commands and arguments by their position.
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("add", "remove", "list", "remote")]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$Arg1,

    [Parameter(Position=2)]
    [string]$Arg2
)

# --- Configuration File Handling ---
$configFile = Join-Path $PSScriptRoot "tunnel_config.json"

# If config file doesn't exist, create it with a default value.
if (-not (Test-Path $configFile)) {
    $defaultConfig = @{
        remoteServer = "user@myserver.com"
    }
    $defaultConfig | ConvertTo-Json | Set-Content -Path $configFile
}

# Load the configuration from the JSON file.
$config = Get-Content -Path $configFile | ConvertFrom-Json
# ------------------------------------

# --- Command Processing ---
switch ($Command) {
    "remote" {
        if (-not $Arg1) {
            Write-Host "ERROR: A remote path (e.g., user@host) is required." -ForegroundColor Red
            break
        }
        $config.remoteServer = $Arg1
        $config | ConvertTo-Json | Set-Content -Path $configFile
        Write-Host "OK: Remote SSH path set to '$($config.remoteServer)'." -ForegroundColor Green
    }

    "add" {
        $remotePort = $Arg1
        $localPort = $Arg2
        if (-not $remotePort) {
            Write-Host "ERROR: A remote port is required." -ForegroundColor Red
            break
        }
        # If localPort isn't specified, default it to be the same as remotePort.
        if (-not $localPort) {
            $localPort = $remotePort
        }
        $sshArgs = "-fN -R $($remotePort):localhost:$($localPort) $($config.remoteServer)"
        Write-Host "Starting tunnel: Port $($remotePort) on $($config.remoteServer) -> localhost:$($localPort)"
        Start-Process ssh.exe -ArgumentList $sshArgs -NoNewWindow
        Write-Host "OK: Tunnel started in the background." -ForegroundColor Green
    }

    "remove" {
        $remotePort = $Arg1
        if (-not $remotePort) {
            Write-Host "ERROR: A remote port to stop is required." -ForegroundColor Red
            break
        }
        # Find the process by its command line arguments
        $process = Get-CimInstance Win32_Process -Filter "name = 'ssh.exe' AND CommandLine LIKE '%-R $($remotePort):%' AND CommandLine LIKE '%$($config.remoteServer)%'"
        if ($process) {
            Write-Host "Stopping tunnel for port $($remotePort) (PID: $($process.ProcessId))..."
            Stop-Process -Id $process.ProcessId -Force
            Write-Host "OK: Tunnel stopped." -ForegroundColor Green
        } else {
            Write-Host "INFO: No active tunnel found for port $($remotePort)." -ForegroundColor Yellow
        }
    }

    "list" {
        Write-Host "--- Active Tunnels for '$($config.remoteServer)' ---"
        Get-CimInstance Win32_Process -Filter "name = 'ssh.exe' AND CommandLine LIKE '%-R %' AND CommandLine LIKE '%$($config.remoteServer)%'" | Select-Object ProcessId, CommandLine
        Write-Host "----------------------------------------------------"
    }
    
    default {
        Write-Host "Invalid command. Usage: `n"
        Write-Host "  .\tunnel.ps1 remote [user@host]"
        Write-Host "  .\tunnel.ps1 add [remote_port] [local_port_optional]"
        Write-Host "  .\tunnel.ps1 remove [remote_port]"
        Write-Host "  .\tunnel.ps1 list"
    }
}
