#! /bin/bash

echo -e "localhost\tdummy\t0\ttestesttest.\n" | /usr/sbin/send_nsca -H localhost -c /etc/send_nsca.cfg

