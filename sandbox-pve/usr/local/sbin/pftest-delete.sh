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

function remove_vm {
	VMID=$1
	TYPE=$2
	HOST_NAME=$3
	PLATEFORM_NAME=$4
	

	echo "echo -n \"Suppression de la VM $VMID du pool $PLATFORM_NAME ... \"" >> $DESTROYING_FILE

## Suppression du DNS
	echo "CMD_IP=\$($VZCTL_BIN exec $VMID ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/')" >> $DESTROYING_FILE
	echo "grep -v \$CMD_IP /$VZ_BIN/$VMID_HOT/etc/hosts > /$VZ_BIN/$VMID_HOT/etc/hosts.tmp" >> $DESTROYING_FILE
	echo "cat /$VZ_BIN/$VMID_HOT/etc/hosts.tmp > /$VZ_BIN/$VMID_HOT/etc/hosts && rm /$VZ_BIN/$VMID_HOT/etc/hosts.tmp" >> $DESTROYING_FILE
	echo "if [[ \${CMD_IP}\"toto\" == \"toto\" ]]" >> $DESTROYING_FILE
        echo "then" >> $DESTROYING_FILE
        echo "  CMD_IP=NO_IP_VALUE" >> $DESTROYING_FILE
        echo "fi" >> $DESTROYING_FILE
## Suppression du serveur Xymon
#	echo "grep -v \$CMD_IP /$XYMON_BIN/hosts.cfg > /$XYMON_BIN/hosts.cfg.tmp" >> $DESTROYING_FILE
#	echo "cat /$XYMON_BIN/hosts.cfg.tmp > /$XYMON_BIN/hosts.cfg && rm /$XYMON_BIN/hosts.cfg.tmp" >> $DESTROYING_FILE
#	echo "su xymon -c \"/home/xymon/server/bin/xymon.sh restart\"" >> $DESTROYING_FILE

## Suppression de la machine du pool
	echo "$PVESH_BIN set /pools/$PLATFORM_NAME -delete -vms $VMID" >> $DESTROYING_FILE

## Arret et suppression de la machine
	echo "$VZCTL_BIN stop $VMID" >> $DESTROYING_FILE
	echo "$VZCTL_BIN destroy $VMID" >> $DESTROYING_FILE
}

function remove_vms {
	VM_COUNT=$1
	TYPE=$2
	PLATFORM_NAME=$3
	START_VMID=$4
	for (( VM_INDEX = 1 ; VM_INDEX <= $VM_COUNT ; VM_INDEX++ ))
	do
		VMID=$(($START_VMID + $VM_INDEX - 1))
		NUMBER=`printf "%02d" $VM_INDEX`
		remove_vm $VMID $TYPE "${PLATFORM_NAME}-${TYPE}${NUMBER}.${DOMAIN}" $PLATFORM_NAME
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

DESTROYING_FILE="/tmp/pftest-destroying.$$"
touch $DESTROYING_FILE

echo "#!/bin/sh" > $DESTROYING_FILE 2> /dev/null
if [ ! -w $DESTROYING_FILE ]
then
	echo "$SCRIPT: $DESTROYING_FILE is not writable" >&2
	exit 1
fi
chmod +x $DESTROYING_FILE


for (( PLATFORM_INDEX = 0 ; PLATFORM_INDEX < $PLATFORM_COUNT ; PLATFORM_INDEX++ ))
do
	
	START_VMID=$(($INITIAL_VMID + 100 * $PLATFORM_INDEX))
	remove_vms $EMPTY_COUNT empty ${PLATFORM_NAMES[$PLATFORM_INDEX]} $START_VMID
	
	echo "echo -n \"Suppression du pool ${PLATFORM_NAMES[$PLATFORM_INDEX]} ... \"" >> $DESTROYING_FILE
        echo "$PVESH_BIN delete /pools/${PLATFORM_NAMES[$PLATFORM_INDEX]}" >> $DESTROYING_FILE
done

$DESTROYING_FILE
rm -f $DESTROYING_FILE
