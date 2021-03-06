#!/bin/bash

# Get parameter
NODE="$1"
BMC_USER="$2"
BMC_MDP="$3"
NOTIF_DIR="$4"

# Translate name to real
NODE=`cat translate | grep -P "$NODE\t" | awk '{print $2;}'`

# Set ssh parameters
SSH_USER="root"
SSH_OPTS=' -o StrictHostKeyChecking=no -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o LogLevel=quiet '


function wait_for_halt {
    local NODE="$1"

	# Check if the chassis status is off
	while [ `ipmitool -H $(host $(echo "$NODE" | cut -d'.' -f1)-bmc.$(echo "$NODE" | cut -d'.' -f2,3,4) | awk '{print $4;}') -I lan -U $BMC_USER -P $BMC_MDP chassis status | grep System | grep off | wc -l` -lt 1 ]; do
		sleep 2
	done
}

if [ -n "$NODE" ]; then
	if [ -f "$NODE" ]; then
		echo -e "Start\tPowering off $(cat $NODE | wc -l) nodes"

		# If NOTIF_DIR is specified, the node will alert the CTL when it is up again
		if [ -n "$NOTIF_DIR" ]; then
			for N in `cat $NODE`; do
				ssh $SSH_USER@$N $SSH_OPTS "sed -i 's;<REMOTE_HOST>;$(hostname);g' /etc/init.d/bootNotify"
				ssh $SSH_USER@$N $SSH_OPTS "sed -i 's;<REMOTE_DIR>;$NOTIF_DIR;g' /etc/init.d/bootNotify"
				ssh $SSH_USER@$N $SSH_OPTS "update-rc.d bootNotify defaults >/dev/null 2>&1"
			done
		fi

		# Using kapower
		#kapower3 --off -f $NODE >/dev/null

		# Using remote ssh cmd
		for N in `cat $NODE`; do
			ssh $SSH_USER@$N $SSH_OPTS 'halt' &
		done
		wait
	
		if [ -n "$BMC_USER" -a -n "$BMC_MDP" ]; then
		
			# Wait for shutdown of all nodes
			START=$(date +%s)
			for N in `cat $NODE`; do
				wait_for_halt $N &
			done
			wait
			END=$(date +%s)

			echo -e "End:\tPowering off $(cat $NODE | wc -l) nodes\t(time=$(($END - $START)))s"
		else
			echo
		fi
	else
		echo -e "Start:\tPowering off node '$NODE'"

		# If NOTIF_DIR is specified, the node will alert the CTL when it is up again
		if [ -n "$NOTIF_DIR" ]; then
			ssh $SSH_USER@$NODE $SSH_OPTS "sed -i 's;<REMOTE_HOST>;$(hostname);g' /etc/init.d/bootNotify"
			ssh $SSH_USER@$NODE $SSH_OPTS "sed -i 's;<REMOTE_DIR>;$NOTIF_DIR;g' /etc/init.d/bootNotify"
			ssh $SSH_USER@$NODE $SSH_OPTS "update-rc.d bootNotify defaults"
		fi

		# Using kapower
		#kapower3 --off -m $NODE >/dev/null

		# Using remote ssh cmd
		ssh $SSH_USER@$NODE $SSH_OPTS 'halt'

		if [ -n "$BMC_USER" -a -n "$BMC_MDP" ]; then

			# Wait for shutdow
			START=$(date +%s)
			wait_for_halt $NODE
			END=$(date +%s)

			echo -e "End:\tPowering off node '$NODE'\t(time=$(($END - $START)))s"
		else
			echo
		fi
	fi	
fi
