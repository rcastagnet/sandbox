#!/bin/bash

SCRIPT=`basename $0`
SSH_BIN=/usr/bin/ssh
PVECTL_BIN=/usr/bin/pvectl
VZCTL_BIN=/usr/sbin/vzctl
PVESH_BIN=/usr/bin/pvesh
VZ_BIN=/var/lib/vz/private
#XYMON_BIN=/home/xymon/server/etc
VERBOSE=0

HOST_FILE=/var/pve/scripts.cfg

if [ -r $HOST_FILE ]
then
        source $HOST_FILE
else
        echo "$SCRIPT: $HOST_FILE is not a readable file" >&2
        exit 1
fi

OIFS=$IFS
IFS='.'
IP_NETWORK_TAB=($IP_NETWORK)
IFS=$OIFS
NAME_SERVER=${IP_NETWORK_TAB[0]}.${IP_NETWORK_TAB[1]}.${IP_NETWORK_TAB[2]}.1

function create_vm {
	VMID=$1
	TYPE=$2
	VM_NAME=$3
	PLATFORM_NAME=$4

## Création et démarrage de la machine	
	echo "$PVECTL_BIN create $VMID '${OS_TEMPLATE[$TYPE]}' -disk ${DISK_SPACE[$TYPE]} -password '$HASHED_ROOT_PASSWORD' -hostname $VM_NAME -nameserver $NAME_SERVER -searchdomain ${DOMAIN[$TYPE]} -onboot ${ONBOOT[$TYPE]} -swap ${SWAP[$TYPE]} -memory ${MEMORY[$TYPE]} -cpus ${CPUS[$TYPE]} -netif '${NETIF[$TYPE]}' -pool '$PLATFORM_NAME'" >> $HEAD_BUILDING_FILE
	echo "$VZCTL_BIN set $VMID --features 'nfs:on' --save" >> $HEAD_BUILDING_FILE
	echo "$VZCTL_BIN start $VMID" >> $HEAD_BUILDING_FILE
	
	case ${OS_TEMPLATE[$TYPE]} in
		local:vztmpl/debian*)
## Mise en place du réseau grâce au serveur DHCP
			echo "$VZCTL_BIN exec $VMID 'echo \"auto eth0\" >> /etc/network/interfaces'" >> $TAIL_BUILDING_FILE
			echo "$VZCTL_BIN exec $VMID 'echo \"iface eth0 inet dhcp\" >> /etc/network/interfaces'" >> $TAIL_BUILDING_FILE
			echo "$VZCTL_BIN exec $VMID 'ifup eth0'" >> $TAIL_BUILDING_FILE

## Ajout du nom dans le DNS
			echo "CMD_IP=\$($VZCTL_BIN exec $VMID ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/')" >> $TAIL_BUILDING_FILE
			echo "CMD_HOST=\$($VZCTL_BIN exec $VMID 'echo \"\$HOSTNAME\"')" >> $TAIL_BUILDING_FILE
			echo "echo \"\$CMD_IP \$CMD_HOST.${DOMAIN[$TYPE]} \$CMD_HOST\" >> $VZ_BIN/$VMID_HOT/etc/hosts" >> $TAIL_BUILDING_FILE

## Cache APT
                        echo "$VZCTL_BIN exec $VMID 'echo \"Acquire::http {\" > /etc/apt/apt.conf'" >> $TAIL_BUILDING_FILE
                        echo "$VZCTL_BIN exec $VMID 'echo \"        Proxy \\\"http://$NAME_SERVER:3142\\\";\" >> /etc/apt/apt.conf'" >> $TAIL_BUILDING_FILE
                        echo "$VZCTL_BIN exec $VMID 'echo \"        };\" >> /etc/apt/apt.conf'" >> $TAIL_BUILDING_FILE

## Installation du client Hobbit
#			echo "$VZCTL_BIN exec $VMID 'echo \"d-i hobbit-mbs/server select hobbit.ing-sys.cvf" >> $TAIL_BUILDING_FILE
#			echo "d-i hobbit-mbs/start select oui" >> $TAIL_BUILDING_FILE
#			echo "\"|debconf-set-selections'" >> $TAIL_BUILDING_FILE
#			echo "$VZCTL_BIN exec $VMID 'apt-key update && apt-get update && apt-get -y upgrade && apt-get install -y --force-yes xymon-client-mbs'" >> $TAIL_BUILDING_FILE
#			echo "$VZCTL_BIN exec $VMID 'echo \"HOBBITSERVERS=\\\"$IP_HOST\\\"\" > /etc/default/hobbit-client'" >> $TAIL_BUILDING_FILE
#			echo "$VZCTL_BIN exec $VMID 'echo \"CLIENTHOSTNAME=\\\"$HOST_NAME\\\"\" >> /etc/default/hobbit-client'" >> $TAIL_BUILDING_FILE

## Ajout de l'adresse du client sur le serveur Xymon
#			echo "echo \"\$CMD_IP \$CMD_HOST\" >> $XYMON_BIN/hosts.cfg" >> $TAIL_BUILDING_FILE

## Installation du paquet spécifique de la machine
			case $TYPE in
				empty)
				;;
			esac
		;;

## CentOS
	esac 
}

function create_vms {
	VM_COUNT=$1
	TYPE=$2
	PLATFORM_NAME=$3
	START_VMID=$4
	for (( VM_INDEX = 1 ; VM_INDEX <= $VM_COUNT ; VM_INDEX++ ))
	do
		VMID=$(($START_VMID + $VM_INDEX - 1))
		NUMBER=`printf "%02d" $VM_INDEX`
		create_vm $VMID $TYPE "${PLATFORM_NAME}-${TYPE}${NUMBER}.${DOMAIN}" $PLATFORM_NAME
	done
}

function usage {
        echo "Usage: $SCRIPT [-v] -c FILENAME" >&2
        echo "PARAMETERS:" >&2
        echo "  -v            (optionnal) mode verbose" >&2
        echo "  -c FILENAME   (required) provide the configuration file" >&2
        exit 1
}

while getopts vc: opt
do
        case $opt in
                v)
                        if [[ $VERBOSE == 3 ]]
                        then
                                exec 1>&3 3>&-
                        fi
                        VERBOSE=1
                        ;;
                c)
                        if [[ $VERBOSE != 1 ]]
                        then
                                exec 3>&1
                                exec >/dev/null
                                VERBOSE=3
                        fi
                        CONFIG_FILE=$OPTARG
                        ;;
                \?)
                        echo "Invalid parameter: -$OPTARG" >&2
                        usage
                        ;;
                :)
                        echo "Parameter -$OPTARG requires a file name." >&2
                        usage
                        ;;
        esac
done

if [[ -z "$CONFIG_FILE" ]]
then
	echo "Missing required parameter" >&2
	usage
fi

if [ -r $CONFIG_FILE ]
then
	source $CONFIG_FILE
else
	echo "$SCRIPT: $CONFIG_FILE is not a readable file" >&2
	exit 1
fi

BUILDING_FILE="/tmp/pftest-building.$$"
touch $BUILDING_FILE

echo "#!/bin/sh" > $BUILDING_FILE 2> /dev/null
if [ ! -w $BUILDING_FILE ]
then
	echo "$SCRIPT: $BUILDING_FILE is not writable" >&2
	exit 1
fi
chmod +x $BUILDING_FILE

HEAD_BUILDING_FILE="/tmp/pftest-head.$$"
TAIL_BUILDING_FILE="/tmp/pftest-tail.$$"
touch $HEAD_BUILDING_FILE
touch $TAIL_BUILDING_FILE 

for (( PLATFORM_INDEX = 0 ; PLATFORM_INDEX < $PLATFORM_COUNT ; PLATFORM_INDEX++ ))
do
	echo "echo -n \"Création du pool ${PLATFORM_NAMES[$PLATFORM_INDEX]} ... \"" >> $HEAD_BUILDING_FILE
	echo "$PVESH_BIN create /pools -poolid '${PLATFORM_NAMES[$PLATFORM_INDEX]}'" >> $HEAD_BUILDING_FILE
	
	START_VMID=$(($INITIAL_VMID + 100 * $PLATFORM_INDEX))
	create_vms $EMPTY_COUNT empty ${PLATFORM_NAMES[$PLATFORM_INDEX]} $START_VMID
	
#	echo "su xymon -c \"/home/xymon/server/bin/xymon.sh restart\"" >> $TAIL_BUILDING_FILE
done

cat $HEAD_BUILDING_FILE >> $BUILDING_FILE
echo "sleep 5s" >> $BUILDING_FILE
cat $TAIL_BUILDING_FILE >> $BUILDING_FILE
rm -f $HEAD_BUILDING_FILE
rm -f $TAIL_BUILDING_FILE

$BUILDING_FILE
rm -f $BUILDING_FILE
