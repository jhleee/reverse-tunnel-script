#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
# -------------------------

# --- Configuration File Handling ---
CONFIG_FILE="$(dirname "$0")/tunnel_config.json"

# If config file doesn't exist, create it with a default value.
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"remoteServer": "user@myserver.com"}' > "$CONFIG_FILE"
fi

# Load the configuration from the JSON file.
# Note: This simple grep is for avoiding dependencies like 'jq'.
remoteServer=$(grep -oP '"remoteServer":\s*"\K[^"]+' "$CONFIG_FILE")
# ------------------------------------

# --- Command Processing ---
COMMAND=$1
ARG1=$2
ARG2=$3

case "$COMMAND" in
    "remote")
        if [ -z "$ARG1" ]; then
            echo -e "${RED}ERROR: A remote path (e.g., user@host) is required.${NC}" >&2
            exit 1
        fi
        # Overwrite the config file with the new remote server.
        echo "{\"remoteServer\": \"$ARG1\"}" > "$CONFIG_FILE"
        echo -e "${GREEN}OK: Remote SSH path set to '$ARG1'.${NC}"
        ;;

    "add")
        remotePort=$ARG1
        localPort=$ARG2
        if [ -z "$remotePort" ]; then
            echo -e "${RED}ERROR: A remote port is required.${NC}" >&2
            exit 1
        fi
        # If localPort isn't specified, default it to be the same as remotePort.
        if [ -z "$localPort" ]; then
            localPort=$remotePort
        fi
        
        echo "Starting tunnel: Port $remotePort on $remoteServer -> localhost:$localPort"
        ssh -fN -R "$remotePort:localhost:$localPort" "$remoteServer"
        echo -e "${GREEN}OK: Tunnel started in the background.${NC}"
        ;;

    "remove")
        remotePort=$ARG1
        if [ -z "$remotePort" ]; then
            echo -e "${RED}ERROR: A remote port to stop is required.${NC}" >&2
            exit 1
        fi

        # Find the process ID (PID)
        PID=$(ps aux | grep "ssh -fN -R $remotePort:localhost:" | grep "$remoteServer" | grep -v grep | awk '{print $2}')

        if [ -z "$PID" ]; then
            echo -e "${YELLOW}INFO: No active tunnel found for port $remotePort.${NC}"
        else
            echo "Stopping tunnel for port $remotePort (PID: $PID)..."
            kill $PID
            echo -e "${GREEN}OK: Tunnel stopped.${NC}"
        fi
        ;;

    "list")
        echo -e "${YELLOW}--- Active Tunnels for '$remoteServer' ---${NC}"
        # Store the output of ps to check if it's empty
        tunnel_list=$(ps aux | grep "ssh -fN -R" | grep "$remoteServer" | grep -v grep)
        if [ -z "$tunnel_list" ]; then
            echo -e "${YELLOW}No active tunnels found.${NC}"
        else
            echo "$tunnel_list"
        fi
        echo -e "${YELLOW}----------------------------------------------------${NC}"
        ;;
    
    *)
        echo "Invalid command. Usage:"
        echo "  $0 remote [user@host]"
        echo "  $0 add [remote_port] [local_port_optional]"
        echo "  $0 remove [remote_port]"
        echo "  $0 list"
        exit 1
        ;;
esac

exit 0
