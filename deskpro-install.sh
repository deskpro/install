#!/bin/bash

set -o errexit -o noclobber -o nounset -o pipefail

# info parsed by getopt
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
	local params=$(getopt -o 'hq' -l 'help,quiet' --name "$0" -- "$@")
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

check_memory() {
	if [ $ARG_QUIET -ne 0 ]; then
		return
	fi

	local total_mem=$(awk '/^MemTotal/ { print $2 }' /proc/meminfo)

	if [ "$total_mem" -lt 1000000 ]; then
		cat <<-EOT
			This DeskPRO install requires at least 1GB of memory to
			work properly. Installation on less than 1GB of memory is
			not supported and may fail for many different reasons.
		EOT
	fi
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
	check_memory
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
