# Inspired by timlesallen/nagios
FROM debian:jessie
MAINTAINER Josef Friedrich <josef@friedrich.rocks>

ENV NAGIOSADMIN_USER jf
ENV NAGIOSADMIN_PASS ShreecPhiOd8
ENV NSCA_PASSWORD js4Ie0rK54dfr
ENV NSCA_ENCRYPTION 8
ENV DEBIAN_FRONTEND noninteractive

# Install
# supervisor -> process manager
# wget -> check_drupal
# curl -> check_wordpress_update
# dnsutils -> check_dns
# ssmpt -> mail handling
RUN apt-get update && \ 
	apt-get install -y --no-install-recommends \
	supervisor \
	wget \
	curl \
	ssmtp \
	nagios3 \
	monitoring-plugins \
	nagios-nrpe-plugin \
	nsca \
	dnsutils

RUN apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure apache and the nagios daemon to start on boot
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ADD setup-on-run.sh /setup-on-run.sh

RUN echo "Europe/Berlin" > /etc/timezone && \
	cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime

##
# Apache2 setup.
##

# Disable apache2 default site.
RUN a2dissite 000-default
RUN rm /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf
ADD apache.conf /etc/apache2/sites-available/nagios.conf
RUN a2ensite nagios
RUN echo 'Alias /stylesheets /etc/nagios3/stylesheets' >> /etc/apache2/conf-available/nagios3.conf 
RUN echo 'ScriptAlias /cgi-bin /usr/lib/cgi-bin/nagios3' >> cat /etc/apache2/conf-available/nagios3.conf
RUN sed "s%Alias /nagios3 /usr/share/nagios3/htdocs%#Alias /nagios3 /usr/share/nagios3/htdocs%" -i "/etc/apache2/conf-available/nagios3.conf" 

# Allow www-data to write to the command file.
RUN usermod -a -G nagios www-data

# Hack around weird things that were meaning no permission.
RUN rm -rf /var/lib/nagios3/rw && \
	mkdir /var/lib/nagios3/rw && \ 
	chown nagios:www-data /var/lib/nagios3/rw && \
	chmod 750 /var/lib/nagios3/rw && \
	mkfifo /var/lib/nagios3/rw/nagios.cmd && \
	chown nagios:nagios /var/lib/nagios3/rw/nagios.cmd

##
# Nagios3 setup.
##

# nagios.cfg
RUN sed -i "s,check_external_commands=0,check_external_commands=1," /etc/nagios3/nagios.cfg && \
	sed -i "s,check_host_freshness=0,check_host_freshness=1," /etc/nagios3/nagios.cfg && \
	sed -i "s,check_for_updates=1,check_for_updates=0," /etc/nagios3/nagios.cfg

RUN sed -i \
	's#$corewindow="main.php";#$corewindow="cgi-bin/nagios3/status.cgi?servicegroup=all\&style=summary";#' \ 
	/usr/share/nagios3/htdocs/index.php

RUN sed -i "s%url_html_path=/nagios3%url_html_path=/%" /etc/nagios3/cgi.cfg

ADD test/nagios-config.sh /test-nagios-config.sh

##
# NSCA setup.
##

RUN sed -i "s,#password=,password=${NSCA_PASSWORD}," /etc/send_nsca.cfg && \
	sed -i "s,encryption_method=1,encryption_method=${NSCA_ENCRYPTION}," /etc/send_nsca.cfg && \
	sed -i "s,#password=,password=${NSCA_PASSWORD}," /etc/nsca.cfg && \
	sed -i "s,decryption_method=1,decryption_method=${NSCA_ENCRYPTION}," /etc/nsca.cfg && \
	sed -i "s,debug=0,debug=1," /etc/nsca.cfg

RUN touch /var/run/nsca.pid && \
	chown nagios:nogroup /var/run/nsca.pid && \
	chmod 644 /var/run/nsca.pid 

ADD test/nsca.sh /test-nsca.sh

# Additional plugins.
ADD plugins/check_drupal /usr/lib/nagios/plugins/check_drupal
ADD plugins/check_wp_update /usr/lib/nagios/plugins/check_wp_update


VOLUME ["/etc/nagios3/conf.d"]
VOLUME ["/etc/nagios-plugins"]

EXPOSE 80
EXPOSE 5666
EXPOSE 5667

CMD ["/usr/bin/supervisord"]
