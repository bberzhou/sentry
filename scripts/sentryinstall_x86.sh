#!/usr/bin/env bash

get_package()
{
	echo "开始下载所需软件包....................................."
	sleep 2
	mkdir /bigdata
	cd /bigdata/
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
	yum install -y -q libaio*
	yum install -y -q git
	yum install -y -q gcc rpm-build rpm-devel rpmlint make python bash coreutils diffutils patch rpmdevtools expect
	yum install -y -q krb5-libs krb5-server krb5-workstation krb5-devel

	echo "所需软件包下载完成"
}

set_env()
{	
	echo "开始配置JDK........................................."
	sleep 2
	cd /bigdata/
	tar -zxf bisheng-jdk-8u312-linux-x64.tar.gz
	sleep 2
	tar -zxf apache-maven-3.2.5-bin.tar.gz

	cat <<-EOF >> /etc/profile
	
	#Java8     
	export JAVA_HOME=/bigdata/bisheng-jdk1.8.0_312
	export PATH=\$JAVA_HOME/bin:\$PATH
	
	
	#Hadoop
	export HADOOP_HOME=/bigdata/hadoop-2.6.0
	export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
	
	#Mysql
	export MYSQL_HOME=/usr/local/mysql
	export PATH=\$PATH:\$MYSQL_HOME/bin
	
	#Hive
	export HIVE_HOME=/bigdata/apache-hive-1.1.0-bin
	export PATH=\$PATH:\$HIVE_HOME/bin
	
	#Sentry
	export SENTRY_HOME=/usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin
	export PATH=\$PATH:\$SENTRY_HOME/bin

	#Maven
	export MAVEN_HOME=/bigdata/apache-maven-3.2.5
	export PATH=\$PATH:\$MAVEN_HOME/bin

	EOF

	source /etc/profile
	java -version
	mvn -v
	git --version
}


set_mysql()
{	
	echo "开始配置Mysql........................................."
	sleep 2
	cd /bigdata/
	mv mysql-5.7.12-linux-glibc2.5-x86_64.tar.gz /usr/local/
	cd /usr/local/
	tar -zxf mysql-5.7.12-linux-glibc2.5-x86_64.tar.gz 
	mv /usr/local/mysql-5.7.12-linux-glibc2.5-x86_64 /usr/local/mysql
	mkdir -p /usr/local/mysql/logs
	mkdir /usr/local/mysql/data
	touch /usr/local/mysql/logs/mysqld.log
        groupadd -r mysql && useradd -r -g mysql -s /sbin/nologin -M mysql
        chown -R mysql:mysql /usr/local/mysql
        cp -rf /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
        chmod +x /etc/init.d/mysqld
        systemctl enable mysqld
	cd /usr/local/mysql/bin
	./mysqld --initialize-insecure --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
	sleep 5
	systemctl start mysqld
	sleep 5
	mysql -u root -e "create database sentry;CREATE USER sentry IDENTIFIED BY 'sentry';GRANT all ON sentry.* TO sentry@'%' IDENTIFIED BY 'sentry';GRANT ALL PRIVILEGES ON  *.* TO 'root'@'%' IDENTIFIED BY '123456';use mysql;update user set authentication_string=password('123456') where user = 'root' and host = 'localhost';flush privileges;"
	sleep 5
}

set_kerbros()
{	
	echo "开始配置Kerberos........................................."
	sleep 3
	cd /bigdata
	unzip jce_policy-8.zip 
	cd UnlimitedJCEPolicyJDK8/
	mv local_policy.jar /bigdata/bisheng-jdk1.8.0_312/jre/lib/security
	mv US_export_policy.jar /bigdata/bisheng-jdk1.8.0_312/lib/security
	cat <<-EOF > /etc/krb5.conf
	[logging]
	 default = FILE:/var/log/krb5libs.log
	 kdc = FILE:/var/log/krb5kdc.log
	 admin_server = FILE:/var/log/kadmind.log
	 
	[libdefaults]
	 default_realm = EXAMPLE.COM  
	 dns_lookup_kdc = false
	 dns_lookup_realm = false
	 ticket_lifetime = 86400
	 renew_lifetime = 604800
	 forwardable = true
	 default_tgs_enctypes = rc4-hmac des3-cbc-sha1 arcfour-hmac aes256-cts des-cbc-md5 des-cbc-crc
	 default_tkt_enctypes = rc4-hmac des3-cbc-sha1 arcfour-hmac aes256-cts des-cbc-md5 des-cbc-crc
	 permitted_enctypes = rc4-hmac des3-cbc-sha1 arcfour-hmac aes256-cts des-cbc-md5 des-cbc-crc
	 udp_preference_limit = 1
	 kdc_timeout = 3000
	
	[realms]
	 EXAMPLE.COM = {
	 kdc = localhost
	 admin_server = localhost  
	 }
	EOF

	cat <<-EOF > /var/kerberos/krb5kdc/kdc.conf
	[kdcdefaults]
	 kdc_ports = 88
	 kdc_tcp_ports = 88

	[realms]
	 EXAMPLE.COM = {
	  #master_key_type = aes256-cts
	  acl_file = /var/kerberos/krb5kdc/kadm5.acl
	  dict_file = /usr/share/dict/words
	  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
	  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
	 }
	EOF

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

set_hadoop()
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


	cd /bigdata/
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
	cd /bigdata/
	tar -zxf hadoop-2.6.0.tar.gz 
	hadoop version


	cd /bigdata/hadoop-2.6.0/etc/hadoop/
	

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/ssl-server.xml
	<?xml version="1.0"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	   Licensed to the Apache Software Foundation (ASF) under one or more
	   contributor license agreements.  See the NOTICE file distributed with
	   this work for additional information regarding copyright ownership.
	   The ASF licenses this file to You under the Apache License, Version 2.0
	   (the "License"); you may not use this file except in compliance with
	   the License.  You may obtain a copy of the License at
	
	       http://www.apache.org/licenses/LICENSE-2.0
	
	   Unless required by applicable law or agreed to in writing, software
	   distributed under the License is distributed on an "AS IS" BASIS,
	   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	   See the License for the specific language governing permissions and
	   limitations under the License.
	-->
	<configuration>
		<property>
			<name>ssl.server.truststore.location</name>
			<value>/etc/hadoop/https/truststore</value>
			<description>Truststore to be used by NN and DN. Must be specified.</description>
		</property>
		<property>
			<name>ssl.server.truststore.password</name>
			<value>123456</value>
			<description>Optional. Default value is "".</description>
		</property>
		<property>
			<name>ssl.server.truststore.type</name>
			<value>jks</value>
			<description>Optional. The keystore file format, default value is "jks".</description>
		</property>
		<property>
			<name>ssl.server.truststore.reload.interval</name>
			<value>10000</value>
			<description>Truststore reload check interval, in milliseconds.Default value is 10000 (10 seconds).
		</description>
		</property>
		<property>
			<name>ssl.server.keystore.location</name>
			<value>/etc/hadoop/https/keystore</value>
			<description>Keystore to be used by NN and DN. Must be specified.</description>
		</property>
		<property>
			<name>ssl.server.keystore.password</name>
			<value>123456</value>
			<description>Must be specified.</description>
		</property>
		<property>
			<name>ssl.server.keystore.keypassword</name>
			<value>123456</value>
			<description>Must be specified.</description>
		</property>
		<property>
			<name>ssl.server.keystore.type</name>
			<value>jks</value>
			<description>Optional. The keystore file format, default value is "jks".</description>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/ssl-client.xml
	<?xml version="1.0"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	   Licensed to the Apache Software Foundation (ASF) under one or more
	   contributor license agreements.  See the NOTICE file distributed with
	   this work for additional information regarding copyright ownership.
	   The ASF licenses this file to You under the Apache License, Version 2.0
	   (the "License"); you may not use this file except in compliance with
	   the License.  You may obtain a copy of the License at
	
	       http://www.apache.org/licenses/LICENSE-2.0
	
	   Unless required by applicable law or agreed to in writing, software
	   distributed under the License is distributed on an "AS IS" BASIS,
	   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	   See the License for the specific language governing permissions and
	   limitations under the License.
	-->
	<configuration>
		<property>
			<name>ssl.client.truststore.location</name>
			<value>/etc/hadoop/https/truststore</value>
			<description>Truststore to be used by clients like distcp. Must bespecified.</description>
		</property>
		<property>
			<name>ssl.client.truststore.password</name>
			<value>123456</value>
			<description>Optional. Default value is "".</description>
		</property>
		<property>
			<name>ssl.client.truststore.type</name>
			<value>jks</value>
			<description>Optional. The keystore file format, default value is "jks".</description>
		</property>
		<property>
			<name>ssl.client.truststore.reload.interval</name>
			<value>10000</value>
			<description>Truststore reload check interval, in milliseconds.Default value is 10000 (10 seconds).</description>
		</property>
		<property>
			<name>ssl.client.keystore.location</name>
			<value>/etc/hadoop/https/keystore</value>
			<description>Keystore to be used by clients like distcp. Must bespecified.</description>
		</property>
		<property>
			<name>ssl.client.keystore.password</name>
			<value>123456</value>
			<description>Optional. Default value is "".</description>
		</property>
		<property>
			<name>ssl.client.keystore.keypassword</name>
			<value>123456</value>
			<description>Optional. Default value is "".</description>
		</property>
		<property>
			<name>ssl.client.keystore.type</name>
			<value>jks</value>
			<description>Optional. The keystore file format, default value is "jks".</description>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/core-site.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	  Licensed under the Apache License, Version 2.0 (the "License");
	  you may not use this file except in compliance with the License.
	  You may obtain a copy of the License at
	
	    http://www.apache.org/licenses/LICENSE-2.0
	
	  Unless required by applicable law or agreed to in writing, software
	  distributed under the License is distributed on an "AS IS" BASIS,
	  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	  See the License for the specific language governing permissions and
	  limitations under the License. See accompanying LICENSE file.
	-->
	
	<!-- Put site-specific property overrides in this file. -->
	
	<configuration>
		<property>
	        <name>hadoop.tmp.dir</name>
	        <value>file:/usr/local/hadoop/tmp</value>
	        <description>Abase for other temporary directories.</description>
	    </property>
	    <property>
	        <name>fs.defaultFS</name>
	        <value>hdfs://localhost:9000</value>
	    </property>
		<property>
			<name>hadoop.proxyuser.hive.hosts</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.hive.groups</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.hdfs.hosts</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.hdfs.groups</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.HTTP.hosts</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.HTTP.groups</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.yarn.hosts</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.yarn.groups</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.security.authorization</name>
			<value>true</value>
		</property>
		<property>
			<name>hadoop.security.authentication</name>
			<value>kerberos</value>
		</property>
		<property>
			<name>hadoop.proxyuser.yarn.hosts</name>
			<value>*</value>
		</property>
		<property>
			<name>hadoop.proxyuser.yarn.groups</name>
			<value>*</value>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/hdfs-site.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	  Licensed under the Apache License, Version 2.0 (the "License");
	  you may not use this file except in compliance with the License.
	  You may obtain a copy of the License at
	
	    http://www.apache.org/licenses/LICENSE-2.0
	
	  Unless required by applicable law or agreed to in writing, software
	  distributed under the License is distributed on an "AS IS" BASIS,
	  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	  See the License for the specific language governing permissions and
	  limitations under the License. See accompanying LICENSE file.
	-->
	
	<!-- Put site-specific property overrides in this file. -->
	
	<configuration>
		<property>
	    	<name>dfs.replication</name>
	        <value>1</value>
	    </property>
	    <property>
	        <name>dfs.namenode.name.dir</name>
	        <value>file:/usr/local/hadoop/tmp/dfs/name</value>
	    </property>
	    <property>
	        <name>dfs.datanode.data.dir</name>
	        <value>file:/usr/local/hadoop/tmp/dfs/data</value>
	     </property>
		<!-- General HDFS security config -->
		<property>
			<name>dfs.block.access.token.enable</name>
			<value>true</value>
		</property>
		<!-- NameNode security config -->
		<property>
			<name>dfs.namenode.keytab.file</name>
			<value>/etc/hadoop/conf/hdfs.keytab</value>
		</property>
		<property>
			<name>dfs.namenode.kerberos.principal</name>
			<value>hdfs/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>dfs.namenode.kerberos.internal.spnego.principal</name>
			<value>HTTP/localhost@EXAMPLE.COM</value>
		</property>
		<!-- Secondary NameNode security config -->
		<property>
			<name>dfs.secondary.namenode.keytab.file</name>
			<value>/etc/hadoop/conf/hdfs.keytab</value>
		</property>
		<property>
			<name>dfs.secondary.namenode.kerberos.principal</name>
			<value>hdfs/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>dfs.secondary.namenode.kerberos.internal.spnego.principal</name>
			<value>HTTP/localhost@EXAMPLE.COM</value>
		</property>
		<!-- DataNode security config -->
		<property>
			<name>dfs.datanode.data.dir.perm</name>
			<value>700</value> 
		</property>
		<!--<property>
			<name>dfs.datanode.address</name>
			<value>0.0.0.0:50010</value>
		</property>
		<property>
			<name>dfs.datanode.http.address</name>
			<value>0.0.0.0:50075</value>
		</property>-->
		<property>
			<name>dfs.datanode.keytab.file</name>
			<value>/etc/hadoop/conf/hdfs.keytab</value>
		</property>
		<property>
			<name>dfs.datanode.kerberos.principal</name>
			<value>hdfs/localhost@EXAMPLE.COM</value>
		</property>
		<!-- Web Authentication config -->
		<property>
			<name>dfs.web.authentication.kerberos.principal</name>
			<value>HTTP/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>dfs.journalnode.keytab.file</name>
			<value>/etc/hadoop/conf/hdfs.keytab</value>
		</property>
		<property>
			<name>dfs.journalnode.kerberos.principal</name>
			<value>hdfs/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>dfs.journalnode.kerberos.internal.spnego.principal</name>
			<value>HTTP/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>dfs.data.transfer.protection</name>
			<value>integrity</value>
		</property>
		<property>
			<name>dfs.http.policy</name>
			<value>HTTPS_ONLY</value>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/yarn-site.xml
	<?xml version="1.0"?>
	<!--
	  Licensed under the Apache License, Version 2.0 (the "License");
	  you may not use this file except in compliance with the License.
	  You may obtain a copy of the License at
	
	    http://www.apache.org/licenses/LICENSE-2.0
	
	  Unless required by applicable law or agreed to in writing, software
	  distributed under the License is distributed on an "AS IS" BASIS,
	  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	  See the License for the specific language governing permissions and
	  limitations under the License. See accompanying LICENSE file.
	-->
	<configuration>
	
	<!-- Site specific YARN configuration properties -->
		<property>
	        <name>yarn.nodemanager.aux-services</name>
	        <value>mapreduce_shuffle</value>
	    </property>
		<!-- ResourceManager security configs -->
		<property>
			<name>yarn.resourcemanager.keytab</name>
			<value>/etc/hadoop/conf/yarn.keytab</value>
		</property>
		<property>
			<name>yarn.resourcemanager.principal</name>
			<value>yarn/localhost@EXAMPLE.COM</value>
		</property>
		<!-- NodeManager security configs -->
		<property>
			<name>yarn.nodemanager.keytab</name>
			<value>/etc/hadoop/conf/yarn.keytab</value>
		</property>
		<property>
			<name>yarn.nodemanager.principal</name>
			<value>yarn/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>yarn.resourcemanager.proxy-user-privileges.enabled</name>
			<value>true</value>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/hadoop-2.6.0/etc/hadoop/mapred-site.xml
	<?xml version="1.0"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	  Licensed under the Apache License, Version 2.0 (the "License");
	  you may not use this file except in compliance with the License.
	  You may obtain a copy of the License at
	
	    http://www.apache.org/licenses/LICENSE-2.0
	
	  Unless required by applicable law or agreed to in writing, software
	  distributed under the License is distributed on an "AS IS" BASIS,
	  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	  See the License for the specific language governing permissions and
	  limitations under the License. See accompanying LICENSE file.
	-->
	
	<!-- Put site-specific property overrides in this file. -->
	
	<configuration>
	    <property>
	        <name>mapreduce.framework.name</name>
	        <value>yarn</value>
	    </property>
		<property>
		     <name>mapreduce.jobhistory.keytab</name>
		     <value>/etc/hadoop/conf/mapred.keytab</value>
		</property>
		<property>
		     <name>mapreduce.jobhistory.principal</name>
		     <value>mapred/localhost@EXAMPLE.COM</value>
		</property>
		<property>
		     <name>mapreduce.jobhistory.webapp.spnego-principal</name>
		     <value>HTTP/localhost@EXAMPLE.COM</value>
		</property>
		<property>
		     <name>mapreduce.jobhistory.webapp.spnego-keytab-file</name>
		     <value>/etc/hadoop/conf/mapred.keytab</value>
		</property>
	</configuration>
	EOF

	mkdir -p /bigdata/hadoop-2.6.0/logs
	chmod -R 755 /bigdata
	chmod -R 777 /bigdata/hadoop-2.6.0

	hdfs namenode -format
	chmod -R 777 /usr/local/hadoop

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

set_sentry()
{	
	echo "开始编译打包安装sentry........................................."
	sleep 2
	rpmdev-setuptree
	echo "git clone source....................."
	cd /bigdata
	git clone https://gitee.com/bberzhou/sentry.git
	cd sentry/spec
	mv apache-sentry-1.6.0_rc0.tar.gz /root/rpmbuild/SOURCES/
	mv sentry.spec /root/rpmbuild/SPECS/
	cd /root/rpmbuild/SPECS
	rpmbuild -ba sentry.spec
	# rpmbuild --undefine=_disable_source_fetch -ba sentry.spec
	cd /root/rpmbuild/RPMS/noarch
	yum -y install apache-sentry-1.6.0_rc0-1.noarch.rpm
	cp /bigdata/mysql-connector-java-5.1.47.jar /usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin/lib/
	cat <<-EOF > /usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin/conf/sentry-site.xml
	<?xml version="1.0"?>
	<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
	<!--
	   Licensed to the Apache Software Foundation (ASF) under one or more
	   contributor license agreements.  See the NOTICE file distributed with
	   this work for additional information regarding copyright ownership.
	   The ASF licenses this file to You under the Apache License, Version 2.0
	   (the "License"); you may not use this file except in compliance with
	   the License.  You may obtain a copy of the License at
	
	       http://www.apache.org/licenses/LICENSE-2.0
	
	   Unless required by applicable law or agreed to in writing, software
	   distributed under the License is distributed on an "AS IS" BASIS,
	   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	   See the License for the specific language governing permissions and
	   limitations under the License.
	-->
	
	<!-- WARNING!!! This file is provided for documentation purposes ONLY!              -->
	<!-- WARNING!!! You should copy to sentry-site.xml and make modification instead.   -->
	
	<configuration>
		<property>
			<name>sentry.service.allow.connect</name>
			<value>hive,admin</value>
			<description>comma separated list of users - List of users that are allowed to connect to the service (eg Hive, Impala) </description>
		</property>
		<property>
			<name>sentry.store.jdbc.url</name>
			<value>jdbc:mysql://localhost:3306/sentry?createDatabaseIfNotExist=true&amp;useSSL=false</value>
			<description>JDBC connection URL for the backed DB</description>
		</property>
		<property>
			<name>sentry.store.jdbc.user</name>
			<value>root</value>
			<description>Userid for connecting to backend db </description>
		</property>
		<property>
			<name>sentry.store.jdbc.password</name>
			<value>123456</value>
			<description>Sentry password for backend JDBC user </description>
		</property>
		<property>
			<name>sentry.service.server.rpcport</name>
			<value>8038</value>
			<description> TCP port number for service</description>
		</property>
		<property>
			<name>sentry.service.server.rpcaddress</name>
			<value>0.0.0.0</value>
			<description> TCP interface for service to bind to</description>
		</property>
		<property>
			<name>sentry.store.jdbc.driver</name>
			<value>com.mysql.jdbc.Driver</value>
			<description>Backend JDBC driver - org.apache.derby.jdbc.EmbeddedDriver (only when dbtype = derby) JDBC Driver class for the backed DB</description>
		</property>
		<property>
			<name>sentry.service.admin.group</name>
			<value>admin</value>
			<description>Comma separates list of groups.  List of groups allowed to make policy updates</description>
		</property>
		<property>
			<name>sentry.store.group.mapping</name>
			<value>org.apache.sentry.provider.common.HadoopGroupMappingService</value>
			<description>
				Group mapping class for Sentry service. org.apache.sentry.provider.file.LocalGroupMapping service can be used for local group mapping. </description>
		</property>
		<property>
			<name>sentry.service.security.mode</name>
			<value>none</value>
			<description>Options: kerberos, none.  Authentication mode for Sentry service. Currently supports Kerberos and trusted mode </description>
		</property>
		<property>
			<name>sentry.service.server.principal</name>
			<value> </value>
		</property>
		<property>
			<name>sentry.service.server.keytab</name>
			<value> </value>
		</property>
		<property>
			<name>sentry.service.reporting</name>
			<value>JMX</value>
		</property>
		<property>
			<name>sentry.service.server.rpc-address</name>
			<value>localhost</value>
		</property>
		<property>
			<name>sentry.service.server.rpc-port</name>
			<value>8038</value>
		</property>
		<property>
			<name>sentry.hive.server</name>
			<value>server1</value>
		</property>
		<property>
			<name>sentry.service.web.enable</name>
			<value>true</value>
		</property>
		<property>
			<name>sentry.service.web.port</name>
			<value>51000</value>
		</property>
		<property>
			<name>sentry.service.web.authentication.type</name>
			<value>NONE</value>
		</property>
	</configuration>

	EOF
	chmod -R 755 /usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin
	cp /usr/local/apache-sentry/apache-sentry-1.6.0-incubating-bin/lib/jline-2.12.jar ${HADOOP_HOME}/share/hadoop/yarn/lib/
	rm -rf ${HADOOP_HOME}/share/hadoop/yarn/lib/jline-0.9.94.jar 
	sentry --command schema-tool --conffile  ${SENTRY_HOME}/conf/sentry-site.xml --dbType mysql --initSchema

	mkdir /bigdata/logs
	chmod -R 777 /bigdata/logs

}

set_hive()
{	
	echo "开始配置hive........................................."
	sleep 3
	cd /bigdata/
	tar -zxf apache-hive-1.1.0-bin.tar.gz
	cd apache-hive-1.1.0-bin/
	cp /bigdata/mysql-connector-java-5.1.47.jar ./lib/

	cat <<-EOF > /bigdata/apache-hive-1.1.0-bin/conf/sentry-site.xml
	<configuration>
		<property>
			<name>sentry.service.client.server.rpc-address</name>
			<value>localhost</value>
		</property>
		<property>
			<name>sentry.service.client.server.rpc-port</name>
			<value>8038</value>
		</property>
		<property>
			<name>sentry.service.client.server.rpc-connection-timeout</name>
			<value>200000</value>
		</property>
		<!--配置认证-->
		<property>
			<name>sentry.service.security.mode</name>
			<value>none</value>
		</property>
		<property>
			<name>sentry.service.server.principal</name>
			<value> </value>
		</property>
		<property>
			<name>sentry.service.server.keytab</name>
			<value> </value>
		</property>
		<property>
			<name>sentry.provider</name>
			<value>org.apache.sentry.provider.file.HadoopGroupResourceAuthorizationProvider</value>
		</property>
		<property>
			<name>sentry.hive.provider.backend</name>
			<value>org.apache.sentry.provider.db.SimpleDBProviderBackend</value>
		</property>
		<property>
			<name>sentry.metastore.service.users</name>
			<value>hive</value>
		<!--queries made by hive user (beeline) skip meta store check-->
		</property>
		<property>
			<name>sentry.hive.server</name>
			<value>server1</value>
		</property>
		<property>
			<name>sentry.hive.testing.mode</name>
			<value>true</value>
		</property>
	</configuration>
	EOF

	cat <<-EOF > /bigdata/apache-hive-1.1.0-bin/conf/hive-site.xml 
	<configuration>
		<property>
			<name>javax.jdo.option.ConnectionURL</name>
			<value>jdbc:mysql://localhost:3306/hive?createDatabaseIfNotExist=true&amp;useSSL=false</value> 
		</property>
		<property> 
			<name>javax.jdo.option.ConnectionDriverName</name>
			<value>com.mysql.jdbc.Driver</value> 
		</property>
		<property> 
			<name>javax.jdo.option.ConnectionUserName</name> 
			<value>root</value>
		</property>
		<property> 
			<name>javax.jdo.option.ConnectionPassword</name> 
			<value>123456</value>
		</property>
		<property> 
			<name>hive.server2.thrift.bind.host</name>
			<value>localhost</value>
		</property>
		<property>
			<name>hive.server2.thrift.port</name>
			<value>10000</value>
		</property>
		<property>
			<name>hive.sentry.conf.url</name>
			<value>file:///bigdata/apache-hive-1.1.0-bin/conf/sentry-site.xml</value>
		</property>
		<property>
			<name>hive.stats.collect.scancols</name>
			<value>true</value>
		</property>
		<property>
			<name>hive.metastore.pre.event.listeners</name>
			<value>org.apache.sentry.binding.metastore.MetastoreAuthzBinding</value>
		</property>
		<property>
			<name>hive.metastore.event.listeners</name>
			<value>org.apache.sentry.binding.metastore.SentryMetastorePostEventListener</value>
		</property>
		<property>
			<name>hive.server2.session.hook</name>
			<value>org.apache.sentry.binding.hive.HiveAuthzBindingSessionHook</value>
		</property>
		<property>
			<name>hive.security.authorization.task.factory</name>
			<value>org.apache.sentry.binding.hive.SentryHiveAuthorizationTaskFactoryImpl</value>
		</property>
		<property>
			<name>hive.server2.authentication</name>
			<value>KERBEROS</value>
		</property>
		<property>
			<name>hive.server2.authentication.kerberos.principal</name>
			<value>hive/localhost@EXAMPLE.COM</value>
		</property>
		<property>
			<name>hive.server2.authentication.kerberos.keytab</name>
			<value>/etc/hive/conf/hive.keytab</value>
		</property>
		<property>
			<name>hive.metastore.sasl.enabled</name>
			<value>true</value>
		</property>
		<property>
			<name>hive.metastore.kerberos.keytab.file</name>
			<value>/etc/hive/conf/hive.keytab</value>
		</property>
		<property>
			<name>hive.metastore.kerberos.principal</name>
			<value>hive/localhost@EXAMPLE.COM</value>
		</property>
	</configuration>	
	EOF
	cp ${SENTRY_HOME}/lib/sentry*.jar ${HIVE_HOME}/lib
	cp ${SENTRY_HOME}/lib/shiro-*.jar ${HIVE_HOME}/lib
	chmod -R 755 /bigdata/apache-hive-1.1.0-bin
	schematool -dbType mysql -initSchema
	mkdir /bigdata/data
	cat <<-EOF > /bigdata/data/events.csv
	10.1.2.3,US,android,createNote
	10.200.88.99,FR,windows,updateNote
	10.1.2.3,US,android,updateNote
	10.200.88.77,FR,ios,createNote
	10.1.4.5,US,windows,updateTag
	EOF
	chmod -R 755 /bigdata/data

	su - hive <<-EOF
	kinit -kt /etc/hive/conf/hive.keytab hive/localhost@EXAMPLE.COM;
	klist;
	hive -e "create database if not exists sensitive; create table if not exists sensitive.events (ip STRING, country STRING, client STRING, action STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ','; load data local inpath '/bigdata/data/events.csv' overwrite into table sensitive.events; create database if not exists filtered; create view if not exists filtered.events as select country, client, action from sensitive.events; create view if not exists filtered.events_usonly as select * from filtered.events where country = 'US';select * from sensitive.events;";
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
	get_package
	set_env
	set_mysql
	set_kerbros
	set_hadoop
	set_sentry
	set_hive
	echo "环境配置完成!"
}
main


