#! /bin/sh

# Nagios http password
htpasswd -c -b -s /etc/nagios3/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
chown nagios:nagios /etc/nagios3/htpasswd.users

sed -i "s,nagiosadmin,${NAGIOSADMIN_USER}," /etc/nagios3/cgi.cfg

