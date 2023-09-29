#!/bin/sh
# init.d service to reconnect OpenVPN in case ping loss
# checked on DSM 6.x
# place this file to: /usr/local/etc/rc.d/S20_openvpn_reconnect.sh

# type your IP here
monitor_ip=192.168.220.1

name=$(basename $0)
interval=120              # Interval between ping
log=/var/log/$name.log    # Log file 
version=1.1
descr="OpenVPN auto-reconnection service v$version"
pid=/var/run/$name.pid


if [ "$1" == "debug" ]; then
    echo "$descr started in foreground. Log: $log, PID: $pid. Monitoring $monitor_ip..."
    $0 service
    exit
fi

if [ "$1" == "start" ]; then
    echo "$descr started. Log: $log, PID: $pid. Monitoring $monitor_ip..."
    $0 service >/dev/null 2>&1 &
    exit
fi

if [ "$1" == "stop" ]; then
    kill $(cat $pid)
    code=$?
    rm $pid
    exit $code
fi

if [ ! "$1" == "service" ]; then
    echo "Usage: $0 start|stop|debug"
    exit 1
fi


# ===============================================================================
# service part of the script:
# ===============================================================================

echo $$>$pid
echo "$descr started. PID: $$. Monitoring $monitor_ip..." | tee -a $log

recovery() {
    echo "Stopping VPN..." | tee -a $log
    /usr/syno/etc/synovpnclient/scripts/synovpnclient.sh stop  2>&1 | tee -a $log
    echo "VPN Stop Done" | tee -a $log
    # just in case
    sleep 5
    echo "Starting VPN..." | tee -a $log
    /usr/syno/etc/synovpnclient/scripts/synovpnclient.sh start 2>&1 | tee -a $log
    echo "VPN Start Done" | tee -a $log
}


while true; do
    sleep $interval
    ping -c 2 $monitor_ip >/dev/null && continue
    echo "$(date) Ping loss to $monitor_ip. Running recovery..." | tee -a $log
    recovery
done
