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
DELAY_MINUTES=1  # minutes to wait for clear before sending an alert
DAILY_LIMIT=6  # max incidents reported via email/sms during the current day
HOURLY_LIMIT=2  # max incidents reported via email/sms during the current hour


check() {
	# recommendations for writing a check:
	# - use curl -s
	# - set curl --connect-timeout and --max-time to a small number
	# - see https://stackoverflow.com/a/42873372 for notes on curl retry options

	curl -s --connect-timeout 5 --max-time 15 --retry 3 --retry-max-time 45 https://www.dzombak.com | grep -c "<title> # Chris Dzombak</title>"
}

#################################
# Do not modify below this line #
#################################

mkdir -p "$HOME/.lightweight-healthcheck"
LOG_FILE="$HOME/.lightweight-healthcheck/$LOGFILE_NAME.log"
HOSTNAME=$(hostname)
NOW=$(date +"%F %T %Z")
NOW_D=$(date +"%F")
NOW_H=$(date +"%F %H")

log_ok() {
	echo "$NOW | OK" >> "$LOG_FILE"
}

log_down() {
	echo "$NOW | DOWN" >> "$LOG_FILE"
}

log_alert() {
	echo "$NOW | ALERT" >> "$LOG_FILE"
}

if [ ! -f "$LOG_FILE" ]; then
	log_ok
fi
if ! tail -n 1 "$LOG_FILE" | grep -c "|" >/dev/null; then
	# last log is the old format. log a parse-able line, exit, and we'll finish checking next time
	log_ok
	exit 0
fi

IFS='|' read -ra LASTLOG <<< "$(tail -n 1 "$LOG_FILE")"
# shellcheck disable=SC2001
LAST_DATE=$(echo "${LASTLOG[0]}" | sed -e 's/[[:space:]]*$//')
# shellcheck disable=SC2001
LAST_STATUS=$(echo "${LASTLOG[1]}" | sed -e 's/^[[:space:]]*//')

OK=false
if check > /dev/null ; then
	OK=true
else
	sleep 5s
	if check > /dev/null ; then
		OK=true
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

alert_would_exceed_max_allowed() {
	local ALERTS_TODAY
	ALERTS_TODAY=$(grep "$NOW_D" "$LOG_FILE" | grep -c "ALERT")
	if (( ALERTS_TODAY >= (2*DAILY_LIMIT) )); then
		return 0  # success exit code, indicating yes it would exceed max allowed
	fi
	local ALERTS_THIS_HOUR
	ALERTS_THIS_HOUR=$(grep "$NOW_H" "$LOG_FILE" | grep -c "ALERT")
	if (( ALERTS_THIS_HOUR >= (2*HOURLY_LIMIT) )); then
		return 0  # success exit code, indicating yes it would exceed max allowed
	fi
	return 1  # failure exit code, indicating it would not exceed max allowed
}

send_ok() {
	if alert_would_exceed_max_allowed ; then
		return
	fi
	echo -e "$THING_DESC recovered at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - Recovered" $EMAIL_TO
	send_sms "$THING_DESC recovered at $NOW"
}

send_alert() {
	if alert_would_exceed_max_allowed ; then
		return
	fi
	if [ "$LAST_STATUS" = "DOWN" ]; then
		echo -e "$THING_DESC was DOWN at $LAST_DATE\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - ALERT" $EMAIL_TO
		send_sms "$THING_DESC was DOWN at $LAST_DATE"
	else
		echo -e "$THING_DESC was DOWN at $NOW\n\n(seen by $HOSTNAME)" | mailx -s "$EMAIL_SUBJECT - ALERT" $EMAIL_TO
		send_sms "$THING_DESC was DOWN at $NOW"
	fi
}

if [ "$OK" == true ]; then
	if [ "$LAST_STATUS" = "OK" ]; then
		exit 0
	elif [ "$LAST_STATUS" = "DOWN" ]; then
		log_ok
	elif [ "$LAST_STATUS" = "ALERT" ]; then
		log_ok
		send_ok
	else
		log_ok
	fi
else
	if [ "$LAST_STATUS" = "OK" ]; then
		log_down
		if (( DELAY_MINUTES == 0)); then
			send_alert
			log_alert
		fi
	elif [ "$LAST_STATUS" = "DOWN" ]; then
		if command -v gdate >/dev/null; then
			EPOCH_LAST_LOG=$(gdate -d "$LAST_DATE" +%s)
			EPOCH_NOW=$(gdate -d "$NOW" +%s)
		else
			EPOCH_LAST_LOG=$(date -d "$LAST_DATE" +%s)
			EPOCH_NOW=$(date -d "$NOW" +%s)
		fi
		MINUTES_SINCE_LAST_LOG=$(( (EPOCH_NOW - EPOCH_LAST_LOG + 1) / 60))
		if (( MINUTES_SINCE_LAST_LOG >= DELAY_MINUTES )); then
			send_alert
			log_alert
		fi
	elif [ "$LAST_STATUS" = "ALERT" ]; then
		exit 0
	else
		log_down
	fi
fi
