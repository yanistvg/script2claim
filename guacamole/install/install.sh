#!/bin/bash

#########################
###                   ###
### Global Var Define ###
###                   ###
#########################

TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.112/bin/apache-tomcat-9.0.112.tar.gz"
TOMCAT_HOME="/opt/tomcat"

# Colors define
cl_black="\033[1;30m"
cl_red="\033[1;31m"
cl_green="\033[1;32m"
cl_yellow="\033[1;33m"
cl_blue="\033[1;34m"
cl_purple="\033[1;35m"
cl_cyan="\033[1;36m"
cl_grey="\033[1;37m"
cl_df="\033[0;m"

# writeLog <message> <level>
#   <message> : message to write in log
#   <level>   : success | failed | warn -> to change color
writeLog() {
    if [[ "$2" = "success" ]] then
        /usr/bin/echo -e "[$(date +"%T")] [$cl_green+$cl_df] $1"
    elif [[ "$2" = "failed" ]] then
        /usr/bin/echo -e "[$(date +"%T")] [$cl_red-$cl_df] $1"
    else
        /usr/bin/echo -e "[$(date +"%T")] $cl_yellow/|\\ $cl_df$1"
    fi
}

# checkCmdError <message> <quit>
#   <message> : message to write in log
#   <quit>    : true | false : if failed and true, quit exec
checkCmdError() {
    if [[ "$?" = 0 ]] then
        writeLog "$1" "success"
    else
        writeLog "$1" "failed"
        if [[ "$2" = "true" ]] then
            writeLog "Stop programm" "failed"
            exit 1
        fi
    fi
}

# Stop if not root user
if [[ "$(id -u)" != 0 ]] then
    writeLog "This script need to be executed in root" "warn"
    exit 1
fi

#########################
###                   ###
### Programm Starting ###
###                   ###
#########################
# Update and upgrade OS
writeLog "Start to update and upgrade OS" "success"
/usr/bin/apt-get update -y > /dev/null 2>&1
checkCmdError "Update OS" "true"
/usr/bin/apt-get upgrade -y > /dev/null 2>&1
checkCmdError "Upgrade OS" "true"

# Install package
writeLog "Start install package : default-jdk" "success"
/usr/bin/apt-get install default-jdk -y > /dev/null 2>&1
checkCmdError "default-jdk" "true"

# Create Tomcat user
writeLog "Creation of tomcat user" "success"
/usr/sbin/groupadd tomcat > /dev/null 2>&1
groupCreation="$?"
if [[ "$groupCreation" = 9 ]] then
    writeLog "    Failed to create group tomcat because already exist" "warn"
elif [[ "$groupCreation" = 0 ]] then
    writeLog "    Creation of group tomcat" "success"
else
    writeLog "    Creation of group tomcat" "failed"
    exit 1
fi

/usr/sbin/useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat > /dev/null 2>&1
userCreation="$?"
if [[ "$userCreation" = 9 ]] then
    writeLog "    Failed to create user tomcat because already exist" "warn"
elif [[ "$userCreation" = 0 ]] then
    writeLog "    Creation of user tomcat" "success"
else
    writeLog "    Creation of user tomcat" "failed"
    exit 1
fi

# setup tomcat
writeLog "Install Apache tomcat" "success"
/usr/bin/wget -O /tmp/apache-tomcat9.tar.gz "$TOMCAT_URL" > /dev/null 2>&1
checkCmdError "    Download tomcat sources" "true"
/usr/bin/mkdir -p "$TOMCAT_HOME" > /dev/null 2>&1
checkCmdError "    Create tomcat home directory" "true"
/usr/bin/tar xzf /tmp/apache-tomcat9.tar.gz -C "$TOMCAT_HOME" --strip-components=1 > /dev/null 2>&1
checkCmdError "    Unzip tomcat sources" "true"

/usr/bin/rm -rf /tmp/apache-tomcat9.tar.gz

/usr/bin/chgrp -R tomcat "$TOMCAT_HOME" > /dev/null 2>&1
configError=$(($?))
/usr/bin/chmod -R g+r "$TOMCAT_HOME/conf" > /dev/null 2>&1
configError=$(($configError + $?))
/usr/bin/chmod g+x "$TOMCAT_HOME/conf" > /dev/null 2>&1
configError=$(($configError + $?))
/usr/bin/chown -R tomcat "$TOMCAT_HOME/webapps/" "$TOMCAT_HOME/work/" "$TOMCAT_HOME/temp/" "$TOMCAT_HOME/logs/" > /dev/null 2>&1
configError=$(($configError + $?))

if [[ "$configError" != 0 ]] then
    writeLog "    Failed to configure tomcat sources right" "failed"
    exit 1
else
    writeLog "    Configuration of tomcat sources right" "success"
fi

# create service tomcat
JAVA_HOME=$(update-java-alternatives -l | rev | cut -d " " -f1 | rev)
writeLog "Write tomcat9 service systemv" "success"
cat > /etc/systemd/system/tomcat9.service <<-EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

/usr/bin/systemctl daemon-reload > /dev/null 2>&1
checkCmdError "Actialyse systemctl daemons" "false"
/usr/bin/systemctl enable tomcat9.service > /dev/null 2>&1
checkCmdError "Set tomcat9.service start on poweron" "false"
/usr/bin/systemctl start tomcat9.service > /dev/null 2>&1
checkCmdError "Start tomcat9.service" "false"

#################################
###                           ###
### Installation de guacamole ###
###                           ###
#################################
# Installation de freerdp2 via des fichiers deb
FREERDP_SOURCES="./sources/freerdp2.10-dev"

# libfreerdp-client2-2
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libavutil57/libavutil57_5.1.7-0+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libcodec2-1.0/libcodec2-1.0_1.0.5-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libdav1d6/libdav1d6_1.0.0-2+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libjxl0.7/libjxl0.7_0.7.0-10+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/librav1e0/librav1e0_0.5.1-6_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libsvtav1enc1/libsvtav1enc1_1.4.1+dfsg-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libswresample4/libswresample4_5.1.7-0+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libvpx7/libvpx7_1.12.0-1+deb12u4_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libx265-199/libx265-199_3.5-2+b1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libavcodec59/libavcodec59_5.1.7-0+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libswscale6/libswscale6_5.1.7-0+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libwinpr2-2/libicu72/libicu72_72.1-3+deb12u1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libwinpr2-2/libwinpr2-2_2.10.0+dfsg1-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp2-2/libfreerdp2-2_2.10.0+dfsg1-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-client2-2/libfreerdp-client2-2_2.10.0+dfsg1-1_arm64.deb"
# libfreerdp-server2-2
dpkg -i "$FREERDP_SOURCES/libfreerdp-server2-2/libfreerdp-server2-2_2.10.0+dfsg1-1_arm64.deb"
# libfreerdp-shadow-subsystem2-2
dpkg -i "$FREERDP_SOURCES/libfreerdp-shadow-subsystem2-2/libfreerdp-shadow2-2/libwinpr-tools2-2/libwinpr-tools2-2_2.10.0+dfsg1-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-shadow-subsystem2-2/libfreerdp-shadow2-2/libfreerdp-shadow2-2_2.10.0+dfsg1-1_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libfreerdp-shadow-subsystem2-2/libfreerdp-shadow-subsystem2-2_2.10.0+dfsg1-1_arm64.deb"
# libwinpr2-dev
dpkg -i "$FREERDP_SOURCES/libwinpr2-dev/libssl-dev/libssl3/libssl3_3.0.17-1~deb12u2_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libwinpr2-dev/libssl-dev/libssl-dev_3.0.17-1~deb12u2_arm64.deb"
dpkg -i "$FREERDP_SOURCES/libwinpr2-dev/libwinpr2-dev_2.10.0+dfsg1-1_arm64.deb"
# winpr-utils
dpkg -i "$FREERDP_SOURCES/winpr-utils/winpr-utils_2.10.0+dfsg1-1_arm64.deb"

dpkg -i "$FREERDP_SOURCES/freerdp2-dev_2.10.0+dfsg1-1_arm64.deb"

#######################################################
# Action saved during test
# To finish

wget -O /tmp/guacamole.tar.gz https://downloads.apache.org/guacamole/1.5.5/source/guacamole-server-1.5.5.tar.gz
mkdir -p /etc/guacamole
tar xzf /tmp/guacamole.tar.gz -C /tmp/
mv /tmp/guacamole-server-*/* /etc/guacamole/
apt install -y build-essential libpng-dev libjpeg-dev libcairo2-dev

cd /etc/guacamole
./configure -with-systemd-dir=/etc/systemd/system/

# apt install -y freerdp2-dev libpango1.0-dev libavcodec-dev libavformat-dev libavformat-dev libssh2-1-dev libssl-dev libswscale-dev libtelnet-dev libvncserver-dev libvorbis-dev libpulse-dev libwebsockets-dev libwebp-dev
apt install -y libpango1.0-dev libavcodec-dev libavformat-dev libavformat-dev libssh2-1-dev libssl-dev libswscale-dev libtelnet-dev libvncserver-dev libvorbis-dev libpulse-dev libwebsockets-dev libwebp-dev
./configure -with-systemd-dir=/etc/systemd/system/

sudo apt install build-essential libcairo2-dev libpng-dev      \
                 libtool-bin libossp-uuid-dev libvncserver-dev \
                 libssh2-1-dev libtelnet-dev libwebsockets-dev \
                 libpulse-dev libvorbis-dev libwebp-dev        \
                 libssl-dev libpango1.0-dev libswscale-dev     \
                 libavcodec-dev libavutil-dev libavformat-dev

### freerdp2-dev
# https://debian.pkgs.org/12/debian-main-arm64/freerdp2-dev_2.10.0+dfsg1-1_arm64.deb.html
# libfreerdp-client2-2
#     libfreerdp2-2
#         libavcodec59
#             libavutil57
#             libcodec2-1.0
#             libdav1d6
#             libjxl0.7
#             librav1e0
#             libsvtav1enc1
#             libswresample4
#             libvpx7
#             libx265-199
#         libswscale6
#         libwinpr2-2
#             libicu72
# libfreerdp-server2-2
# libfreerdp-shadow-subsystem2-2
#     libfreerdp-shadow2-2
#         libwinpr-tools2-2
# libwinpr2-dev
#     libssl-dev
#         libssl3
# winpr-utils








### freerdp2-dev
# https://debian.pkgs.org/11/debian-main-arm64/freerdp2-dev_2.3.0+dfsg1-2+deb11u1_arm64.deb.html
with source .deb:
    libfreerdp2-2
        libavcodec58
            libaom0
            libavutil56
            libcodec2-0.9
            libdav1d4
            libswresample3
            libvpx6
            libwebp6
            libx264-160
            libx265-192
        libssl1.1
        libswscale5
        libwinpr2-2
            libicu67
    libfreerdp-client2-2
    libfreerdp-server2-2
    libfreerdp-shadow2-2
        libwinpr-tools2-2
    libfreerdp-shadow-subsystem2-2
    libwinpr2-dev
    winpr-utils

# wsock32
with source .deb:


