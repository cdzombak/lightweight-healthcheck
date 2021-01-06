# lightweight-healthcheck

lightweight-healthcheck is a minimal but effective healthchecking/monitoring script.

- written in Bash & deployable on Linux or macOS
- email & SMS (via Twilio) notifications, including date/time and the hostname that sent the alert
- mail/SMS alert rate limiting, to avoid blowing through your Twilio/Mailgun quota
- customizable delay between first detecting a down condition and sending alert
- logging of down/alert/ok events

## Deployment

Make a copy of the script and put it somewhere like `~/scripts/healthcheck-website.sh`. Make it executable. Change the variables at the top of the script, and customize the `check` function, to get the script set up for whatever you're monitoring. Schedule it via cron however frequently you want.

### Email

I use [Mailgun](https://www.mailgun.com) to ensure reliable delivery of mail from my servers. Set it up for the system following eg. [this guide](https://www.jamroom.net/brian/documentation/guides/1312/set-up-postfix-with-mailgun-for-reliable-e-mail-delivery).

### SMS

SMS alerts are sent via [Twilio](https://www.twilio.com). You'll need to configure that via the Twilio variables in the script.

### macOS

The script requires the GNU version of `date` to be named `gdate` and be available in the PATH. Install it via [Homebrew](https://brew.sh) with `brew install coreutils`.
