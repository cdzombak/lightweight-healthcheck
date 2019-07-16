# lightweight-healthcheck

lightweight-healthcheck is a minimal healthchecking/monitoring script.

- written in Bash & deployable anywhere
- email & SMS (Twilio) notifications, including date/time and the hostname that sent the alert
- mail/SMS alert rate limiting, to avoid blowing through your Twilio/Mailgun quota
- alert logging

## Deployment

Make a copy of the script and put it somewhere like `~/scripts/healthcheck-website.sh`. Make it executable. Change the variables at the top of the script, and customize the `check` function, to get the script set up for whatever you're monitoring. Schedule it via cron however frequently you want.

### Email

I use [Mailgun](https://www.mailgun.com) to ensure reliable delivery of mail from my servers. Set it up for the system following eg. [this guide](https://www.jamroom.net/brian/documentation/guides/1312/set-up-postfix-with-mailgun-for-reliable-e-mail-delivery).

### SMS

SMS alerts are sent via [Twilio](https://www.twilio.com). You'll need to configure that via the Twilio variables in the script.
