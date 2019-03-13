FROM centos/systemd

WORKDIR /root/

##镜像时区 
ENV TZ=Asia/Shanghai

ENV DBIP 127.0.0.1
ENV DBPort 3306
ENV DBUser root
ENV DBPassword password

# Mysql里tars用户的密码，缺省为tars2015
ENV DBTarsPass tars2015

ENV GOPATH=/usr/local/go

# 中文字符集支持
ENV LC_ALL "zh_CN.UTF-8"

ENV JAVA_HOME /usr/java/jdk-11.0.2

ENV MAVEN_HOME /usr/local/apache-maven-3.6.0

##安装
RUN yum -y install https://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/mysql80-community-release-el7-1.noarch.rpm \
	&& yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
	&& yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm \
	&& yum -y install yum-utils && yum-config-manager --enable remi-php73 \
	&& yum -y install git gcc gcc-c++ go make wget cmake mysql mysql-devel unzip iproute which glibc-devel flex bison ncurses-devel protobuf-devel zlib-devel kde-l10n-Chinese glibc-common hiredis-devel rapidjson-devel boost boost-devel php php-cli php-devel php-mbstring php-mcrypt php-json php-gd php-curl php-mysql php-zip php-fileinfo php-phpiredis php-seld-phar-utils pcre-devel tzdata \
	# 设置时区与编码
	&& ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
	&& localedef -c -f UTF-8 -i zh_CN zh_CN.utf8 \
	# 安装Mysql8 C++ Connector
	&& wget -c -t 0 https://dev.mysql.com/get/Downloads/Connector-C++/mysql-connector-c++-8.0.11-linux-el7-x86-64bit.tar.gz \
	&& tar zxf mysql-connector-c++-8.0.11-linux-el7-x86-64bit.tar.gz && cd mysql-connector-c++-8.0.11-linux-el7-x86-64bit \
	&& cp -Rf include/jdbc/* /usr/include/mysql/ && cp -Rf include/mysqlx/* /usr/include/mysql/ && cp -Rf lib64/* /usr/lib64/mysql/ \
	&& cd /root && rm -rf mysql-connector* \
	&& mkdir -p /usr/local/mysql && ln -s /usr/lib64/mysql /usr/local/mysql/lib && ln -s /usr/include/mysql /usr/local/mysql/include && echo "/usr/local/mysql/lib/" >> /etc/ld.so.conf && ldconfig \
	&& cd /usr/local/mysql/lib/ && rm -f libmysqlclient.a && ln -s libmysqlclient.so.*.*.* libmysqlclient.a \
	# 获取最新TARS源码
	&& cd /root/ && git clone https://github.com/TarsCloud/Tars \
	&& cd /root/Tars/ && git submodule update --init --recursive framework \
	&& git submodule update --init --recursive web \
	&& git submodule update --init --recursive php \
	&& git submodule update --init --recursive go \
	&& git submodule update --init --recursive java \
	&& mkdir -p /data && chmod u+x /root/Tars/framework/build/build.sh \
	# 以下对源码配置进行mysql8对应的修改
	&& sed -i '32s/rt/rt crypto ssl/' /root/Tars/framework/CMakeLists.txt \
	# 开始构建
	&& cd /root/Tars/framework/build/ && ./build.sh all \
	&& ./build.sh install \
	&& cd /root/Tars/framework/build/ && make framework-tar \
	&& make tarsstat-tar && make tarsnotify-tar && make tarsproperty-tar && make tarslog-tar && make tarsquerystat-tar && make tarsqueryproperty-tar \
	&& mkdir -p /usr/local/app/tars/ && cp /root/Tars/framework/build/framework.tgz /usr/local/app/tars/ && cp /root/Tars/framework/build/t*.tgz /root/ \
	&& cd /usr/local/app/tars/ && tar xzfv framework.tgz && rm -rf framework.tgz \
	&& mkdir -p /usr/local/app/patchs/tars.upload \
	&& cd /tmp && curl -fsSL https://getcomposer.org/installer | php \
	&& chmod +x composer.phar && mv composer.phar /usr/local/bin/composer \
	&& cd /root/Tars/php/tars-extension/ && phpize --clean && phpize \
	&& ./configure --enable-phptars --with-php-config=/usr/bin/php-config && make && make install \
	&& echo "extension=phptars.so" > /etc/php.d/phptars.ini \
	# 安装PHP swoole模块
	&& cd /root && git clone https://github.com/swoole/swoole-src.git \
	&& cd swoole-src && phpize \
	&& ./configure --enable-openssl --enable-sockets \
	&& make && make install \
	&& echo "extension=swoole.so" > /etc/php.d/swoole.ini \
	&& cd /root && rm -rf swoole-src \
	&& mkdir -p /root/phptars && cp -f /root/Tars/php/tars2php/src/tars2php.php /root/phptars \
	# 安装tars go
	&& go get github.com/TarsCloud/TarsGo/tars \
	&& cd $GOPATH/src/github.com/TarsCloud/TarsGo/tars/tools/tars2go && go build . \
	# 获取并安装nodejs
	&& wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash \
	&& source ~/.bashrc && nvm install v8.15.1 \
	&& cp -Rf /root/Tars/web /usr/local/tarsweb && cd /usr/local/tarsweb/ && npm install \
	&& npm install -g pm2 @tars/deploy @tars/stream @tars/rpc @tars/logs @tars/config @tars/monitor @tars/notify @tars/utils @tars/dyeing @tars/registry \
	# 获取并安装JDK
	&& mkdir -p /root/init && mkdir -p /usr/java && cd /root/init/ \
	&& wget -c -t 0 https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz \
	&& tar zxf openjdk-11.0.2_linux-x64_bin.tar.gz && mv jdk-11.0.2 /usr/java/ \
	&& rm -rf /root/init/openjdk-11.0.2_linux-x64_bin.tar.gz \
	&& echo "export JAVA_HOME=/usr/java/jdk-11.0.2" >> /etc/profile \
	&& echo "CLASSPATH=\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar" >> /etc/profile \
	&& echo "PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile \
	&& echo "export PATH JAVA_HOME CLASSPATH" >> /etc/profile \
	&& echo "export JAVA_HOME=/usr/java/jdk-11.0.2" >> /root/.bashrc \
	&& echo "CLASSPATH=\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar" >> /root/.bashrc \
	&& echo "PATH=\$JAVA_HOME/bin:\$PATH" >> /root/.bashrc \
	&& echo "export PATH JAVA_HOME CLASSPATH" >> /root/.bashrc \
	&& cd /usr/local/ && wget -c -t 0 https://mirrors.tuna.tsinghua.edu.cn/apache/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz \
	&& tar zxvf apache-maven-3.6.0-bin.tar.gz && echo "export MAVEN_HOME=/usr/local/apache-maven-3.6.0/" >> /etc/profile \
	# 设置阿里云maven镜像
	# && sed -i '/<mirrors>/a\\t<mirror>\n\t\t<id>nexus-aliyun<\/id>\n\t\t<mirrorOf>*<\/mirrorOf>\n\t\t<name>Nexus aliyun<\/name>\n\t\t<url>http:\/\/maven.aliyun.com\/nexus\/content\/groups\/public<\/url>\n\t<\/mirror>' /usr/local/apache-maven-3.6.0/conf/settings.xml \
	&& echo "export PATH=\$PATH:\$MAVEN_HOME/bin" >> /etc/profile \
	&& echo "export PATH=\$PATH:\$MAVEN_HOME/bin" >> /root/.bashrc \
	&& source /etc/profile && mvn -v \
	&& rm -rf apache-maven-3.6.0-bin.tar.gz \
	&& sed -i 's/<dependencies>/<dependencies>\n<dependency>\n\t<groupId>javax\.annotation<\/groupId>\n\t<artifactId>javax\.annotation-api<\/artifactId>\n\t<version>1\.3\.2<\/version>\n<\/dependency>/g' /root/Tars/java/core/server.pom.xml \
	&& sed -i 's/<dependencies>/<dependencies>\n<dependency>\n\t<groupId>javax\.annotation<\/groupId>\n\t<artifactId>javax\.annotation-api<\/artifactId>\n\t<version>1\.3\.2<\/version>\n<\/dependency>/g' /root/Tars/java/core/client.pom.xml \
	&& sed -i 's/<dependencies>/<dependencies>\n<dependency>\n\t<groupId>javax\.annotation<\/groupId>\n\t<artifactId>javax\.annotation-api<\/artifactId>\n\t<version>1\.3\.2<\/version>\n<\/dependency>/g' /root/Tars/java/core/pom.xml \
	&& cd /root/Tars/java && source /etc/profile \
	&& mvn clean install && mvn clean install -f core/client.pom.xml \
	&& mvn clean install -f core/server.pom.xml \
	&& cd /root/init && mvn archetype:generate -DgroupId=com.tangramor -DartifactId=TestJava -DarchetypeArtifactId=maven-archetype-webapp -DinteractiveMode=false \
	&& cd /root/Tars/java/examples/quickstart-server/ && mvn tars:tars2java && mvn package \
	&& mkdir -p /root/sql && cp -rf /root/Tars/framework/sql/* /root/sql/ \
	&& cd /root/Tars/framework/build/ && ./build.sh cleanall \
	&& yum clean all && rm -rf /var/cache/yum


# 是否将开启Tars的Web管理界面登录功能，预留，目前没用
ENV ENABLE_LOGIN false

# 是否将Tars系统进程的data目录挂载到外部存储，缺省为false以支持windows下使用
ENV MOUNT_DATA false

# 网络接口名称，如果运行时使用 --net=host，宿主机网卡接口可能不叫 eth0
ENV INET_NAME eth0

VOLUME ["/data"]
	
##拷贝资源
COPY install.sh /root/init/
COPY entrypoint.sh /sbin/

ADD confs /root/confs

RUN chmod 755 /sbin/entrypoint.sh
ENTRYPOINT [ "/sbin/entrypoint.sh", "start" ]

#Expose ports
EXPOSE 3000
EXPOSE 80
