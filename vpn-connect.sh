#!/bin/bash

##################################################
#  My silly little script to connect to FreeVPN  #
#              AAnarchYY@gmail.com               #
##################################################

iam=`whoami`
servers=( "se" "im" "it" "be" "co.uk" "me" "eu" )
user=`whoami`
pwd=`pwd`
gateway=`ip route | awk '/default/ { print $3 }'` # I'd like to fix this to be more specific, perhaps per device
server=""
version="0.2"

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

trap ctrl_c INT

### Functions ###

usage()
{

	echo "Tool to connect to FreeVPN Version:$version (aanarchyy@gmail.com)"
	echo -e "\t$0 {arguments}"
	echo -e "\t-u \tServer (se im it be co.uk me eu)"
	echo -e "\t-p \tProtocol (TCP UDP)"
	echo -e "\t-t \tPort (TCP-80/443 UDP-53/40000)"
	echo -e "\t-4 \tAttempt to block IPV4 incase the VPN drops"
	echo -e "\t-6 \tAttempt to block IPV6"
	echo -e "\t-r \tRestore old iptables rules if they are backed up"
	echo -e "\t-h \thelp"
	exit 0
}

ctrl_c()
{
	echo -e "\n\nCTRL-C!"
	exit 0
}

syscheck()
{
	#Start of the dummy checks... I hate doing this...
	#Not gonna check for xterm, cuz who doesn't have that.
	#Checking if we have xdotool
	xdck=`xdotool &> /dev/null`
	if [ "$?" = "127" ] ; then echo -e "You either dont have the xdotool or it is not in your path!" 
		exit 1
	fi 
	#Checking if we have openvpn
	xdck=`openvpn &> /dev/null`
	if [ "$?" = "127" ] ; then echo -e "You either dont have the openvpn or it is not in your path!" 
		exit 1
	fi 
}

server()
{
	echo "Please enter server: se im it be co.uk me eu"
	exit 1
}

restore()
{

	if [ -e iptables-works ] ; then	
		echo "Restoring old iptables rules"
		iptables -F
		iptables-restore iptables-works
		rm iptables-works
	fi
	
	if [ -e ip6tables-works ] ; then	
		echo "Restoring old ip6tables rules"
		ip6tables -F
		ip6tables-restore ip6tables-works
		rm ip6tables-works
		sysctl -w net.ipv6.conf.all.disable_ipv6=0
		sysctl -w net.ipv6.conf.default.disable_ipv6=0
	fi
	exit 0
}

ipv4kill()
{
	iptables-save > iptables-works
	echo "Attempting to block IPV4 traffic if the VPN drops connection"
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT DROP

	iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

	iptables -A OUTPUT -o lo -j ACCEPT
	iptables -A OUTPUT -o tun0 -p icmp -j ACCEPT

	iptables -A OUTPUT -d $gateway/24 -j ACCEPT
	iptables -A OUTPUT -d 1.1.1.1 -j ACCEPT #Fix this dns

	iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
	iptables -A OUTPUT -p udp -m udp --dport 40000 -j ACCEPT
	iptables -A OUTPUT -o tun0 -j ACCEPT
}

ipv6kill()
{
	ip6tables-save > ip6tables-works
	echo "Attempting to block IPV6 traffic"
	sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sysctl -w net.ipv6.conf.default.disable_ipv6=1
	ip6tables -P INPUT DROP
	ip6tables -P FORWARD DROP
	ip6tables -P OUTPUT DROP

}

### End of Functions ###

while getopts u:p:t:46hr opt
do
	case $opt in
	u) server="$OPTARG";;
	t) port="$OPTARG";;
	p) proto="$OPTARG";;
	4) ipv4=1;;
	6) ipv6=1;;
	h) usage;;
	r) restore;;
	*) usage ;;
	esac
done
if [ ! $server ] ; then
	echo "1)me 2)se 3)im 4)it 5)be 6)co.uk 7)eu"
	echo "Server?"
	read server
fi

server=${server,,} #non-posix, may fix later
if [ "$server" = "1" ] || [ "$server" = "me" ] ; then server="me" ; num=1 ; ct="FR" ; fi
if [ "$server" = "2" ] || [ "$server" = "se" ] ; then server="se" ; num=2 ; ct="FR" ; fi
if [ "$server" = "3" ] || [ "$server" = "im" ] ;then server="im" ; num=3 ; ct="FR" ; fi
if [ "$server" = "4" ] || [ "$server" = "it" ] ; then server="it" ; num=4 ; ct="FR" ; fi
if [ "$server" = "5" ] || [ "$server" = "be" ] ; then server="be" ; num=5 ; ct="PL" ; fi
if [ "$server" = "6" ] || [ "$server" = "co.uk" ] ; then server="co.uk" ; num=6 ; ct="DE" ; fi
if [ "$server" = "7" ] || [ "$server" = "eu" ] ; then server="eu" ; num=7 ; ct="NL" ; fi
if [[ ! $server =~ ^(se|im|it|be|co.uk|me|eu)$ ]]; then echo "Please enter a valid server!" ; exit 1 ; fi

echo -e "SERVER $server NUM $num CT $ct\n"

if [ ! $proto ] ; then
	echo "1)TCP 2)UDP"
	echo "Protocol?"
	read proto
fi

if [ "$proto" = "1" ] ; then proto=TCP ; fi
if [ "$proto" = "2" ] ; then proto=UDP ; fi
proto=${proto^^} #non-posix, may fix later

echo -e "Protocol $proto\n"

if [[ ! $proto =~ ^(TCP|UDP)$ ]] ; then echo "Please enter a valid protocol!" ; exit 1 ; fi

if [ ! $port ] ; then
	if [ "$proto" = "TCP" ] ; then
		echo "1)80 2)443"
		echo "Port?"
		read port
		if [ "$port" = "1" ] ; then port=80 ; fi
		if [ "$port" = "2" ] ; then port=443 ; fi
	fi
	if [ "$proto" = "UDP" ] ; then
		echo "1)53 2)40000"
		echo "Port?"
		read port
		if [ "$port" = "1" ] ; then port=53 ; fi
		if [ "$port" = "2" ] ; then port=40000 ; fi
	fi
fi

if [[ "$proto" = "TCP" ]] && [[ ! $port =~ ^(80|443)$ ]]; then echo "Invalid" ; exit 1 ; fi
if [[ "$proto" = "UDP" ]] && [[ ! $port =~ ^(53|40000)$ ]]; then echo "Invalid" ; exit 1 ; fi

echo -e "Port $port\n"
folder='"'
folder+=$num
folder+=" - FreeVPN."
folder+=$server
folder+=" - "
folder+=$ct
folder+="/"

file="FreeVPN."
file+=$server
file+="-"
file+=$proto
if [ "$proto" = "UDP" ] ; then file+="-" ; fi
file+=$port
file+='.ovpn"'
echo "openvpn $folder$file"

#Really want to fix this so I don't have to open an xterm
xterm -hold -e "openvpn $folder$file ; $SHELL" &

#Scrape the password from the site
curl -s https://freevpn.$server/accounts/ | grep "Password" > tmp_file
passwd=`cat tmp_file | gawk -F 'Password:<' '{print $2}' | cut -c 5- | gawk -F '<' '{print $1}'`
rm tmp_file

su $user -c "xdotool type freevpn.$server"
su $user -c "xdotool key Return"
su $user -c "xdotool type $passwd"
su $user -c "xdotool key Return"

if [ $ipv4 ] ; then ipv4kill ; fi
if [ $ipv6 ] ; then ipv6kill ; fi
