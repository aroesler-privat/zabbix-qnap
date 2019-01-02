# zabbix-qnap

## About
It was about Christmas and I started to feel a little nerdy. So inside of me a wish was growing up: I wanted to have an overview over all the backup- and sync-processes I run during the day. So I installed Zabbix and started to play around with its extensions. This is a Bash-script running in the background permanently checking a logfile for QNAP-events. Events will be reported via zabbix_sender to a given virtual Zabbix host (backup job). When installed in your Zabbix-scripts-directory and after deploying the Template you may see the following data per backup job:
* Error - error status (no error = 0)
* Current backup status - started, finished or error
* Last finished backup time - string with the time, when last backup was finished
* Last error message - guess what ;-)

QNAP-devices aren't very verbose outside their own communication channels (e-mail, Skype, Facebook Messanger). So the only way to fetch a backup-job's status is by checking the logfiles. One could do this on the QNAP-device itself or configure rsyslog e.g. on the Zabbix-server and let QNAP use this as loghost, which is how I am doing it.

I am using "Hybrid Backup Sync". I expect other QNAP backup-tools to work as well this way, but they will need some change to the script in the <code>case "$QNAPAPP" in</code>-section.

## Install and Configure
1. download qnap-backup-monitor.sh and install it to you ExternalScripts-directory (zabbix_server.conf -> ExternalScripts)
2. make it executable: <code>chmod a+x qnap-backup-monitor.sh</code>
3. carefully read the output of <code>./qnap-backup-monitor.sh --help</code> - I hate to document and I did it just for you! ;-)

You have to add the jobs you want to monitor to the <code>JOBS</code>-array in the beginning of qnap-backup-monitor.sh. The job's names have to be exactly named as the jobs are named in QNAP Hybrid Backup Sync, as they are greb'd in the logfile.

After doing this I suggest to do a dry-run to check what would happen. Assuming the file QNAP sends its log-messages to is /var/log/syslog the following is to be done:
1. Make sure there are already jobs logged to the file. If this is not the case just start the jobs by hand.
2. Call <code>./qnap-backup-monitor.sh --file=/var/log/syslog --import --dryrun</code>
You should see something like this:
> [...]
> TS251_Sync_to_TS212 status 1546432143 "started"
> TS251_Sync_to_TS212 error 1546432143 0
> TS212_Sync_to_TS212 status 1546432141 "started"
> TS212_Sync_to_TS212 error 1546432141 0
> TS251_Sync_to_TS212 status 1546432353 "finished"
> TS251_Sync_to_TS212 error 1546432353 0
> TS251_Sync_to_TS212 last 1546432353 "Jan 2 13:32:33"
> TS212_Sync_to_TS212 status 1546432351 "finished"
> TS212_Sync_to_TS212 error 1546432351 0
> TS212_Sync_to_TS212 last 1546432351 "Jan 2 13:32:31"
> [...]
