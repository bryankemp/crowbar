# Kickstart file automatically generated by anaconda.

install
url=http://192.168.0.1:8091/redhat_dvd/
key --skip
lang en_US.UTF-8
keyboard us
xconfig --startxonboot
network --device eth0 --bootproto dhcp
# crowbar
rootpw --iscrypted $1$H6F/NLec$Fps2Ut0zY4MjJtsa1O2yk0
firewall --disabled
authconfig --enableshadow --enablemd5
selinux --disabled
timezone --utc Europe/London
bootloader --location=mbr --driveorder=sda
zerombr yes
clearpart --all --drives=sda
part /boot --fstype ext3 --size=100 --ondisk=sda
part pv.6 --size=0 --grow --ondisk=sda
volgroup lv_admin --pesize=32768 pv.6
logvol / --fstype ext3 --name=lv_root --vgname=lv_admin --size=1 --grow
reboot

%packages
@base
@core
@editors
@text-internet
keyutils
trousers
fipscheck
device-mapper-multipath
OpenIPMI
OpenIPMI-tools
emacs-nox
openssh

%post
export PS4='${BASH_SOURCE}@${LINENO}(${FUNCNAME[0]}): '
set -x
(
    # copy the install image.
    mkdir -p /tftpboot/redhat_dvd
    ( cd /tftpboot/redhat_dvd
	wget -r -np -nH --cut-dirs=1 http://192.168.0.1:8091/redhat_dvd/
    )
    # rewrite network config with correct config for next boot
    cat <<EOF >/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
NETMASK=255.255.255.0
IPADDR=192.168.124.10
GATEWAY=192.168.124.1
TYPE=Ethernet
EOF

    BASEDIR="/tftpboot/redhat_dvd"
    
    (cd /etc/yum.repos.d && rm *)
    
    cat >/etc/yum.repos.d/RHEL5.6-Base.repo <<EOF
[RHEL56-Base]
name=RHEL 5.6 Server
baseurl=file:///$BASEDIR/Server
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
    
    cat >/etc/yum.repos.d/crowbar-xtras.repo <<EOF
[crowbar-xtras]
name=Crowbar Extra Packages
baseurl=file:///$BASEDIR/extra/pkgs
gpgcheck=0
EOF
    
# Make sure /opt is created
    mkdir -p /opt/dell/bin
    
# Copy the dell parts into a hidden install directory.
    cd /opt
    cp -r /$BASEDIR/dell .dell-install
    
# Make a destination for dell finishing scripts
    
    finishing_scripts=(update_hostname.sh validate_data_bag.rb \
	validate_bags.rb blocking_chef_client.sh looper_chef_client.sh single_chef_client.sh \
	install_barclamp.sh barclamp_lib.rb gather_logs.sh gather_cli.sh)
    ( cd /opt/.dell-install; cp "${finishing_scripts[@]}" /opt/dell/bin; )
    
# "Install h2n for named management"
    cd /opt/dell/
    tar -zxf /tftpboot/redhat_dvd/extra/h2n.tar.gz
    ln -s /opt/dell/h2n-2.56/h2n /opt/dell/bin/h2n
    
    cp -r /opt/.dell-install/openstack_manager /opt/dell
    
# Make a destination for switch configs
    mkdir -p /opt/dell/switch
    cp /opt/.dell-install/*.stk /opt/dell/switch
    
# Install dell code
    cd /opt/.dell-install
    
# put the chef files in place
    cp -r chef /opt/dell
    cp rsyslog.d/* /etc/rsyslog.d/
    
# Install barclamps for now
    cd barclamps
    for i in *; do
	[[ -d $i ]] || continue
	cd "$i"
	( cd chef; cp -r * /opt/dell/chef )
	( cd app; cp -r * /opt/dell/openstack_manager/app )
	( cd config; cp -r * /opt/dell/openstack_manager/config )
	( cd command_line; cp * /opt/dell/bin )
	( cd public ; cp -r * /opt/dell/openstack_manager/public )
	cd ..
    done
    cd ..
    
# Make sure the bin directory is executable
    chmod +x /opt/dell/bin/*
    
# Make sure the ownerships are correct
    chown -R openstack.admin /opt/dell
    
#
# Make sure the permissions are right
# Copy from a cd so that means most things are read-only which is fine, except for these.
#
    chmod 755 /opt/dell/chef/data_bags/crowbar
    chmod 644 /opt/dell/chef/data_bags/crowbar/*
    chmod 755 /opt/dell/openstack_manager/db
    chmod 644 /opt/dell/openstack_manager/db/*
    chmod 755 /opt/dell/openstack_manager/tmp
    chmod -R +w /opt/dell/openstack_manager/tmp/*
    chmod 755 /opt/dell/openstack_manager/public/stylesheets
    
# Get out of the directories.
    cd 
    
# Look for any crowbar specific kernel parameters
    for s in $(cat /proc/cmdline); do
	VAL=${s#*=} # everything after the first =
	case ${s%%=*} in # everything before the first =
	    crowbar.hostname) CHOSTNAME=$VAL;;
	    crowbar.url) CURL=$VAL;;
	    crowbar.use_serial_console) 
		sed -i "s/\"use_serial_console\": .*,/\"use_serial_console\": $VAL,/" /opt/dell/chef/data_bags/crowbar/bc-template-provisioner.json;;
	    crowbar.debug.logdest) 
		echo "*.*    $VAL" >> /etc/rsyslog.d/00-crowbar-debug.conf
		mkdir -p "$BASEDIR/rsyslog.d"
		echo "*.*    $VAL" >> "$BASEDIR/rsyslog.d/00-crowbar-debug.conf"
		;;
	    crowbar.authkey)
		mkdir -p "/root/.ssh"
		printf "$VAL\n" >>/root/.ssh/authorized_keys
		cp /root/.ssh/authorized_keys "$BASEDIR/authorized_keys"
		;;
	esac
    done
    
    if [[ $CHOSTNAME ]]; then
	
	cat > /install_system.sh <<EOF
#!/bin/bash
set -e
cd /tftpboot/redhat_dvd/extra
./install $CHOSTNAME

rm -f /etc/rc2.d/S99install
rm -f /etc/rc3.d/S99install
rm -f /etc/rc5.d/S99install

rm -f /install_system.sh

EOF
	
	chmod +x /install_system.sh
	ln -s /install_system.sh /etc/rc3.d/S99install
	ln -s /install_system.sh /etc/rc5.d/S99install
	ln -s /install_system.sh /etc/rc2.d/S99install
	
    fi
) &>/root/post-install.log