#!/bin/bash

set -o errexit -o noclobber -o nounset -o pipefail

# info parsed by getopt
ARG_UNATTENDED=0
ARG_QUIET=0

# data needed by the script
DATA_ANSIBLE_DIR=''

info_message() {
	local no_newline=''

	if [ "$1" == "-n" ]; then
		no_newline="-n"
		shift
	fi

	if [ $ARG_QUIET -eq 0 ]; then
		echo $no_newline $1
	fi
}

parse_args() {
	local params=$(getopt -o 'hqu' -l 'help,quiet,unattended' --name "$0" -- "$@")
	eval set -- "$params"

	while true; do
		case "$1" in
			-h|--help)
				show_usage
				exit 0
				;;
			-q|--quiet)
				ARG_QUIET=1
				shift
				;;
			-u|--unattended)
				ARG_UNATTENDED=1
				shift
				;;
			--)
				shift
				break
				;;
			*)
				echo "Unknown argument: $1"
				exit 1
		esac
	done
}

show_usage() {
	cat <<EOT
Usage: $0 [OPTIONS]

Options:
  -h, --help            Show usage (this message)
  -q, --quiet           Show less text during the install
  -u, --unattended      Perform an unattended install. No questions
                        will be asked.
EOT
}

question_confirm() {
	while true; do
		read -p "$1 (yes/no) " yesno
		case $yesno in
			yes)
				break
				;;
			no)
				exit 1
				;;
			*)
				echo 'Please answer yes or no'
				;;
		esac
	done
}

install_ansible_debian() {
	info_message -n 'Installing ansible... '
	(
		sudo apt-get update
		sudo apt-get install -y ansible
	) >/dev/null 2>&1
	info_message 'Done'
}

install_ansible_ubuntu() {
	info_message -n 'Installing ansible... '
	(
		sudo apt-get update
		sudo apt-get install -y software-properties-common
		sudo apt-add-repository -y ppa:ansible/ansible
		sudo apt-get update
		sudo apt-get install -y ansible
	) >/dev/null 2>&1
	info_message 'Done'
}

install_ansible_fedora() {
	echo 'Fedora is not supported by this script yet'
	exit 1
}

install_ansible_centos() {
	info_message -n 'Installing ansible... '
	(
		sudo yum install -y epel-release
		sudo yum install -y ansible
	) >/dev/null 2>&1
	info_message 'Done'
}

install_ansible_rhel() {
	echo 'RHEL is not supported by this script yet'
	exit 1
}

detect_repository() {
	local current_dir=$(dirname $0)
	DATA_ANSIBLE_DIR=$current_dir/ansible

	if [ ! -e $DATA_ANSIBLE_DIR ]; then
		local tmp_dir=$(mktemp -dt dpbuild-XXXXXXXX)

		info_message -n 'Downloading ansible scripts... '

		cd $tmp_dir
		curl -s -L https://github.com/DeskPRO/install/archive/master.tar.gz | tar xz

		info_message 'Done'

		DATA_ANSIBLE_DIR=$tmp_dir/install-master/ansible
	fi
}

detect_distro() {
	if [ -e /etc/os-release ]; then
		. /etc/os-release

		case $ID in
			fedora)
				install_ansible_fedora
				;;
			centos)
				install_ansible_centos
				;;
			rhel)
				install_ansible_rhel
				;;
			ubuntu)
				install_ansible_ubuntu
				;;
			debian)
				install_ansible_debian
				;;
			*)
				echo 'Unknown Linux distribution'
				exit 1
		esac
	elif [ -e /etc/redhat-release ]; then
		install_ansible_rhel
	elif [ -e /etc/debian_version ]; then
		install_ansible_debian
	else
		echo 'Unknown Linux distribution'
		exit 1
	fi
}

explain_install() {
	if [ $ARG_UNATTENDED -eq 1 ]; then
		return 0
	fi

	cat <<'EOF'
Hi there,

This script will install DeskPRO on this very server. Here's a
rough guide to what will happen during the install:

    * Ansible playbooks will be downloaded
    * We'll install repositories for software not usually bundled
      with your distribution
    * Your system will be upgraded
    * A user named `deskpro` will be created
    * We'll install ansible, nginx, MariaDB, PHP, and Elasticsearch
      (and configure all that)
    * Set up your firewall to allow only ports 22, 80, 443 in
    * Download and install DeskPRO itself
    * Set up a couple cron jobs

You can check the sources for what is really happening at this
address:

    https://github.com/DeskPRO/install

EOF

	if [ "$(id -u)" != "0" ]; then
		cat <<-'EOT'
		Some commands will need to run as root. You'll be prompted for
		the sudo password at the right time. If you do not want to be
		prompted, download this script instead and run it with:
		    
		    sudo bash deskpro-install.sh

		EOT
	fi

	question_confirm "Would you like to continue with the installation?"
}

install_deskpro() {
	cd $DATA_ANSIBLE_DIR

	info_message -n 'Installing role dependencies... '
	ansible-galaxy install -r requirements.txt -i -p roles >/dev/null 2>&1
	info_message 'Done'

	sudo ansible-playbook -i 127.0.0.1, full-install.yml
}

main() {
	parse_args "$@"
	explain_install
	detect_repository
	detect_distro
	install_deskpro

	if [ $ARG_QUIET -eq 0 ]; then
		local ip=$(curl -s https://api.ipify.org)

		cat <<-EOT
			All done! To start using your instance, point your browser
			to the following address and follow the instructions on the
			screen:

			    http://$ip/

		EOT
	fi
}

main "$@"
