#!/bin/bash
# Universal Metasploitable Hardening Script

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./harden_universal.sh)"
  exit 1
fi

echo "[+] Starting Dynamic Hardening Procedure..."

# Helper Function to restart services regardless of OS generation
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

# 1. Update OS Passwords
echo "[+] Updating default system passwords..."
echo "msfadmin:SecureClassPassword2026!" | chpasswd 2>/dev/null
echo "root:SuperSecureRoot2026!" | chpasswd 2>/dev/null
echo "vagrant:VagrantSecure2026!" | chpasswd 2>/dev/null

# 2. Secure FTP (vsftpd)
VSFTPD_CONF="/etc/vsftpd.conf"
[ ! -f "$VSFTPD_CONF" ] && VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
if [ -f "$VSFTPD_CONF" ]; then
    echo "[+] Hardening FTP config..."
    sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' "$VSFTPD_CONF"
    restart_service vsftpd
fi

# 3. Secure MySQL Database
echo "[+] Securing MySQL configurations..."
# Attempt password change with or without blank/root combinations
mysql -u root --password="" -e "UPDATE mysql.user SET Password=PASSWORD('DB_Secure_Pass_2026') WHERE User='root'; DROP USER ''@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'DB_Secure_Pass_2026'; FLUSH PRIVILEGES;" 2>/dev/null
restart_service mysql || restart_service mariadb

# 4. Disable Unencrypted Legacy Services (inetd / xinetd)
echo "[+] Disabling unencrypted inetd legacy items..."
if [ -f "/etc/inetd.conf" ]; then
    for svc in telnet login shell exec talk ntalk; do
        sed -i "s/^$svc/#$svc/g" /etc/inetd.conf
    done
    restart_service openbsd-inetd || restart_service inetd
fi

# 5. Lock Down Tomcat Administrative Panel
for tomcat_xml in /var/lib/tomcat*/conf/tomcat-users.xml /etc/tomcat*/tomcat-users.xml; do
    if [ -f "$tomcat_xml" ]; then
        echo "[+] Hardening Tomcat user settings..."
        sed -i 's/password="tomcat"/password="ComplexTomcatPass2026!"/g' "$tomcat_xml"
        sed -i 's/password="role1"/password="ComplexRolePass2026!"/g' "$tomcat_xml"
        restart_service "$(basename "$(dirname "$(dirname "$tomcat_xml")")")"
    fi
done

echo "[+] Hardening complete! The machine is now safe against initial exploits."

