#!/bin/bash
#
# Debian compatible version of System related utilities -- https://www.linode.com/stackscripts/view/124
#
# Derived originally from https://cloud.linode.com/stackscripts/10446
#
#

function lower {
    # helper function
    echo $1 | tr '[:upper:]' '[:lower:]'
}

function rand-str {
    # Return random alpha-numeric string of given LENGTH
    #
    # Usage: VALUE=$(rand-str $LENGTH)
    #    or: VALUE=$(rand-str)

    local DEFAULT_LENGTH=64
    local LENGTH=${1:-$DEFAULT_LENGTH}

    LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c $LENGTH
    # LC_ALL=C: required for Mac OS X - https://unix.stackexchange.com/a/363194/403075
    # -dc: delete complementary set == delete all except given set
}

function system_select_packages() {    

echo -e "
Select your preferred software package(s)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
| 1.) Just the essentials               |
| 2.) Add'l packages for system admins  |
| 3.) Add'l packages for developers     |
| 4.) All of the above                  |
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#\n"

read -e -p "Select 1-4: " choice

if [ "$choice" == "1" ]; then

    pkg_install=essentials

elif [ "$choice" == "2" ]; then

    pkg_install=sysadmins

elif [ "$choice" == "3" ]; then

    pkg_install=developers
    
elif [ "$choice" == "4" ]; then

    pkg_install=kitchensink

else

    echo "Please select 1-4" && sleep 3
    clear && system_select_packages

fi
    echo "${pkg_install}" >> /tmp/pkg_install.tmp

}

function ssh_keygen {
    # ssh_keygen(key_filename, key_comment)
    if [[ $1 && $2 ]]; then
            ssh-keygen -t rsa -f /tmp/$1 -b 2048  -C "$2"
        else
            echo 'Usage: ./keygen.sh filename-for-key comment-for-key';
    fi
}

function system_update_locale_en_US_UTF_8 {
    # locale-gen en_US.UTF-8
    dpkg-reconfigure -f noninteractive locales
    update-locale LANG=en_US.UTF-8
}

function system_update_hostname {
    # system_update_hostname(system hostname)
    if [ -z "$1" ]; then
        echo "system_update_hostname() requires the system hostname as its first argument"
        return 1;
    fi
    echo $1 > /etc/hostname
    hostname -F /etc/hostname
    echo -e "\n127.0.0.1 $1 $1.local\n" >> /etc/hosts
}

function system_update_hosts {
    # $1 - The IP address to set a hosts entry for
    # $2 - The fqdn to set to the IP
    local -r ip_address="$1" fqdn="$2"
    [ -z "$ip_address" -o -z "$fqdn" ] && {
        printf "IP address and/or fqdn undefined in system_add_host_entry()\n"
        return 1;
    }
    echo "$ip_address $fqdn" >> /etc/hosts
}

function system_get_codename {
    echo `lsb_release -sc`
}

function system_get_release {
    echo `lsb_release -sr`
}

function system_enable_extended_sources {
     mv /etc/apt/sources.list /etc/apt/sources.list_bak
     echo "deb http://httpredir.debian.org/debian buster main non-free contrib" > /etc/apt/sources.list
     echo "deb-src http://httpredir.debian.org/debian buster main non-free contrib" >> /etc/apt/sources.list
     echo -e "\ndeb http://security.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list
     echo -e "deb-src http://security.debian.org/debian-security buster/updates main contrib non-free\n" >> /etc/apt/sources.list
    apt-get update
}

function system_install_essentials {
    DEBIAN_FRONTEND=noninteractive aptitude install -y apt-show-versions apt-transport-https ca-certificates curl gnupg2 net-tools software-properties-common ufw wget2 zip
}

function system_install_sysadmin {
    DEBIAN_FRONTEND=noninteractive aptitude install -y ack bsd-mailx certbot fonts-powerline htop iftop iotop libapt-pkg-perl libauthen-pam-perl libio-pty-perl libnet-ssleay-perl lshw psmisc python rsync screenfetch ssh-tools tree
}

function system_install_devtools {
    DEBIAN_FRONTEND=noninteractive aptitude install -y autoconf automake build-essential colormake default-jre-headless gdb git libffi-dev zlib1g-dev libssl-dev nodejs npm python3 
}

function system_add_user {
    # system_add_user(username, password, groups, shell=/bin/bash)
    USERNAME=`lower $1`
    PASSWORD=$2
    SUDO_GROUP=$3
    SHELL=$4
    if [ -z "$4" ]; then
        SHELL="/bin/bash"
    fi
    useradd --create-home --shell "$SHELL" --user-group --groups "$SUDO_GROUP" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
}

function system_add_system_user {
    # system_add_system_user(username, home, shell=/bin/bash)
    USERNAME=`lower "$1"`
    HOME_DIR=$2
    SHELL=$3
    if [ -z "$3" ]; then
        SHELL="/bin/bash"
    fi
    useradd --system --create-home --home-dir "$HOME_DIR" --shell "$SHELL" --user-group $USERNAME
}

function system_lock_user {
    # system_lock_user(username)
    passwd -l "$1"
}

function system_default_user_name {
    # system_default_user_name(1000)
    if [ -z "$1" ]; then
    cat /etc/passwd | grep "1000:" | cut --delimiter=":" -f1 >> ./default_user.txt
    fi
    cat /etc/passwd | grep "$1:" | cut --delimiter=":" -f1 >> ./default_user.txt
}

function system_get_admin_email {
    # Get email for sys admin
    
    echo -en "Provide an email address for receiving system monitoring events: "
    read admin_email
    if [ -z "${admin_email}" ]; then
    echo "Please provide a valid email address" && sleep 3
    else
    echo "Admin email set to ${admin_email} "
    clear && system_get_admin_email
    fi
}

function system_get_admin_ip {
    # Get IP address for sys admin to add to fail2ban ignore list
    
    echo -en "What is your local public IP address? Visit https://ipinfo.io/ip if unsure. "
    read admin_ip
    if [ -z "${admin_ip}" ]; then
    echo "Admin ip set to ${admin_ip} "
    else
    echo "Please provide a valid IP address" && sleep 3
    clear && system_get_admin_ip
    fi
}

function system_get_user_home {
    # system_get_user_home(username)
    cat /etc/passwd | grep "^$1:" | cut --delimiter=":" -f6
}

function system_pimp_user_profiles {
    # system_pimp_user_profiles(username)
    USERNAME=`lower $1`
    USER_HOME=`system_get_user_home "$USERNAME"`
    mv /etc/bash.bashrc /etc/bash.bashrc_bak
    wget -O /etc/bash.bashrc https://raw.githubusercontent.com/nativeit/nixprofile/main/bash.bashrc
    wget -O /etc/DIR_COLORS https://raw.githubusercontent.com/nativeit/nixprofile/main/DIR_COLORS
    DEBIAN_FRONTEND=noninteractive apt-get -y install fonts-powerline screenfetch
    echo -e "\n# Display ASCII informational logo at login\nscreenfetch\n" >> /$USER_HOME/.bashrc
}

function system_user_add_ssh_key {
    # system_user_add_ssh_key(username, ssh_key)
    USERNAME=`lower $1`
    USER_HOME=`system_get_user_home "$USERNAME"`
    sudo -u "$USERNAME" mkdir "$USER_HOME/.ssh"
    sudo -u "$USERNAME" touch "$USER_HOME/.ssh/authorized_keys"
    sudo -u "$USERNAME" echo "$2" >> "$USER_HOME/.ssh/authorized_keys"
    chmod 0600 "$USER_HOME/.ssh/authorized_keys"
}

function system_configure_sshd {
    # system_configure_sshd(sshkey, sshport, username)
    USERNAME=`lower $3`
    USER_HOME=`system_get_user_home "$USERNAME"`
    touch /etc/ssh/sshd_config.tmp
    if [ -z "$1" ]; then
        echo "PubkeyAuthentication no" >> /etc/ssh/sshd_config.tmp
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.tmp
    else
        sudo -u "$USERNAME" mkdir "$USER_HOME/.ssh"
        sudo -u "$USERNAME" touch "$USER_HOME/.ssh/authorized_keys"
        sudo -u "$USERNAME" echo "$1" >> "$USER_HOME/.ssh/authorized_keys"
        chmod 0600 "$USER_HOME/.ssh/authorized_keys"
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config.tmp
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.tmp
    fi
    if [ -z "$2" ]; then
        SSHD_PORT=22
        echo "Port $SSHD_PORT" >> /etc/ssh/sshd_config.tmp
    else
        SSHD_PORT=$2
        echo "Port $SSHD_PORT" >> /etc/ssh/sshd_config.tmp
    fi
    sed -n 's/\(HostKey .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(UsePrivilegeSeparation .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(KeyRegenerationInterval .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(ServerKeyBits .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(SyslogFacility .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(LogLevel .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(LoginGraceTime .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(StrictModes .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(RSAAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(IgnoreRhosts .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(RhostsRSAAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(HostbasedAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(PermitEmptyPasswords .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(ChallengeResponseAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(X11Forwarding .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(X11DisplayOffset .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(PrintMotd .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(PrintLastLog .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(TCPKeepAlive .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(MaxStartups .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(AcceptEnv .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(Subsystem .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    sed -n 's/\(UsePAM .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
    echo "AllowGroups `echo sshusers | tr '[:upper:]' '[:lower:]'`" >> /etc/ssh/sshd_config.tmp

    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
    chmod 0600 /etc/ssh/sshd_config.tmp
    cp /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
    touch /tmp/restart-sshd
}

function system_sshd_edit_bool {
    # system_sshd_edit_bool (param_name, "Yes"|"No")
    VALUE=`lower $2`
    if [ "$VALUE" == "yes" ] || [ "$VALUE" == "no" ]; then
        sed -i "s/^#*\($1\).*/\1 $VALUE/" /etc/ssh/sshd_config
    fi
}

function system_sshd_permitrootlogin {
    # system_sshd_permitrootlogin(param_name, "Yes"|"No")
    system_sshd_edit_bool "PermitRootLogin" "$1"
}

function system_sshd_passwordauthentication {
    system_sshd_edit_bool "PasswordAuthentication" "$1"
}

function system_sshd_pubkeyauthentication {
    system_sshd_edit_bool "PubkeyAuthentication" "$1"
}

function system_passwordless_sudo {
    # system_passwordless_sudo(username)
    SUDO_USER=`lower $1`
    cp /etc/sudoers /etc/sudoers.tmp
    chmod 0640 /etc/sudoers.tmp
    echo "${SUDO_USER} ALL = NOPASSWD: ALL" >> /etc/sudoers.tmp
    mv /etc/sudoers /etc/sudoers.orig  
    mv /etc/sudoers.tmp /etc/sudoers

}

function system_security_logcheck {
    # Get admin email address
    system_get_admin_email
    
    # Install logcheck
    DEBIAN_FRONTEND=noninteractive apt-get -y install logcheck logcheck-database
    
    # Configure logcheck.conf
    touch /etc/logcheck/logcheck.tmp
    sed -n 's/\(REPORTLEVEL .*\)/\1/p' < /etc/logcheck/logcheck.conf >> /etc/logcheck/logcheck.tmp
    echo "SENDMAILTO=${admin_email}" >> /etc/logcheck/logcheck.tmp
    sed -n 's/\(MAILASATTACH .*\)/\1/p' < /etc/logcheck/logcheck.conf >> /etc/logcheck/logcheck.tmp
    sed -n 's/\(FQDN .*\)/\1/p' < /etc/logcheck/logcheck.conf >> /etc/logcheck/logcheck.tmp
    sed -n 's/\(TMP .*\)/\1/p' < /etc/logcheck/logcheck.conf >> /etc/logcheck/logcheck.tmp
    
    mv /etc/logcheck/logcheck.conf /etc/logcheck/logcheck.orig
    cp /etc/logcheck/logcheck.tmp /etc/logcheck/logcheck.conf
    touch /tmp/restart-logcheck
}

function system_security_fail2ban {
    # Get ignore IP address
    system_get_admin_ip
    
    # Install and configure fail2ban
    DEBIAN_FRONTEND=noninteractive apt-get -y install fail2ban
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    
    # Add user's local IP to ignore
    fail2ban-client set JAIL addignoreip ${admin_ip}
}

function system_security_ufw_install {
    DEBIAN_FRONTEND=noninteractive apt-get -y install ufw
    ufw logging on

    ufw default allow outgoing
    ufw default deny incoming

    ufw allow ssh/tcp
    ufw limit ssh/tcp

    ufw allow http/tcp
    ufw allow https/tcp

    ufw enable
    ufw logging off
    systemctl enable ufw
}

function system_security_ufw_configure_advanced {
    ufw allow 53,80,443,996,2377,3000,4222,4789,7946/tcp
    ufw allow 53,7946,4789,2377/udp
    ufw allow 4242/tcp
    ufw allow 9000/tcp
    ufw reload
}

function restart_services {
    # restarts upstart services that have a file in /tmp/needs-restart/
    for service_name in $(ls /tmp/ | grep restart-* | cut -d- -f2-10); do
        systemctl restart $service_name
        rm -f /tmp/restart-$service_name
    done
}

function restart_initd_services {
    # restarts upstart services that have a file in /tmp/needs-restart/
    for service_name in $(ls /tmp/ | grep restart_initd-* | cut -d- -f2-10); do
        /etc/init.d/$service_name restart
        rm -f /tmp/restart_initd-$service_name
    done
}
