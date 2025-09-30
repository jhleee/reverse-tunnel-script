#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
# -------------------------

# --- SUDO Check ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}Warning: This script requires root privileges to see all processes.${NC}"
    echo -e "${YELLOW}Please run with: sudo $0 $*${NC}"
    exit 1
fi
# --------------------

# --- Usage Guide ---
usage() {
    echo "Usage: $0 {list|kick|log}"
    echo
    echo "Commands:"
    echo "  list               - Shows all active reverse tunnels from connected users."
    echo "  kick user <user>   - Kicks all sessions for a specific user."
    echo "  kick port <port>   - Kicks the session forwarding a specific port."
    echo "  log                - Shows recent SSH login/logout activity."
    exit 1
}

# --- Main Logic ---
COMMAND=$1
ARG1=$2
ARG2=$3

case "$COMMAND" in
    "list")
        echo -e "${YELLOW}--- Active SSH Reverse Tunnels ---${NC}"
        
        # [수정됨] sshd 프로세스가 리스닝하는 포트 중, 22번 포트를 제외하고 검색
        # grep -vE ':22($|\s)' : ':22'로 끝나거나 뒤에 공백이 오는 라인을 제외 (IPv4, IPv6 모두 처리)
        ss_output=$(ss -ltnp | grep 'users:(("sshd"' | grep -vE ':22($|\s)')

        if [ -z "$ss_output" ]; then
            echo -e "${YELLOW}No active SSH tunnels found.${NC}"
        else
            echo -e "${CYAN}USER            PORT                    PID${NC}"
            echo "-------------------------------------------"
            while IFS= read -r line; do
                listen_addr=$(echo "$line" | awk '{print $4}')
                pid=$(echo "$line" | grep -oP 'pid=\K[0-9]+')
                
                if [ -n "$pid" ]; then
                    user=$(ps -o user= -p "$pid")
                    printf "%-15s %-23s %-10s\n" "$user" "$listen_addr" "$pid"
                fi
            done <<< "$ss_output"
        fi
        echo "-------------------------------------------"
        ;;

    "kick")
        # ... (kick, log 명령어는 이전과 동일하게 유지)
        if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
            usage
        fi

        if [ "$ARG1" == "user" ]; then
            USER_TO_KICK=$ARG2
            echo "Kicking all sessions for user '$USER_TO_KICK'..."
            pids_to_kill=$(pgrep -u "$USER_TO_KICK" sshd)
            if [ -z "$pids_to_kill" ]; then
                echo -e "${YELLOW}No active sessions found for user '$USER_TO_KICK'.${NC}"
            else
                kill -9 $pids_to_kill
                echo -e "${GREEN}OK: All sessions for '$USER_TO_KICK' have been terminated.${NC}"
            fi
        
        elif [ "$ARG1" == "port" ]; then
            PORT_TO_KICK=$ARG2
            echo "Kicking session on port '$PORT_TO_KICK'..."
            pid_to_kill=$(ss -ltnp "sport == $PORT_TO_KICK" | grep 'users:(("sshd"' | grep -oP 'pid=\K[0-9]+')
            if [ -z "$pid_to_kill" ]; then
                echo -e "${YELLOW}No sshd process found listening on port '$PORT_TO_KICK'.${NC}"
            else
                kill -9 "$pid_to_kill"
                echo -e "${GREEN}OK: Process with PID $pid_to_kill on port $PORT_TO_KICK has been terminated.${NC}"
            fi
        else
            usage
        fi
        ;;

    "log")
        echo -e "${YELLOW}--- Recent SSH Activity (last 50 lines) ---${NC}"
        if [ -f /var/log/auth.log ]; then
            LOG_FILE="/var/log/auth.log"
        elif [ -f /var/log/secure ]; then
            LOG_FILE="/var/log/secure"
        else
            echo -e "${RED}ERROR: Cannot find auth.log or secure log file.${NC}"
            exit 1
        fi
        tail -n 50 "$LOG_FILE" | grep -E 'sshd.*(Accepted|Disconnected|Failed)'
        echo -e "${YELLOW}---------------------------------------------${NC}"
        ;;

    *)
        usage
        ;;
esac

exit 0
