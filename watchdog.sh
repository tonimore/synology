#!/bin/sh
# init.d service to reconnect OpenVPN in case ping loss
# checked on DSM 6.x


# type your IP here
monitor_ip=192.168.220.1

interval=120              # Interval between ping
log=/var/log/$name.log    # Log file 

name=$(basename $0)
descr="OpenVPN auto-reconnection service"
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

recovery() {
    /usr/syno/etc/synovpnclient/scripts/synovpnclient.sh stop  2>&1 | tee -a $log
    # just in case
    sleep 5
    /usr/syno/etc/synovpnclient/scripts/synovpnclient.sh start 2>&1 | tee -a $log
}


while true; do
    sleep $interval
    ping -c 2 $monitor_ip >/dev/null && continue
    echo "$(date) Ping loss to $monitor_ip. Running recovery..." | tee -a $log
    recovery
done
