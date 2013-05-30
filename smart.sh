#!/bin/bash

#while [ $# != 0 ]
#  do
#    argument="$1"
#    name=`echo "${argument}" |awk -F'=' '{print $1}'`
#    argument=${argument##*=}
#
#    if [[ "$name" == -[dtmw] ]] && [[ "$argument" == "$name" ]]
#       then
#            argument="$2";
#            shift;
#    fi
#
#    case "$name" in
#        '-d'|'--datafile' )
#            file_path="$argument"; CASE='data'
#        ;;
#        '-t'|'--testfile' )
#            file="$argument"; CASE='test'
#        ;;
#        '-m'|'--mnt' )
#            mnt="$argument"
#        ;;
#        '-w'|'--workdir' )
#            workdir="$argument"
#        ;;
#        '--hash' )
#            hash="$argument"
#        ;;
#        '--types' )
#            types="$argument"
#        ;;
#        '-h'|'--help' )
#            usage
#            exit 0
#        ;;
#        '-v'|'--version' )
#            version
#            exit 0
#        ;;
#        * )
#            usage
#            exit 1
#        ;;
#    esac
#    shift
#  done



# Проверяем дистрибутив и подстраиваемся под него:
OS=`cat /etc/issue | grep -vE "Kernel|^$" | awk '{print $1}'`
IP=`ifconfig eth0 | grep "inet addr" | awk '{print $2}' | awk -F":" '{print $2}'`
allmem=`cat /proc/meminfo | grep MemTotal | awk '{print $2/1024}'`
# Устанавливаем библиотеку dialog и узнаем пути к основным конфигам и скриптам:
case "$OS" in
"CentOS")
	echo "Сбор необходимых данных..."
	if [ $(rpm -qa dialog | wc -l) != "1" ] ; then
		echo "Устанавливаю библиотеки dialog..."
		yum install -y dialog > /dev/null
	else
		echo "Библиотеки dialog установлены..."
	fi
	if [ $(rpm -qa bc | wc -l) != "1" ] ; then
		echo "Устанавливаю калькулятор bc..."
		yum install -y bc > /dev/null
	else
		echo "Калькулятор bc установлен..."
	fi
	mycnf="/etc/my.cnf" # путь к конфигу MySQL
	mysqlinit="/etc/init.d/mysqld" # путь к init-скрипту MySQL
	;;
"Debian")
	echo "Сбор необходимых данных..."
	if [ $(dpkg -l dialog | grep dialog | wc -l) != "1" ] ; then
                echo "Устанавливаю библиотеки dialog..."
		apt-get install -y dialog > /dev/null
	else
                echo "Библиотеки dialog установлены..."
        fi
        if [ $(dpkg -l bc | grep bc | wc -l) != "1" ] ; then
                echo "Устанавливаю калькулятор bc..."
		apt-get install -y bc > /dev/null
	else
                echo "Калькулятор bc установлен..."
        fi
	mycnf="/etc/mysql/my.cnf"
	mysqlinit="/etc/init.d/mysql"
	;;
"Ubuntu")
	echo "Сбор необходимых данных..."
        if [ $(dpkg -l dialog | grep dialog | wc -l) != "1" ] ; then
                echo "Устанавливаю библиотеки dialog..."
                apt-get install -y dialog > /dev/null
        else
                echo "Библиотеки dialog установлены..."
        fi
        if [ $(dpkg -l bc | grep bc | wc -l) != "1" ] ; then
                echo "Устанавливаю калькулятор bc..."
                apt-get install -y bc > /dev/null
        else
                echo "Калькулятор bc установлен..."
        fi
	mycnf="/etc/mysql/my.cnf"
	mysqlinit="/etc/init.d/mysql"
	;;
esac


# Рисуем главное меню выбора первого пункта:

DIALOG=`which dialog`
$tempfile=`mktemp 2>/dev/null` || tempfile=/tmp/_temp0$$

$DIALOG --clear --title "Выбор действий" \
	--backtitle "SystemIntegra server management" \
	--menu "Что необходимо установить/настроить на сервере?" 25 56 18 \
	"ISPManager" "Установка ISPManager" \
	"MySQL" "Оптимизация MySQL" \
	"OpenVPN" "Сервер OpenVPN" \
	"eJabberd" "Jabber-сервер" \
	"SVN-server" "Установка SVN" \
	"Apache-mpm-itk" "Установка в ISPManager" \
	"Nginx" "Установка в ISPManager" \
	"MRTG" "Мониторинг MRTG" \
	"Munin" "Мониторинг Munin" \
	"GeoIP (php)" "Модуль GeoIP для PHP" \
	"GeoIP (apache)" "Модуль GeoIP для Apache" \
	"GeoIP (nginx)" "Модуль GeoIP для Nginx" \
	"Zend Optimizer" "Zend Optimizer" \
	"IonCube" "Установка IonCube" \
	"xCache" "Установка xCache" \
	"RoundCube" "Установка в ISPManager" \
	"ffmpeg" "Сборка ffmpeg" 2>$tempfile

retval=$?
choice=`cat $tempfile`


# Парсим варианты выбора пунктов:
case "$choice" in

################################################################################################################################
# Установка ISPManager
################################################################################################################################
"ISPManager")




;;

################################################################################################################################
# Оптимизация MySQL
################################################################################################################################
"MySQL")
	COUNT=10
	(
	while test $COUNT != 100
	do
	echo "$COUNT"

	cp $mycnf $mycnf.`date +%Y%m%d-%H%M`
	echo "[mysqld]" > $mycnf
	# Оптимизация MySQL-сервера:
	# Вычисляем и создаем tmpdir:
	mysqltmpdir="/mnt/mysqltmpdir"
	mysqltmpsize=`echo "($allmem/100*12)/1" | bc -s`
	mysqluid=`cat /etc/passwd | grep mysql | awk -F":" '{print $3}'`
	mysqlgid=`cat /etc/group | grep \`cat /etc/passwd | grep mysql | awk -F":" '{print $4}'\` | awk -F":" '{print $3}'`

	COUNT=`expr $COUNT + 10`
	echo "$COUNT"

	printf "tmpfs\t$mysqltmpdir\ttmpfs\tuid=$mysqluid,gid=$mysqlgid,size=$mysqltmpsize""M\t0 0\n" >> /etc/fstab
	mkdir $mysqltmpdir 2>/dev/null
	mount $mysqltmpdir
	echo "tmpdir = $mysqltmpdir" >> $mycnf
	echo "tmp_table_size = $mysqltmpsize""M" >> $mycnf
	echo "sort_buffer_size = `echo "($allmem/100*0.1*1024)/1" | bc -s`""k" >> $mycnf
	echo "read_buffer_size = `echo "($allmem/100*0.1*1024)/1" | bc -s`""k" >> $mycnf
	echo "read_rnd_buffer_size = `echo "($allmem/100*0.1*1024)/1" | bc -s`""k" >> $mycnf
	echo "max_allowed_packet = 100""M" >> $mycnf
	echo "query_cache_size = `echo "($allmem/100*10)/1" | bc -s`""M" >> $mycnf
	echo "query_cache_limit = `echo "($allmem/100*2)/1" | bc -s`""M" >> $mycnf
	echo "query_cache_type = 1" >> $mycnf
	echo "max_heap_table_size = `echo "($allmem/100*10)/1" | bc -s`""M" >> $mycnf
	echo "thread_cache_size = `echo "($allmem/100*40)/1" | bc -s`" >> $mycnf
	echo "net_buffer_length = `echo "($allmem/100*0.1*1024)/1" | bc -s`""k" >> $mycnf
	echo "log-error = /var/log/mysql.error.log" >> $mycnf
	echo "key_buffer = `echo "($allmem/100*1)/1" | bc -s`""M" >> $mycnf
	echo "wait_timeout = 30" >> $mycnf
	echo "low_priority_updates = 1" >> $mycnf
	echo "long_query_time = 1" >> $mycnf
	#echo "log-slow-queries = /var/log/mysql.log-slow-queries.log" >> $mycnf

	COUNT=`expr $COUNT + 30`
	echo "$COUNT"

	touch /var/log/mysql.error.log
	touch /var/log/mysql.log-slow-queries.log
	chown mysql:mysql /var/log/mysql.error.log
	chown mysql:mysql /var/log/mysql.log-slow-queries.log

	COUNT=`expr $COUNT + 20`
	echo "$COUNT"

	echo `$mysqlinit stop` > /dev/null
	killall -9 mysqld 2>/dev/null
	echo `$mysqlinit start` > /dev/null

	COUNT=`expr $COUNT + 30`
	echo "$COUNT"
	sleep 1
	done ) | \
	$DIALOG --clear --title "Оптимизация настроек MySQL" --gauge "Подождите, скоро все будет готово..." 8 50 0
	$DIALOG --msgbox "Все готово!" 7 30
;;


################################################################################################################################
# Установка OpenVPN
################################################################################################################################
"OpenVPN")


;;


################################################################################################################################
# Настройка eJabberd
################################################################################################################################
"eJabberd")

	backtitle="SystemIntegra server management"
	dialog_host='Введите DNS имя Jabber сервера:'
	dialog_user='Введите пользователя с правами администратора:'
	dialog_password='Введите пароль пользователя:'
	dialog_anonymous='Разрешать анонимный доступ (yes/no):'

	jabber_host='localhost'
	jabber_user='user'
	jabber_password='password'
	jabber_anonymous='yes'

	exec 3>&1
	INPUT=$($DIALOG --ok-label "Готово" \
	    --backtitle "$backtitle" \
	    --title "Настройка Jabber сервера." \
	    --form "Изменение параметров настройки." 10 90 0 \
	    "$dialog_host" 1 1  "$jabber_host"   1 60 90 0 \
	    "$dialog_user" 2 1  "$jabber_user"   2 60 90 0 \
	    "$dialog_password" 3 1  "$jabber_password"   3 60 90 0 \
	    "$dialog_anonymous" 4 1  "$jabber_anonymous"   4 60 90 0 \
	    2>&1 1>&3)
	exec 3>&-

	jabber_host=`echo $INPUT |awk '{print $1}'`
	jabber_user=`echo $INPUT |awk '{print $2}'`
	jabber_password=`echo $INPUT |awk '{print $3}'`
	jabber_anonymous=`echo $INPUT |awk '{print $4}'`

	(echo "10"
	case "$OS" in
	    "CentOS")
		yum install -y ejabberd >/dev/null
		echo "60"
		jabberconfdir="/etc/ejabberd" # путь к каталогу настроек
	    ;;
	    "Debian")
		apt-get install -y ejabberd >/dev/null
		echo "60"
		jabberconfdir="/etc/ejabberd"
	    ;;
	    "Ubuntu")
		apt-get install -y ejabberd >/dev/null
		echo "60"
		jabberconfdir="/etc/ejabberd"
	    ;;
	esac

	sed "s/\"localhost\"/\"$jabber_host\"/" $jabberconfdir/ejabberd.cfg > $jabberconfdir/ejabberd.cfg.tmp
	mv $jabberconfdir/ejabberd.cfg.tmp $jabberconfdir/ejabberd.cfg
	chown ejabberd:ejabberd $jabberconfdir/ejabberd.cfg
	chmod 640 $jabberconfdir/ejabberd.cfg

	echo "70"
	/etc/init.d/ejabberd restart >/dev/null

	echo "80"

	ejabberdctl register $jabber_user $jabber_host $jabber_password
	sed "s/ACCESS CONTROL LISTS/ACCESS CONTROL LISTS\\n{acl,\ admin,\ {user,\ \"$jabber_user\",\ \"$jabber_host\"}}./" $jabberconfdir/ejabberd.cfg > $jabberconfdir/ejabberd.cfg.tmp
	mv $jabberconfdir/ejabberd.cfg.tmp $jabberconfdir/ejabberd.cfg
	chown ejabberd:ejabberd $jabberconfdir/ejabberd.cfg
	chmod 640 $jabberconfdir/ejabberd.cfg

	if [[ "$jabber_anonymous" == 'yes' ]]
	    then
		cat <<EOF >> $jabberconfdir/ejabberd.cfg
{auth_method, [anonymous]}.
{anonymous_protocol, login_anon}.
EOF
	fi

	echo "90"
	/etc/init.d/ejabberd restart >/dev/null

	echo "100";) | $DIALOG --backtitle "$backtitle" --title "Идёт процес установки и настройки Jabber !" --gauge "Подождите пожалуйста..." 10 90 0

	user_add_gude=""
	$DIALOG --backtitle "$backtitle" --title "Jabber установлен и настроен." --msgbox \
	    "Для администрирования войдите на страницу http://$jabber_host:5280/admin/\n \
	    используя имя пользователя $jabber_user@$jabber_host и пароль $jabber_password\n \
	    $user_add_gude" 15 115


;;


################################################################################################################################
# Настройка SVN
################################################################################################################################
"SVN-server")
	backtitle="SystemIntegra server management"
	dialog_root='Введите путь к корню репозитория:'
	dialog_project='Введите имя репозитория:'
	dialog_user='Введите пользователя с правом изменения репозитория:'
	dialog_password='Введите пароль пользователя:'
	dialog_anonymous='Разрешать анонимный доступ (yes/no):'

	svn_root='/var/svn'
	svn_project='myproject'
	svn_user='user'
	svn_password='password'
	svn_anonymous='yes'

	exec 3>&1
	INPUT=$($DIALOG --ok-label "Готово" \
	        --backtitle "$backtitle" \
	        --title "Настройка SVN сервера." \
	        --form "Изменение параметров настройки." 10 90 0 \
	        "$dialog_root" 1 1  "$svn_root"   1 60 90 0 \
	        "$dialog_project" 2 1  "$svn_project"   2 60 90 0 \
	        "$dialog_user" 3 1  "$svn_user"   3 60 90 0 \
	        "$dialog_password" 4 1  "$svn_password"   4 60 90 0 \
	        "$dialog_anonymous" 5 1  "$svn_anonymous"   5 60 90 0 \
	2>&1 1>&3)
	exec 3>&-

	svn_root=`echo $INPUT |awk '{print $1}'`
	svn_project=`echo $INPUT |awk '{print $2}'`
	svn_user=`echo $INPUT |awk '{print $3}'`
	svn_password=`echo $INPUT |awk '{print $4}'`
	svn_anonymous=`echo $INPUT |awk '{print $5}'`

	(echo "10"
	case "$OS" in
	"CentOS")
	        yum install -y subversion >/dev/null
	        echo "50"
	        yum install -y xinetd >/dev/null
	        initsubversion="/etc/xinetd.d/svn" # путь к init-скрипту SVN
	        ;;
	"Debian")
	        apt-get install -y subversion >/dev/null
	        echo "50"
	        apt-get install -y xinetd >/dev/null
	        initsubversion="/etc/xinetd.d/svn"
	        ;;
	"Ubuntu")
	        apt-get install -y subversion >/dev/null
	        echo "50"
	        apt-get install -y xinetd >/dev/null
	        initsubversion="/etc/xinetd.d/svn"
	        ;;
	esac

	echo "70"
	#if [ ! -f $initsubversion ]
	#    then
cat <<EOF > $initsubversion
      service svn
      {
      flags           = REUSE
      socket_type     = stream
      wait            = no
      user            = root
      server          = /usr/bin/svnserve
      server_args     = -i -r $svn_root
      log_on_failure  += USERID
      disable         = no
      }
EOF
	#fi

	mkdir -p $svn_root
	svnadmin create $svn_root/$svn_project

	echo "75"
cat <<EOF >> $svn_root/$svn_project/conf/svnserve.conf

[general]
#anon-access = none
#auth-access = write
password-db = passwd
authz-db = authz
realm = My First Repository
EOF

cat <<EOF >> $svn_root/$svn_project/conf/passwd

[users]
$svn_user = $svn_password
EOF

cat <<EOF >> $svn_root/$svn_project/conf/authz

[/]
$svn_user = rw
* =

[repository:/$svn_project]
$svn_user = rw
EOF
	if [[ "$svn_anonymous" == 'yes' ]]
	    then
	        echo "* = r" >> $svn_root/$svn_project/conf/authz
	    else
	        echo "* =" >> $svn_root/$svn_project/conf/authz
	fi

	echo "80"
	/etc/init.d/xinetd restart >/dev/null

	echo "100";) | $DIALOG --backtitle "$backtitle" --title "Идёт процес установки и настройки SVN !" --gauge "Подождите пожалуйста..." 10 90 0

	$DIALOG --backtitle "$backtitle" --title "SVN установлен и настроен." --msgbox \
	"Для добавления пользователей в этот репозитарий отредактируйте файлы:\n \
	$svn_root/$svn_project/conf/passwd\n \
	$svn_root/$svn_project/conf/authz\n\n \
	Для настройки дополнительного репозитория запустите ещё раз, но путь к корню указывайте тот же: $svn_root" 15 115
;;


################################################################################################################################
# Настройка Apache-mpm-itk
################################################################################################################################
"Apache-mpm-itk")

case "$OS" in
    "CentOS")
            yum update -y httpd >/dev/null
            ;;
    "Debian")
            apt-get install -y apache2-mpm-itk >/dev/null
            ;;
    "Ubuntu")
            apt-get install -y apache2-mpm-itk >/dev/null
            ;;
    esac

;;


################################################################################################################################
# Настройка Nginx
################################################################################################################################
"Nginx")


;;


################################################################################################################################
# Настройка MRTG
################################################################################################################################
"MRTG")


;;


################################################################################################################################
# Настройка Munin
################################################################################################################################
"Munin")
case "$OS" in
"CentOS")
	COUNT=10
	(
	while test $COUNT != 100
	do
	echo "$COUNT"

        yum install -y munin > /dev/null
	COUNT=`expr $COUNT + 30`
        echo "$COUNT"

        yum install -y munin-common > /dev/null
	COUNT=`expr $COUNT + 20`
        echo "$COUNT"

	yum install -y munin-node > /dev/null
	COUNT=`expr $COUNT + 20`
        echo "$COUNT"

	muninconf="/etc/munin/munin.conf"
	muninnodeconf="/etc/munin/munin-node.conf"
	munininit="/etc/init.d/munin-node"
	
	COUNT=`expr $COUNT + 20`
        echo "$COUNT"
	sleep 1
        done) | \
	$DIALOG --clear --title " Установка и настройка Munin " --gauge "Подождите, скоро все будет готово..." 8 50 0


	# Спросим, по какому адресу должен быть доступен Munin:
	tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/htmldir$$
	trap "rm -f $tempfile" 0 1 2 5 15
	$DIALOG --title " Адрес доступа к Munin " --clear \
		--inputbox "Укажите путь к директории сайта для доступа к Munin:" 12 60 "/var/www/html/munin" 2>$tempfile
	COUNT=30
	(
        while test $COUNT != 100
        do
        echo "$COUNT"

	retval=$?
	htmldir=`cat $tempfile`/

	COUNT=`expr $COUNT + 20`
        echo "$COUNT"
	
	echo "htmldir $htmldir" >> $muninconf
	cp -R /var/www/html/munin/* $htmldir
	mkdir -p $htmldir
	chown -R munin $htmldir
	
	COUNT=`expr $COUNT + 20`
        echo "$COUNT"

	echo "$munininit restart" > /dev/null

	COUNT=`expr $COUNT + 30`
        echo "$COUNT"
	sleep 1
	done) | \
	$DIALOG --clear --title "Установка и настройка Munin" --gauge "Подождите, скоро все будет готово..." 8 50 0

	$DIALOG --msgbox "Все готово!" 7 30
        ;;
"Debian")
        apt-get install -y munin > /dev/null
        apt-get install -y munin-common > /dev/null
        ;;
"Ubuntu")
        apt-get install -y munin > /dev/null
        apt-get install -y munin-common > /dev/null
        ;;
esac

;;


################################################################################################################################
# Настройка GeoIP (php)
################################################################################################################################
"GeoIP (php)")


;;


################################################################################################################################
# Настройка GeoIP (apache)
################################################################################################################################
"GeoIP (apache)")


;;


################################################################################################################################
# Настройка GeoIP (nginx)
################################################################################################################################
"GeoIP (nginx)")


;;


################################################################################################################################
# Настройка Zend Optimizer
################################################################################################################################
"Zend Optimizer")


;;


################################################################################################################################
# Настройка IonCube
################################################################################################################################
"IonCube")


;;


################################################################################################################################
# Настройка xCache
################################################################################################################################
"xCache")


;;


################################################################################################################################
# Настройка RoundCube
################################################################################################################################
"RoundCube")


;;


################################################################################################################################
# Настройка ffmpeg
################################################################################################################################
"ffmpeg")


;;
esac



