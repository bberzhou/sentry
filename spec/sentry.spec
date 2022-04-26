Name:       	    apache-sentry 
Version:    	    1.6.0_rc0 
Release:    	    1%{?dist} 
License:    	    Apache-2.0 License
URL:		    https://sentry.apache.org/
Source0:            apache-sentry-1.6.0_rc0.tar.gz 
BuildRoot:	    %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX) 
# BuildRequires:    maven java-1.8.0-openjdk java-1.8.0-openjdk-devel wget
Autoreq:	    yes 
Requires:	    java-1.8.0-openjdk java-1.8.0-openjdk-devel 
BuildArch:          noarch
Summary:            apache-sentry 1.6.0_rc0 

%description
The apache sentry.

%prep

%setup -q 

%build 
mvn clean compile package -DskipTests

%install 
rm -rf %{buildroot} 
mkdir -p %{buildroot}/usr/local/apache-sentry/ 
tar -zxf /root/rpmbuild/BUILD/apache-sentry-1.6.0_rc0/sentry-dist/target/apache-sentry-1.6.0-incubating-bin.tar.gz
cp -r /root/rpmbuild/BUILD/apache-sentry-1.6.0_rc0/sentry-dist/target/apache-sentry-1.6.0-incubating-bin/apache-sentry-1.6.0-incubating-bin/ %{buildroot}/usr/local/apache-sentry/

%pre 
rm -rf /usr/local/apache-sentry 
mkdir -p /usr/local/apache-sentry 

%post 

%files
%defattr (-,root,root)
/usr/local/apache-sentry/* 

%preun 
rm -rf /usr/local/apache-sentry 

%changelog
