#!/bin/bash
# Universal Metasploitable Vulnerability Restoration Script

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./unharden_universal.sh)"
  exit 1
fi

echo "[-] Commencing Vulnerability Rollback Procedure..."

restart_service() {
    local service_name=$1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart "$service_name" 2>/dev/null
    elif command -v service >/dev/null 2>&1; then
        service "$service_name" restart 2>/dev/null
    elif [ -x "/etc/init.d/$service_name" ]; then
        "/etc/init.d/$service_name" restart 2>/dev/null
    fi
}

# 1. Restore Default Weak OS Passwords
echo "[-] Reverting system account passwords..."
echo "msfadmin:msfadmin" | chpasswd 2>/dev/null
echo "root:root" | chpasswd 2>/dev/null
echo "vagrant:vagrant" | chpasswd 2>/dev/null

# 2. Re-enable Anonymous FTP
VSFTPD_CONF="/etc/vsftpd.conf"
[ ! -f "$VSFTPD_CONF" ] && VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
if [ -f "$VSFTPD_CONF" ]; then
    echo "[-] Exposing FTP configurations..."
    sed -i 's/anonymous_enable=NO/anonymous_enable=YES/g' "$VSFTPD_CONF"
    restart_service vsftpd
fi

# 3. Strip MySQL Database Security
echo "[-] Clearing database root administrative passwords..."
mysql -u root -p'DB_Secure_Pass_2026' -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -p'DB_Secure_Pass_2026' -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null
restart_service mysql || restart_service mariadb

# 4. Open Legacy Network Services
echo "[-] Exposing unencrypted communication utilities..."
if [ -f "/etc/inetd.conf" ]; then
    for svc in telnet login shell exec talk ntalk; do
        sed -i "s/^#$svc/$svc/g" /etc/inetd.conf
    done
    restart_service openbsd-inetd || restart_service inetd
fi

# 5. Restore Default Weak Tomcat Credentials
for tomcat_xml in /var/lib/tomcat*/conf/tomcat-users.xml /etc/tomcat*/tomcat-users.xml; do
    if [ -f "$tomcat_xml" ]; then
        echo "[-] Restoring default weak Tomcat manager configs..."
        sed -i 's/password="ComplexTomcatPass2026!"/password="tomcat"/g' "$tomcat_xml"
        sed -i 's/password="ComplexRolePass2026!"/password="role1"/g' "$tomcat_xml"
        restart_service "$(basename "$(dirname "$(dirname "$tomcat_xml")")")"
    fi
done

echo "[-] Rollback complete! The machine configuration is fully vulnerable again."

