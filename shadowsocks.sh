#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install LNMT"
    exit 1
fi

clear
echo "*************************************************************************"
echo "*                                                                       *"
echo "*  Shadowsocks onekey install V1.0 for CentOS7 Server, Written by Dong  *"
echo "*                                                                       *"
echo "*************************************************************************"

ss_port=""
ss_port_default=1`cat /dev/urandom | tr -dc '0-9' | fold -w ${1:-4} | head -n 1`
ss_encryption="aes-256-cfb"
ss_password=""
ss_password_default=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-10} | head -n 1`
ss_ip=`ip route get 1 | awk '{print $NF;exit}'`

is_active="N"
reinstall="N"

systemctl is-active shadowsocks >/dev/null 2>&1 && is_active="Y"  || is_active="N"

if [ "$is_active" = "Y" ]; then
	echo -e "\033[31mWarning: Shadowsocks server is currently active.\033[0m"
	echo -e '\n'
	read -p "Please choose option for your operation, enter 'y' to kill the ssserver and reinstall, enter 'n' to exit the program (y/n):" reinstall
	if [ "$reinstall" = "" ]; then
		reinstall="N"
	fi
	
	case "$reinstall" in
	y|Y|Yes|YES|yes|yES|yEs|YeS|yeS)
	echo "Stoping shadowsocks..."
	systemctl stop shadowsocks
	;;
	n|N|No|NO|no|nO)
	echo "bye!"
	exit 0
	;;
	*)
	echo "INPUT error,the program will be exit!"
	exit 0
	esac
	
	echo -e '\n'
fi

# setting port
echo "Please input the port of Shadowsocks:"
read -p "(Default port: $ss_port_default):" ss_port
if [ "$ss_port" = "" ]; then
	ss_port="$ss_port_default"
fi

echo "------------------------------"
echo "Shadowsocks port is: $ss_port"
echo "------------------------------"
echo -e '\n'
# setting encryption
echo "Please input the encryption of Shadowsocks:"
read -p "(Default encryption: aes-256-cfb):" ss_encryption
if [ "$ss_encryption" = "" ]; then
	ss_encryption="aes-256-cfb"
fi

echo "------------------------------"
echo "Shadowsocks encryption is: $ss_encryption"
echo "------------------------------"
echo -e '\n'
# setting password
echo "Please input the password of Shadowsocks:"
read -p "(Default password: $ss_password_default):" ss_password
if [ "$ss_password" = "" ]; then
	ss_password="$ss_password_default"
fi

echo "------------------------------"
echo "Shadowsocks password is: $ss_password"
echo "------------------------------"
echo -e '\n'

get_char()
{
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo

	stty $SAVEDSTTY
}
echo ""
echo "Press any key to start...or Press Ctrl+c to cancel"
char=`get_char`

function initEnv(){
	
	uname -a
	total_mem=`free -m | grep Mem | awk '{print  $2}'` 
	used_mem=`free -m | grep Mem | awk '{print  $3}'` 
	
	total_swap=`free -m | grep Swap | awk '{print  $2}'` 
	used_swap=`free -m | grep Swap | awk '{print  $3}'` 
	echo -e "\n\033[41;33m Memory is: ${used_mem}/${total_mem} MB \033[0m"
	
	echo -e "\n\033[41;33m Swap is: ${used_swap}/${total_swap} MB \033[0m\n"
	
	#Set timezone
	rm -rf /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	
	yum install -y ntp
	ntpdate -u pool.ntp.org
	date

	
	for packages in patch make cmake gcc gcc-c++ gcc-g77 file libtool libtool-libs kernel-devel curl curl-devel openssl openssl-devel vim-minimal nano fonts-chinese unzip;
	do yum -y install $packages; done
}

function installShadowsocks(){
	#yum -y install python-setuptools && easy_install pip
	curl -fsSL https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
	python get-pip.py
	pip install --upgrade pip
	pip install shadowsocks
	
	
	cat > /root/.shadowsocks-port<<EOF
$ss_port
EOF

	cat > /root/.shadowsocks-password<<EOF
$ss_password
EOF

	cat > /root/.shadowsocks-encryption<<EOF
$ss_encryption
EOF
	
	systemctl disable shadowsocks
	
	cat > /etc/systemd/system/shadowsocks.service<<EOF
[Unit]
Description=Shadowsocks
[Service]
TimeoutStartSec=0
ExecStart=/usr/bin/ssserver -s ::0 -p `cat /root/.shadowsocks-port` -k `cat /root/.shadowsocks-password` -m `cat /root/.shadowsocks-encryption`
[Install]
WantedBy=multi-user.target
EOF
	
	systemctl enable shadowsocks
	systemctl start shadowsocks
	
}

function validInstall(){
	systemctl status shadowsocks -l
	echo -e '\n'
	systemctl is-active shadowsocks >/dev/null 2>&1 && echo -e "\033[46;1;37m Shadowsocks is installed \033[0m"  || echo echo -e "\033[41;1;32m Shadowsocks is not installed \033[0m"
	
	echo "================================"
	echo ""
	echo "Congratulations! Shadowsocks has been installed on your system."
	echo "You shadowsocks connection info:"
	echo "--------------------------------"
	echo -e "\033[32m  host:        ${ss_ip}\033[0m"
	echo -e "\033[32m  port:        ${ss_port}\033[0m"
	echo -e "\033[32m  password:    ${ss_password}\033[0m"
	echo -e "\033[32m  method:      ${ss_encryption}\033[0m"
	echo "--------------------------------"
}

function fuckFirewall(){
	
	fw_is_active="N"
	systemctl is-active firewalld.service >/dev/null 2>&1 && fw_is_active="Y"  || fw_is_active="N"
	
	if [ "$fw_is_active" = "Y" ]; then
		echo "Add shadowsocks service to the firewall exceptions list."
		systemctl start firewalld.service
		firewall-cmd --zone=public --add-port="$ss_port"/tcp --permanent
		systemctl restart firewalld.service
	fi
	
	if [ "$fw_is_active" = "N" ]; then
		echo -e "\033[31mWarning: The firewalld service is unavailable.\033[0m"
	fi
}
initEnv 2>&1 | tee /root/ss-init.log
installShadowsocks 2>&1 | tee /root/ss-install.log
validInstall 2>&1 | tee /root/ss-finish.log
fuckFirewall 2>&1 | tee /root/ss-finish.log
