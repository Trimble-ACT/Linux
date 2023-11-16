#!/bin/bash
export PATH='/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin'
umask 0022

export prog=`basename $0`
export prog='trimbleify-linux-workstation'

export HOST_CLASS='Workstation'

unset PRIMARY_USER COUNTRY_CODE DISPLAY

export DEBIAN_FRONTEND=noninteractive


while [ "$1" != "" ];
do
        case $1 in
                --user) PRIMARY_USER=$2; shift ; shift;;
                --country)      COUNTRY_CODE=$2; shift ; shift;;
                --hostname)     OVERRIDE_HOSTNAME=$2; shift; shift;;
		--no-openvpn)	DISABLE_OPENVPN=1; shift;;
                --no-FDE)       DISABLE_FDE=1; shift;;
        esac
done


spinner()
{
	while [ "`fuser $1 2>/dev/null`" != "" ]
        do
               echo -ne '|\b'; sleep 1; echo -ne '/\b';sleep 1;echo -ne '-'; echo -ne '\b';sleep 1;echo -ne '\'; echo -ne '\b'
               sleep 5
        done
	echo ""
}

unset TERM SSH_TTY

#disable LDAP TLS checks
export LDAPTLS_REQCERT=never

CODES_AP='nz|cn|au'
CODES_AM='us|ca|ca'
CODES_EU='fi|ro|no|se|cy|bg|be|at|dk|ee|es|gr|hr|hu|it|lt|lu|lv|mt|nl|pl|pt|si|in|eu|fr|za|br|uk|ie|ba|de'

export VALID_CODES="$CODES_AP|$CODES_AM|$CODES_EU"

if [ `id -u` -ne 0 ]; then
        echo "ERROR: must run as root. Try again with \"sudo \" at the front"
        exit 1
fi

( 
service packagekit stop > /dev/null 2>&1
systemctl stop packagekit  > /dev/null 2>&1
UMPID=`ps auxw|grep update-manager|grep -v grep|awk '{print $2}'|egrep '^[0-9]*$'|egrep -v '^1$'`
if [ "$UMPID" != "" ]; then
	kill $UMPID > /dev/null 2>&1
fi

apt update
apt -y install fping 
if [ $? -ne 0 ]; then
	apt-get install --fix-broken -y && apt -y install fping
fi
yum -y install fping 
) > /dev/null 2>&1


if [ ! -x "/usr/sbin/dmidecode" ]; then
	(apt update ; apt -y install dmidecode) > /dev/null 2>&1
	#I think Fedora defaults to having dmidecode - so background
	yum -y install dmidecode > /dev/null 2>&1 &
fi

DMIDECODE=`dmidecode 2>/dev/null`

if [ "`echo \"$DMIDECODE\"|egrep 'Type:\W.*(Mobile|Hand|Portable|Laptop|Notebook|Netbook)'`" != "" ]; then
        WS_TYPE='l'
        WS_DESC="Laptop"
elif [ "`echo \"$DMIDECODE\"|egrep '(Name|Type):\W.*(Virt|Hyper|QEMU)'`" != "" ]; then
	WS_TYPE='v'
	WS_DESC='Virtual'
	export vmtools='open-vm-tools'
	DISABLE_FDE=1
else
        WS_TYPE='d'
        WS_DESC="Desktop"
	#Don't encrypt desktops
	DISABLE_FDE=1
fi
export WS_TYPE WS_DESC

MANUFACTURER=`echo "$DMIDECODE"|grep Manufacturer|head -1|sed -e 's/^.*Manufacturer: //g'`
MODEL=`echo "$DMIDECODE"|grep 'Product Name:'|head -1|sed -e 's/^.*Product Name: //g'`
SERIAL_NUMBER=`echo "$DMIDECODE"|grep 'Serial Number:'|head -1|sed -e 's/^.*Serial Number: //g'|egrep -v 'Not Specified'`
if [ "`echo $MODEL|grep Mac`" -a "$SERIAL_NUMBER" == "" ]; then
	SERIAL_NUMBER=`echo "$DMIDECODE"|sed -e '/^Base Board Information/ q' |grep 'Serial Number'|tail -1|sed -e 's/^.*Serial Number: //g'`
fi
export MANUFACTURER MODEL SERIAL_NUMBER

cat<<EOF

Manufacturer: $MANUFACTURER
Model: $MODEL
Workstation Type: $WS_DESC
Serial Number/ServiceTag: $SERIAL_NUMBER

EOF

#SecureBoot for Linux test
if [ "`uname -s|grep Linux`" != "" ]; then
        mC=`mokutil --sb-state 2>/dev/null|egrep -E 'SecureBoot (enabled|disabled)'|egrep -m 1 -o -E '(enabled|disabled)'`
        if [ "$mC" != "" ]; then
                secureBoot="$mC"
        fi
        if [ "$secureBoot" = "enabled" -a `cat /proc/keys 2>/dev/null| grep -c crowdstrike` -gt 0 ]; then
                secureBoot="enabled-and-working"
        fi
        if [ "$secureBoot" = "enabled" ]; then
                echo ""
                echo "Fatal error: SecureBoot under Linux is not currently supported. Please read the SecureBoot comments in:"
                echo ""
                echo "https://cis-infosec.trimble.com/wiki/index.php/CrowdStrike_Falcon"
                echo ""
                exit 99
        fi
fi

if [ "`echo $1|grep '\-h'`" != "" ]; then
	cat<<EOF
$0 (no options) - will create a CIS managed Linux workstation (please DO NOT 
use on servers), joined to the *.TRIMBLECORP Active Directory. As with Mac/Windows,
this action will need to be carried out while this host has access to the Trimble WAN.

Naming convention is "username"-"country"-"l$WS_TYPE" (Linux $WS_DESC). 
An incremented number will be placed at the end if the initial hostname 
is already taken

By default, will install the following:

* Google-Chrome and Firefox
* configures system to auto-patch, tibs/nessus scanner access
* Crowdstrike, NessusAgent
* Always-on VPN (openvpn). So be prepared to add this new AD host to TRIMBLECORP/SWD-OpenVPN-Global-Install afterwards


$0 --user [domain/username] - will use as primary user and will base hostname off that username.
                              domain must be one of AP, AM or EU
$0 --country [two-letters]  
$0 --hostname - if not set, this script will auto-create a new one based on the user and country fields
$0 --no-openvpn - skip the openvpn bit

eg

$0 --user ap/jhaar --country nz [--hostname jhaar-nz-ll04]


Note: this is safe to play with: you will always be asked to confirm at the end before it will action anything

EOF
	exit 0
fi

(cat<<EOF
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVIRENDQTRXZ0F3SUJBZ0lCWkRBTkJna3Fo
a2lHOXcwQkFRUUZBRENCcVRFTE1Ba0dBMVVFQmhNQ1ZWTXgKRXpBUkJnTlZCQWdUQ2tOaGJHbG1i
M0p1YVdFeEVqQVFCZ05WQkFjVENWTjFibTU1ZG1Gc1pURWdNQjRHQTFVRQpDaE1YVkhKcGJXSnNa
U0JPWVhacFoyRjBhVzl1SUV4MFpDNHhFekFSQmdOVkJBc1RDbFJ5YVcxaWJHVWdRMEV4CkV6QVJC
Z05WQkFNVENsUnlhVzFpYkdVZ1EwRXhKVEFqQmdrcWhraUc5dzBCQ1FFV0ZsUnlhVzFpYkdVdFEw
RkEKZEhKcGJXSnNaUzVqYjIwd0hoY05NRGN3TkRJMk1ERXlOVFF6V2hjTk16WXdNVEF4TURFeU5U
UXpXakNCcVRFTApNQWtHQTFVRUJoTUNWVk14RXpBUkJnTlZCQWdUQ2tOaGJHbG1iM0p1YVdFeEVq
QVFCZ05WQkFjVENWTjFibTU1CmRtRnNaVEVnTUI0R0ExVUVDaE1YVkhKcGJXSnNaU0JPWVhacFoy
RjBhVzl1SUV4MFpDNHhFekFSQmdOVkJBc1QKQ2xSeWFXMWliR1VnUTBFeEV6QVJCZ05WQkFNVENs
UnlhVzFpYkdVZ1EwRXhKVEFqQmdrcWhraUc5dzBCQ1FFVwpGbFJ5YVcxaWJHVXRRMEZBZEhKcGJX
SnNaUzVqYjIwd2daOHdEUVlKS29aSWh2Y05BUUVCQlFBRGdZMEFNSUdKCkFvR0JBTUs4a0x2K1NO
RWFXSUxJa0RaYXVQaStuQm83d08zMzdYaDZqSm5udEtpeGNQUENWUlJWRzN6dXRSYXcKdkFRZUZz
cElwVlpCZlVtd0JqOERrTytxVGlhcURpcSthU3FEVUh1bE85aHhZNHhpYWRmdk5ja0pWYjdNNXZE
QgpTck42dWYzcHpIS3AvTlYrQnBVTCtWNlpPSnJyY2JWZ0M1OUEzazhwUFlZYTVOOVpBZ01CQUFH
amdnRlFNSUlCClREQWRCZ05WSFE0RUZnUVVNU0JsVWdBNVV3NU5XdzlpREFoQS83alh5dFl3Z2RZ
R0ExVWRJd1NCempDQnk0QVUKTVNCbFVnQTVVdzVOV3c5aURBaEEvN2pYeXRhaGdhK2tnYXd3Z2Fr
eEN6QUpCZ05WQkFZVEFsVlRNUk13RVFZRApWUVFJRXdwRFlXeHBabTl5Ym1saE1SSXdFQVlEVlFR
SEV3bFRkVzV1ZVhaaGJHVXhJREFlQmdOVkJBb1RGMVJ5CmFXMWliR1VnVG1GMmFXZGhkR2x2YmlC
TWRHUXVNUk13RVFZRFZRUUxFd3BVY21sdFlteGxJRU5CTVJNd0VRWUQKVlFRREV3cFVjbWx0WW14
bElFTkJNU1V3SXdZSktvWklodmNOQVFrQkZoWlVjbWx0WW14bExVTkJRSFJ5YVcxaQpiR1V1WTI5
dGdnRmtNQXdHQTFVZEV3UUZNQU1CQWY4d0lRWURWUjBSQkJvd0dJRVdWSEpwYldKc1pTMURRVUIw
CmNtbHRZbXhsTG1OdmJUQWhCZ05WSFJJRUdqQVlnUlpVY21sdFlteGxMVU5CUUhSeWFXMWliR1V1
WTI5dE1BMEcKQ1NxR1NJYjNEUUVCQkFVQUE0R0JBQmowcmU3TWFEOEVLaTF3ZVNDNDBTUXRyM09S
dWxYakcxVWsvTWt5TkErdwowMlZpSklsZC9aM2V0bkFQNFNmYjhHOW1HRVVxK1pMTE1BZU8rRjdm
L09TcC9QQksyd2lSWXFSY2ZoZWkwU0tlCnU2SWdCRUVWdDBKK3hZelNVWVlyTFNaUVp1N1V0WlNE
c0g0cU44d2kvK1lOa1BocC9yNUxuSDFocFZHK2JSb2cKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0t
LQo=
EOF
)|base64 -d > /etc/Trimble-CA2.pem
(cat<<EOF
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUh4RENDQmF5Z0F3SUJBZ0lKQVA2eVdaaVpS
OWhXTUEwR0NTcUdTSWIzRFFFQkRBVUFNSUhaTVFzd0NRWUQKVlFRR0V3SlZVekVUTUJFR0ExVUVD
Qk1LUTJGc2FXWnZjbTVwWVRFU01CQUdBMVVFQnhNSlUzVnVibmwyWVd4bApNU0F3SGdZRFZRUUtF
eGRVY21sdFlteGxJRTVoZG1sbllYUnBiMjRnVEhSa0xqRXJNQ2tHQTFVRUN4TWlWSEpwCmJXSnNa
U0JEWlhKMGFXWnBZMkYwYVc1bklFRjFkR2h2Y21sMGVTQjJNekVyTUNrR0ExVUVBeE1pVkhKcGJX
SnMKWlNCRFpYSjBhV1pwWTJGMGFXNW5JRUYxZEdodmNtbDBlU0IyTXpFbE1DTUdDU3FHU0liM0RR
RUpBUllXVkhKcApiV0pzWlMxRFFVQjBjbWx0WW14bExtTnZiVEFlRncweE5ERXdNRFl3TWpBMU5E
WmFGdzB6TmpBeE1ERXdNakExCk5EWmFNSUhaTVFzd0NRWURWUVFHRXdKVlV6RVRNQkVHQTFVRUNC
TUtRMkZzYVdadmNtNXBZVEVTTUJBR0ExVUUKQnhNSlUzVnVibmwyWVd4bE1TQXdIZ1lEVlFRS0V4
ZFVjbWx0WW14bElFNWhkbWxuWVhScGIyNGdUSFJrTGpFcgpNQ2tHQTFVRUN4TWlWSEpwYldKc1pT
QkRaWEowYVdacFkyRjBhVzVuSUVGMWRHaHZjbWwwZVNCMk16RXJNQ2tHCkExVUVBeE1pVkhKcGJX
SnNaU0JEWlhKMGFXWnBZMkYwYVc1bklFRjFkR2h2Y21sMGVTQjJNekVsTUNNR0NTcUcKU0liM0RR
RUpBUllXVkhKcGJXSnNaUzFEUVVCMGNtbHRZbXhsTG1OdmJUQ0NBaUl3RFFZSktvWklodmNOQVFF
QgpCUUFEZ2dJUEFEQ0NBZ29DZ2dJQkFOaVFPVXdHL0tSTVdGMC9zTjJ2c1FjbzZkcnoyL0dncWVC
L1E5Y05ldW9QCithSEFOVnJJMEY1bjZWcGE5OWY4bHZTYm8rTDBhZDJMc0daZTdmUTJ1Nlo1TXVl
SEpqVFFiMDJkNDVPZUl4RGkKSTI2UW9zYUpXSHlDWGFmc04xNUhkYzJjeFVnUWtsTlE5ME1iRWdK
d2lQcGhTcGdtTk9rQ0VwQm1JU0dxYzRwRQpsd3k3eHh5cGJzdnhyU3g0OHJ1NGtkSEwreUNNZzRj
RlNEbzM5bFJnMkNJaDhKQjJTZlN4cy9UUGpIS1FCRXdDCmR5UXhlSG5SbTlPMklma0NIMUdhenpO
bTRpUHh4WFp2Y0hncEphQVFPQWtmWlg2OEFoOUZyNFNlZHU4Z2k2Y3gKVGFFYStjSGpNaTJYMjBF
TjJhTnM5MklPYlVPWVdIcnYyQlRjSFV1QTZyU0NsQ2FKMFA3T3VaMytCaWYzaXZ1RwpkcWkreit3
Y0o0dUhtU3NQMDFOb1V3SzYvS1A1VFRxMks3UVNWaVhabVQwcndCbVQrRjE2VFcwSVMwaEk1OGpQ
ClZGV1ptTlI0dFlyRE9sT3pDWGZEZjEyRTh3WVRTVENIdTVLaWJaNmVOQWJjaDl3c2ZlUjkzK1Jr
M0VNeFFpTXYKK0RvamJ6RDRBdjBEa2U1ZnBoVzdxVmF2NFJoZlhONEpQbkdIYTA0KzhoQVozclR6
R0d2bXhXR2h0Q09tcnFMVQplc3FhdEFmTU9UV2xNbU96LzlwSHl5VzhmY3lIenBwaVI0cDJOMXF3
WWpDTjFMNnZsUks2bnlnZ0JJVUlXKy85Ck82Mkg4ZnNSRW44Ri9ZdEl6cVluelUwWEllMVBWRmg3
Z29Dam9Jdnh0QTBkbjh4aDF1akJocHNwakgrbXdXSzEKQWdNQkFBR2pnZ0dMTUlJQmh6QWRCZ05W
SFE0RUZnUVVsRURCWUpCOGt3N3o2dXkvMjJkd2JWSEFDUWt3Z2dFUQpCZ05WSFNNRWdnRUhNSUlC
QTRBVWxFREJZSkI4a3c3ejZ1eS8yMmR3YlZIQUNRbWhnZCtrZ2R3d2dka3hDekFKCkJnTlZCQVlU
QWxWVE1STXdFUVlEVlFRSUV3cERZV3hwWm05eWJtbGhNUkl3RUFZRFZRUUhFd2xUZFc1dWVYWmgK
YkdVeElEQWVCZ05WQkFvVEYxUnlhVzFpYkdVZ1RtRjJhV2RoZEdsdmJpQk1kR1F1TVNzd0tRWURW
UVFMRXlKVQpjbWx0WW14bElFTmxjblJwWm1sallYUnBibWNnUVhWMGFHOXlhWFI1SUhZek1Tc3dL
UVlEVlFRREV5SlVjbWx0CllteGxJRU5sY25ScFptbGpZWFJwYm1jZ1FYVjBhRzl5YVhSNUlIWXpN
U1V3SXdZSktvWklodmNOQVFrQkZoWlUKY21sdFlteGxMVU5CUUhSeWFXMWliR1V1WTI5dGdna0Ev
ckpabUpsSDJGWXdEQVlEVlIwVEJBVXdBd0VCL3pBaApCZ05WSFJFRUdqQVlnUlpVY21sdFlteGxM
VU5CUUhSeWFXMWliR1V1WTI5dE1DRUdBMVVkRWdRYU1CaUJGbFJ5CmFXMWliR1V0UTBGQWRISnBi
V0pzWlM1amIyMHdEUVlKS29aSWh2Y05BUUVNQlFBRGdnSUJBSW1VYVpibEVPNTIKYUxPQ2REMGd1
RFlEdHlQenJGQ1RHbFA2MHAzYjUzdFp2YlZtaFRLdm05VXE2MFFQVWQxZmNKOUZwUnA2ZlhibQpy
Ylg3NUZZY2lRSUtnRzkzNFRmeVFHQTFQbE94a1FTeVliNVRPbHZrUXIybDdwNjNmSFBtQUdJVmJh
MHNjUDkzCkM4RVJZM21XTWsvbGVhNmtjUTMyYzN5Sis1Q3VEVitjQUpVM3ZaZm5MUXBGdWhKNnVq
aktDbThjOG1zY0FZYWsKc0M1T0V1L0ZVWENTMWtoQjRscW9vbXJkV3ozWFpOZ2Y0ZUlvR3VyYll0
c2lLR2kvWnFiQnpWRjdOL1VhVjR2SwpRZDI5TGlZNG5vN3lzRTNUbDVlS21XeElmVFIyQ1hDaVBY
VFRWS0ZPNnViejRrK1VjUVhTSU5WaVR2bFN3S05RCkhIZi9GcTlKei9PbTVERlBUa2FwUlZrNWJB
NEsyb2ZyKzI1QzBqSlZqWkpUakUxMUtvckI0aFBxSEJxV2g3VkQKdlkyRVFOeGp6UWFPVDlUejFO
SG51d1BldjhSdC94U1U2aElUZjRTbURYTGhmWHhFOFB5aFV0VFNEUmZudVArQgozVTBVS1ZlbFoz
NTUvR0hZU3pRZkxLRkR5QjdXcDVWK20veVQ5SXBxZlZiSjBBYlhJOGN3U0hDaGd4OXpCSmRmCm1n
U1N6Qkt3cll3N0JxTHFLbkRxdmpjek1kMFptNU9xWkFhYi85WWdLeVFXQmNKd2VxS1ZwRWhvUFVu
Mk1GQ2cKdm1pZWlXZ1VUQ0gxOW03TVJkL0cwK1lMRHB4T2xTY1p0UjZ0Nm9ObUJ4VVpPZUgxSXFS
UElmNWJ6QUFCbnIvVQo0cjIwZjQ4MzNoUzlweE5GeWNnQjNNU1Nka0JqbzBwMQotLS0tLUVORCBD
RVJUSUZJQ0FURS0tLS0tCg==
EOF
)|base64 -d> /etc/Trimble-CA3.pem
cat /etc/Trimble-CA3.pem /etc/Trimble-CA2.pem > /etc/Trimble-CAs.pem

if [ -d /etc/security/limits.d ]; then
	printf "# make sure file descriptors are high enough to keep code42 happy\n*\t-\tnofile\t409600\n" > /etc/security/limits.d/90-code42.conf
fi

if [ "`which curl 2>/dev/null|grep /`" != "" ]; then
	curl -A $prog -s -o unix-tibs-access.sh "https://cis-infosec.trimble.com/unix-tibs-access.sh" 2>/dev/null
else
	wget "https://cis-infosec.trimble.com/unix-tibs-access.sh" 2>/dev/null
fi

bash unix-tibs-access.sh --workstation
if [ $? -ne 0 ]; then
        echo "Fatal error in unix-tibs-access.sh - fix and re-run"
        exit 1
fi

echo ""
if [ "$DISABLE_FDE" != "1" ]; then
	echo "This script will convert a *new* encrypted Linux laptop into a CIS workstation."
	#grab first Linux non-boot partition, as it should be the encrypted one
	for part in `fdisk -l 2>/dev/null|egrep '(nvme|mmcb|sda).*Linux|loop'|sed -e 's/^Disk //g' |awk '{print $1}'|sed 's/:$//g'`
	do
		if [ "$RAW_FDE_PARTITION" == "" ]; then
			cryptsetup isLuks $part
			isLuks=$?
			if [ $isLuks -eq 0 ]; then
				RAW_FDE_PARTITION=$part
			fi
		fi
	done
	if [ "$RAW_FDE_PARTITION" != "" ]; then
		export LUKSDUMP=`cryptsetup luksDump $RAW_FDE_PARTITION 2>/dev/null`
		if [ "`echo \"$LUKSDUMP\"|egrep 'Key Slot .*ENABLED'`" == "" ]; then
			#hmm, is this luks2?
			if [ "`echo \"$LUKSDUMP\"|sed -e '/^Tokens:/ q' -e '1,/^Keyslots:/ d'|grep ': luks2$'`" == "" ]; then
				unset RAW_FDE_PARTITION
			fi
		fi
	fi	
else
	echo "This script will convert a *new* Linux $WS_DESC into a CIS workstation."
fi



cat<<EOF

It will use the username you provide it with to define the primary user/owner and will 
use that information to create an appropriate hostname, and will create a local username 
for that user to use. This script will automatically create a default password for the 
user to use, but you should tell the user to manually change it to match their AD password 
and that they will have to manually keep them in sync going forward.

EOF
if [ "$DISABLE_FDE" != "1" ]; then
	echo "The workstation *must have an encrypted harddisk* (Full Disk Encryption) before this script will run."
	if [ "$RAW_FDE_PARTITION" == "" ]; then
		cat<<EOF

Unfortunately, that is not the case on this system, so this script will now exit...

EOF
		exit 1
	else
		cat<<EOF

You should have set the FDE password to a password that is stored somewhere in case of emergency.
As part of the install, this script will ask you for that boot-time password, it will use it to add 
a *second* FDE password (yes, Linux supports this  - like FileVault for Macs), and will
set it to the same value as the user password it creates. i.e the end result is that helpdesk
will be able to unlock the disk with a "CIS Linux FDE recovery key" and the user will be able to use 
their own separate one. 

EOF
	fi
fi
cat<<EOF

Besides joining it to the domain, it will install the following software:

* Google-Chrome and Firefox
* configures system to auto-patch, tibs/nessus scanner access
* Crowdstrike, NessusAgent
* Always-on VPN (openvpn). So be prepared to add this new AD host to TRIMBLECORP/SWD-OpenVPN-Global-Install afterwards


EOF

echo -ne "Hit ENTER to continue: "
read ans

if [ "$DISABLE_FDE" != "1" ]; then
        if [ "`dmsetup status 2>/dev/null|grep crypt`" == "" ]; then
                echo "Fatal error. All CIS laptops must be encrypted. You will need to REINSTALL and"
                echo "choose encryption during the installation process"
                exit 1
        fi
fi

OVERRIDE_HOSTNAME=`echo $OVERRIDE_HOSTNAME|cut -d. -f1`

if [ "$PRIMARY_USER" == "" ]; then
        echo -ne "Primary owner username [DOM/username]: "
        read PRIMARY_USER
fi
if [ "`echo $PRIMARY_USER|egrep -i '^[a-z]+/[a-z0-9]+$'`" == "" ]; then
        echo "Error: username not in correct format [DOM/username]. Try again"
	echo -ne "Enter username [DOM/username]: "
	read PRIMARY_USER
	if [ "`echo $PRIMARY_USER|egrep -i '^[a-z]+/[a-z0-9]+$'`" == "" ]; then
		echo "Error: username not in correct format [DOM/username]."
        	exit 1
	fi
fi

if [ "$COUNTRY_CODE" == "" ]; then
        echo -ne "Enter two-letter country-code this host will live in (to create ${PRIMARY_USER}-XX-${WS_TYPE}l): "
        read COUNTRY_CODE
fi
if [ "`echo $COUNTRY_CODE|egrep -i \"^[a-z][a-z]$\"`" == "" ]; then
        echo "Error: country code is not two letters. Try again"
	echo -ne "Enter two-letter country-code that host will live in (to create ${PRIMARY_USER}-XX-${WS_TYPE}l): "
	read COUNTRY_CODE
	if [ "`echo $COUNTRY_CODE|egrep -i \"^[a-z][a-z]$\"`" == "" ]; then
		echo "Error: country code is not two letters."
        	exit 1
	else
		COUNTRY_CODE=`echo $COUNTRY_CODE|awk '{print tolower($0)}'`
	fi
fi

PRIMARY_DOMAIN=`echo $PRIMARY_USER|cut -d/ -f1|awk '{print toupper($0)}'|cut -d. -f1`
PRIMARY_USER=`echo $PRIMARY_USER|cut -d/ -f2`
if [ "`echo $PRIMARY_DOMAIN|grep -i ^trimblecorp`" != "" ]; then
	PRIMARY_AD_REALM="TRIMBLECORP"
else
	PRIMARY_AD_REALM=`echo $PRIMARY_DOMAIN".trimblecorp.net"|awk '{print toupper($0)}'`
fi

export PRIMARY_USER PRIMARY_DOMAIN PRIMARY_AD_REALM

if [ "`echo $PRIMARY_DOMAIN|egrep -i '^(ap|eu|am)$'`" == "" ]; then
	echo "Error: \"$PRIMARY_DOMAIN\" is not a corporate domain (AP,EU,AM) - exiting"
	exit 1
fi

export IPADDR=`ip addr 2>/dev/null|grep 'inet '|egrep -v '127.0.0.'|awk '{print $2}'|cut -d/ -f1|head -1`
if [ "$IPADDR" == "" ]; then
	echo "Fatal error - cannot find live IP address - this host isn't on a network?"
	exit 1
fi

#Get WiFi
INT_WIFI=`iwconfig 2>/dev/null|grep 802.11|head -1|awk '{print $1}'`
if [ "$INT_WIFI" != "" ]; then
	echo "This system has WiFi - make sure DaVinci exists and is configured correctly" > /dev/null
	DV=`nmcli connection show 2>/dev/null|grep ^DaVinci`
	if [ "$DV" == "" ]; then
		nmcli conn add connection.type 802-11-wireless con-name DaVinci ifname $INT_WIFI ssid DaVinci >/dev/null 2>&1 || nmcli conn add connection.type wifi  con-name DaVinci ifname $INT_WIFI ssid DaVinci > /dev/null 2>&1
	fi
	#now DaVinci must be defined, so force correct settings
	nmcli conn modify DaVinci 802-1x.identity $PRIMARY_USER@$PRIMARY_AD_REALM 802-1x.anonymous-identity $PRIMARY_USER@$PRIMARY_AD_REALM 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.phase1-peapver 0 802-1x.ca-cert /etc/Trimble-CAs.pem ipv4.method auto connection.permissions "" 802-11-wireless-security.key-mgmt wpa-eap 802-11-wireless-security.auth-alg open 802-11-wireless.hidden yes > /dev/null 2>&1
	nmcli conn modify DaVinci 802-1x.password-flags 0x1 connection.autoconnect yes > /dev/null 2>&1
	#hopefully the first time the primary user connects to DaVinci, they'll only be prompted for password and all the other settings will be pre-set
fi


#if [ -f "/etc/gdm3/custom.conf" -a "`grep '^WaylandEnable=false' /etc/gdm3/custom.conf`" != "" ]; then
#	sed -i 's/^#WaylandEnable=false/WaylandEnable=false/g' /etc/gdm3/custom.conf
#fi

#nslookup to test we're on the internal network
DD=`nslookup $PRIMARY_AD_REALM 2>/dev/null|grep ^Name|grep -i $PRIMARY_AD_REALM`
if [ "$DD" == "" ]; then
	echo "Error: cannot see $PRIMARY_AD_REALM, network is not working?"
	exit 1
fi

#find closest DNS server to use as LDAP and Domain controller
ALL_REALM_DNS=`nslookup $PRIMARY_AD_REALM 2>/dev/null|grep ^Add|tail --lines=+2|awk '{print $NF}'`

FPING=`fping $ALL_REALM_DNS 2>/dev/null|grep alive|awk '{print $1}'`

#make sure they are LDAPS-capable
unset CLOSEST_REALM_SERVER SECOND_CLOSEST_REALM_SERVER
for potential in $FPING
do
	if [ "$SECOND_CLOSEST_REALM_SERVER" = "" ]; then
		DD=`echo ""|timeout 20 openssl s_client -connect $potential:636 2>/dev/null|grep ^issuer`
		if [ "$DD" != "" ]; then
			if [ "$CLOSEST_REALM_SERVER" = "" ]; then
				CLOSEST_REALM_SERVER="$potential"
			else
				SECOND_CLOSEST_REALM_SERVER="$potential"
			fi
		fi
	fi
done
 
if [ "$CLOSEST_REALM_SERVER" == "" ]; then
	echo "Error: cannot ping $PRIMARY_AD_REALM IP addresses, network problem?"
	exit 1
else
	if [ "`grep 'really nasty, but hopefully' /etc/hosts`" == "" ]; then
		echo "### $0:really nasty, but hopefully fixes DNS bug in Ubuntu" >> /etc/hosts
		echo "$CLOSEST_REALM_SERVER	$PRIMARY_AD_REALM" >> /etc/hosts
		if [ "$SECOND_CLOSEST_REALM_SERVER" != "" ]; then
			echo "$SECOND_CLOSEST_REALM_SERVER	$PRIMARY_AD_REALM" >> /etc/hosts
		fi
	fi
fi


if [ "`grep -i ubuntu /etc/os-release 2>/dev/null`" != "" ]; then
	OS_VENDOR="Ubuntu"
	OS_VERSION=`grep ^VERSION_ID= /etc/os-release|sed -e 's/^VERSION_ID=//g' -e 's/"//g'|awk '{print $1}'`
	if [ "`echo $OS_VERSION|egrep '^(22|20|18)'`" == "" ]; then
		echo "Error - this Ubuntu system is too old and cannot be supported"
		exit 1
	fi
	OS_TYPE='l'
	PKG="apt"
elif [ "`egrep -i 'fedora' /etc/os-release /etc/redhat-release 2>/dev/null`" != "" ]; then
        OS_VENDOR="Fedora"
	if [ "`echo $OS_VENDOR|grep Amazon`" != "" ]; then
		OS_VENDOR="Amazon"
	fi
	OS_VERSION=`grep ^VERSION_ID= /etc/os-release|sed -e 's/^VERSION_ID=//g' -e 's/"//g'|awk '{print $1}'`
	OS_TYPE='l'
	PKG="yum"
else
	echo "Fatal error: unsupported OS - only Ubuntu and Fedora are supported"
	exit 1
fi

mkdir -p /root/.tmp
TMPDIR=`mktemp -d /root/.tmp/$prog-XXXXXX`
cd $TMPDIR

ldapConf="/etc/ldap/ldap.conf"

echo ""
echo "Ensure needed standard packages are installed (will take a while...)"
if [ "$OS_VENDOR" == "Ubuntu" ]; then
	#disable packagekit during this install to stop locking issues
	systemctl stop packagekit  > /dev/null 2>&1
	UMPID=`ps auxw|grep update-manager|grep -v grep|awk '{print $2}'|egrep '^[0-9]*$'|egrep -v '^1$'`
	if [ "$UMPID" != "" ]; then
		kill $UMPID > /dev/null 2>&1
	fi

	systemctl stop packagekit  > /dev/null 2>&1
	apt -y install openssh-server > /dev/null 2>&1
	(apt -y install fping at curl wget libnss3-tools network-manager-openconnect-gnome samba ubuntu-desktop network-manager-openvpn-gnome openvpn openvpn-systemd-resolved pwgen firefox dnsutils dmidecode ldap-utils unattended-upgrades samba-common-bin wireless-tools $vmtools ; apt -y install fping at curl wget libnss3-tools network-manager-openconnect-gnome samba network-manager-openvpn-gnome openvpn openvpn-systemd-resolved pwgen firefox dnsutils dmidecode ldap-utils unattended-upgrades samba-common-bin wireless-tools $vmtools ) > apt-install.err 2>&1&

#	if [ "`dmidecode 2>/dev/null|grep -i nvidia`" != "" ]; then 
	#add testing support to get NVidia drivers
#	       	add-apt-repository -y ppa:graphics-drivers/ppa > /dev/null 2>&1
#        	apt update  > /dev/null 2>&1
#        	apt -y install nvidia-driver-390 > /dev/null 2>&1
#        	apt -y install nvidia-driver-430 > /dev/null 2>&1
#	fi

	systemctl stop packagekit  > /dev/null 2>&1
	spinner apt-install.err
	apt -y remove 'thunderbird*' > /dev/null 2>&1
	systemctl stop packagekit  > /dev/null 2>&1
	#force full upgrade
	systemctl stop packagekit  > /dev/null 2>&1
	apt -y upgrade > apt-upgrade.err 2>&1&
	spinner apt-upgrade.err
	systemctl stop packagekit  > /dev/null 2>&1
	#add additional drivers if discovered
	(ubuntu-drivers list ; ubuntu-drivers autoinstall ) > /dev/null 2>&1
	systemctl stop packagekit  > /dev/null 2>&1
	(systemctl enable ssh ; systemctl start ssh ; systemctl enable smbd ; systemctl start smbd) > /dev/null 2>&1
	systemctl restart systemd-resolved > /dev/null 2>&1
	#automate patching
	if [ -d /etc/apt/sources.list.d -a ! -f /etc/apt/sources.list.d/endpoint-verification.list ]; then
		echo "deb https://packages.cloud.google.com/apt endpoint-verification main" > /etc/apt/sources.list.d/endpoint-verification.list
		curl -s -m 30 https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - > /dev/null 2>&1
		apt update > /dev/null 2>&1
		apt -y install endpoint-verification > /dev/null 2>&1
	fi
	if [ -f "/etc/apt/apt.conf.d/10periodic" ]; then
		if [ "`grep 'APT::Periodic::Download-Upgradeable-Packages' /etc/apt/apt.conf.d/10periodic`" != "" -a "`grep 'APT::Periodic::Download-Upgradeable-Packages.*0' /etc/apt/apt.conf.d/10periodic`" != "" ]; then
			sed -e 's/APT::Periodic::Download-Upgradeable-Packages.*/APT::Periodic::Download-Upgradeable-Packages "1";/g' /etc/apt/apt.conf.d/10periodic > /etc/apt/apt.conf.d/10periodic.tmp && mv -f /etc/apt/apt.conf.d/10periodic.tmp /etc/apt/apt.conf.d/10periodic
		fi
		if [ "`grep 'APT::Periodic::Unattended-Upgrade' /etc/apt/apt.conf.d/10periodic`" != "" -a "`grep 'APT::Periodic::Unattended-Upgrade.*0' /etc/apt/apt.conf.d/10periodic`" != "" ]; then
			sed -e 's/APT::Periodic::Unattended-Upgrade.*/APT::Periodic::Unattended-Upgrade "1";/g' /etc/apt/apt.conf.d/10periodic > /etc/apt/apt.conf.d/10periodic.tmp &&
 			mv -f /etc/apt/apt.conf.d/10periodic.tmp /etc/apt/apt.conf.d/10periodic
		fi
	fi
	if [ -f "/etc/apt/apt.conf.d/20auto-upgrades" ]; then
		if [ "`grep 'APT::Periodic::Unattended-Upgrade.*0' /etc/apt/apt.conf.d/20auto-upgrades`" != "" ]; then
			sed -e 's/APT::Periodic::Unattended-Upgrade.*/APT::Periodic::Unattended-Upgrade "1";/g' /etc/apt/apt.conf.d/20auto-upgrades > /etc/apt/apt.conf.d/20auto-upgrades.tmp && mv -f /etc/apt/apt.conf.d/20auto-upgrades.tmp /etc/apt/apt.conf.d/20auto-upgrades
		fi
	fi
	ldapConf="/etc/ldap/ldap.conf"
	echo ""
	if [ ! -x "/usr/bin/google-chrome-stable" ]; then
		echo "Install Google Chrome (big download - will take a while)"
		curl -sL -O https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
		apt -y install  ./google-chrome-stable_current_amd64.deb > /dev/null 2>&1
	fi
	if [ ! -f "/usr/bin/teamviewer" ]; then
		echo "Install Teamviewer"
		curl -sL -O https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
		apt -y install  ./teamviewer_amd64.deb > /dev/null 2>&1
		#reinstall certain pkgs that teamviewer depends on
		apt-get -y --reinstall install libqt5dbus5 libqt5widgets5 libqt5network5 libqt5gui5 libqt5core5a libdouble-conversion1 libxcb-xinerama0  > /dev/null 2>&1
	fi
else
	yum -y install fping wireless-tools wget at curl firefox NetworkManager-openconnect-gnome openldap-clients openvpn pwgen samba samba-common yum-cron-daily bind-utils dmidecode openldap-clients openssh-server $vmtools > yum-install.err 2>&1
	yum -y erase 'thunderbird*' > /dev/null 2>&1
	yum -y update > /dev/null 2>&1
	(systemctl enable sshd ; systemctl start sshd; systemctl enable smb ; systemctl start smb) > /dev/null 2>&1
	ldapConf="/etc/openldap/ldap.conf"
	echo ""
	if [ ! -x "/usr/bin/google-chrome-stable" ]; then
		echo "Install Google Chrome (big download - will take a while)"
		curl -sL -O https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
		yum -y install ./google-chrome-stable_current_x86_64.rpm > /dev/null 2>&1
	fi
	if [ ! -f "/usr/bin/teamviewer" ]; then
                echo "Install Teamviewer"
                curl -sL -O https://download.teamviewer.com/download/linux/teamviewer.x86_64.rpm
                yum -y install  ./teamviewer.x86_64.rpm > /dev/null 2>&1
        fi
fi

#move first account (probably helpdesk_local) to >999 to make it system account
FIRST_USER=`grep :x:1000:1000: /etc/passwd|egrep -vi "^$PRIMARY_USER:"|cut -d: -f1|head -1`
if [ "$FIRST_USER" != "" -a "`echo $FIRST_USER|grep -i ^$PRIMARY_USER`" == "" ]; then
        #force account to uid=888
        sed -i "s/^$FIRST_USER:x:1000:1000:/$FIRST_USER:x:888:888:/g" /etc/passwd
        groupmod -g 888 helpdesk_local # ADDED
        chown -R $FIRST_USER:888 /home/$FIRST_USER > alter-$FIRST_USER.err 2>&1
    if [ -f "/var/lib/AccountsService/users/$FIRST_USER" ]; then
        sed -i -e 's/^SystemAccount=false/SystemAccount=true/g' "/var/lib/AccountsService/users/$FIRST_USER"
    fi
fi

#make sure ldap can talk to DCs, disable cert validation
if [ -f $ldapConf ]; then
	(cat<<EOF
#disable cert validation - too much self-signed in Trimble to bother
TLS_REQCERT	never
EOF
) >> $ldapConf 
fi


export NEW_USER_PASSWORD=`pwgen 10 1 2>/dev/null`

echo ""

export PKG OS_TYPE OS_VENDOR


FPING_TARGETS=`nslookup  $PRIMARY_AD_REALM 2>/dev/null|grep ^Add|egrep ' 10\.'|awk '{print $2}'`

DMIDECODE=`dmidecode 2>/dev/null`

if [ "`grep -i $PRIMARY_AD_REALM /etc/krb5.conf 2>/dev/null`" == "" ]; then
        (cat<<EOF
includedir /etc/krb5.conf.d/
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log
[libdefaults]
 dns_canonicalize_hostname = false
 dns_lookup_realm = true
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = $PRIMARY_AD_REALM
 default_ccache_name = KEYRING:persistent:%{uid}
[realms]
 $PRIMARY_AD_REALM = {
        kdc = $PRIMARY_AD_REALM
        admin_server = kerberos.$PRIMARY_AD_REALM
 }
EOF
)>/etc/krb5.conf
	for realm in EU AP AM 
	do
		if [ "`echo $PRIMARY_AD_REALM|grep ^$realm`" == "" ]; then
			(cat<<EOF
 $realm.TRIMBLECORP.NET = {
        kdc = $realm.TRIMBLECORP.NET
        admin_server = kerberos.$realm.TRIMBLECORP.NET
 }
EOF
)>>/etc/krb5.conf
		fi
	done
	if [ "`echo $PRIMARY_AD_REALM|grep ^TRIMBLECORP`" == "" ]; then
		(cat<<EOF
 TRIMBLECORP.NET = {
 	kdc = TRIMBLECORP.NET
	admin_server = kerberos.TRIMBLECORP.NET
 }

EOF
) >> /etc/krb5.conf
	fi
	echo "[domain_realm]" >>/etc/krb5.conf
fi

#with that file in place, it should now be safe to do unattended krb5 install
apt -y install krb5-user  > /dev/null 2>&1
yum -y install krb5-workstation > /dev/null 2>&1

PRIMARY_WORKSTATION="${PRIMARY_USER}-${COUNTRY_CODE}-${WS_TYPE}${OS_TYPE}"

echo "Enter $PRIMARY_DOMAIN Active Directory creds that can be used to query and add a host to the $PRIMARY_DOMAIN domain"
echo "- make sure it has privileges to add computers to $PRIMARY_DOMAIN"
echo "(safe/not stored: just used as a one-off)"
echo ""
echo -ne "Username to use (default:$PRIMARY_DOMAIN/$PRIMARY_USER): "
read adUser
if [ "$adUser" == "" ]; then
	adDom="$PRIMARY_DOMAIN"
	adUser="$PRIMARY_USER"
fi
if [ "`echo $adUser|grep /`" != "" ]; then
	adDom=`echo $adUser|cut -d/ -f1|cut -d. -f1`
	adUser=`echo $adUser|cut -d/ -f2`
else
	adDom="$PRIMARY_DOMAIN"
fi
export pwdFile=`mktemp /dev/shm/adPwd-XXXXXX`

echo -ne "Password for $adDom/$adUser: "
read -s -r adPassword
if [ "$adPassword" == "" ]; then
	echo
	echo -ne "Password for $adDom/$adUser: "
	read -s -r adPassword
fi
if [ "`echo $adDom|grep -i ^trimblecorp`" == "" ]; then
	adRealm="$adDom.trimblecorp.net"
else
	adRealm="trimblecorp.net"
fi
adRealm=`echo $adRealm|awk '{print toupper($0)}'`


echo -ne "$adPassword" > $pwdFile

echo ""

BASE=`echo $PRIMARY_AD_REALM|sed -e 's/\./,dc=/g' -e 's/^/dc=/g'`

#get AD details for username
ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$CLOSEST_REALM_SERVER -b "$BASE" "(sAMAccountName=$PRIMARY_USER)" > ldapsearch-sAMAccountName.txt 2>ldapsearch-sAMAccountName.err
adStatus=$?
AD_DETAILS=`cat ldapsearch-sAMAccountName.txt`
if [ "`echo \"$AD_DETAILS\"|egrep ^dn:`" == "" ]; then
	if [ "`grep -i 'invalid' ldapsearch-sAMAccountName.err`" != "" ]; then
		echo "Failed to connect to LDAP server ($CLOSEST_REALM_SERVER), bad credentials, try again"
		echo -ne "Username to use (default:$adDom/$adUser): "
		read adUser2
		if [ "$adUser2" == "" ]; then
			true
		else
			if [ "`echo $adUser2|grep /`" != "" ]; then
				adDom=`echo $adUser2|cut -d/ -f1`
				adUser=`echo $adUser2|cut -d/ -f2`
			fi
		fi
		echo -ne "Password for $adDom/$adUser: "
		read -s -r adPassword
		echo -ne "$adPassword" > $pwdFile
		if [ "`echo $adDom|grep -i trimblecorp`" == "" ]; then
			adRealm="$adDom.trimblecorp.net"
		else
			adRealm="trimblecorp.net"
		fi
		adRealm=`echo $adRealm|awk '{print toupper($0)}'`
		ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$CLOSEST_REALM_SERVER -b "$BASE" "(sAMAccountName=$PRIMARY_USER)" > ldapsearch-sAMAccountName-2.txt 2>ldapsearch-sAMAccountName-2.err
		adStatus=$?
		AD_DETAILS=`cat ldapsearch-sAMAccountName-2.txt`
	else
		echo "maybe the user doesn't exist?" > /dev/null
		XX=`ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$CLOSEST_REALM_SERVER -b "$BASE" "(sAMAccountName=administrator)" cn lastLogonTimestamp lastLogonname userPrincipalName 2>&1`
		if [ "`echo \"$XX\"|grep ^userPrincipalName`" != "" ]; then
			echo "Active Directory has no record of $adDom/$PRIMARY_USER - did you make a spelling mistake? Exiting..."
			rm -f /dev/shm/adPwd*
			exit 1
		fi
		echo "Failed to connect to LDAP server ($CLOSEST_REALM_SERVER)"
		cat ldapsearch-sAMAccountName.err
		rm -f /dev/shm/adPwd*
		exit 1
	fi
fi

if [ "`echo \"$AD_DETAILS\"|egrep ^dn:`" == "" ]; then
	echo "Failed to connect to LDAP server ($CLOSEST_REALM_SERVER), giving up"
	rm -f /dev/shm/adPwd*
	exit 1
fi

#get primary user DN
AD_USER_DN=`echo "$AD_DETAILS"|grep ^dn:|sed -e 's/^dn: //g'`
AD_USER_CN=`echo "$AD_DETAILS"|grep ^cn:|sed -e 's/^cn: //g'`
AD_USER_MAIL=`echo "$AD_DETAILS"|grep ^mail:|sed -e 's/^mail: //g'`


#set password policy for system
if [ -f "/etc/security/pwquality.conf" ]; then
	echo "#Trimble Password Policy" >> /etc/security/pwquality.conf
	echo "gecoscheck = 1" >> /etc/security/pwquality.conf
	echo "minlen = 8" >> /etc/security/pwquality.conf
	echo -ne "dictcheck = 1\nusercheck = 1\n" >> /etc/security/pwquality.conf
fi

#create local user - with sudo/admin privs
wheel="sudo"
if [ "`grep ^$wheel /etc/group`" == "" ]; then
	wheel="wheel"
fi
useradd -m -s /bin/bash -U -c "$AD_USER_CN" -G "$wheel,adm,cdrom"  $PRIMARY_USER > /dev/null 2>&1
echo "$PRIMARY_USER:$NEW_USER_PASSWORD" |chpasswd > chpasswd.out 2>&1

cat<<EOF

New local username "$PRIMARY_USER" has been created with password: "$NEW_USER_PASSWORD".
Please write that down to hand over to $AD_USER_CN.

We recommend they reset that to their current AD password

EOF

echo -ne "Hit ENTER to continue: "
read ans

#force secondary dm-crypt password to same value

if [ "$DISABLE_FDE" != "1" ]; then
	cat<<EOF

We will now set a secondary FDE encryption password to the same value as 
$PRIMARY_USER's password ($NEW_USER_PASSWORD).

When prompted, please enter the *current* FDE encryption password, which will
allow us to unlock the encrypted disk and set the secondary password.

EOF

	echo -ne "Please enter the *current* FDE recovery key: "
	read  -r passphrase
	if [ "$passphrase" == "$NEW_USER_PASSWORD" ]; then
		echo -ne "Nope - I said the *current* FDE key - not the new one"
		exit 1
	fi

	#always make the CIS key slot 0 and the primary user key slot 1
	echo ""
	echo "Attempting to insert new key..."
	cryptsetup luksKillSlot $RAW_FDE_PARTITION 1 -q > cryptsetup-luksKillSlot.err 2>&1
	(sleep 4 ; echo "$passphrase"; sleep 4 ; echo "$NEW_USER_PASSWORD"; sleep 2; echo "$NEW_USER_PASSWORD"; sleep 2)|cryptsetup luksAddKey $RAW_FDE_PARTITION --key-slot 1 > cryptsetup-luksAddKey.err 2>&1
	if [ $? -ne 0 ]; then
		echo "Failed operation - bad password. Try again"
		echo -ne "Please enter the *current* FDE recovery key: "
		read -r passphrase
		echo ""
		echo "Attempting to insert new key..."
		cryptsetup luksKillSlot $RAW_FDE_PARTITION 1 -q > cryptsetup-luksKillSlot.err 2>&1
        	(sleep 4 ; echo "$passphrase"; sleep 4 ; echo "$NEW_USER_PASSWORD"; sleep 2; echo "$NEW_USER_PASSWORD"; sleep 2)|cryptsetup luksAddKey $RAW_FDE_PARTITION --key-slot 1 > cryptsetup-luksAddKey.err 2>&1
	fi
	if [ $? -ne 0 ]; then
		echo "Fatal error: bad password? Cannot continue"
		rm -f /dev/shm/adPwd*
		exit 1
	fi

	cat<<EOF


OK, we have successfully set a secondary FDE encryption password.
The user should change it to something more memorable - like 
their AD password. To do that, they must run

[GUI] - Activities->Disks->(find LUKS partition)->Change Passphrase

or

[SHELL] - sudo cryptsetup luksChangeKey $RAW_FDE_PARTITION

EOF
	echo -ne "Hit ENTER to continue: "
	read ans
fi

#Add Trimble CA certs
for i in /etc/Trimble-CA2.pem /etc/Trimble-CA3.pem
do
        if [ -d /etc/pki/tls/certs ]; then
                #Redhat/CentOS
                if [ ! -f /etc/pki/tls/certs/`basename $i .pem`.crt ]; then
                        ln -s $i /etc/pki/tls/certs/`basename $i .pem`.crt
                fi
		if [ -d /etc/pki/ca-trust/source/anchors ]; then
			#Redhat/CentOS
			if [ ! -f /etc/pki/ca-trust/source/anchors/`basename $i .pem`.crt ]; then
				ln -s $i /etc/pki/ca-trust/source/anchors/`basename $i .pem`.crt
			fi
		fi
        else
                #Ubuntu
                mkdir -p /usr/local/share/ca-certificates/
                if [ ! -f /usr/local/share/ca-certificates/`basename $i .pem`.crt ]; then
                        ln -s $i /usr/local/share/ca-certificates/`basename $i .pem`.crt
                fi
        fi
done
(
#update Ubuntu (affects curl and other system tools - but NOT browsers!!!
update-ca-certificates
#update Fedora/CentOS/RHE system tools
update-ca-trust
) > /dev/null 2>&1



#Chrome gets certs from $HOME/.pki
mkdir -p /home/$PRIMARY_USER/.pki/nssdb
certutil -d sql:/home/$PRIMARY_USER/.pki/nssdb -A -t TC -n "Trimble-CA2" -i /etc/Trimble-CA2.pem
certutil -d sql:/home/$PRIMARY_USER/.pki/nssdb -A -t TC -n "Trimble-CA3" -i /etc/Trimble-CA3.pem
chown -R $PRIMARY_USER:$PRIMARY_USER /home/$PRIMARY_USER/.pki

#firefox has it's own store, so initialize
if [ ! -d "/home/$PRIMARY_USER/.mozilla/firefox" ]; then
	runuser -u $PRIMARY_USER -- timeout 10 firefox --headless > /dev/null 2>&1
	FF_PATH=`/bin/ls -ltrd /home/$PRIMARY_USER/.mozilla/firefox/*.default|awk '{print $NF}'|tail -1`
	if [ -d "$FF_PATH" ]; then
		runuser -u $PRIMARY_USER -- certutil -A -n "Trimble-CA2" -t "CT,C,C" -d sql:$FF_PATH -i /etc/Trimble-CA2.pem 
		runuser -u $PRIMARY_USER -- certutil -A -n "Trimble-CA3" -t "CT,C,C" -d sql:$FF_PATH -i /etc/Trimble-CA3.pem
	fi
fi


#now discover workstations
DD=`ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$CLOSEST_REALM_SERVER -b "$BASE" "(cn=${PRIMARY_WORKSTATION}*)" cn 2>/dev/null|grep '^cn: '|sed -e 's/^cn: //g'`
if [ "$DD" != "" ]; then
	#first remove non-numbered version
	DD=`echo "$DD"|egrep -vi "^$PRIMARY_WORKSTATION$"`
	if [ "$DD" != "" ]; then
		DD_NUM=`echo "$DD"|sed -e "s?^$PRIMARY_WORKSTATION??gi"|sort -n|tail -1|egrep -o '[0-9]*$'|grep -v '^0$'`
		DD_NUM=${DD_NUM:-1}
		DD_NUM=`expr $DD_NUM + 1`
	else
		DD_NUM=2
	fi
	if [ $DD_NUM -gt 1 ]; then
		PRIMARY_WORKSTATION="${PRIMARY_WORKSTATION}0$DD_NUM"
	fi
fi

if [ "$OVERRIDE_HOSTNAME" != "" ]; then
	export PRIMARY_WORKSTATION="$OVERRIDE_HOSTNAME"
fi

echo ""
echo "Please confirm or change the hostname to add to the $PRIMARY_DOMAIN domain."
echo -ne "$PRIMARY_WORKSTATION: "
read ans
if [ "$ans" != "" ]; then
	if [ "`echo $ans|egrep -i \"^[a-z0-9\-]+$\"`" != "" ]; then
       		export PRIMARY_WORKSTATION="$ans"
	fi
fi


echo ""
echo "Ready to name this host $PRIMARY_DOMAIN/$PRIMARY_WORKSTATION and add it to AD."
echo -ne "Shall I continue: [Y]/n "
read ans
if [ "`echo $ans|egrep -i 'n|0'`" != "" ]; then
	rm -f /dev/shm/adPwd*
	exit
fi

dnsname=`echo $PRIMARY_WORKSTATION.$PRIMARY_AD_REALM|awk '{print tolower($0)}'`
sed -i "s/$HOSTNAME.*/$dnsname $PRIMARY_WORKSTATION/ig" /etc/hosts
if [ -f "/etc/hostname" ]; then
	sed -i "s/$HOSTNAME.*/$PRIMARY_WORKSTATION/gi" /etc/hostname
fi

#now set new HOSTNAME so that other commands in this script get the correct value
export HOSTNAME="$dnsname"
hostname $dnsname 


if [ "`grep $PRIMARY_AD_REALM /etc/samba/smb.conf 2>/dev/null`" == "" ]; then
	(cat<<EOF
[global]
	workgroup = $PRIMARY_DOMAIN
	realm = $PRIMARY_AD_REALM
	server string = Samba Server Version %v
	log file = /var/log/samba/log.%m
	log level = 9
	max log size = 50
	security = ads
	passdb backend = tdbsam
	load printers = yes
	cups options = raw
	winbind cache time = 36000
	winbind enum groups = No
	winbind enum users = No
	winbind expand groups = 0
	winbind max clients = 200
	winbind max domain connections = 1
	winbind nested groups = Yes
	winbind offline logon = Yes
	winbind request timeout = 60
	winbind rpc only = No
	winbind sealed pipes = Yes
	winbind trusted domains only = Yes
	winbind use default domain = No
[homes]
	comment = Home Directories
	browseable = no
	writable = yes
[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = no
	guest ok = no
	writable = no
	printable = yes
EOF
)> /etc/samba/smb.conf
	mkdir -p /var/spool/samba /var/log/samba /etc/krb5.conf.d
fi

(sleep 2; echo "$adPassword")|kinit $adUser@$adRealm > /dev/null 2>&1


net ads join -k -U"$adUser@$adRealm%$adPassword" -I $CLOSEST_REALM_SERVER -d10 -W$PRIMARY_DOMAIN osName=$OS_VENDOR osVer=$OS_VERSION > net-ads-join.txt 2>net-ads-join.err
if [ "`grep  '^Join' net-ads-join.txt`" == "" ]; then
	sleep 5
	net ads join -k -U"$adUser@$adRealm%$adPassword" -I $CLOSEST_REALM_SERVER -d10 -W$PRIMARY_DOMAIN osName=$OS_VENDOR osVer=$OS_VERSION > net-ads-join.txt 2>net-ads-join.err
	if [ "`grep '^Join' net-ads-join.txt`" == "" ]; then
		#try again without kerberos
		net ads join -U"$adUser@$adRealm%$adPassword" -I $CLOSEST_REALM_SERVER -d10 -W$PRIMARY_DOMAIN osName=$OS_VENDOR osVer=$OS_VERSION > net-ads-join.txt 2>net-ads-join.err
	fi
	if [ "`grep '^Join' net-ads-join.txt`" == "" ]; then
		if [ "`egrep 'permissions|denied|Insufficient access' net-ads-join.txt`" != "" ]; then
                        echo "Failed to join $PRIMARY_DOMAIN domain via $CLOSEST_REALM_SERVER domain controller, using $adUser@$adRealm. $adUser does not have permission to add computer objects"
                else
			echo "Failed to join $PRIMARY_DOMAIN domain via $CLOSEST_REALM_SERVER domain controller, using $adUser@$adRealm, see $PWD/net-ads-join.txt"
		fi
		rm -f /dev/shm/adPwd*
		exit 1
	fi
fi
sleep 10
if [ "`grep 'pipe netlogon to machine ' net-ads-join.err`" == "" ]; then
	echo "Failed to join $PRIMARY_DOMAIN domainvia $CLOSEST_REALM_SERVER domain controller, using $adUser@$adRealm, see $PWD/net-ads-join.txt"
	rm -f /dev/shm/adPwd*
	exit 1
fi

#give things a moment
sleep 10

#RESPONSIBLE_DC=`grep 'pipe netlogon to machine ' net-ads-join.err|sed -e 's/^.*pipe netlogon to machine //g'|awk '{print $1}'|sort|uniq -c|sort -n|tail -1|awk '{print $NF}'`
RESPONSIBLE_DC="$CLOSEST_REALM_SERVER"

DD=`ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$RESPONSIBLE_DC -b "$BASE" "(cn=${PRIMARY_WORKSTATION})" 2>/dev/null|grep ^dn|sed -e 's/^dn: //g'`
attempt=0
while [ $attempt -le 3 ];
do
	if [ "$DD" == "" ]; then
		sleep 10
		DD=`ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$RESPONSIBLE_DC -b "$BASE" "(cn=${PRIMARY_WORKSTATION})" 2>/dev/null|grep ^dn|sed -e 's/^dn: //g'|tail -1`
	fi
	attempt=`expr $attempt + 1`
done
if [ "$DD" == "" ]; then
	echo "Bloody hell, what's the story" > /dev/null
	net ads join -k -U"$adUser@$adRealm%$adPassword" -I $CLOSEST_REALM_SERVER -d10 -W$PRIMARY_DOMAIN osName=$OS_VENDOR osVer=$OS_VERSION > net-ads-join.txt 2>net-ads-join.err
	sleep 30
	DD=`ldapsearch -x -LLL -D$adUser@$adRealm -y $pwdFile -H ldaps://$RESPONSIBLE_DC -b "$BASE" "(cn=${PRIMARY_WORKSTATION})" 2>/dev/null|grep ^dn|sed -e 's/^dn: //g'`
fi
if [ "$DD" == "" ]; then
	echo "Cannot discover new AD record for ${PRIMARY_WORKSTATION}. Cannot continue"
	exit 1
fi
export AD_MACHINE_DN="$DD"
export AD_USER_DN

(cat<<EOF
dn: $AD_MACHINE_DN
changetype: modify
replace: managedBy
managedBy: $AD_USER_DN
-

EOF
)> manager.ldif
ldapmodify -D"$adUser@$adRealm" -y $pwdFile -H ldaps://$RESPONSIBLE_DC  -f manager.ldif > ldamod.err 2>&1

if [ "$DISABLE_OPENVPN" = "" ]; then
	#see if you can auto-add this user to  TRIMBLECORP/SWD-OpenVPN-Global-Install
	(cat<<EOF
dn: CN=SWD-OpenVPN-Global-Install,OU=Delegated,OU=SCCM - Software Installation Groups,OU=Groups,OU=System Center,DC=trimblecorp,DC=net
changetype: modify
add: member
member: $AD_MACHINE_DN
EOF
)> add-to-openvpn.ldif
	ldapmodify -D"$adUser@$adRealm" -y $pwdFile -H ldaps://trimblecorp.net  -f add-to-openvpn.ldif > add-to-openvpn.err 2>&1
fi

rm -f $pwdFile 

#create .xprofile file to run one-off changes to primary owner when they first login
if [ ! -f "/home/$PRIMARY_USER/.xprofile" ]; then
	(cat<<EOF
#!/bin/sh
dconf write /org/gnome/shell/favorite-apps "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'rhythmbox.desktop', 'libreoffice-writer.desktop', 'org.gnome.Software.desktop', 'google-chrome.desktop']"
dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type "'nothing'"
mv /home/$PRIMARY_USER/.xprofile /home/$PRIMARY_USER/.xprofile-oneoff
EOF
)> /home/$PRIMARY_USER/.xprofile
	chmod 755 /home/$PRIMARY_USER/.xprofile
	chown $PRIMARY_USER /home/$PRIMARY_USER/.xprofile
fi

echo ""
echo "Linux workstation configuration complete, now installing security agents"

curl -A $prog -s https://cis-infosec-cdn.trimble.com/trimbleify.sh > trimbleify.sh

if [ "$DISABLE_OPENVPN" = "" ]; then
	/bin/bash -x  trimbleify.sh --openvpn --no-auto-update 2>trimbleify.err
else
	/bin/bash -x  trimbleify.sh --no-auto-update 2>trimbleify.err
fi


#Add Anyconnect profiles, use cert if the openvpn install was lucky enough to grab it
# NOTE: as Okta anyconnect doesn't support openconnect - there's no point in any of this

#if [ -f "/opt/trimblesw/openvpn/etc/$HOSTNAME.key" -a -f "/opt/trimblesw/openvpn/etc/$HOSTNAME.pem" ]; then
#	mkdir -p /home/$PRIMARY_USER/.certs
#	cp -a /opt/trimblesw/openvpn/etc/$HOSTNAME.key /home/$PRIMARY_USER/.certs/$PRIMARY_USER.key
#	cp -a /opt/trimblesw/openvpn/etc/$HOSTNAME.pem /home/$PRIMARY_USER/.certs/$PRIMARY_USER.pem
#	chown -R $PRIMARY_USER /home/$PRIMARY_USER/.certs 
#	chmod -R 700 /home/$PRIMARY_USER/.certs
#	echo $PRIMARY_USER > /opt/trimblesw/openvpn/etc/primary.account
#	for vpdn in usd-vpdn-1.trimble.com nzc-vpdn-1.trimble.com sed-vpdn-1.trimble.com
#	do
#        	nmcli conn add connection.type vpn con-name $vpdn  ifname -- vpn.service-type org.freedesktop.NetworkManager.openconnect > nmcli-$vpdn.err 2>&1
#        	nmcli conn modify $vpdn connection.autoconnect no connection.permissions user:$PRIMARY_USER vpn.user-name $PRIMARY_USER@$PRIMARY_AD_REALM vpn.data "authtype = cert, gateway = $vpdn, protocol = anyconnect, cookie-flags = 2, certsigs-flags = 0, xmlconfig-flags = 0, stoken_source = disabled, cacert = /etc/Trimble-CAs.pem, usercert = /home/$PRIMARY_USER/.certs/$PRIMARY_USER.pem, userkey = /home/$PRIMARY_USER/.certs/$PRIMARY_USER.key, autoconnect-flags = 0, gateway-flags = 2, gwcert-flags = 2, pem_passphrase_fsid = no, enable_csd_trojan = no, lasthost-flags = 0" >> nmcli-$vpdn.err 2>&1
#	done
#fi


#move first account (probably helpdesk_local) to >999 to make it system account
#FIRST_USER=`grep :x:1000:1000: /etc/passwd|egrep -vi "^$PRIMARY_USER:"|cut -d: -f1|head -1`
#if [ "$FIRST_USER" != "" -a "`echo $FIRST_USER|grep -i ^$PRIMARY_USER`" == "" ]; then
#        #force account to uid=888
#        sed -i "s/^$FIRST_USER:x:1000:1000:/$FIRST_USER:x:888:888:/g" /etc/passwd
#        chown -R $FIRST_USER:888 /home/$FIRST_USER > alter-$FIRST_USER.err 2>&1
#	if [ -f "/var/lib/AccountsService/users/$FIRST_USER" ]; then
#		sed -i -e 's/^SystemAccount=false/SystemAccount=true/g' "/var/lib/AccountsService/users/$FIRST_USER"
#	fi
#fi

echo "Software installtion complete."
if [ "$DISABLE_OPENVPN" = "" ]; then
	cat<<EOF

Always-on VPN is installed, but will not work until 
$PRIMARY_DOMAIN/${PRIMARY_WORKSTATION} is added to TRIMBLECORP/SWD-OpenVPN-Global-Install
and you have published the user vpnclient cert via https://ca-srv.trimble.com/openvpn.php
EOF
fi
cat<<EOF

BTW this "$USER" account had to be fiddled with, so if you need to use it more, you'll need to 
logout and in again, otherwise weird things might happen...

EOF
