#!/usr/bin/env bash

start_sentry(){
	echo "开始启动sentry...................."
	nohup sentry --command service --conffile  ${SENTRY_HOME}/conf/sentry-site.xml >> /tmp/download/logs/sentry.log 2>&1 &
	sleep 3
	tail -n 15 /tmp/download/logs/sentry.log 
	echo "sentry启动完成...................."
}

start_hadoop(){
	echo "开始启动hdfs...................."
	su - hdfs <<-EOF
	kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/localhost@EXAMPLE.COM;
	klist;
	hadoop-daemon.sh start namenode;
	hadoop-daemon.sh start datanode;
	exit;
	EOF
	sleep 5
	echo "hdfs启动完成...................."

	echo "开始启动historyserver...................."
	su - mapred <<-EOF
	kinit -kt /etc/hadoop/conf/mapred.keytab mapred/localhost@EXAMPLE.COM;
	klist;
	mr-jobhistory-daemon.sh start historyserver;
	exit;
	EOF
	sleep 5
	echo "historyserver启动完成...................."

	echo "开始启动yarn...................."
	su - yarn <<-EOF
	kinit -kt /etc/hadoop/conf/yarn.keytab yarn/localhost@EXAMPLE.COM
	klist;
	yarn-daemon.sh start resourcemanager;
	yarn-daemon.sh start nodemanager;
	exit;
	EOF
	sleep 5
	echo "yarn启动完成...................."
}

stop_hadoop(){
	chmod -R 777 /tmp/download/hadoop-2.6.0/logs/
	u - yarn <<-EOF
	kinit -kt /etc/hadoop/conf/yarn.keytab yarn/localhost@EXAMPLE.COM
	klist;
	yarn-daemon.sh stop nodemanager;
	yarn-daemon.sh stop resourcemanager;
	exit;
	EOF

	su - mapred <<-EOF
	kinit -kt /etc/hadoop/conf/mapred.keytab mapred/localhost@EXAMPLE.COM;
	klist;
	mr-jobhistory-daemon.sh stop historyserver;
	exit;
	EOF

	su - hdfs <<-EOF
	kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/localhost@EXAMPLE.COM;
	klist;
	hadoop-daemon.sh stop datanode;
	hadoop-daemon.sh stop namenode;
	exit;
	EOF
}

start_hive(){
	echo "开始启动hive2...................."
	su - hive <<-EOF
	kinit -kt /etc/hive/conf/hive.keytab hive/localhost@EXAMPLE.COM;
	klist;
	nohup hive --service metastore >> /tmp/download/logs/hive-metastore.log 2>&1 &
	nohup hive --service hiveserver2 >> /tmp/download/hive-server2.log 2>&1 &
	exit;
	EOF
	echo "hive2启动中........."
	sleep 5
}

add_hive_sentry_permission(){
	echo "开始初始化权限账户,获取admin kerberos票据........................................................."
	su - admin <<-EOF
	kinit -kt /etc/hive/conf/admin.keytab admin/localhost@EXAMPLE.COM;
	klist;
	echo "创建admin角色.........................................................";
	sleep 6
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "create role admin_role;";
	
	echo "把最高权限授予admin角色.........................................................";
	sleep 6
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "GRANT ALL ON SERVER server1 TO ROLE admin_role;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "GRANT ROLE admin_role TO GROUP admin;";
	
	echo "创建test角色.........................................................";
	sleep 6
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "create role test_role;";
	
	sleep 6
	echo "把filtered库所有权限授予test角色,把sensitive.events的ip字段查询权限授予test角色......";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "GRANT ALL ON DATABASE filtered TO ROLE test_role;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "use sensitive;" -e "GRANT SELECT(ip) on TABLE sensitive.events TO ROLE test_role;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "GRANT ROLE test_role TO GROUP test;";
	exit;
	EOF
	echo "权限初始化设置完成........................................................."
}

check_hive_sentry_admin_user(){
	echo "开始验证admin账户权限........................................................."
	su - admin <<-EOF
	echo "获取admin用户Kerberos票据........................................................";
	sleep 5
	kinit -kt /etc/hive/conf/admin.keytab admin/localhost@EXAMPLE.COM;
	klist;

	echo "验证admin账户权限,admin账户拥有所有权限........................................................";
	sleep 5
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "show roles;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "show grant role admin_role;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "show grant role test_role;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "show databases;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "select * from filtered.events;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n admin -p admin -e "select * from sensitive.events;";
	echo "admin账户权限验证完成............................................................";
	sleep 5
	exit;
	EOF
}

check_hive_sentry_test_user(){
	echo "开始验证test账户权限........................................................."
	su - test <<-EOF
	echo "获取test用户Kerberos票据........................................................";
	sleep 5
	kinit -kt /etc/hive/conf/test.keytab test/localhost@EXAMPLE.COM;
	klist;
	
	sleep 5
	echo "验证test账户权限,test用户没有 'show roles' 权限..............................";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n test -p test -e "show roles;";
	
	
	echo "验证test账户权限,test用户有 'show databases'、'filtered'库权限...............";
	sleep 5
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n test -p test -e "show databases;";
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n test -p test -e "select * from filtered.events;";
	
	
	echo "验证test账户权限,test用户没有 'sensitive.events'表全部字段select库权限.........";
	sleep 5
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n test -p test -e "select * from sensitive.events;";
	
	
	echo "验证test账户权限,test用户有 'sensitive.events'表ip字段select权限...............";
	sleep 5
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n test -p test -e "select ip from sensitive.events;";
	sleep 5
	echo "test账户权限验证完成............................................................";
	exit;
	EOF
}

check_hive_no_kerberos_tgt_user(){
	su - kb5test <<-EOF
	echo "验证没有Kerberos票据用户 kb5test 权限................................................";
	sleep 5
	beeline -u "jdbc:hive2://localhost:10000/;principal=hive/localhost@EXAMPLE.COM" -n hive -p hive;
	exit;
	EOF
	echo "kb5test用户由于没有Kerberos票据,无法进入hive2客户端..............................."
	echo "hive、sentry、kerberos集成及权限验证完成!"
}
main(){
	source /etc/profile
	start_sentry
	start_hadoop
	start_hive
	add_hive_sentry_permission
	check_hive_sentry_admin_user
	check_hive_sentry_test_user
	check_hive_no_kerberos_tgt_user
}
main
