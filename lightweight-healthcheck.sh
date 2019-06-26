#!/usr/bin/env bash

set -u

THING_DESC="dzombak.com"
EMAIL_SUBJECT="[dzombak.com] Website"
LASTSTATUS_FILE="$HOME/.website-healthcheck-status"
EMAIL_TO="chris@example.com"
SMS_TO="+1xxxxxxxxxx"
TWILIO_NUMBER="+1xxxxxxxxxx"
TWILIO_ACCOUNT="ACxxxxx"
TWILIO_APIKEY="xxxxx"

check() {
	# recommendations for writing a check:
	# * use curl -s
	# * set curl --connect-timeout
	curl -s --connect-timeout 5 https://www.dzombak.com | grep -c "<title> # Chris Dzombak</title>"
}

#
# Do not modify below this line
#

HOSTNAME=$(hostname)
NOW=$(date +"%F %T %Z")
OK=
if check > /dev/null ; then
	OK="1"
else
	sleep $(( ( RANDOM % 5 )  + 1 ))s
	if check > /dev/null ; then
		OK="1"
	else
		OK="0"
	fi
fi

send_sms() {
	curl -s -X POST https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT/Messages.json \
			--data-urlencode "From=$TWILIO_NUMBER" \
			--data-urlencode "Body=$1" \
			--data-urlencode "To=$SMS_TO" \
			-u $TWILIO_ACCOUNT:$TWILIO_APIKEY > /dev/null
}

if ! grep -c "$OK" "$LASTSTATUS_FILE" >/dev/null ; then
	if [[ "$OK" == "1" ]]; then
		echo -e "$THING_DESC recovered at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - Recovered" $EMAIL_TO
		send_sms "$THING_DESC recovered at $NOW"
	else
		echo -e "$THING_DESC was DOWN at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - ALERT" $EMAIL_TO
		send_sms "$THING_DESC was DOWN at $NOW"
	fi
fi

echo "$OK" > "$LASTSTATUS_FILE"
