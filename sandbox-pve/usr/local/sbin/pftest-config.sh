#!/bin/bash

SCRIPT=`basename $0`
declare -A OS_TEMPLATE
declare -A DISK_SPACE
declare -A MEMORY
declare -A SWAP
declare -A CPUS
declare -A ONBOOT
declare -A NETIF

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

function usage {
	echo "Usage: $SCRIPT -o OUPUT_FILE" >&2
	exit 1
}

while getopts ":o:" opt
do
	case $opt in
		o)
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
	echo "Missing output file" >&2
	usage
fi

if [ -f $CONFIG_FILE ]
then
	read -p "$CONFIG_FILE already exists, overright it ? [y|n] " overright
	if [[ "$overright" != "y" && "$overright" != "Y" ]]
	then
		exit 1
	fi
fi

touch $CONFIG_FILE 2> /dev/null
if [ ! -w $CONFIG_FILE ]
then
	echo "$SCRIPT: $CONFIG_FILE is not writable" >&2
	exit 1
fi


function read_template {
	TYPE=$1
	declare -a TEMPLATES=(
		'local:vztmpl/debian-6.0-x86.tar.gz')
	echo "  │   Templates available :"
	echo "  │     1: debian 6.0 standard 32 bits"
	read -p "  ├ Template number : [1] " TEMPLATE_NUMBER
	TEMPLATE_NUMBER=${TEMPLATE_NUMBER:-1}
	OS_TEMPLATE[$TYPE]="'${TEMPLATES[$((TEMPLATE_NUMBER-1))]}'"
}

function read_config {
	COUNT=$1
	TYPE=$2
	if [[ $COUNT > 0 ]]
	then
		read_template $TYPE
		read -p "  ├ Disk space : [2] " DISK_SPACE[$TYPE]
		DISK_SPACE[$TYPE]=${DISK_SPACE[$TYPE]:-2}
		read -p "  ├ Memory : [512] " MEMORY[$TYPE]
		MEMORY[$TYPE]=${MEMORY[$TYPE]:-512}
		read -p "  ├ Swap : [512] " SWAP[$TYPE]
		SWAP[$TYPE]=${SWAP[$TYPE]:-512}
		read -p "  ├ CPUs : [1] " CPUS[$TYPE]
		CPUS[$TYPE]=${CPUS[$TYPE]:-1}
		read -p "  ├ Start on boot : [yes] " ONBOOT[$TYPE]
		ONBOOT[$TYPE]=${ONBOOT[$TYPE]:-yes}
		read -p "  └ Bridge : [vmbr1] " BRIDGE
		BRIDGE=${BRIDGE:-vmbr1}
		NETIF[$TYPE]="'ifname=eth0,bridge=$BRIDGE'"
	fi
}

function print_config {
	COUNT=${!1}
	TYPE=$2
	echo "$1=$COUNT"
	if [[ $COUNT > 0 ]]
	then
		echo "OS_TEMPLATE[$TYPE]=${OS_TEMPLATE[$TYPE]}"
		echo "DISK_SPACE[$TYPE]=${DISK_SPACE[$TYPE]}"
		echo "MEMORY[$TYPE]=${MEMORY[$TYPE]}"
		echo "SWAP[$TYPE]=${SWAP[$TYPE]}"
		echo "CPUS[$TYPE]=${CPUS[$TYPE]}"
		echo "ONBOOT[$TYPE]=${ONBOOT[$TYPE]}"
		echo "NETIF[$TYPE]=${NETIF[$TYPE]}"
	fi
}

echo "*** Architecture des plate-formes ***"
read -p "VMID initial : [1000] " INITIAL_VMID
INITIAL_VMID=${INITIAL_VMID:-1000}
read -p "Nombre de machines simples : [0] " EMPTY_COUNT
EMPTY_COUNT=${EMPTY_COUNT:-0}
read_config $EMPTY_COUNT empty
echo ""
echo "*** Nombre de plate-formes ***"
read -p "Nombre de plate-forme à créer : [1] " PLATFORM_COUNT
PLATFORM_COUNT=${PLATFORM_COUNT:-1}

declare -a PLATFORM_NAMES
for (( PLATFORM_INDEX = 0 ; PLATFORM_INDEX < $PLATFORM_COUNT ; PLATFORM_INDEX++ ))
do
	read -p "Nom de la plate-forme $((PLATFORM_INDEX + 1)) : " PLATFORM_NAME
	PLATFORM_NAMES[$PLATFORM_INDEX]=$PLATFORM_NAME
done

HASHED_ROOT_PASSWORD='password'
echo "HASHED_ROOT_PASSWORD='$HASHED_ROOT_PASSWORD'" > $CONFIG_FILE
echo "NAME_SERVER=${IP_NETWORK_TAB[0]}.${IP_NETWORK_TAB[1]}.${IP_NETWORK_TAB[2]}.1" >> $CONFIG_FILE
echo "DOMAIN=$DOMAIN" >> $CONFIG_FILE
echo "declare -A OS_TEMPLATE" >> $CONFIG_FILE
echo "declare -A DISK_SPACE" >> $CONFIG_FILE
echo "declare -A MEMORY" >> $CONFIG_FILE
echo "declare -A SWAP" >> $CONFIG_FILE
echo "declare -A CPUS" >> $CONFIG_FILE
echo "declare -A ONBOOT" >> $CONFIG_FILE
echo "declare -A NETIF" >> $CONFIG_FILE

echo >> $CONFIG_FILE
print_config EMPTY_COUNT empty >> $CONFIG_FILE
echo >> $CONFIG_FILE
echo "PLATFORM_COUNT=$PLATFORM_COUNT" >> $CONFIG_FILE
echo "PLATFORM_NAMES=(${PLATFORM_NAMES[*]})" >> $CONFIG_FILE
echo >> $CONFIG_FILE
echo "INITIAL_VMID=$INITIAL_VMID" >> $CONFIG_FILE
