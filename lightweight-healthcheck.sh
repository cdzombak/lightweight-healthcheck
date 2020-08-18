#!/usr/bin/env bash

set -u

THING_DESC="dzombak.com"
EMAIL_SUBJECT="[dzombak.com] Website"
EMAIL_TO="chris@example.com"
SMS_TO="+1xxxxxxxxxx"  # set empty to disable Twilio sms
TWILIO_NUMBER="+1xxxxxxxxxx"
TWILIO_ACCOUNT="ACxxxxx"
TWILIO_APIKEY="xxxxx"
LOGFILE_NAME="website"  # logs will be written to $HOME/.lightweight-healthcheck/website.log
DAILY_LIMIT=6  # max incidents reported via email/sms during the current day
HOURLY_LIMIT=2  # max incidents reported via email/sms during the current hour

check() {
	# recommendations for writing a check:
	# * use curl -s
	# * set curl --connect-timeout
	# * see https://stackoverflow.com/a/42873372 for notes on curl retry options
	curl -s --connect-timeout 5 --max-time 15 --retry 3 --retry-max-time 50 https://www.dzombak.com | grep -c "<title> # Chris Dzombak</title>"
}

#
# Do not modify below this line
#

mkdir -p "$HOME/.lightweight-healthcheck"
LASTSTATUS_FILE="$HOME/.lightweight-healthcheck/.$LOGFILE_NAME.status"
LOG_FILE="$HOME/.lightweight-healthcheck/$LOGFILE_NAME.log"
HOSTNAME=$(hostname)
NOW=$(date +"%F %T %Z")
NOW_D=$(date +"%F")
NOW_H=$(date +"%F %H")

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
	if [ -n "$SMS_TO" ]; then
		curl -s -X POST https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT/Messages.json \
				--data-urlencode "From=$TWILIO_NUMBER" \
				--data-urlencode "Body=$1" \
				--data-urlencode "To=$SMS_TO" \
				-u $TWILIO_ACCOUNT:$TWILIO_APIKEY > /dev/null
	fi
}

send_ok() {
	echo -e "$THING_DESC recovered at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - Recovered" $EMAIL_TO
	send_sms "$THING_DESC recovered at $NOW"
}

send_alert() {
	echo -e "$THING_DESC was DOWN at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - ALERT" $EMAIL_TO
	send_sms "$THING_DESC was DOWN at $NOW"
}

if ! grep -c "$OK" "$LASTSTATUS_FILE" >/dev/null ; then
	SEND="1"
	ALERTS_TODAY=$(grep -c "$NOW_D" "$LOG_FILE")
	if (( ALERTS_TODAY >= (DAILY_LIMIT * 2) )); then
		SEND="0"
	fi
	ALERTS_THIS_HOUR=$(grep -c "$NOW_H" "$LOG_FILE")
	if (( ALERTS_THIS_HOUR >= (HOURLY_LIMIT * 2) )); then
		SEND="0"
	fi

	if [[ "$OK" == "1" ]]; then
		echo "$NOW - OK" >> "$LOG_FILE"
		if [[ "$SEND" == "1" ]]; then
			send_ok
		fi
	else
		echo "$NOW - ALERT" >> "$LOG_FILE"
		if [[ "$SEND" == "1" ]]; then
			send_alert
		fi
	fi
fi

echo "$OK" > "$LASTSTATUS_FILE"
