#!/bin/sh
# .notes-start
#wired (ethernet) static ip setup for freebsd.
#must be run as root (sudo sh connect_eth_static.sh).
#gateway must provide nameserver(s).
#this script will cause a network error if the wlan is statically set. a failover/lag should be used
#if dhcp is used on the lan or wlan adpater this script wont have issues. if static lan or wlan is already set use a failover/lag.
#this script will not reboot the device but if sshed in will disconnect and maybe reconnect depending if the IP changes.
#ideally save this script locally to the device and run it if sshed in. cd to dir, ee connect_eth_static.sh  chmod +x connect_eth_static.sh  sudo /path/to/your/connect_eth_static.sh  
#to get your ethernet interface run, ifconfig -a .
# .notes-end
# .vars-start
#ethernet interface (e.g. em0, igb0, re0, bge0).
ethint="YourEthernetInterfaceHere"
#ipv4 address to assign to the adapter.
ipv4="xx.xxx.xx.xxx"
#subnet prefix length (e.g. /24 for 255.255.255.0).
prefix="24"
#gateway.
gateway="xx.xxx.xx.xxx"
#dns server(s).
dns="xx.xxx.xx.xxx"
#ethernet config file.
rc_conf="/etc/rc.conf"
#DNS file.
resolv_conf="/etc/resolv.conf"
#existing desired static ip detection.
existingstaticip=$(grep "ifconfig_${ethint}=\"inet $ipv4" "$rc_conf")
#existing dhcp entry detection.
existingdhcp=$(grep "ifconfig_${ethint}=\"DHCP\"" "$rc_conf")
#existing gateway detection.
existinggateway=$(grep "defaultrouter=\"$gateway\"" "$rc_conf")
#ipv6 enable detection.
existingipv6=$(grep "ifconfig_${ethint}_ipv6=" "$rc_conf")
#existing name server(s).
existingnameserver1=10.100.10.102
existingnameserver2=10.100.10.104
#existing name server(s) detection.
existingnameserver1check=$(grep "nameserver $existingnameserver1" "$resolv_conf")
existingnameserver2check=$(grep "nameserver $existingnameserver2" "$resolv_conf")
#exitsuccess
exitsuccess=0
#exitsuccessMSG
exitsuccessMSG="script completed successfully!!!"
#exit9000
exit9000=9000
#exit9000MSG
exit9000MSG="the specified ethernet interface $ethint was not found...ending script..."
# .vars-end
# .functions-start
#exit code log.
log_exit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - EXIT $1: $2" >> /var/log/connect_eth_static.log
    exit $1
}
# .functions-end
# .script-start
#ensure script is run as root.
if [ "$(id -u)" -ne 0 ]; then
    echo "this script must be run as root...exiting..."
    exit 1
fi
#ensure the specified adapter exists, else exits. -n = not empty.
echo "checking for ethernet interface..."
if ifconfig "$ethint" > /dev/null 2>&1; then
    echo "found adapter: $ethint...continuing..."
    #if desired static ip exists it skips adding it, if a dhcp entry exists it replaces it with the static ip, else adds the static ip to the file.
    if [ -n "$existingstaticip" ]; then
        echo "static IP already set to $ipv4, skipping..."
    elif [ -n "$existingdhcp" ]; then
        echo "DHCP entry found, replacing with static IP..."
        sed -i '' "s|ifconfig_${ethint}=\"DHCP\"|ifconfig_${ethint}=\"inet ${ipv4}/${prefix}\"|" "$rc_conf"
    else
        echo "No existing ifconfig entry found, adding static IP..."
        #left justification of the content to be added so its doesn't have odd spacing in the file.
        cat >> "$rc_conf" << EOF
ifconfig_${ethint}="inet ${ipv4}/${prefix}"
EOF
    fi
    #if the desired gateway exists it skips adding it, else adds the gateway to provide the default route.
    if [ -n "$existinggateway" ]; then
        echo "Gateway already set in $rc_conf, skipping..."
    else
        echo "Adding gateway to $rc_conf..."
        #left justification of the content to be added so its doesn't have odd spacing in the file.
        cat >> "$rc_conf" << EOF
defaultrouter="$gateway"
EOF
    fi
    #if ipv6 is enabled, disabled it by appending the enable.
    if [ -n "$existingipv6" ]; then
        echo "Removing IPv6 config from $rc_conf..."
        sed -i '' "/ifconfig_${ethint}_ipv6=/d" "$rc_conf"
    else
        echo "No IPv6 config found in $rc_conf, skipping..."
    fi
    #if the existing nameservers are found in resolv.conf it skips adding them, else adds the gateway to provide the name server(s). note, gateway must provide nameserver(s).
    if [ -n "$existingnameserver1check" ] || [ -n "$existingnameserver2check" ]; then
        echo "Existing DNS servers detected in $resolv_conf, skipping..."
    else
        echo "requested existing nameservers not found in $resolv_conf...adding $dns without overwriting existing content..."
        #left justification of the content to be added so its doesn't have odd spacing in the file.
        cat >> "$resolv_conf" << EOF
nameserver $dns
EOF
    fi
    #apply network settings without rebooting.
    echo "apply network settings without rebooting..."
    service netif restart
    service routing restart
    echo "done...configured $ethint with static IP $ipv4/$prefix"
    log_exit "$exitsuccess" "$exitsuccessMSG"
else
    echo "the specified ethernet interface $ethint was not found...ending script..."
    log_exit "$exit9000" "$exit9000MSG"
fi
# .script-end