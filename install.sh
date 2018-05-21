#!/bin/bash

MachineIp=$(ip addr | grep inet | grep ${INET_NAME} | awk '{print $2;}' | sed 's|/.*$||')
MachineName=$(cat /etc/hosts | grep ${MachineIp} | awk '{print $2}')

build_cpp_framework(){
	echo "build cpp framework ...."
	##Tars数据库环境初始化
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "CREATE USER 'tars'@'%' IDENTIFIED BY '${DBTarsPass}';"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "GRANT ALL ON *.* TO 'tars'@'%' WITH GRANT OPTION;"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "CREATE USER 'tars'@'localhost' IDENTIFIED BY '${DBTarsPass}';"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "GRANT ALL ON *.* TO 'tars'@'localhost' WITH GRANT OPTION;"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "CREATE USER 'tars'@'${MachineName}' IDENTIFIED BY '${DBTarsPass}';"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "GRANT ALL ON *.* TO 'tars'@'${MachineName}' WITH GRANT OPTION;"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "CREATE USER 'tars'@'${MachineIp}' IDENTIFIED BY 'tars2015';"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "GRANT ALL ON *.* TO 'tars'@'${MachineIp}' WITH GRANT OPTION;"
	mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "flush privileges;"

	sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -rl /root/Tars/cpp/framework/sql/*`
	sed -i "s/db.tars.com/${DBIP}/g" `grep db.tars.com -rl /root/Tars/cpp/framework/sql/*`

	cd /root/Tars/cpp/framework/sql/
	sed -i "s/proot@appinside/h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} /g" `grep proot@appinside -rl ./exec-sql.sh`
	
	chmod u+x /root/Tars/cpp/framework/sql/exec-sql.sh
	
	CHECK=$(mysqlshow --user=${DBUser} --password=${DBPassword} --host=${DBIP} --port=${DBPort} db_tars | grep -v Wildcard | grep -o db_tars)
	if [ "$CHECK" = "db_tars" -a ${MOUNT_DATA} = true ];
	then
		echo "DB db_tars already exists" > /root/DB_Exists.lock
	else
		cd /root/Tars/cpp/framework/sql && ./exec-sql.sh
	fi
}

install_base_services(){
	echo "base services ...."
	
	##框架基础服务包
	cd /root
	mv t*.tgz /data
	
	#mkdir -p /data/tars/tarsconfig_data && ln -s /data/tars/tarsconfig_data /usr/local/app/tars/tarsconfig/data
	#mkdir -p /data/tars/tarsnode_data && ln -s /data/tars/tarsnode_data /usr/local/app/tars/tarsnode/data
	#mkdir -p /data/tars/tarspatch_data && ln -s /data/tars/tarspatch_data /usr/local/app/tars/tarspatch/data
	#mkdir -p /data/tars/tarsregistry_data && ln -s /data/tars/tarsregistry_data /usr/local/app/tars/tarsregistry/data
	
	##核心基础服务配置修改
	cd /usr/local/app/tars

	sed -i "s/dbhost.*=.*192.168.2.131/dbhost = ${DBIP}/g" `grep dbhost -rl ./*`
	sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -rl ./*`
	sed -i "s/db.tars.com/${DBIP}/g" `grep db.tars.com -rl ./*`
	sed -i "s/dbport.*=.*3306/dbport = ${DBPort}/g" `grep dbport -rl ./*`
	sed -i "s/registry.tars.com/${MachineIp}/g" `grep registry.tars.com -rl ./*`
	sed -i "s/web.tars.com/${MachineIp}/g" `grep web.tars.com -rl ./*`
	# 修改Mysql里tars用户密码
	sed -i "s/tars2015/${DBTarsPass}/g" `grep tars2015 -rl ./*`

	chmod u+x tars_install.sh
	./tars_install.sh

	./tarspatch/util/init.sh
}

build_web_mgr(){
	echo "web manager ...."
	
	##web管理系统配置修改后重新打war包
	cd /usr/local/resin/webapps/
	mkdir tars
	cd tars
	jar -xvf ../tars.war
	
	sed -i "s/db.tars.com/${DBIP}/g" `grep db.tars.com -rl ./WEB-INF/classes/app.config.properties`
	sed -i "s/3306/${DBPort}/g" `grep 3306 -rl ./WEB-INF/classes/app.config.properties`
	sed -i "s/registry1.tars.com/${MachineIp}/g" `grep registry1.tars.com -rl ./WEB-INF/classes/tars.conf`
	sed -i "s/registry2.tars.com/${MachineIp}/g" `grep registry2.tars.com -rl ./WEB-INF/classes/tars.conf`
	sed -i "s/DEBUG/INFO/g" `grep DEBUG -rl ./WEB-INF/classes/log4j.properties`
	
	jar -uvf ../tars.war .
	cd ..
	rm -rf tars
}

start_redis() {
	sed -i "s/daemonize no/daemonize yes/g" /etc/redis.conf
	redis-server /etc/redis.conf
}

start_apache() {
	mkdir /data/web
	echo "<?php phpinfo(); ?>" > /data/web/phpinfo.php
	rm -rf /var/www/html
	rm -f /etc/httpd/conf.d/welcome.conf
	ln -s /data/web /var/www/html
	httpd
}

build_cpp_framework

install_base_services

build_web_mgr

start_redis

start_apache
