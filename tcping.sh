#!/bin/bash

# Display usage information
usage() {
    echo "Usage: $0 [-t timeout] [-i interval] [-c count] <host> [port]"
    echo "Example: $0 -t 1 -i 0.5 -c 5 example.com 80"
    exit 1
}

# Initialize default parameters
timeout=1
interval=1
count=0
host=""
port="80"  # Default port 80

# Parse command-line arguments
while getopts ":t:i:c:" opt; do
    case $opt in
        t)
            if ! [[ "$OPTARG" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
               [ "$(echo "$OPTARG <= 0" | bc -l)" -eq 1 ]; then
                echo "Error: Timeout must be a positive number."
                usage
            fi
            timeout=$OPTARG
            ;;
        i)
            if ! [[ "$OPTARG" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
               [ "$(echo "$OPTARG <= 0" | bc -l)" -eq 1 ]; then
                echo "Error: Interval must be a positive number."
                usage
            fi
            interval=$OPTARG
            ;;
        c)
            if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                echo "Error: Count must be a non-negative integer."
                usage
            fi
            count=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Get host and optional port
host=$1
if [ -n "$2" ]; then
    port=$2
fi

# Validate host and port parameters
if [ -z "$host" ]; then
    echo "Error: Host must be specified."
    usage
fi

if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Error: Port must be an integer between 1 and 65535."
    exit 1
fi

# Counters
total=0
success=0
fail=0

# Capture Ctrl+C signal
trap 'echo -e "\nTCP Ping Results: Connections (Total/Pass/Fail): [$total/$success/$fail] (Failed: $((fail * 100 / total))%)"; exit 0' SIGINT

# Main loop
current=0
while [ "$count" -eq 0 ] || [ "$current" -lt "$count" ]; do
    current=$((current + 1))
    start_time=$(date +%s%N)
    if timeout "$timeout" bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
        end_time=$(date +%s%N)
        latency_ms=$(( (end_time - start_time) / 1000000 ))
        echo "Connected to $host[$port]: tcp_seq=$((current-1)) time=${latency_ms} ms"
        success=$((success + 1))
        exec 3<&-  # Close connection
    else
        echo "Failed to connect to $host:$port"
        fail=$((fail + 1))
    fi
    total=$((total + 1))
    
    # Wait for the interval time if not finished
    if [ "$count" -eq 0 ] || [ "$current" -lt "$count" ]; then
        sleep "$interval"
    fi
done

# Print final statistics
echo -e "\nTCP Ping Results: Connections (Total/Pass/Fail): [$total/$success/$fail] (Failed: $((fail * 100 / total))%)"
