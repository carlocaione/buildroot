#!/bin/bash

FUNCTION_NAME="pci_epf_vnet"
FALLBACK_FUNCTION="pci_epf_virtio_net"
CONFIG_DIR="/sys/kernel/config"
PCI_EP_DIR="${CONFIG_DIR}/pci_ep"
CONTROLLER="e65d0000.pcie-ep"

setup_network() {
    local ip=$1
    local dev=$(find_network_device)
    ifconfig "$dev" "$ip" up
}

find_network_device() {
    for dev in enp1s0f0 eth0 eth1 eth3; do
        if ifconfig "$dev" &>/dev/null; then
            echo "$dev"
            return
        fi
    done
    echo "eth0"  # Default fallback
}

start_ep_rc() {
    echo "Executing startup operations"

    sysctl -w net.core.rmem_max=1048576 net.core.wmem_max=1048576

    echo performance | tee /sys/devices/system/cpu/cpufreq/policy{0,4}/scaling_governor

    echo "Starting Endpoint function..."
    mount -t configfs none "$CONFIG_DIR"
    export IBV_CONFIG_DIR=/etc/libibverbs.d/

    cd "$PCI_EP_DIR"
    if [[ -n "$(ls controllers/)" ]]; then
        setup_endpoint
        setup_network "192.168.10.22"
        echo "iperf3 is running in server mode (cmd: iperf3 -s)"
        iperf3 -s > /dev/null &
    else
        echo "This device is root complex"
        setup_network "192.168.10.1"
        sleep 1
        ping 192.168.10.22 -c 5 -s 64
    fi
}

setup_endpoint() {
    if [[ ! -e "functions/$FUNCTION_NAME" ]]; then
        FUNCTION_NAME="$FALLBACK_FUNCTION"
    fi
    mkdir -p "functions/$FUNCTION_NAME/func1"
    echo 32 > "functions/$FUNCTION_NAME/func1/msi_interrupts"
    ln -s "functions/$FUNCTION_NAME/func1" "controllers/$CONTROLLER/" && sleep 1
    echo 1 > "controllers/$CONTROLLER/start" && sleep 1
}

stop_ep_rc() {
    echo "Stopping Endpoint function..."
    ifconfig eth0 down up
    cd "$PCI_EP_DIR"
    if [[ -n "$(ls controllers/)" ]]; then
        echo 0 > "controllers/$CONTROLLER/start" && sleep 1
    fi
}

case "$1" in
    start)
        start_ep_rc
        ;;
    stop)
        stop_ep_rc
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0
