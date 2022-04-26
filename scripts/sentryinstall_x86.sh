#!/usr/bin/env bash
DOWNLOAD_PATH=/tmp/download
INSTALL_PATH=/usr/local

download_pkg()
{
	echo "开始下载所需软件包....................................."
	sleep 2
	[ -d "$DOWNLOAD_PATH"] || mkdir $DOWNLOAD_PATH 
	cd $DOWNLOAD_PATH
	wget mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/bisheng-jdk-8u312-linux-x64.tar.gz
	wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.7.12-linux-glibc2.5-x86_64.tar.gz
	# wget https://archive.apache.org/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz
	# wget https://archive.apache.org/dist/hive/hive-1.1.0/apache-hive-1.1.0-bin.tar.gz
	# wget https://gitee.com/bberzhou/apache-sentry/raw/master/pkg/jce_policy-8.zip
	# wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.47/mysql-connector-java-5.1.47.jar
	# wget https://archive.apache.org/dist/maven/maven-3/3.2.5/binaries/apache-maven-3.2.5-bin.tar.gz
	# wget http://124.70.1.233/apache-sentry-1.6.0_rc0-1.noarch.rpm
	wget http://124.70.1.233/hadoop-2.6.0.tar.gz
	wget http://124.70.1.233/apache-hive-1.1.0-bin.tar.gz
	wget http://124.70.1.233/apache-maven-3.2.5-bin.tar.gz
	wget http://124.70.1.233/jce_policy-8.zip
	wget http://124.70.1.233/mysql-connector-java-5.1.47.jar

	echo "所需软件包下载完成.................................."
}

install_depends()
{
	yum install -y -q git libaio* tar gcc rpm-build rpm-devel rpmlint make python bash coreutils diffutils patch rpmdevtools expect krb5-libs krb5-server krb5-workstation krb5-devel
}

env_enable()
{
	source /etc/profile > /dev/null
}

install_java()
{
	cd $INSTALL_PATH
        tar -zxf $DOWNLOAD_PATH/bisheng-jdk-8u312-linux-x64.tar.gz -C ./
        echo 'export JAVA_HOME=/usr/local/bisheng-jdk1.8.0_312'>>/etc/profile
        echo 'export PATH=$JAVA_HOME/bin:$PATH'>>/etc/profile
        env_enable
}
install_maven()
{
        echo "开始配置Maven........................................."
        cd $INSTALL_PATH
        tar -zxf $DOWNLOAD_PATH/apache-maven-3.2.5-bin.tar.gz -C ./
        sed '55 a\<localRepository>/usr/local/apache-maven-3.2.5/repository</localRepository>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '159 a\<mirror>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '160 a\<id>huaweimaven</id>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '161 a\<name>huawei maven</name>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '162 a\<url>https://mirrors.huaweicloud.com/repository/maven/</url>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '163 a\<mirrorOf>central</mirrorOf>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        sed '164 a\</mirror>' -i $INSTALL_PATH/apache-maven-3.2.5/conf/settings.xml
        echo 'export MAVEN_HOME=/usr/local/apache-maven-3.2.5'>>/etc/profile
        echo 'export PATH=$MAVEN_HOME/bin:$PATH'>>/etc/profile
        env_enable
        mvn -v
}



install_mysql()
{	
	echo "开始安装配置Mysql........................................."
	sleep 2
	cd $INSTALL_PATH
	tar -zxf $DOWNLOAD_PATH/mysql-5.7.12-linux-glibc2.5-x86_64.tar.gz -C ./
	mv /usr/local/mysql-5.7.12-linux-glibc2.5-x86_64 /usr/local/mysql
	echo 'export MYSQL_HOME=/usr/local/mysql'>>/etc/profile
        echo 'export PATH=$PATH:$MYSQL_HOME/bin'>>/etc/profile
        env_enable
	mkdir -p $INSTALL_PATH/mysql/logs
	mkdir $INSTALL_PATH/mysql/data
	touch $INSTALL_PATH/mysql/logs/mysqld.log
        groupadd -r mysql && useradd -r -g mysql -s /sbin/nologin -M mysql
        chown -R mysql:mysql $INSTALL_PATH/mysql
        cp -rf $INSTALL_PATH/mysql/support-files/mysql.server /etc/init.d/mysqld
        chmod +x /etc/init.d/mysqld
        systemctl enable mysqld
	cd $INSTALL_PATH/mysql/bin
	./mysqld --initialize-insecure --user=mysql --basedir=$INSTALL_PATH/mysql --datadir=$INSTALL_PATH/mysql/data
	sleep 5
	systemctl start mysqld
	sleep 5
	mysql -u root -e "create database sentry;CREATE USER sentry IDENTIFIED BY 'sentry';GRANT all ON sentry.* TO sentry@'%' IDENTIFIED BY 'sentry';GRANT ALL PRIVILEGES ON  *.* TO 'root'@'%' IDENTIFIED BY '123456';use mysql;update user set authentication_string=password('123456') where user = 'root' and host = 'localhost';flush privileges;"
	sleep 5
}

install_kerberos()
{	
	echo "开始安装配置Kerberos........................................."
	sleep 3
	cd $DOWNLOAD_PATH
	unzip jce_policy-8.zip 
	cd UnlimitedJCEPolicyJDK8/
	mv local_policy.jar $INSTALL_PATH/bisheng-jdk1.8.0_312/jre/lib/security
	mv US_export_policy.jar $INSTALL_PATH/bisheng-jdk1.8.0_312/lib/security
	#  copy kerberos config file cp -f
        cd $WORKSPACE/
        \cp -f $WORKSPACE/../scripts/conf/kerberos/krb5.conf /etc/krb5.conf
        \cp -f $WORKSPACE/../scripts/conf/kerberos/kdc.conf /var/kerberos/krb5kdc/kdc.conf

	expect <<-EOF
	spawn kdb5_util create -r EXAMPLE.COM –s
	expect {
		"*KDC database master key*" { send "123456\n"; exp_continue}
		"*Re-enter*" { send "123456\n" }
	}
	EOF

	expect <<-EOF
	spawn kadmin.local -q "addprinc admin/admin"
	expect {
		"*password for principal*" { send "admin\n"; exp_continue}
		"*Re-enter*" { send "admin\n" }
	}
	EOF

	chkconfig krb5kdc on
	chkconfig kadmin on
	service krb5kdc start
	service kadmin start
	service krb5kdc status

	mkdir -p /etc/hadoop/conf
	chmod -R 755 /etc/hadoop
	mkdir -p /etc/hive/conf
	chmod -R 755 /etc/hive
	chmod -R 777 /tmp

	kadmin.local -q "addprinc -randkey hdfs/localhost@EXAMPLE.COM   "
	kadmin.local -q "addprinc -randkey mapred/localhost@EXAMPLE.COM "
	kadmin.local -q "addprinc -randkey yarn/localhost@EXAMPLE.COM   "
	kadmin.local -q "addprinc -randkey HTTP/localhost@EXAMPLE.COM   "
	kadmin.local -q "addprinc -randkey hive/localhost@EXAMPLE.COM   "
	kadmin.local -q "addprinc -randkey admin/localhost@EXAMPLE.COM  "
	kadmin.local -q "addprinc -randkey test/localhost@EXAMPLE.COM   "

	kadmin.local -q "xst -norandkey -k /etc/hadoop/conf/hdfs.keytab hdfs/localhost@EXAMPLE.COM HTTP/localhost@EXAMPLE.COM"
	kadmin.local -q "xst -norandkey -k /etc/hadoop/conf/mapred.keytab mapred/localhost@EXAMPLE.COM HTTP/localhost@EXAMPLE.COM"
	kadmin.local -q "xst -norandkey -k /etc/hadoop/conf/yarn.keytab yarn/localhost@EXAMPLE.COM HTTP/localhost@EXAMPLE.COM "
	kadmin.local -q "xst -norandkey -k /etc/hive/conf/hive.keytab hive/localhost@EXAMPLE.COM "
	kadmin.local -q "xst -norandkey -k /etc/hive/conf/admin.keytab admin/localhost@EXAMPLE.COM "
	kadmin.local -q "xst -norandkey -k /etc/hive/conf/test.keytab test/localhost@EXAMPLE.COM "

	groupadd hadoop;useradd test;useradd kb5test;useradd admin;useradd hdfs -g hadoop -p hdfs;useradd hive -g hadoop -p hive;useradd yarn -g hadoop -p yarn;useradd mapred -g hadoop -p mapred

	##生成用户Kerberos票据，票据有时间限制
	chown hdfs:hadoop /etc/hadoop/conf/hdfs.keytab
	chown mapred:hadoop /etc/hadoop/conf/mapred.keytab
	chown yarn:hadoop /etc/hadoop/conf/yarn.keytab
	chown hive:hadoop /etc/hive/conf/hive.keytab
	chown admin:admin /etc/hive/conf/admin.keytab
	chown test /etc/hive/conf/test.keytab
	chmod 400 /etc/hadoop/conf/*.keytab
	chmod 400 /etc/hive/conf/*.keytab
}

install_hadoop()
{
	echo "开始配置hadoop........................................."
	sleep 3
	mkdir /etc/hadoop/https
	cd /etc/hadoop/https/

	expect <<-EOF
	spawn openssl req -new -x509 -keyout bd_ca_key -out bd_ca_cert -days 9999 -subj /C=CN/ST=beijing/L=beijing/O=test/OU=test/CN=test
	expect {
		"*PEM pass phrase*" { send "123456\n"; exp_continue}
		"*Verifying*" { send "123456\n"; exp_continue}
	}
	EOF

	expect <<-EOF
	spawn keytool -keystore keystore -alias localhost -validity 9999 -genkey -keyalg RSA -keysize 2048 -dname CN=test,OU=test,O=test,L=beijing,ST=beijing,C=CN
	expect {
		"*密钥库口令*" { send "123456\n"; exp_continue}
		"*Enter keystore password*" { send "123456\n"; exp_continue}
		"*再次输入*" { send "123456\n"; exp_continue}
		"*new password*" { send "123456\n"; exp_continue}
		"*按回车*" { send "\n"; exp_continue}
		"*password):*" { send "\n"; exp_continue}
	}
	EOF

	expect <<-EOF
	spawn keytool -keystore truststore -alias CARoot -import -file bd_ca_cert
	expect {
		"*密钥库口令*" { send "123456\n"; exp_continue}
		"*Enter keystore password*" { send "123456\n"; exp_continue}
		"*再次输入*" { send "123456\n"; exp_continue}
		"*new password*" { send "123456\n"; exp_continue}
		"*是否信任此证书*" { send "y\n"; exp_continue}
		"*Trust this certi*" { send "y\n"; exp_continue}
	}
	EOF

	expect <<-EOF
	spawn keytool -certreq -alias localhost -keystore keystore -file cert
	expect {
		"*密钥库口令*" { send "123456\n"; exp_continue}
		"*Enter keystore password*" { send "123456\n"; exp_continue}
	}
	EOF
	
	openssl x509 -req -CA bd_ca_cert -CAkey bd_ca_key -in cert -out cert_signed -days 9999 -CAcreateserial -passin pass:123456

	expect <<-EOF
	spawn keytool -keystore keystore -alias CARoot -import -file bd_ca_cert
	expect {
		"*密钥库口令*" { send "123456\n"; exp_continue}
		"*Enter keystore password*" { send "123456\n"; exp_continue}
		"*是否信任此证书*" { send "y\n"; exp_continue}
		"*Trust this certi*" { send "y\n"; exp_continue}
	}
	EOF

	expect <<-EOF
	spawn keytool -keystore keystore -alias localhost -import -file cert_signed
	expect {
		"*密钥库口令*" { send "123456\n"; exp_continue}
		"*Enter keystore password*" { send "123456\n"; exp_continue}
	}
	EOF

	chmod -R 755 /etc/hadoop/https


	cd $INSTALL_PATH
	systemctl disable firewalld
	systemctl stop firewalld
	expect <<-EOF
	spawn ssh-keygen -t rsa
	expect {
		"*file in which to save the key*" { send "\n"; exp_continue}
		"*passphrase*" { send "\n"; exp_continue}
		"*same passphrase again*" { send "\n"; exp_continue}
	}
	EOF
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	
	tar -zxf $DOWNLOAD_PATH/hadoop-2.6.0.tar.gz -C ./
        echo 'export HADOOP_HOME=/usr/local/hadoop-2.6.0'>>/etc/profile
        echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'>>/etc/profile
        env_enable
        hadoop version
        # 修改hadoop的配置文件
        cd $WORKSPACE
        \cp -f $WORKSPACE/../scripts/conf/hadoop/ssl-server.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

        \cp -f $WORKSPACE/../scripts/conf/hadoop/ssl-client.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

        \cp -f $WORKSPACE/../scripts/conf/hadoop/core-site.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

        \cp -f $WORKSPACE/../scripts/conf/hadoop/hdfs-site.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

        \cp -f $WORKSPACE/../scripts/conf/hadoop/yarn-site.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

        \cp -f $WORKSPACE/../scripts/conf/hadoop/mapred-site.xml $INSTALL_PATH/hadoop-2.6.0/etc/hadoop/

	mkdir -p $INSTALL_PATH/hadoop-2.6.0/logs
	chmod -R 755 $INSTALL_PATH
	chmod -R 777 $INSTALL_PATH/hadoop-2.6.0

	hdfs namenode -format
	chmod -R 777 $INSTALL_PATH/hadoop

	su - hdfs <<-EOF
	kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/localhost@EXAMPLE.COM;
	klist;
	hadoop-daemon.sh start namenode;
	hadoop-daemon.sh start datanode;
	sleep 5;
	hdfs dfs -mkdir -p /user/hive/warehouse;
	hdfs dfs -mkdir -p /user/mapred;
	hdfs dfs -mkdir -p /user/yarn;
	hdfs dfs -mkdir -p /user/admin;
	hdfs dfs -mkdir -p /user/test;
	hdfs dfs -mkdir -p /tmp;
	hdfs dfs -chown -R hive:hadoop /user/hive;
	hdfs dfs -chown -R mapred:hadoop /user/mapred;
	hdfs dfs -chown -R yarn:hadoop /user/yarn;
	hdfs dfs -chown -R test:test /user/test;
	hdfs dfs -chown -R admin:admin /user/admin;
	hdfs dfs -chmod -R 777 /tmp;
	exit;
	EOF
}

install_sentry()
{	
	echo "开始编译打包安装sentry........................................."
	sleep 2
	rpmdev-setuptree
	cp $WORKSPACE/../spec/sentry.spec ~/rpmbuild/SPECS/
        cp $WORKSPACE/../spec/apache-sentry-1.6.0_rc0.tar.gz ~/rpmbuild/SOURCES/
        cd ~/rpmbuild/SPECS
        rpmbuild -bb --quiet sentry.spec
        echo "编译完成"
	# rpmbuild --undefine=_disable_source_fetch -ba sentry.spec
	cd ~/rpmbuild/RPMS/noarch
	yum install -y -q apache-sentry-1.6.0_rc0-1.noarch.rpm
	echo 'export SENTRY_HOME=/usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin'>>/etc/profile
        echo 'export PATH=$PATH:$SENTRY_HOME/bin'>>/etc/profile
        env_enable

        cp $DOWNLOAD_PATH/mysql-connector-java-5.1.47.jar $INSTALL_PATH/apache-sentry/apache-sentry-1.6.0-incubating-bin/lib/

        # sentry config
        \cp -f $WORKSPACE/../scripts/conf/sentry/sentry-site.xml $INSTALL_PATH/apache-sentry/apache-sentry-1.6.0-incubating-bin/conf/

	chmod -R 755 $INSTALL_PATH/apache-sentry/apache-sentry-1.6.0-incubating-bin
	cp $INSTALL_PATH/apache-sentry/apache-sentry-1.6.0-incubating-bin/lib/jline-2.12.jar ${HADOOP_HOME}/share/hadoop/yarn/lib/
	rm -rf ${HADOOP_HOME}/share/hadoop/yarn/lib/jline-0.9.94.jar 
	sentry --command schema-tool --conffile  ${SENTRY_HOME}/conf/sentry-site.xml --dbType mysql --initSchema
	mkdir $DOWNLOAD_PATH/logs
	chmod -R 777 $DOWNLOAD_PATH/logs

}

install_hive()
{	
	echo "开始配置hive........................................."
	sleep 3
	cd $INSTALL_PATH
        tar -zxf $DOWNLOAD_PATH/apache-hive-1.1.0-bin.tar.gz -C ./
        echo 'export HIVE_HOME=/usr/local/apache-hive-1.1.0-bin'>>/etc/profile
        echo 'export PATH=$PATH:$HIVE_HOME/bin'>>/etc/profile
        env_enable

        cp $DOWNLOAD_PATH/mysql-connector-java-5.1.47.jar $INSTALL_PATH/apache-hive-1.1.0-bin/lib/
        \cp -f $WORKSPACE/../scripts/conf/hive/sentry-site.xml $INSTALL_PATH/apache-hive-1.1.0-bin/conf/

        \cp -f $WORKSPACE/../scripts/conf/hive/hive-site.xml $INSTALL_PATH/apache-hive-1.1.0-bin/conf/

	cp ${SENTRY_HOME}/lib/sentry*.jar ${HIVE_HOME}/lib
	cp ${SENTRY_HOME}/lib/shiro-*.jar ${HIVE_HOME}/lib
	chmod -R 755 $INSTALL_PATH/apache-hive-1.1.0-bin
	schematool -dbType mysql -initSchema
	mkdir $DOWNLOAD_PATH/data
	cat <<-EOF > /tmp/download/data/events.csv
	10.1.2.3,US,android,createNote
	10.200.88.99,FR,windows,updateNote
	10.1.2.3,US,android,updateNote
	10.200.88.77,FR,ios,createNote
	10.1.4.5,US,windows,updateTag
	EOF
	chmod -R 755 $DOWNLOAD_PATH/data

	su - hive <<-EOF
	kinit -kt /etc/hive/conf/hive.keytab hive/localhost@EXAMPLE.COM;
	klist;
	hive -e "create database if not exists sensitive; create table if not exists sensitive.events (ip STRING, country STRING, client STRING, action STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ','; load data local inpath '/tmp/download/data/events.csv' overwrite into table sensitive.events; create database if not exists filtered; create view if not exists filtered.events as select country, client, action from sensitive.events; create view if not exists filtered.events_usonly as select * from filtered.events where country = 'US';select * from sensitive.events;";
	exit;
	EOF
    
        sleep 10
	su - hdfs <<-EOF
	kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/localhost@EXAMPLE.COM;
	klist;
	hadoop-daemon.sh stop datanode;
	hadoop-daemon.sh stop namenode;
	exit;
	EOF
}

main(){
	download_pkg
	install_depends
	install_java
	install_maven
	install_mysql
	install_kerberos
	install_hadoop
	install_sentry
	install_hive
	echo "环境配置完成!"
}
main


