#!/bin/bash

###################################################
#  My silly little script to connect to FreeVPN   #
#              AAnarchYY@gmail.com                #
###################################################

###################################################
#                    TODO                         #
#                                                 #
#  Fix the DNS so it reads the user DNS and adds  #
#    that instead of the cloudfare one i use.     #
#                                                 #
#             Fix that gateway thing              #
#												  #
#  Would like to add the L2TP and PPTP protocols  #
#                  as optional                    #
###################################################

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

#declaring variables
gateway=`ip route | awk '/default/ { print $3 }'`
pwd=`pwd`
version="0.5"
certs="FreeVPN.me-OpenVPN-Bundle-April-2019.zip"

trap ctrl_c INT

### Functions ###

usage()
{
	echo "Tool to connect to FreeVPN Version $version (aanarchyy@gmail.com)"
	echo -e "\t$0 {arguments}"
	echo -e "\t-u \tServer (se im it be co.uk me eu)"
	echo -e "\t-p \tProtocol (TCP UDP)"
	echo -e "\t-t \tPort (TCP-80/443 UDP-53/40000)"
	echo -e "\t-n \tPassword to use"
	echo -e "\t-4 \tAttempt to block IPV4 incase the VPN drops"
	echo -e "\t-6 \tAttempt to block IPV6"
	echo -e "\t-r \tRestore old iptables rules if they are backed up"
	echo -e "\t-f \tTemporary directory to use. Deafault is /dev/shm or /tmp"
	echo -e "\t-h \thelp"
	exit 0
}

ctrl_c()
{
	echo -e "\n\nCTRL-C! Cleaning up best we can!"
	restore
	rm -rf $tmpdr/*FreeVPN*
	rm -f $tmpdr/userpass
	exit 0
}

syscheck()
{
	#Start of the dummy checks... I hate doing this...
	
	#Checking if we have openvpn
	ovpn=`which openvpn &2> /dev/null`
	if [ ! $ovpn ] ; then echo -e "You either dont have openvpn or it is not in your path!" 
		exit 1
	fi 
	
}

restore()
{
	if [ -e iptables-works ] ; then	
		echo "Restoring old iptables rules"
		iptables -F
		iptables -P INPUT ACCEPT
		iptables -P FORWARD ACCEPT
		iptables -P OUTPUT ACCEPT
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
}

ipv4kill()
{
	iptables-save > $tmpdr/iptables-works
	echo "Attempting to block IPV4 traffic if the VPN drops connection"
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT DROP

	iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

	iptables -A OUTPUT -o lo -j ACCEPT
	iptables -A OUTPUT -o tun0 -p icmp -j ACCEPT

	iptables -A OUTPUT -d $gateway/24 -j ACCEPT
	###FIX ME : attempt to read user dns server!###
	iptables -A OUTPUT -d 1.1.1.1 -j ACCEPT

	iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
	iptables -A OUTPUT -p udp -m udp --dport 40000 -j ACCEPT
	iptables -A OUTPUT -o tun0 -j ACCEPT
}

ipv6kill()
{
	ip6tables-save > $tmpdr/ip6tables-works
	echo "Attempting to block IPV6 traffic"
	sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sysctl -w net.ipv6.conf.default.disable_ipv6=1
	ip6tables -P INPUT DROP
	ip6tables -P FORWARD DROP
	ip6tables -P OUTPUT DROP

}

dlcerts()
{
	cd $tmpdr
	echo "DELETING!"
	rm -rf $1/$certs
	rm -rf $1/*FreeVPN*
	#curl -s https://freevpn.me/$certs --output $1/$certs
	wget -q -O $1/$certs https://freevpn.me/$certs 2>&1
	unzip -q -o $1/$certs -d $1
	rm -rf $1/$certs
}

### End of Functions ###

syscheck

while getopts u:p:t:n:f:46hr opt
do
	case $opt in
	u) server="$OPTARG";;
	t) port="$OPTARG";;
	p) proto="$OPTARG";;
	n) passwd="$OPTARG";;
	4) ipv4=1;;
	6) ipv6=1;;
	h) usage;;
	f) tmpdr="$OPTARG";;
	r) restore ; exit 0;;
	*) usage;;
	esac
done

if [ ! $tmpdr ] ; then tmpdr="/dev/shm" ; fi
if [ ! -w /dev/shm ]; then echo "/dev/shm unwritable!"; tmpdr=""; fi
if [ ! $tmpdr ] ; then tmpdr="/tmp" ; fi
if [ ! -w /tmp ]; then echo "/tmp unwritable!"; tmpdr=""; fi
if [ ! -w "$tmpdr" ]; then echo "Please specify a writable folder! -f [/dir]" ; exit 1 ; fi 
echo -e "Temporary directory $tmpdr\n"
dlcerts $tmpdr

if [ ! $server ] ; then
	echo "Server?"
	echo "1)me 2)se 3)im 4)it 5)be 6)co.uk 7)eu"
	read server
fi

server=${server,,} #non-posix, may fix later
if [ "$server" = "1" ] || [ "$server" = "me" ] ; then server="me" ; num=1 ; ct="FR" ; fi
if [ "$server" = "2" ] || [ "$server" = "se" ] ; then server="se" ; num=2 ; ct="FR" ; fi
if [ "$server" = "3" ] || [ "$server" = "im" ] ; then server="im" ; num=3 ; ct="FR" ; fi
if [ "$server" = "4" ] || [ "$server" = "it" ] ; then server="it" ; num=4 ; ct="FR" ; fi
if [ "$server" = "5" ] || [ "$server" = "be" ] ; then server="be" ; num=5 ; ct="PL" ; fi
if [ "$server" = "6" ] || [ "$server" = "co.uk" ] ; then server="co.uk" ; num=6 ; ct="DE" ; fi
if [ "$server" = "7" ] || [ "$server" = "eu" ] ; then server="eu" ; num=7 ; ct="NL" ; fi
if [[ ! $server =~ ^(se|im|it|be|co.uk|me|eu)$ ]] ; then echo "Please enter a valid server!" ; exit 1 ; fi
echo -e "Server freevpn.$server\n"

if [ ! $proto ] ; then
	echo "Protocol?"
	echo "1)TCP 2)UDP"
	read proto
fi
if [ "$proto" = "1" ] ; then proto=TCP ; fi
if [ "$proto" = "2" ] ; then proto=UDP ; fi
proto=${proto^^} #non-posix, may fix later
if [[ ! $proto =~ ^(TCP|UDP)$ ]] ; then echo "Please enter a valid protocol!" ; exit 1 ; fi
echo -e "Protocol $proto\n"

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

if [[ "$proto" = "TCP" ]] && [[ ! $port =~ ^(80|443)$ ]]; then echo "Invalid port" ; exit 1 ; fi
if [[ "$proto" = "UDP" ]] && [[ ! $port =~ ^(53|40000)$ ]]; then echo "Invalid port" ; exit 1 ; fi

echo -e "Port $port\n"

config=' --config "'
config+="$tmpdr/"
config+=$num
config+=" - FreeVPN."
config+=$server
config+=" - $ct/FreeVPN.$server-$proto"
if [ "$proto" = "UDP" ] ; then config+="-" ; fi
config+=$port
config+='.ovpn"'


#Scrape the password from the site

if [ ! $passwd ] ; then
	#Trying wget
	page="`wget -qO- https://freevpn.$server/accounts/accounts`"
	passwd=`echo $page | awk -F 'Password:<' '{print $2}' | cut -c 5- | awk -F '<' '{print $1}' | tr -d '[:space:]'`
fi
	
if [ ! $passwd ] ; then
	echo "Unable to retrieve password from website!"
	exit 1
fi

echo "USER: freevpn.$server PASS: $passwd"
echo "freevpn.$server" > "$tmpdr/userpass"
echo "$passwd" >> "$tmpdr/userpass"
upfile=$tmpdr/userpass

if [ $ipv4 ] ; then ipv4kill ; fi
if [ $ipv6 ] ; then ipv6kill ; fi

if [ -e "$upfile" ] ; then
	cmd="openvpn $config  --mute-replay-warnings --auth-user-pass $tmpdr/userpass"
	echo $cmd
	sh -c "openvpn $config  --mute-replay-warnings --auth-user-pass $tmpdr/userpass"
else
	echo "Unable to connect!"
	exit 1
fi
