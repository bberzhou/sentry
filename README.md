## Apache sentry
### 一、简介
Apache Sentry是一个高度模块化的系统，
用于为存储在Apache Hadoop集群上的数据和元数据提供细粒度的基于角色的授权。

### 二、移植需要依赖

- JDK8

- Maven3.2.5

- sentry1.6.0

  下载源码包之后进行解压，配置Java和maven环境变量，进入到sentry源码目录，执行

  ```shell
  mvn clean install -DskipTests
  ```

  即可完成编译打包工作，注意1.5版本需要JDK1.7，否则会报错。

### 三、测试需要软件

本次测试sentry+Kerberos的权限控制，需要安装如下软件

- JDK1.8
- Hadoop2.6.0
- MySQL5.7.27
- maven3.2.5
- hive1.1.0
- sentry1.6.0
- Kerberos5

### 四、测试步骤

本次主要测试使用sentry+Kerberos来做hive的权限控制，测试步骤如下：

1. 首先安装JDK1.8和maven；
2. 解压sentry源码，使用maven进行编译，生成可执行文件的压缩包；
3. 然后安装MySQL、Hadoop、hive、sentry并进行相关的整合配置；
4. sentry连接MySQL数据库，并进行初始化，然后启动所有组件；
5. 在hive数据库中创建测试数据，并创建两个测试用户admin 和test，给与不同的权限
6. 客户端使用beeline连接hive，测试sentry能否做到权限管理
7. 安装Kerberos，并进行Kerberos+sentry+Hadoop+hive的整合配置；
8. 客户端拿到Kerberos票据之后，使用beeline连接hive，测试Kerberos+sentry能否做到权限管理。

### 五、sentry1.6rpm制作

1. 安装rpm打包相关依赖
2. 下载sentry1.6.0源码
3. 配置JDK和maven
4. 执行SPEC文件，进行rpm打包，
5. sentry安装路径默认为 /usr/local 目录下

