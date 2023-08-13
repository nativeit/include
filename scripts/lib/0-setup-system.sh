#! /bin/bash
# rev 2022-06-19 by sdavis@nativeit.net
#
# (c) 2022 by Native IT [ https://www.nativeit.net ]
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# * The name Native IT and the names of its contributors may not be
# used to endorse or promote products derived from this software without specific prior
# written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
# SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#

source /tmp/lib-bash-utils.sh
source /tmp/lib-system-utils.sh
source /tmp/lib-system-debian.sh

echo "###################################################################################"
echo "Please be Patient: Installation will start now....... It may take some time :)"
echo "###################################################################################"

###########################################################
# Updating system & software
###########################################################
	# Configure APT
		system_enable_extended_sources
		apt-get update && apt-get -y upgrade

	# Install package manager
		apt-get install -y aptitude

	# Set time zone
		timedatectl set-timezone "America/New_York"

	# Configure time sync
		system_configure_ntp

###########################################################
# Init + prerequisites
###########################################################
	# Install required packages
		aptitude install -y sudo qemu-guest-agent openssh-server
	
	# Setup git + versioning for /etc
		system_install_git
		system_start_etc_dir_versioning

		system_record_etc_dir_changes "Initialize /etc versioning"

	# Add SSH user group 
		groupadd sshusers

		system_record_etc_dir_changes "Added sshusers group"

###########################################################
# Script setup
###########################################################
	# Get username
		system_default_user_name 1000
		DEFAULT_USER_NAME=`grep "^." ./default_user.txt`
		
		echo -en "Username? [ "${DEFAULT_USER_NAME}" ]"
		read user_name
		if [ -z "$user_name" ]; then
  			user_name=${DEFAULT_USER_NAME}
		fi
		
		export user_name=${user_name}
		echo "Username is set to : ${user_name} "



	# Get SSH port number
		echo -en "SSH port number? [ 22 ] "
		read ssh_port
		echo "SSH port is set to : ${ssh_port:=22} "

		system_record_etc_dir_changes "SSH Port is set to : ${ssh_port:=22} "

	# Get user's SSH public key, or generate a new key pair
		echo -en "SSH public key? "
		read ssh_key
		if [ -z "$ssh_key" ]; then
  			ssh-keygen -t rsa -f ./id_rsa -b 2048  -C "${user_name}@${HOSTNAME}"
  			ssh_key=`grep "^." ./id_rsa.pub`
		fi
		echo "SSH key has been set to : ${ssh_key} "

		system_record_etc_dir_changes "SSH public key for ${user_name} has been set to : ${ssh_key} "

	# Get user's preferred default login shell (zsh or bash)
		echo -en "Default login shell? [ /bin/bash ] "
		read user_shell
		if [ -z "$user_shell" ]; then
  			user_shell="/bin/bash"
		fi
		echo "Your login shell is set to : ${user_shell:-/bin/bash}"

		system_record_etc_dir_changes "Login shell for ${user_name} is set to : ${user_shell:-/bin/bash}"

		system_record_etc_dir_changes "User preferences have been set for ${user_name}"

###########################################################
# Install add'l packages
###########################################################

	# Choose software package sets
		system_select_packages
		pkg_select=`grep "^." ./pkg_install.tmp`
		
		if [ ${pkg_select} = "essentials" ]; then
			system_install_essentials

			system_record_etc_dir_changes "Add'l packages installed: essentials only. "

		elif  [ ${pkg_select} = "sysadmins" ]; then
			system_install_essentials
			system_install_sysadmin

			system_record_etc_dir_changes "Add'l packages installed: essentials + sysadmin. "

		elif  [ ${pkg_select} = "developers" ]; then
			system_install_essentials
			system_install_devtools

			system_record_etc_dir_changes "Add'l packages installed: essentials + dev tools. "

		elif  [ ${pkg_select} = "kitchensink" ]; then
			system_install_essentials
			system_install_sysadmin
			system_install_devtools

			system_record_etc_dir_changes "Add'l packages installed: everything. "

		fi
		echo "Additional packages have finished installing! "


###########################################################
# Setup login shell & user profile
###########################################################
	# Install ZSH if selected during setup
		if [ ${user_shell} = "/bin/zsh" ]; then
			aptitude install -y zplug zsh zsh zsh-autosuggestions zsh-syntax-highlighting zsh-theme-powerlevel9k
			usermod -s /bin/zsh ${user_name}

			system_record_etc_dir_changes "Installed ZSH login shell for ${user_name}."
		fi

	# Setup BASH user profile
		if [ ${user_shell} = "/bin/bash" ]; then
			system_pimp_user_profiles ${user_name}
		fi

	# Setup user profile
		usermod -aG sudo ${user_name}
		usermod -aG sshusers ${user_name}
		system_configure_sshd ${ssh_key} ${ssh_port} ${user_name}
		system_passwordless_sudo ${user_name}
		
		system_record_etc_dir_changes "Configured user profile and settings for ${user_name}."

###########################################################
# Secure system
###########################################################

	# Get email address for system admin, install Logcheck + Logcheck database
    system_security_logcheck

    system_record_etc_dir_changes "Installed logcheck, configured to send alerts to ${admin_email} ."


	# Configure UFW
	echo -en "Choose basic or advanced UFW configuration? [ basic ]"
	read ufw_config_type
	if [ -z "$ufw_config_type" ]; then
  		ufw_config_type=basic
	fi
		echo "UFW will be configured with : ${ufw_config_type:-basic} defaults"
	if [ $ufw_config_type = "advanced" ]; then
		system_security_ufw_configure_advanced
	else
		system_security_ufw_install
	fi

	# Setup Fail2Ban
	system_security_fail2ban

	system_record_etc_dir_changes "Installed and configured Fail2Ban"

	# Setup automatic security updates
	automatic_security_updates
	system_record_etc_dir_changes "Configured automatic security updates for Debian-based systems"

	ssh_disable_root


###########################################################
# Wrap up
###########################################################

	# Restart upstart services that have a file in /tmp/needs-restart/
	restart_services
	restart_initd_services

	# Misc.
	goodstuff
	all_set
