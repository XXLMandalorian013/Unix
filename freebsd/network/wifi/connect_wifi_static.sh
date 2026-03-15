#!/bin/sh
# .notes-start
#no sudo or root pre-script run as a few vars has sudo in it.
#don't worry about this section in rc.conf as it gets set when installing FreeBSD (create_args_wlan0="country US regdomain FCC")
#gateway must provide nameserver(s).
#this script will not reboot the device but if sshed in will disconnect and maybe reconnect depending if the IP change.
#to get your virtual wlan interface run, ifconfig -a .
# .notes-end
# .vars-start
#virtual wlan interface.
virtwlanint="YourWirelessInterfaceHere"
#wifi name.
ssid="SSIDNameHere"
#ipv4 address to assign to the adapter.
ipv4="XX.XXX.XX.XXX"
#subnet prefix length (e.g. /24 for 255.255.255.0).
prefix="24"
#gateway.
gateway="XX.XXX.XX.XXX"
#dns server(s).
dns="XX.XXX.XX.XXX"
#wifi config file
wpa_conf="/etc/wpa_supplicant.conf"
#ethernet file.
rc_conf="/etc/rc.conf"
#DNS file.
resolv_conf="/etc/resolv.conf"
#existing ssid detection.
existingssid=$(sudo grep "ssid=\"$ssid\"" "$wpa_conf")
#existing name server(s).
existingnameserver1=XX.XXX.XX.XXX
existingnameserver2=XX.XXX.XX.XXX
#existing name server(s) detection.
existingnameserver1check=$(sudo grep "nameserver $existingnameserver1" "$resolv_conf")
existingnameserver2check=$(sudo grep "nameserver $existingnameserver2" "$resolv_conf")
#existing desired static ip detection.
existingstaticip=$(grep "ifconfig_$virtwlanint=\"WPA inet $ipv4" "$rc_conf")
#existing dhcp entry detection.
existingdhcp=$(grep "ifconfig_${virtwlanint}=\"WPA.*DHCP\"" "$rc_conf")
#existing gateway detection.
existinggateway=$(grep "defaultrouter=\"$gateway\"" "$rc_conf")
#ipv6 enable detection.
existingipv6=$(grep "ifconfig_${virtwlanint}_ipv6=" "$rc_conf")
#exitsuccess 
exitsuccess=0
#exitsuccessMSG
exitsuccessMSG="script completed successfully!!!"
#exit9000
exit9000=9000
#exit9000MSG
exit9000MSG="the specified ssid $existingssid already exists in $wpa_conf...ending script..."
#exit9001
exit9001=9001
#exit9001MSG
exit9001MSG="SSID already found in $wpa_conf"
# .vars-end
# .functions-start
#exit code log.
log_exit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - EXIT $1: $2" >> /var/log/wlan_setup.log
    exit $1
}
# .functions-end
# .script-start
#ensure the specified adapter exists, else exits. -n = not empty.
echo "checking for virtual wlan interface..."
if ifconfig "$virtwlanint" > /dev/null 2>&1; then
    echo "found adapter: $virtwlanint...continuing..."
    #if the specified ssid does not exist its added, else exits. z = zero length. don't forget the space and the quotes.
    if [ -z "$existingssid" ]; then
        echo "the specified ssid $ssid was not found...adding $ssid to $wpa_conf without overwriting existing content..."
        #prompt for wifi password and ensures the wifi password is not empty. 
        #stty -echo = blanks out the psk input. stty echo = moves the cursor to the next line so subsequent output isn't blanked.
        while [ -z "$wifi_psk" ]; do
        printf "Please enter wi-fi password: "
        stty -echo
        read wifi_psk
        stty echo
        echo
        done
        #adding ssid and psk to wpa_supplicant.conf. 
        #cat > "\Dir\File.conf" << = 
        #cat = reads the file
        #> = after cat, overwrites the file completely rewritten from scratch and only adds the content specified.
        #>> = after cat, add the blocks w/out overwriting the existing content.
        #<< = end of detection of what to add to the file.
        #EOF = add content to end of file. A second EOF is required to signify the end of the content to be added.
        #left justification of the content to be added so its doesn't have odd spacing in the file.
        cat >> "$wpa_conf" << EOF
network={
ssid="$ssid"
psk="$wifi_psk"
priority=0
}
EOF
        #if desired static ip exists it skips adding it, if a dhcp entry exists it replaces it with the static ip, else adds the static ip to the file.
        if [ -n "$existingstaticip" ]; then
            echo "static IP already set to $ipv4, skipping..."
        elif [ -n "$existingdhcp" ]; then
            echo "DHCP entry found, replacing with static IP..."
            sed -i '' "s|ifconfig_${virtwlanint}=\"WPA.*DHCP\"|ifconfig_${virtwlanint}=\"WPA inet ${ipv4}/${prefix}\"|" "$rc_conf"
        else
            echo "No existing ifconfig entry found, adding static IP..."
            #left justification of the content to be added so its doesn't have odd spacing in the file.
            cat >> "$rc_conf" << EOF
ifconfig_${virtwlanint}="WPA inet ${ipv4}/${prefix}"
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
            sed -i '' "/ifconfig_${virtwlanint}_ipv6=/d" "$rc_conf"
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
        echo "done...connected to $ssid with static IP $ipv4/$prefix"
        log_exit "$exitsuccess" "$exitsuccessMSG"
    else
        echo "the specified ssid $ssid already exists in $wpa_conf...ending script..."
        log_exit "$exit9001" "$exit9001MSG"
    fi
    
else
    echo "the specified virtual wlan interface $virtwlanint was not found...ending script..."
    log_exit "$exit9000" "$exit9000MSG"
fi
# .script-end

