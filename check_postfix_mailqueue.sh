#!/bin/bash

# Uncomment to enable debugging
# set -x

PROGNAME=`basename $0`
VERSION="Version 1.0"
AUTHOR="Vidda"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

warning=0
critical=0

print_version() {
    echo "$PROGNAME $VERSION $AUTHOR"
}

print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo "$PROGNAME - Checks postfix mailqueue statistic"
    echo ""
    echo "$PROGNAME is a Nagios plugin which generates statistics"
    echo "for the postfix mailqueue and checks for corrupt messages."
	echo "The following values will be checked:"
	echo "maildrop: Localy posted mail"
	echo "incoming: Processed local mail and received from network"
	echo "active: Mails being delivered (should be small)"
	echo "deferred: Stuck mails (that will be retried later)"
	echo "corrupt: Messages found to not be in correct format (shold be 0)"
	echo "hold: Recent addition, messages put on hold indefinitly - delete of free"
    echo ""
    echo "Usage: $PROGNAME -w WARN-Level -c CRIT-Level"
    echo ""
    echo "Options:"
    echo "  -w)"
    echo "     Warning level for deferred mails"
    echo "  -c)"
    echo "     Critical level for deferred mail"
    echo "  -h)"
    echo "     This help"
    echo "  -v)"
    echo "     Version"
    exit $STATE_OK
}

# Check for parameters
while test -n "$1"; do
    case "$1" in
		-h)
			print_help
			exit $STATE_OK;;
		-v)
			print_version
			exit $STATE_OK;;
		-w)
			warning=$2
			shift
			;;
		-c)
			critical=$2
			shift
			;;
		*)
			check_postfix_mailqueue
			;;
	esac
	shift
done

check_postfix_mailqueue() {
# Can be set via environment, but default is fetched by postconf (if available,
# else /var/spool/postfix) 
if which postconf > /dev/null ; then
   SPOOLDIR=${spooldir:-`postconf -h queue_directory`}
else
   SPOOLDIR=${spooldir:-/var/spool/postfix}
fi

cd $SPOOLDIR >/dev/null 2>/dev/null || {
     echo -n "Cannot cd to $SPOOLDIR"
     exit $STATE_CRITICAL
}

# Get values
deferred=`(test -d deferred && find deferred -type f ) | wc -l`
active=`(test -d active && find active -type f ) | wc -l`
maildrop=`(test -d maildrop && find maildrop -type f ) | wc -l`
incoming=`(test -d incoming && find incoming -type f ) | wc -l`
corrupt=`(test -d corrupt && find corrupt -type f ) | wc -l`
hold=`( test -d hold && find hold -type f ) | wc -l`
}

check_postfix_mailqueue
values="Deferred mails=$deferred Active deliveries=$active Locally posted mails=$maildrop Incoming mails=$incoming Corrupt mails=$corrupt Mails on hold=$hold"
perfdata="deferred=$deferred;; active=$active;; maildrop=$maildrop;; incoming=$incoming;; corrupt=$corrupt;; hold=$hold;;"

if [ $corrupt -gt 0 ]; then
	echo -n "Postfix Mailqueue CRITICAL - $corrupt corrupt messages found! | $perfdata"
	exit $STATE_CRITICAL
fi

if [ $warning -gt 0 ] && [ $critical -gt 0 ]; then
   if [ $deferred -gt $critical ]; then
      echo -n "Postfix Mailqueue CRITICAL - $values | $perfdata"
      exit $STATE_CRITICAL
   elif [ $deferred -gt $warning ]; then
      echo -n "Postfix Mailqueue WARNING - $values | $perfdata"
      exit $STATE_WARNING
   else
      echo -n "Postfix Mailqueue OK - $values | $perfdata"
      exit $STATE_OK
   fi
else
   echo -n "Postfix Mailqueue OK - $values | $perfdata"
   exit $STATE_OK
fi
