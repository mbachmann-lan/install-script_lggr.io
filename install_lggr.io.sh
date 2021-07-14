#!/bin/bash
#######################################################################
#                                                                     #
# Script to install lggr.io on a FRESH and CLEAN Debian 10 Server.    #
# Adjust the Variables section to your needs, or leave the defaults.  #
#                                                                     #
# rev 1.0 - 02.01.2021 ~ lggr.io@bachmann-lan.de                      #
#                                                                     #
#######################################################################

# bash colors
blue='\e[94m'
red='\e[91m'
white='\e[97m'
green='\e[92m'
bluebackground='\e[44m'
redbackground='\e[101m'
reset='\033[0m'

# check if we are root
if [[ $EUID -ne 0 ]]; then
echo -e $red"This script must be run as root!" 2>&1 $reset
 echo
exit 1
fi

# header warning
clear
echo -e $redbackground"######################################################################"
echo -e "#                                                                    #"
echo -e "# !THIS SCRIPT SHOULD ONLY BE EXECUTED ON A CLEAN INSTALLED SERVER!  #"
echo -e "#                                                                    #"
echo -e "######################################################################"$reset
echo

read -p "$(echo -e $green**$white Are you sure to start the installation of the lggr.io Server? "(Y/N)"$reset) "  -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
echo
 exit 1
else

# header info
function header {
clear
echo -e $bluebackground"######################################################################"
echo -e "#      _                  _           _           _        _ _       #"
echo -e "#     | | __ _  __ _ _ __(_) ___     (_)_ __  ___| |_ __ _| | |      #"
echo -e "#     | |/ _\` |/ _\` | '__| |/ _ \    | | '_ \/ __| __/ _\` | | |      #"
echo -e "#     | | (_| | (_| | |_ | | (_) |   | | | | \__ \ || (_| | | |      #"
echo -e "#     |_|\__, |\__, |_(_)|_|\___/    |_|_| |_|___/\__\__,_|_|_|      #"
echo -e "#        |___/ |___/                                                 #"
echo -e "#                                                                    #"
echo -e "######################################################################"$reset
}

#######################################################################
# Variables - ADJUST, OR GO WITH THE DEFAULTS                         #
#######################################################################
locale="en_US"			# set language (en_US, de_DE)
lggrwebdir="lggr"		# directory to install lggr.io in /var/www/html
lggrwebuser="lggr"		# lggr webinterface user
lggrwebpass="lggradmin"		# lggr webinterface password
lggrdbname="lggr"		# lggr database name
lggrdbuser="lggr"		# lggr user (used by syslog-ng for inserting new data)
lggrdbpass="34fGtir3"		# lggr database password (used by syslog-ng for inserting new data)
lggrdbviewer="lggrviewer"	# lggr logviewer user (used by the web gui for normal viewing)
lggrdbviewerpass="efH34q30"	# lggr logviewer password (used by the web gui for normal viewing)
lggrdbadmin="lggradmin"		# lggr admin user (used by clean up cron job and for archiving)
lggrdbadminpass="92gHu338"	# lggr admin password (used by clean up cron job and for archiving)

# update system
header
echo -e $white*$green update system$reset
apt-get update && apt-get upgrade -y

# install all required packages
header
echo -e $white*$green install all required packages$reset
apt install -y apache2 mariadb-server mariadb-client php7.3 php7.3-cli php7.3-mysql php-redis redis-server syslog-ng libdbd-mysql wget git

#######################################################################
# add de_DE and update locales                                              #
#######################################################################
header
echo -e $white*$green add and update locales$reset

# enable locales de_DE.UTF-8
sed -i 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
/usr/sbin/locale-gen

#######################################################################
# Apache & PHP                                                        #
#######################################################################
header
echo -e $white*$green Apache and  PHP$reset

# set date and timezone
sed -i -e "s/^;date.timezone =/date.timezone = Europe\/Berlin/" /etc/php/7.3/apache2/php.ini
sed -i -e "s/^;date.timezone =/date.timezone = Europe\/Berlin/" /etc/php/7.3/cli/php.ini

# create Apache configuration
mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf_ORG
cat << EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html
	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	# basic authentification for the lggr.io directory
	<Directory "/var/www/html/$lggrwebdir">
	 AllowOverride All
	</Directory>
	</VirtualHost>
EOF

# create index.html to redirect to lggr.io webinterface
cat << EOF > /var/www/html/index.html
<html>
 <head>
   <title>lggr.io</title>
   <meta http-equiv="Content-type" content="text/html; charset=iso-8859-1">
   <meta http-equiv="refresh" content="0; URL=/$lggrwebdir/">
 </head>
 <body></body>
</html>
EOF

# create basic authentification user and password
htpasswd -cb /var/www/webuser $lggrwebuser $lggrwebpass

# activate Apache modules headers and expires
a2enmod headers expires

# restart apache2
systemctl restart apache2.service

#######################################################################
# lggr.io                                                             #
#######################################################################
header
echo -e $white*$green lggr.io$reset

# clone github repository
cd /var/www/html
git clone https://github.com/kkretsch/lggr.git $lggrwebdir

# download and extract 3rd parties libraries
wget https://lggr.io/wp-content/uploads/2015/06/lggr_contrib.tar.gz
tar xfz lggr_contrib.tar.gz -C /var/www/html/$lggrwebdir

# the webuser needs write access to the lggr cache directory
chown www-data:www-data /var/www/html/$lggrwebdir/cache

# create config_class.php 
mv /var/www/html/$lggrwebdir/inc/config_class.php /var/www/html/$lggrwebdir/inc/config_class.php_ORG
cat << EOF > /var/www/html/$lggrwebdir/inc/config_class.php
<?php

class Config extends AbstractConfig {

    function __construct() {
        \$this->setDbUser('$lggrdbviewer');
        \$this->setDbPwd('$lggrdbviewerpass');
        \$this->setDbName('$lggrdbname');

        // Set your preferred language en_US, de_DE, or pt_BR
        \$this->setLocale('$locale');

        /* local storage */
        \$this->setUrlBootstrap('/$lggrwebdir/contrib/bootstrap/');
        \$this->setUrlJquery('/$lggrwebdir/contrib/jquery/');
        \$this->setUrlJqueryui('/$lggrwebdir/contrib/jqueryui/');
        \$this->setUrlJAtimepicker('/$lggrwebdir/contrib/timepicker/');
        \$this->setUrlChartjs('/$lggrwebdir/contrib/chartjs/');
        \$this->setUrlJQCloud('/$lggrwebdir/contrib/jqcloud/');
    } // constructor
} // class
EOF

# create cronjobs for maintenance
cat << EOF > /etc/cron.d/lggr
# disable sending emails
MAILTO=""

# on default it keeps the last 4 weeks of entries, to purge old messages run admin/cron.php daily
30 1 * * * www-data /usr/bin/php /var/www/html/$lggrwebdir/admin/cron.php

# to prepare server id/name relations run admin/cron_often.php every 5 minutes
*/5 * * * * www-data /usr/bin/php /var/www/html/$lggrwebdir/admin/cron_often.php
EOF

#######################################################################
# MariaDB                                                             #
#######################################################################
header
echo -e $white*$green MariaDB$reset

# create database
mysql -e "CREATE DATABASE $lggrdbname;"

# create user.sql
mv /var/www/html/$lggrwebdir/doc/user.sql /var/www/html/$lggrwebdir/doc/user.sql_ORG

cat << EOF > /var/www/html/$lggrwebdir/doc/user.sql
# create the following three mysql users:
# used by syslog-ng for inserting new data, referenced in /etc/syslog-ng/conf.d/08lggr.conf
GRANT INSERT,SELECT,UPDATE ON $lggrdbname.* TO $lggrdbuser@localhost IDENTIFIED BY '$lggrdbpass';

# used by the web gui for normal viewing, referenced in inc/config_class.php
GRANT SELECT ON $lggrdbname.* TO $lggrdbviewer@localhost IDENTIFIED BY '$lggrdbviewerpass';

# used by clean up cron job and for archiving, referenced in inc/adminconfig_class.php
GRANT SELECT,UPDATE,DELETE ON $lggrdbname.* TO $lggrdbadmin@localhost IDENTIFIED BY '$lggrdbadminpass';
GRANT SELECT,INSERT ON TABLE $lggrdbname.servers TO $lggrdbadmin@localhost;
# activate changes
FLUSH PRIVILEGES;
EOF

# adjust database name in db.sql
sed -i -e "s/\`lggr\`/\`$lggrdbname\`/" /var/www/html/$lggrwebdir/doc/db.sql

# import db.sql
mysql -u root $lggrdbname < /var/www/html/$lggrwebdir/doc/db.sql

# import user.sql
mysql -u root < /var/www/html/$lggrwebdir/doc/user.sql

# create new adminconfig_class.php
cat << EOF > /var/www/html/$lggrwebdir/inc/adminconfig_class.php
<?php

class AdminConfig extends AbstractConfig {

    function __construct() {
        \$this->setDbUser('$lggrdbadmin');
        \$this->setDbPwd('$lggrdbadminpass');
        \$this->setDbName('$lggrdbname');
    } // constructor
} // class
EOF

# change SQL_MODE (errors with the current default settings of mariadb)
sed -i '/\[mysqld\]/a sql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER' /etc/mysql/mariadb.conf.d/50-server.cnf

# ***BUG*** mixed upper- and lowercase tablenames, adjust them to lowercase
sed -i '/\[mysqld\]/a lower_case_table_names = 1' /etc/mysql/mariadb.conf.d/50-server.cnf

# restart mariadb
systemctl restart mariadb.service

#######################################################################
# syslog-ng                                                           #
#######################################################################
header
echo -e $white*$green syslog-ng$reset

# create 08lggr.conf
cat << EOF > /etc/syslog-ng/conf.d/08lggr.conf
filter f_no_debug { not level(debug); };
options { keep_hostname(yes); };
source s_net { udp( ip("0.0.0.0") port(514) log-iw-size(2000) ); };
# source s_net { tcp( ip("0.0.0.0") port(514) max-connections(20) log-iw-size(2000) ); };
destination d_newmysql {
sql(
flags(dont-create-tables,explicit-commits)
session-statements("SET NAMES 'utf8'")
batch-lines(10)
batch-timeout(5000)
local_time_zone("Europe/Berlin")
type(mysql)
username("$lggrdbuser")
password("$lggrdbpass")
database("$lggrdbname")
host("localhost")
table("newlogs")
columns("date", "facility", "level", "host", "program", "pid", "message")
values("\${R_YEAR}-\${R_MONTH}-\${R_DAY} \${R_HOUR}:\${R_MIN}:\${R_SEC}", "\$FACILITY", "\$LEVEL", "\$HOST", "\$PROGRAM", "\$PID", "\$MSGONLY")
indexes()
 );
};

log { source(s_net); source(s_src); filter(f_no_debug); destination(d_newmysql); };
EOF

# enable --no-caps option in syslog-ng
sed -i -e "s/^#SYSLOGNG/SYSLOGNG/" /etc/default/syslog-ng

# enable client logging to syslog-ng
cat << EOF > /etc/syslog-ng/conf.d/10lggr-client.conf
destination d_net { udp("127.0.0.1" port(514) log_fifo_size(1000)); };
log { source(s_src); destination(d_net); };
EOF

# restart syslog-ng service
systemctl restart syslog-ng.service

#######################################################################
# BUGS - yes, they still exist                                        #
#######################################################################
header
echo -e $white*$green fixing some bugs$reset

# ***BUG*** remove all ^M characters in *.php files
find $lggrwebdir -name "*.php" -exec sed -i -e "s/\r//g" {} \;

# ***BUG*** archiving logs not possible, wrong path to do.php in lggr.js
sed -i -e "s/'\/do.php/'.\/do.php/g" /var/www/html/$lggrwebdir/js/lggr.js

# ***BUG*** Statistic Page -> Message levels relative distribution, err chart is green instead of red, missing #
sed -i -e "s/d9534f/#d9534f/" /var/www/html/$lggrwebdir/js/lggr_stat_data.php

#######################################################################
# some theme modifications                                            #
#######################################################################
header
echo -e $white*$green some theme modifications$reset

# remove Program Cloud on Statistic page
sed -i -e "s/<h2>Program Cloud<\/h2>/<\!-- <h2>Program Cloud<\/h2> -->/" /var/www/html/$lggrwebdir/stats.php
sed -i -e "s/<div id=\"cloudcontainer\"><\/div>/<\!-- <div id=\"cloudcontainer\"><\/div> -->/" /var/www/html/$lggrwebdir/stats.php

#######################################################################
# create and insert new info page                                         #
#######################################################################
header
echo -e $white*$green create and insert new info page$reset

# add link in header menu to this new page
sed -i '/Project/a \                <li><a href="info.php"><?= _('Info') ?></a></li>\' $lggrwebdir/tpl/nav.inc.php
sed -i s"/(Info)/('Info')/" $lggrwebdir/tpl/nav.inc.php

# create info page
cat << EOF > $lggrwebdir/info.php
<?php
require 'inc/pre.inc.php';
define('TITLE', _('Info'));
require 'tpl/head.inc.php';
define('INC_FOOTER', 'tpl/foot.inc.php');

\$l = null;
try {
            \$l = new Lggr(\$state, \$config);
    }

catch (LggrException \$e) {
            echo '<div class="container"><div class="alert alert-danger" role="alert">' . \$e->getMessage() . '</div></div>';
                require INC_FOOTER;
                exit();
	}

if (version_compare(phpversion(), '5.4', '<')) {
            echo '<div class="container"><div class="alert alert-danger" role="alert">Your PHP version ' .
                        phpversion() . ' might be too old, expecting at least 5.4</div></div>';
		}

require 'tpl/nav.inc.php';
?>

<div class="container" id="infoheader">
        <H1><a href="https://lggr.io/" target="_blank"> https//lggr.io</a> - The web based syslog gui</H1>
        <HR>
        <H2>lggr.io (old version)</H2>
        This <b>lggr.io</b> installation was build from the old and archived <a href="https://github.com/kkretsch/lggr" target="_blank"><b>GitHub</b></a> Repository.<br />
        <HR>
        <H2>lggr.io (new version)</H2>
        The new maintained version can be found on <a href="https://gitlab.kretschmann.software/kai/lggr" target="_blank"><b>GitLab</b></a>.<br /><br />
        <ul>
        <li>26.12.2020 <a href="https://lggr.io/2020/12/updated-main-branch" target="_blank">Updated main branch</a></li>
        <li>13.12.2020 <a href="https://lggr.io/2020/12/develop-branch" target="_blank">Develop branch</a> (Demo and Documentation)</li>
        <li>29.11.2020 <a href="https://lggr.io/2020/11/new-sql-user-management/" target="_blank">New sql user management</a></li>
        <li>24.10.2020 <a href="https://lggr.io/2020/10/git-branches/" target="_blank">git branches</a></li>
        <li>22.10.2020 <a href="https://lggr.io/2020/10/modernizing-the-php/" target="_blank">Modernizing the PHP</a></li>
        </ul>
</div>

<?php
require INC_FOOTER;
?>
EOF

#######################################################################
# FINISHED                                                            #
#######################################################################
header
echo -e $white*$green finished$reset
echo
echo "---------------------------------------------------------------------"
echo -e "*$green lggr.io Webinterface $white                               " 
echo "---------------------------------------------------------------------"
echo "url	: http://`hostname -f`                                         "
echo "url	: http://`hostname -I`                                         "
echo "login	: user: $lggrwebuser with password: $lggrwebpass               "
echo "---------------------------------------------------------------------"
echo -e $reset

fi

# END OF SCRIPT
