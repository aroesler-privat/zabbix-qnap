#!/bin/bash

FILE=/var/log/syslog
DRYRUN=0
LOGFILE=/tmp/qnap-backup-monitor.log

JOBS=("Backup Job 1" "Another Backup Job")

ZABBIX_SERVER=127.0.0.1
ZABBIX_SENDER=`which zabbix_sender`

FILE_COMMAND="tail -fn0"

function log_message() { ######################################################
# echos all given parameters to $LOGFILE                                      #
###############################################################################
	echo $* >> $LOGFILE
}

function create_zabbix_input() { ##############################################
# creates input for zabbix_send-command                                       #
# -> no parameter: initializes STRING to ""                                   #
# -> any parameter is added to the string                                     #
# -> format: ZABBIXHOST_NAME ZAXXIXITEM_KEY TIMESTAMP VALUE                   #
# -> per function-call a newline is added                                     #
# -> use as: echo $ZABBIX_INPUT | tr '|' '\n'                                 #
###############################################################################
	if [ "$#" == 0 ] ; then
		ZABBIX_INPUT=""
	elif [ -z "$ZABBIX_INPUT" ]; then
		ZABBIX_INPUT="$*"
	else
		ZABBIX_INPUT+='|'"$*"
	fi
}

function send_to_zabbix() { ###################################################
# sends $ZABBIX_INPUT to $ZABBIX_SERVER                                       #
###############################################################################

	if [ "$DRYRUN" == "0" ] ; then
		echo $ZABBIX_INPUT | tr '|' '\n' | \
		RESULT=`$ZABBIX_SENDER -z $ZABBIX_SERVER -T -i -`
		[ "$?" == 0 ] || log_message "send_to_zabbix: failed $RESULT command was $ZABBIX_INPUT"
	else
		echo $ZABBIX_INPUT | tr '|' '\n'
	fi
}

function get_zabbix_host() { ##################################################
# generates Zabbix-Hostname to be logged to from parameter $LINE              #
# -> Format: $QNAPHOST_$QNAPJOB                                               #
###############################################################################
	LINE=$1

	QNAPJOB=""
	QNAPHOST=`echo $LINE | awk '{ printf $4 }'`

	for i in ${!JOBS[*]} ; do
		echo $LINE | grep "${JOBS[$i]}" > /dev/null
		if [ "$?" == 0 ] ; then
			QNAPJOB=`echo "${JOBS[$i]}"`
		fi
	done

	if [ "$QNAPJOB" != "" ] ; then
	       	echo -n "$QNAPHOST $QNAPJOB" | tr ' ' '_'
	fi
}

###############################################################################
###############################################################################

for PARAM in $* ; do
	OPTION=`echo $PARAM | sed -es/"^\([^=]*\)=.*$"/"\1"/`
	VALUE=`echo $PARAM | sed -es/"^[^=]*=\([^=]*\)$"/"\1"/ | grep -v "^--"`

	case $OPTION in
		"--file")
			FILE=$VALUE
			;;
		"--dryrun")
			DRYRUN=1
			;;
		"--logfile")
			LOGFILE=$VALUE
			;;
		"--zabbix-server")
			ZABBIX_SERVER=$VALUE
			;;
		"--hosts-to-create")
			grep "qlogd" $FILE | tr '"' '-' | while read line ; do
				QNAPAPP=`echo $line | sed -es/"^.*qlogd\[[0-9]*\][^\[]*\[\([A-Za-z\ ]*\)\].*$"/"\1"/`
				[ "$QNAPAPP" == "Hybrid Backup Sync" ] || continue

				HOST=`get_zabbix_host "$line"`
				[ -n "$HOST" ] && echo $HOST
			done | sort | uniq

			exit 0
			;;
		"--import")
			FILE_COMMAND="cat"
			;;
		"--help")
			echo "Usage: $0 [parameter]"
			echo ""
			echo "--file=<file>            - Logfile receiving the QNAP-logs (default: $FILE)"
			echo "--zabbix-server=<server> - address of Zabbix-server (default: $ZABBIX_SERVER)"
			echo "--logfile=<file>         - where to print errors & Co. (default: $LOGFILE)"
			echo ""
			echo "Tools for setup and debugging"
			echo "--hosts-to-create        - prints names of Zabbix-hosts to be created"
			echo "--import                 - does import all existing events from file"
			echo "--dryrun                 - just print what would be sent to Zabbix, but don't send it"
			exit 0
			;;
		*)
			echo "use $0 --help to get help"
			exit 0
			;;
	esac
done

log_message "Starting as PID $$, monitoring $FILE"

if [ "$DRYRUN" != "1" ] ; then
	PIDFILE=`basename "$0"`
	[ -f /var/run/$PIDFILE.pid ] && kill `cat /var/run/$PIDFILE.pid`
	echo $$ > /var/run/$PIDFILE.pid
fi

$FILE_COMMAND $FILE | while read line ; do
        echo $line | grep "qlogd" > /dev/null
	[ "$?" == 0 ] || continue

	QNAPHOST=`echo $line | awk '{ printf $4 }'`
	QNAPAPP=`echo $line | sed -es/"^.*qlogd\[[0-9]*\][^\[]*\[\([A-Za-z\ ]*\)\].*$"/"\1"/`
	QNAPDATE=`echo $line | sed -es/"^\(.*\)\ $QNAPHOST\ qlogd.*$"/"\1"/`
	TIMESTAMP=`date -d "$QNAPDATE" +"%s"`

	case "$QNAPAPP" in
		"Hybrid Backup Sync") #########################################
		###############################################################

			ZABBIX_HOST=`get_zabbix_host "$line"`
			
			if [ -z "$ZABBIX_HOST" ] ; then
				log_message "$QNAPDATE/$QNAPHOST/$QNAPAPP job not found: $line"
				continue
			fi

			create_zabbix_input

			echo $line | grep -i "started" > /dev/null
			if [ "$?" == 0 ] ; then
				create_zabbix_input "$ZABBIX_HOST status $TIMESTAMP \"started\""
				create_zabbix_input "$ZABBIX_HOST error $TIMESTAMP 0"
			else
				echo $line | grep -i "finished" > /dev/null
				if [ "$?" == 0 ] ; then
					create_zabbix_input "$ZABBIX_HOST status $TIMESTAMP \"finished\""
					create_zabbix_input "$ZABBIX_HOST error $TIMESTAMP 0"
					create_zabbix_input "$ZABBIX_HOST last $TIMESTAMP \"$QNAPDATE\""
				else
					STATUS=`echo $line | sed -es/"^.*$QNAPAPP\]\ \(.*\)$"/"\1"/ | tr '\"' '^'`
					create_zabbix_input "$ZABBIX_HOST status $TIMESTAMP \"error\""
					create_zabbix_input "$ZABBIX_HOST error $TIMESTAMP 1"
					create_zabbix_input "$ZABBIX_HOST lasterror $TIMESTAMP \"$STATUS\""
				fi
			fi

			send_to_zabbix

			;;
		"Antivirus") ##################################################
		###############################################################
			log_message "$QNAPDATE/$QNAPHOST/$QNAPAPP no action defined: $line"
			;;
		*) ############################################################
		###############################################################
			log_message "$QNAPDATE/$QNAPHOST app \"$QNAPAPP\" not found: $line"
			;;
	esac
done
