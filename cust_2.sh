#!/bin/bash
cp ports.conf /etc/apache2; cp 000-default.conf /etc/apache2/sites-enabled;
\cp index.html /var/www/html; systemctl start apache2; 
\cp filebeat.yml /etc/filebeat; systemctl restart filebeat; 
\cp mysqld.cnf /etc/mysql/mysql.conf.d; service mysql restart; 
\cp prometheus.yml /etc/prometheus; systemctl restart prometheus; 
\systemctl restart prometheus-node-exporter; 
\systemctl restart grafana-server
