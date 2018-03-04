## Remi Dependency on CentOS 6 and Red Hat (RHEL) 6 ##
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
 
## CentOS 6 and Red Hat (RHEL) 6 ##
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

## Install Apache (httpd) Web server and PHP 5.5.9
yum --enablerepo=remi,remi-php55 install httpd php php-common

## Install PHP 5.5.9 modules
yum --enablerepo=remi,remi-php55 install php-pecl-apc php-cli php-pear php-pdo php-mysqlnd php-pgsql php-pecl-mongo php-sqlite php-pecl-memcache php-pecl-memcached php-gd php-mbstring php-mcrypt php-xml

## Start Apache HTTP server (httpd) and autostart Apache HTTP server (httpd) on boot
service httpd start ## use restart after update
chkconfig --levels 235 httpd on

## Remi Dependency on CentOS 6 and Red Hat (RHEL) 6 ##
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
 
## CentOS 6 and Red Hat (RHEL) 6 ##
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

## Check Available MySQL versions
yum --enablerepo=remi,remi-test list mysql mysql-server

## Update or Install MySQL 5.5.33
yum --enablerepo=remi,remi-test install mysql mysql-server

## Start MySQL server and autostart MySQL on boot
service mysqld start ## use restart after update
chkconfig --levels 235 mysqld on

## Start MySQL Secure Installation with following command
/usr/bin/mysql_secure_installation

## Connect to MySQL database (localhost) with password
mysql -u root -p

## Update firewall rules
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT

## Reload firewall
service iptables restart