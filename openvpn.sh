#!/bin/bash

# Copyright by Anton Baranov <anton.s.baranov@gmail.com>
# 2012

#export path for binaries
PATH="/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
export PATH

#installing need programms and repositories
InstallEpel()
{
if test -e /etc/yum.repos.d/epel.repo; then
        echo "Epel already installed"
else
        wget http://dl.fedoraproject.org/pub/epel/5/`uname -i`/epel-release-5-4.noarch.rpm
        rpm -ihv epel-release-5-4.noarch.rpm
        if [ `echo $?` -eq 0 ]; then
                echo "Epel succesfully installed"
        else
                echo "Some errors occurred during installing Epel. Exit"
        fi
        rm -f epel-release-5-4.noarch.rpm
fi
}

InstallRpmForge()
{
if test -e /etc/yum.repos.d/rpmforge.repo; then
        echo "RpmForge already installed"
else
        wget http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el5.rf.`uname -i`.rpm
        rpm -ihv rpmforge-release-0.5.2-2.el5.rf.`uname -i`.rpm
        if [ `echo $?` -eq 0 ]; then
                rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
                echo "RpmForge succesfully installed"
        else
                echo "Some errors occurred during installing RpmForge. Exit"
        fi
        rm -f rpmforge-release-0.5.2-2.el5.rf.`uname -i`.rpm
fi
}

OpenVpnScriptsPrepare()
{
		OP="/etc/openvpn"
		CCP="/root/openvpn"
		mkdir $OP/ccd
		cp -r $ERPath/2.0 /etc/openvpn/easy-rsa
		cp $ERPath/1.0/openssl.cnf /etc/openvpn/
		cp $ERPath/1.0/openssl.cnf /etc/openvpn/easy-rsa/
		cd $OP/easy-rsa
         	head -n54 /etc/openvpn/easy-rsa/openssl-0.9.8.cnf > /tmp/test_openssl
		echo "unique_subject = no" >> /tmp/test_openssl
		tail -n236 /etc/openvpn/easy-rsa/openssl-0.9.8.cnf >> /tmp/test_openssl
		mv /etc/openvpn/easy-rsa/openssl-0.9.8.cnf /etc/openvpn/easy-rsa/openssl-0.9.8.cnf.old
		mv /tmp/test_openssl /etc/openvpn/easy-rsa/openssl-0.9.8.cnf
		chmod +x clean-all
		chmod +x build*
		chmod +x pkitool
		chmod +x whichopensslcnf
		chmod +x vars
		source ./vars
		. vars
		./clean-all
		./build-dh
		./pkitool --initca
		./pkitool --server openvpn.server
}

InstallEnvironment()
{
		InstallEpel
		InstallRpmForge

		#install openvpn; ntp for time synchronisation
		yum -y install openvpn ntp iptables

		if test -e /proc/sys/xen/independent_wallclock; then
				echo "xen.independent_wallclock = 1" >> /etc/sysctl.conf
				sysctl xen.independent_wallclock=1
		fi
		
		#time synchronisation
		ntpdate pool.ntp.org

		#enable iptables autostart
		chkconfig iptables on

		#preparing openvpn scripts
		ERPath=`find /usr/share/doc/ -name "easy-rsa" | head -n1`
		if test -d $ERPath/2.0; then
			OpenVpnScriptsPrepare
		else
			echo "OpenVPN installation broken. Cannot find easy-rsa dir"
			break
		fi
}

FinishInstall()
{
	/etc/init.d/iptables save
	sysctl net.ipv4.ip_forward=1
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
	/etc/init.d/openvpn restart
	tar -czf /root/openvpn.tgz /root/openvpn
}
#$1=ip,$2=port,$3=protocol,$4=device(tun),$5=clientsubnetip,$6=name of config in $OP
GenerateServerConfig()
{
echo -e "local $1\nport $2\nproto $3\ndev $4\ntls-server\nserver $5 255.255.255.0\nkeepalive 10 120\npersist-key\npersist-tun\nstatus openvpn-status.log\nclient-config-dir $OP/ccd\npush \"redirect-gateway def1\"\npush \"dhcp-option DNS 8.8.8.8\"\nduplicate-cn\nca $OP/keys/ca.crt\ncert $OP/keys/openvpn.server.crt\nkey $OP/keys/openvpn.server.key\ndh $OP/keys/dh1024.pem"  > $OP/$6
}

#$1=client config's name,$2=connect ip,$3=connect port,$4=device name,$5=protocol
GenerateClientConfig()
{
echo -e "client\ntls-client\nverb 3\ndev $4\nproto $5\nnobind\npersist-key\npersist-tun\nca ca.crt\ncert $1.crt\nkey $1.key\nremote $2 $3" > $CCP/$1/$1.ovpn
}

InstallSingleConfig()
{
	InstallEnvironment
	OpenVpnScriptsPrepare
	cd $OP/easy-rsa
	./pkitool client1
	cp -pr $OP/easy-rsa/keys $OP/keys
	mainip=`ifconfig eth0 | grep "inet addr" | awk '{print $2}' | cut -d: -f2`
	GenerateServerConfig $mainip 1140 tcp tun1 192.168.101.0 openvpn.conf
	iptables -t nat -A POSTROUTING -s 192.168.101.0/255.255.255.0 -o eth0 -j MASQUERADE
	echo "ifconfig-push 192.168.101.2 192.168.101.1" > $OP/ccd/client1
	mkdir -p $CCP/client1
	GenerateClientConfig client1 $mainip 1140 tun tcp
	cp $OP/easy-rsa/keys/client1.crt $CCP/client1/
	cp $OP/easy-rsa/keys/client1.key $CCP/client1/
	cp $OP/easy-rsa/keys/ca.crt $CCP/client1/
	FinishInstall
}

InstallNonIP()
{
	InstallEnvironment
	OpenVpnScriptsPrepare
	
	mainip=`ifconfig eth0 | grep "inet addr" | awk '{print $2}' | cut -d: -f2`
	
	InitIP=100
	InitPort=1139
	for i in $(seq 1 $1); do
	
	let "CurIP = InitIP + i"
	
	let "CurPort = InitPort + i"
	
	cd $OP/easy-rsa
	./pkitool client$i
	cp -pr $OP/easy-rsa/keys $OP/keys
	
	GenerateServerConfig $mainip $CurPort tcp tun$i 192.168.$CurIP.0 openvpn$i.conf
	iptables -t nat -A POSTROUTING -s 192.168.$CurIP.0/255.255.255.0 -o eth0 -j MASQUERADE
	echo "ifconfig-push 192.168.$CurIP.2 192.168.$CurIP.1" > $OP/ccd/client$i
	mkdir -p $CCP/client$i
	GenerateClientConfig client$i $mainip $CurPort tun tcp
	cp $OP/easy-rsa/keys/client$i.crt $CCP/client$i/
	cp $OP/easy-rsa/keys/client$i.key $CCP/client$i/
	cp $OP/easy-rsa/keys/ca.crt $CCP/client$i/

	done;

	FinishInstall
	
}

InstallNonNip()
{

	InstallEnvironment
	OpenVpnScriptsPrepare
	
	i=0
	InitIP=100
	InitPort=1139
	ifconfig |grep "inet addr" | grep -v 192.168 | grep -v 127.0.0.1 | awk '{print $2}' | cut -d: -f2 | while read mainip; do
	
	let "i = i + 1"
	
	let "CurIP = InitIP + i"
	
	let "CurPort = InitPort + i"
	
	cd $OP/easy-rsa
	./pkitool client$i
	cp -pr $OP/easy-rsa/keys $OP/keys
	
	GenerateServerConfig $mainip $CurPort tcp tun$i 192.168.$CurIP.0 openvpn$i.conf
	iptables -t nat -A POSTROUTING -s 192.168.$CurIP.0/255.255.255.0 -j SNAT --to-source $mainip
	echo "ifconfig-push 192.168.$CurIP.2 192.168.$CurIP.1" > $OP/ccd/client$i
	mkdir -p $CCP/client$i
	GenerateClientConfig client$i $mainip $CurPort tun tcp
	cp $OP/easy-rsa/keys/client$i.crt $CCP/client$i/
	cp $OP/easy-rsa/keys/client$i.key $CCP/client$i/
	cp $OP/easy-rsa/keys/ca.crt $CCP/client$i/

	done;

	FinishInstall

}


InitialMenu()
{
while true; do
echo "Please, choose:"
echo "1 : Single client on main IP"
echo "2 : N clients on main IP"
echo "3 : N clients on N IPs"
echo

echo -n "Enter your choice, or 0 for exit: "
read choice
echo

case $choice in
     1)
     InstallSingleConfig
	 break
     ;;
     2)
     echo "Please, enter the number of clients"
	 read newchoice
	 if [ $newchoice -gt 0 ]; then
			InstallNonIP $newchoice
			break
	 else
			echo "Number of clients should not be a zero. Exit"
			break
	 fi
     ;;
     3)
     echo "Please, enter the number of clients"
	 read newchoice
	 if [ $newchoice -gt `ifconfig | grep "inet addr" | grep -v 127.0.0.1 | awk '{print $2}' | cut -d: -f2 | wc -l` ]; then
			echo "The number of clients exceeds the number of ip. Exit"
			break
	 else
			if [ $newchoice -gt 0 ]; then
					InstallNonNip $newchoice
					break
			else
					echo "Number of clients should not be a zero. Exit"
					break
			fi
	 fi
     ;;
	 0)
     echo "OK, see you!"
     break
     ;;
     *)
     echo "That is not a valid choice, try a number from 0 to 3."
     ;;
esac  
done
}

InitialMenu
