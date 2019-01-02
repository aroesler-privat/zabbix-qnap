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
You should see lots of lines like <code>TS251_Sync_to_TS212 status 1546432143 "started"</code>. Every line reflect what would be sent via zabbix_sender to Zabbix. The format of the first parameter is <code>QNAPHOST_BACKUPJOB</code>, whereby spaces are replaced by underscores. The QNAPHOST is grep'd from the logfile, while BACKUPJOB is one of the jobs you defined in the <code>JOBS</code>-array.

Now download the template (template_qnap-backup-monitor.xml) and add it to your Zabbix via Configuration -> Templates -> Import. Every <code>QNAPHOST_BACKUPJOB</code> needs to be a virtual Zabbix-host equiped with this template. To easy figure out the names of the hosts to be created you should call <code>./qnap-backup-monitor.sh --file=/var/log/syslog --hosts-to-create</code>.

### Populate the Zabbix-hosts with existing data
If you want to import existing data to Zabbix call <code>./qnap-backup-monitor.sh --file=/var/log/syslog --import</code>. 

### Create systemd-service
Create <code>/etc/systemd/system/qnap-backup-monitor.service</code> ...
```
[Unit]
Description=Backup-Monitor for log-entries by QNAP / rsyslog
After=getty.target

[Service]
ExecStart=/usr/share/zabbix-scripts/qnap-backup-monitor.sh --file=/var/log/syslog
Restart=always

[Install]
WantedBy=multi-user.target
```
... and activate it via <code>systemctl daemon-reload</code>, <code>systemctl enable qnap-backup-monitor.service</code> and <code>systemctl start qnap-backup-monitor.service</code>.

This will start the script monitoring /var/log/syslog. Whenever the script ends / is killed it is restarted.

### Take care on log-rotation
When the logfile gets rotated the script has to be aligned to the new file-handle. This is easiest done by just killing it or calling <code>systemctl restart qnap-backup-monitor.service</code>. To kill it during logrotation simply add <code>kill `cat /var/run/qnap-backup-monitor.sh.pid`</code> to the <code>postrotate</code>-section of your logrotation-config.
