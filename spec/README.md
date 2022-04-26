## Apache sentry
### 介绍
Apache Sentry is a highly modular system for providing fine grained role based authorization to both data and metadata stored on an Apache Hadoop cluster.

### Building Sentry


### 使用说明
   1. 使用git clone本仓库；
   1. 将源码包复制到rpmbuild的SOURCES目录下；
   2. 执行sepc文件打包rpm；
   2. spec文件里面会对源码进行解压，然后使用maven进行编译，生成可执行文件，
   2. 安装时，默认安装到系统的 /usr/local 目录下
