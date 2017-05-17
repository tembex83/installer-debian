#!/bin/bash
#
# virtualmin-solaris.sh
# Version 1.1
#
# Copyright 2005-2009 Virtualmin, Inc.
# Sets up a Solaris system to use CSW packages, installs the ones we need,
# installs Webmin, configures modules, installs Virtualmin modules, then runs
# the generic Virtualmin install script.
#
# Tested on Solaris 10 only. Any existing Webmin install will be over-written,
# and Sun-supplied apache, sendmail and bind servers will be shut down.
# Should only be run on a pristine system! 
#
# A manual install might work for you though.
# See here: http://www.virtualmin.com/documentation/id,virtualmin_administrators_guide/#alternative_manual_installation

if [ "$SERIAL" = "" ]; then
	SERIAL=GPL
fi
if [ "$KEY" = "" ]; then
	KEY=GPL
fi

PATH=$PATH:/opt/csw/bin
export PATH

# Create Virtualmin licence file
echo Creating Virtualmin licence file
cat >/etc/virtualmin-license <<EOF
SerialNumber=$SERIAL
LicenseKey=$KEY
EOF

# Install CSW pkg-get
echo Installing CSW package installer
cd /tmp
rm -f pkgutil.pkg
uname -r | grep 86 >/dev/null
if [ "$?" = 0 ]; then
	/usr/sfw/bin/wget -O pkgutil.pkg http://blastwave.network.com/csw/pkgutil_i386.pkg
else
	/usr/sfw/bin/wget -O pkgutil.pkg http://blastwave.network.com/csw/pkgutil_sparc.pkg
fi
pkginfo CSWpkgutil
if [ "$?" != "0" ]; then
	yes y | pkgadd -d pkgutil.pkg CSWpkgutil || exit 1
fi
PATH=$PATH:/opt/csw/bin
export PATH

# Update all CSW packages
echo Updating all installed CSW packages
yes y | /opt/csw/bin/pkgutil upgrade

# Disable Sun-supplied apps that we are going to install from CSW
echo Disabling Sun-supplied servers that will be replaced
svcadm disable ftp
svcadm disable sendmail
svcadm disable bind
svcadm disable apache
svcadm disable apache2

# Remove Sun-supplied Webmin
echo Removing any existing Webmin install
svcadm disable webmin
yes y | pkgrm SUNWwebminr
yes y | pkgrm WSwebmin
/etc/webmin/stop >/dev/null 2>&1
rm -rf /etc/webmin /var/webmin /opt/webmin

# Install apps used by Virtualmin from CSW
echo Installing required servers from CSW
for pkg in apache2 postfix procmail mysql4 mysql4devel mysql4client spamassassin php5 php5_mysql php5_session logrotate clamav dovecot proftpd wget perl pm_iotty pm_netssleay pm_cryptssleay pm_xmlsimple pm_dbdsqlite bind sasl saslauthd ap2_suexec awstats webalizer ruby rubygems; do
	yes y | /opt/csw/bin/pkgutil -i $pkg
	if [ "$?" != "0" ]; then
		echo Installation of $pkg from CSW failed
		exit 2
	fi
done

# Install Webmin
echo Installing Webmin
cd /tmp
if [ "$SERIAL" = "GPL" ]; then
	wget -O webmin-current.tar.gz http://software.virtualmin.com/gpl/wbm/webmin-current.tar.gz
else
	wget -O webmin-current.tar.gz http://$SERIAL:$KEY@software.virtualmin.com/wbm/webmin-current.tar.gz
fi
if [ "$?" != "0" ]; then
	echo Download of Webmin failed
	exit 3
fi
gunzip -c webmin-current.tar.gz | tar xf -
if [ "$?" != "0" ]; then
	echo Extraction of Webmin tar.gz file failed
	exit 3
fi
rm webmin-current.tar.gz
cd webmin-[0-9]*
config_dir=/etc/webmin
var_dir=/var/webmin
autoos=3
port=10000
login=root
crypt=x
ssl=1
atboot=1
perl=/opt/csw/bin/perl
theme=virtual-server-theme
export config_dir var_dir autoos port login crypt ssl atboot perl theme
./setup.sh /opt/webmin
if [ "$?" != "0" ]; then
	echo Webmin setup script failed
	exit 3
fi
cd /tmp
rm -rf webmin-[0-9]*

# Install Usermin
echo Installing Usermin
cd /tmp
if [ "$SERIAL" = "GPL" ]; then
	wget -O usermin-current.tar.gz http://software.virtualmin.com/gpl/wbm/usermin-current.tar.gz
else
	wget -O usermin-current.tar.gz http://$SERIAL:$KEY@software.virtualmin.com/wbm/usermin-current.tar.gz
fi
if [ "$?" != "0" ]; then
	echo Download of Usermin failed
	exit 4
fi
gunzip -c usermin-current.tar.gz | tar xf -
if [ "$?" != "0" ]; then
	echo Extraction of Usermin tar.gz file failed
	exit 4
fi
rm usermin-current.tar.gz
cd usermin-[0-9]*
config_dir=/etc/usermin
var_dir=/var/usermin
autoos=3
port=20000
ssl=1
atboot=1
perl=/opt/csw/bin/perl
export config_dir var_dir autoos port ssl atboot perl
./setup.sh /opt/usermin
if [ "$?" != "0" ]; then
	echo Usermin setup script failed
	exit 4
fi
cd /tmp
rm -rf usermin-[0-9]*

# Update configuration of modules that use CSW-supplied packages
echo Configuring Webmin modules to use CSW servers
cat >/etc/webmin/apache/config <<EOF
show_order=0
test_always=0
test_manual=0
httpd_conf=/etc/opt/csw/apache2/httpd.conf
show_list=0
access_conf=
mime_types=
apachectl_path=/opt/csw/apache2/sbin/apachectl
test_apachectl=1
max_servers=100
srm_conf=
test_config=1
httpd_path=/opt/csw/apache2/sbin/httpd
httpd_dir=/opt/csw/apache2
virt_name=
defines_mods=
link_dir=
stop_cmd=
virt_file=
pid_file=/var/opt/csw/apache2/run/httpd.pid
start_cmd=
graceful_cmd=
defines_file=
show_names=
httpd_version=
apply_cmd=
apache_docbase=
defines_name=
EOF

# Postfix
if [ -d /opt/csw/etc/postfix ]; then
	postfixetc=/opt/csw/etc/postfix
else
	postfixetc=/etc/opt/csw/postfix
fi
cat >/etc/webmin/postfix/config <<EOF
mailq_cmd=/opt/csw/bin/mailq
postfix_config_file=$postfixetc/main.cf
mailq_sort=0
postfix_config_command=/opt/csw/sbin/postconf
mailq_count=0
postfix_control_command=/opt/csw/sbin/postfix
perpage=20
delete_warn=1
fwd_mode=0
wrap_width=80
postfix_aliases_table_command=/opt/csw/sbin/postalias
sort_mode=0
show_cmts=0
check_config=1
mailq_dir=/var/spool/postfix
postfix_queue_command=/opt/csw/sbin/postqueue
prefix_cmts=0
postcat_cmd=/opt/csw/sbin/postcat
index_check=1
postfix_super_command=/opt/csw/sbin/postsuper
postfix_master=$postfixetc/master.cf
top_buttons=1
max_records=200
columns=2
postfix_newaliases_command=/opt/csw/bin/newaliases
postfix_lookup_table_command=/opt/csw/sbin/postmap
EOF

# Procmail
cat >/etc/webmin/procmail/config <<EOF
procmail=/opt/csw/bin/procmail
procmailrc=/opt/csw/etc/procmailrc
includes=0
EOF

# MySQL
cat >/etc/webmin/mysql/config <<EOF
date_subs=0
max_text=1000
perpage=25
mysqldump=/opt/csw/mysql4/bin/mysqldump
nodbi=0
mysql_libs=/opt/csw/mysql4/lib/mysql
max_dbs=50
start_cmd=cd /opt/csw/mysql4 ; ./bin/mysqld_safe &
mysql_data=/opt/csw/mysql4/var
mysqlimport=/opt/csw/mysql4/bin/mysqlimport
access=*: *
style=0
my_cnf=/opt/csw/mysql4/var/my.cnf
login=root
mysqlshow=/opt/csw/mysql4/bin/mysqlshow
mysql=/opt/csw/mysql4/bin/mysql
add_mode=1
passwd_mode=0
blob_mode=0
mysqladmin=/opt/csw/mysql4/bin/mysqladmin
EOF

# BIND
svcs -a | grep cswnamed >/dev/null
if [ "$?" = 0 ]; then
	namedstart="svcadm enable cswnamed"
	namedstop="svcadm disable cswnamed"
else
	namedstart="/etc/init.d/cswnamed start"
	namedstop="/etc/init.d/cswnamed stop"
	cp /etc/opt/csw/init.d/cswnamed /etc/init.d/cswnamed
	/opt/webmin/init/create-boot.pl cswnamed
fi
cat >/etc/webmin/bind8/config <<EOF
updserial_man=1
updserial_def=0
named_conf=/etc/opt/csw/named.conf
relative_paths=0
rev_must=0
soa_start=0
records_order=0
reversezonefilename_format=ZONE.rev
no_pid_chroot=0
short_names=0
master_ttl=1
allow_comments=0
no_chroot=0
named_path=/opt/csw/sbin/named
whois_cmd=whois
updserial_on=1
allow_long=0
allow_wild=0
show_list=0
rev_def=0
stop_cmd=$namedstop
confirm_zone=1
forwardzonefilename_format=ZONE.hosts
by_view=0
rndcconf_cmd=/opt/csw/sbin/rndc-confgen
start_cmd=$namedstart
rndc_conf=/etc/opt/csw/rndc.conf
support_aaaa=0
ipv6_mode=1
confirm_rec=0
soa_style=0
max_zones=50
largezones=0
allow_underscore=1
rndc_cmd=/opt/csw/sbin/rndc
auto_chroot=
pid_file=/var/opt/csw/named/named.pid
default_prins=
restart_cmd=
file_perms=
extra_reverse=
default_master=
master_dir=
chroot=
file_owner=
ndc_cmd=
named_group=
this_ip=
named_user=
free_nets=
zones_file=
extra_forward=
slave_dir=
EOF

# SpamAssassin
cat >/etc/webmin/spam/config <<EOF
procmailrc=
procmail_cmd=*
processes=spamd amavisd
sa_learn=/opt/csw/bin/sa-learn
spamassassin=/opt/csw/bin/spamassassin
warn_procmail=1
call_spam=1
local_cf=/etc/opt/csw/spamassassin/local.cf
before_cmd=
after_cmd=
restart_cmd=
EOF

# Dovecot
cat >/etc/webmin/dovecot/config <<EOF
init_script=dovecot
pid_file=/opt/csw/var/run/dovecot/master.pid
dovecot=/opt/csw/sbin/dovecot
dovecot_config=/opt/csw/etc/dovecot.conf
EOF

# ProFTPd
cat >/etc/webmin/proftpd/config <<EOF
ftpusers=/etc/ftpusers
pid_file=/opt/csw/var/proftpd.pid
test_always=0
test_config=1
proftpd_path=/opt/csw/sbin/proftpd
test_manual=0
proftpd_conf=/opt/csw/etc/proftpd.conf
start_cmd=
stop_cmd=
add_file=
EOF

# Create MySQL databases
if [ ! -d "/opt/csw/mysql4/var/mysql" ]; then
	echo Creating initial MySQL database
	cd /opt/csw/mysql4
	./bin/mysql_install_db
	chown -R mysql:mysql /opt/csw/mysql4/var
fi

# Create initial BIND config
if [ ! -r "/etc/opt/csw/named.conf" ]; then
	echo Creating initial BIND configuration file
	cat >/etc/opt/csw/named.conf <<EOF
options {
        directory "/etc/opt/csw";
        pid-file "/var/opt/csw/named/named.pid";
        };

zone "." {
        type hint;
        file "/etc/opt/csw/db.cache";
        };
EOF
	cp /opt/webmin/bind8/db.cache /etc/opt/csw/db.cache
fi

# Create initial Dovecot config
echo Creating Dovecot configuration file and certificates
if [ ! -r "/opt/csw/etc/dovecot.conf" ]; then
	cp /opt/csw/etc/dovecot-example.conf /opt/csw/etc/dovecot.conf
fi
if [ ! -r "/opt/csw/ssl/certs/dovecot.pem" ]; then
	mkdir -p /opt/csw/ssl/certs
	cp /etc/webmin/miniserv.pem /opt/csw/ssl/certs/dovecot.pem
fi
if [ ! -r "/opt/csw/ssl/private/dovecot.pem" ]; then
	mkdir -p /opt/csw/ssl/private
	cp /etc/webmin/miniserv.pem /opt/csw/ssl/private/dovecot.pem
fi
cp /opt/csw/etc/dovecot.conf /tmp/$$.dovecot.conf
cat /tmp/$$.dovecot.conf | sed -e 's/^#*disable_plaintext_auth.*/disable_plaintext_auth = no/' | sed -e 's/^ *#*pop3_uidl_format.*/ pop3_uidl_format = %v.%u/' >/opt/csw/etc/dovecot.conf
rm -f /tmp/$$.dovecot.conf

# Create initial proftpd config
if [ ! -r "/opt/csw/etc/proftpd.conf" ]; then
	echo Creating ProFTPd configuration file
	cp /opt/csw/etc/proftpd.conf.CSW /opt/csw/etc/proftpd.conf
fi

# Create ftp user, for proftpd
echo Adding FTP users
grep ftp: /etc/group >/dev/null || groupadd ftp
grep ftp: /etc/passwd >/dev/null || useradd -G ftp ftp

# Configure Apache to use SSL, by removing <IfDefine SSL> block
echo Configuring Apache to enable SSL
cp /etc/opt/csw/apache2/httpd.conf /tmp/$$.httpd.conf
cat /tmp/$$.httpd.conf | /opt/csw/bin/perl -e 'while(<>) { $h .= $_ }; $h =~ s/<IfDefine SSL>\n(.*)\n<.IfDefine>/$1/; print $h' >/etc/opt/csw/apache2/httpd.conf
rm -f /tmp/$$.httpd.conf
if [ ! -r "/etc/opt/csw/apache2/server.crt" ]; then
  cp /etc/webmin/miniserv.pem /etc/opt/csw/apache2/server.crt
fi
if [ ! -r "/etc/opt/csw/apache2/server.key" ]; then
  cp /etc/webmin/miniserv.pem /etc/opt/csw/apache2/server.key
fi

# Enable DAV apache module
echo Enabling Apache DAV module
cp /etc/opt/csw/apache2/httpd.conf /tmp/$$.httpd.conf
cat /tmp/$$.httpd.conf | sed -e 's/^#LoadModule dav_module/LoadModule dav_module/' | sed -e 's/^#LoadModule dav_fs_module/LoadModule dav_fs_module/' >/etc/opt/csw/apache2/httpd.conf
rm -f /tmp/$$.httpd.conf

# Use initial clamav databases
echo Using default ClamAV databases
if [ ! -r "/var/opt/csw/clamav/db/daily.cvd" ]; then
	cp /var/opt/csw/clamav/db/daily.cvd.CSW /var/opt/csw/clamav/db/daily.cvd
fi
if [ ! -r "/var/opt/csw/clamav/db/main.cvd" ]; then
	cp /var/opt/csw/clamav/db/main.cvd.CSW /var/opt/csw/clamav/db/main.cvd
fi

# Copy template awstats config to the right place
if [ ! -r "/opt/csw/awstats/etc/awstats.model.conf" ]; then
	echo Creating AWstats configuration file
	cp /opt/csw/awstats/wwwroot/cgi-bin/awstats.model.conf /opt/csw/awstats/etc/awstats.model.conf
fi

# If hostname is not fully qualified, make it so in Postfix config
hostname | fgrep . >/dev/null
if [ "$?" != "0" ]; then
	echo Ensuring hostname is fully qualified in Postfix configuration
	grep '^myhostname' $postfixetc/main.cf | fgrep . >/dev/null
	if [ "$?" != "0" ]; then
		# Work out full hostname
		domain=`grep domain /etc/resolv.conf | cut -f 2 -d ' '`
		if [ "$domain" = "" ]; then
			domain=unknown
		fi
		hostname=`hostname`.$domain

		# Fix Postfix config
		grep -v '^myhostname' $postfixetc/main.cf >/tmp/$$.main.cf
		echo myhostname = $hostname >>/tmp/$$.main.cf
		cat /tmp/$$.main.cf >$postfixetc/main.cf
		rm -f /tmp/$$.main.cf
	fi
else
	echo Hostname `hostname` is good
fi

# Make libdb available to Postfix smtpd. This is a workaorund for a SASL
# authentication bug.
echo Enabling SASL for Postfix
if [ ! -r /opt/csw/lib/libdb-4.2.so ]; then
	ln -s /opt/csw/bdb4/lib/libdb-4.2.so /opt/csw/lib
fi
usermod -G sasl postfix 2>/dev/null	# Needed so that Postfix can talk to
					# the SASL socket

# Make sure all CSW servers are started at boot, and now
echo Configuring all CSW servers to start at boot time, and starting them now
/opt/webmin/init/create-boot.pl apache2 "Apache webserver" "/opt/csw/apache2/sbin/apachectl start" "/opt/csw/apache2/sbin/apachectl stop"
mkdir -p /opt/csw/apache2/var/log
/etc/init.d/apache2 start
svcadm disable cswapache2	# We use our own init script
svcadm enable cswpostfix
/opt/webmin/init/create-boot.pl mysql4 "MySQL database server" "cd /opt/csw/mysql4 ; /opt/csw/mysql4/bin/mysqld_safe &" "ps -ef | grep mysql | grep -v grep | awk '{ print \$2 }' | xargs kill -9"
(cd /opt/csw/mysql4 ; /opt/csw/mysql4/bin/mysqld_safe >/dev/null 2>&1 </dev/null) &
$namedstart
/opt/webmin/init/create-boot.pl dovecot "Dovecot IMAP / POP3 server" /opt/csw/sbin/dovecot "kill \`cat /opt/csw/var/run/dovecot/master.pid\`"
/opt/webmin/init/create-boot.pl proftpd "ProFTPd FTP server" /opt/csw/sbin/proftpd "kill \`cat /opt/csw/var/proftpd.pid\`"
/opt/webmin/init/create-boot.pl cswsaslauthd
if [ ! -r /etc/opt/csw/saslauthd.init ]; then
	echo "MECHANISM=pam" >/etc/opt/csw/saslauthd.init
fi
/etc/init.d/cswsaslauthd start
/opt/webmin/init/create-boot.pl usermin "Usermin" /etc/usermin/start /etc/usermin/stop

# Install Virtulmin-specific modules and themes, as defined in updates.txt
echo Installing Virtualmin modules and themes
cd /tmp
if [ "$SERIAL" = "GPL" ]; then
	wget -O - http://www.webmin.com/updates/updates.txt | grep virtual-server >updates.txt
	wget -O - http://www.webmin.com/updates/updates.txt | grep virtualmin- >>updates.txt
	wget -O - http://www.webmin.com/updates/updates.txt | grep security-updates >>updates.txt
else
	wget -O updates.txt http://$SERIAL:$KEY@software.virtualmin.com/wbm/updates.txt
fi
for modpath in `cut -f 3 updates.txt`; do
	modfile=`basename $modpath`
	if [ "$SERIAL" = "GPL" ]; then
		wget -O $modfile http://www.webmin.com/$modpath
	else
		wget -O $modfile http://$SERIAL:$KEY@software.virtualmin.com/$modpath
	fi
	if [ "$?" != "0" ]; then
		echo Download of Webmin module from $modpath failed
		exit 5
	fi
	/opt/webmin/install-module.pl /tmp/$modfile
	if [ "$?" != "0" ]; then
		echo Installation of Webmin module from $modpath failed
		exit 5
	fi
	rm -f /tmp/$modfile
done

# Configure Webmin to use updates.txt
echo Configuring Webmin to use Virtualmin updates service
if [ "$SERIAL" != "GPL" ]; then
	echo "upsource=http://software.virtualmin.com/wbm/updates.txt	http://www.webmin.com/updates/updates.txt" >>/etc/webmin/webmin/config
	echo "upuser=$SERIAL" >>/etc/webmin/webmin/config
	echo "uppass=$KEY" >>/etc/webmin/webmin/config
fi
echo "upshow=1" >>/etc/webmin/webmin/config
echo "upthird=1" >>/etc/webmin/webmin/config

# AWstats Webmin module config - has to be done after the plugin is installed
cat >/etc/webmin/virtualmin-awstats/config <<EOF
noedit=0
nocron=0
awstats=/opt/csw/awstats/wwwroot/cgi-bin/awstats.pl
icons=/usr/local/awstats/wwwroot/icon
config_dir=/opt/csw/awstats/etc
plugins=
lang=
format=
copyto=
aliases=
lib=
EOF

# Install our setuid procmail wrapper
echo Downloading and installing Procmail wrapper
wget -O /opt/csw/bin/procmail-wrapper http://$SERIAL:$KEY@software.virtualmin.com/solaris/procmail-wrapper.`uname -p`
if [ "$?" != "0" ]; then
	echo Download of procmail wrapper failed
	exit 6
fi
chmod 6755 /opt/csw/bin/procmail-wrapper

# Install our replacement suexec
echo Downloading and installing replacement for SuExec
wget -O /opt/csw/apache2/sbin/suexec http://$SERIAL:$KEY@software.virtualmin.com/solaris/suexec.`uname -p`
if [ "$?" != "0" ]; then
	echo Download of replacement suexec failed
	exit 7
fi
cp /opt/csw/apache2/sbin/suexec /opt/csw/apache2/sbin/suexec.virtualmin
chmod 4755 /opt/csw/apache2/sbin/suexec /opt/csw/apache2/sbin/suexec.virtualmin

# Run standard install script to adjust other Webmin settings to suit Virtualmin
echo Downloading and running Virtualmin configuration script
/etc/webmin/stop
/etc/webmin/start
wget -O /tmp/virtualmin-base-standalone.pl http://software.virtualmin.com/lib/virtualmin-base-standalone.pl
chmod +x /tmp/virtualmin-base-standalone.pl
/opt/csw/bin/perl /tmp/virtualmin-base-standalone.pl install
if [ "$?" != "0" ]; then
	echo Virtualmin post-install configuration script failed
	exit 8
fi

# Don't use mod_fcgid, as we don't have it on Solaris yet
echo Disabling use of fcgid by Virtualmin
cp /etc/webmin/virtual-server/config /tmp/$$.config
cat /tmp/$$.config | sed -e 's/php_suexec=2/php_suexec=1/' >/etc/webmin/virtual-server/config
rm -f /tmp/$$.config

# Turn off mailman plugin, as no CSW package exists for it
echo Disabling use of mailman by Virtualmin
cp /etc/webmin/virtual-server/config /tmp/$$.config
cat /tmp/$$.config | sed -e 's/virtualmin-mailman//' >/etc/webmin/virtual-server/config
rm -f /tmp/$$.config

# All done
host=`hostname`
echo -----------------------------------------------------------------------
echo Virtualmin installation is complete. You can now login at :
echo https://$host:10000/ as root with the system\'s root password.
echo -----------------------------------------------------------------------

