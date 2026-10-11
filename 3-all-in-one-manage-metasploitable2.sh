#!/bin/bash
# ==============================================================================
# Universal Metasploitable Configuration Master Script
# Usage: sudo ./manage_lab.sh --harden   (Secures the configuration)
#        sudo ./manage_lab.sh --vulnerable (Restores all original flaws)
# ==============================================================================

# Ensure the script is run with administrative privileges
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run this master script as root (e.g., sudo $0)"
  exit 1
fi

# Helper Function: Detects the OS initialization engine dynamically to restart services safely
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

# Core Logic: Hardening Routine
harden_machine() {
    echo "[+] Executing Version-Agnostic Hardening Procedure..."

    # 1. Update OS Passwords
    echo "[+] Updating default system passwords to secure complex strings..."
    echo "msfadmin:SecureClassPassword2026!" | chpasswd 2>/dev/null
    echo "root:SuperSecureRoot2026!" | chpasswd 2>/dev/null
    echo "vagrant:VagrantSecure2026!" | chpasswd 2>/dev/null

    # 2. Secure FTP (vsftpd)
    VSFTPD_CONF="/etc/vsftpd.conf"
    [ ! -f "$VSFTPD_CONF" ] && VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
    if [ -f "$VSFTPD_CONF" ]; then
        echo "[+] Disabling Anonymous FTP access..."
        sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' "$VSFTPD_CONF"
        restart_service vsftpd
    fi

    # 3. Secure MySQL/MariaDB
    echo "[+] Securing MySQL database default root privileges..."
    mysql -u root --password="" -e "UPDATE mysql.user SET Password=PASSWORD('DB_Secure_Pass_2026') WHERE User='root'; DROP USER ''@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null || \
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'DB_Secure_Pass_2026'; FLUSH PRIVILEGES;" 2>/dev/null
    restart_service mysql || restart_service mariadb

    # 4. Disable Unencrypted Legacy Services (inetd / xinetd)
    if [ -f "/etc/inetd.conf" ]; then
        echo "[+] Disabling legacy unencrypted services (Telnet/Rsh/Shell)..."
        for svc in telnet login shell exec talk ntalk; do
            sed -i "s/^$svc/#$svc/g" /etc/inetd.conf
        done
        restart_service openbsd-inetd || restart_service inetd
    fi

    # 5. Lock Down Tomcat Administrative Panel
    for tomcat_xml in /var/lib/tomcat*/conf/tomcat-users.xml /etc/tomcat*/tomcat-users.xml; do
        if [ -f "$tomcat_xml" ]; then
            echo "[+] Hardening Apache Tomcat administrative deployment credentials..."
            sed -i 's/password="tomcat"/password="ComplexTomcatPass2026!"/g' "$tomcat_xml"
            sed -i 's/password="role1"/password="ComplexRolePass2026!"/g' "$tomcat_xml"
            restart_service "$(basename "$(dirname "$(dirname "$tomcat_xml")")")"
        fi
    done

    echo "[+] Configuration Hardening Completed! Run a scan to verify."
}

# Core Logic: Reversion Routine
expose_machine() {
    echo "[-] Executing Vulnerability Restoration Procedure..."

    # 1. Restore Default Weak OS Passwords
    echo "[-] Resetting system passwords back to well-known defaults..."
    echo "msfadmin:msfadmin" | chpasswd 2>/dev/null
    echo "root:root" | chpasswd 2>/dev/null
    echo "vagrant:vagrant" | chpasswd 2>/dev/null

    # 2. Re-enable Anonymous FTP
    VSFTPD_CONF="/etc/vsftpd.conf"
    [ ! -f "$VSFTPD_CONF" ] && VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
    if [ -f "$VSFTPD_CONF" ]; then
        echo "[-] Re-enabling Anonymous FTP server access configurations..."
        sed -i 's/anonymous_enable=NO/anonymous_enable=YES/g' "$VSFTPD_CONF"
        restart_service vsftpd
    fi

    # 3. Strip MySQL Database Security
    echo "[-] Stripping MySQL root password security protections..."
    mysql -u root -p'DB_Secure_Pass_2026' -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
    mysql -u root -p'DB_Secure_Pass_2026' -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; FLUSH PRIVILEGES;" 2>/dev/null || \
    mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null
    restart_service mysql || restart_service mariadb

    # 4. Open Legacy Network Services
    if [ -f "/etc/inetd.conf" ]; then
        echo "[-] Restoring unencrypted daemon components (Telnet/Rsh)..."
        for svc in telnet login shell exec talk ntalk; do
            sed -i "s/^#$svc/$svc/g" /etc/inetd.conf
        done
        restart_service openbsd-inetd || restart_service inetd
    fi

    # 5. Restore Default Weak Tomcat Credentials
    for tomcat_xml in /var/lib/tomcat*/conf/tomcat-users.xml /etc/tomcat*/tomcat-users.xml; do
        if [ -f "$tomcat_xml" ]; then
            echo "[-] Restoring weak factory default tomcat panel authentication settings..."
            sed -i 's/password="ComplexTomcatPass2026!"/password="tomcat"/g' "$tomcat_xml"
            sed -i 's/password="ComplexRolePass2026!"/password="role1"/g' "$tomcat_xml"
            restart_service "$(basename "$(dirname "$(dirname "$tomcat_xml")")")"
        fi
    done

    echo "[-] Vulnerability Reset Complete! The environment is fully insecure again."
}

# Parameter Parsing Switch
case "$1" in
    --harden)
        harden_machine
        ;;
    --vulnerable)
        expose_machine
        ;;
    *)
        echo "[-] Error: Invalid or missing argument."
        echo "Usage: sudo $0 [--harden | --vulnerable]"
        exit 1
        ;;
esac

