#!/bin/bash

set -o errexit -o errtrace -o noclobber -o nounset -o pipefail

# info parsed by getopt
ARG_QUIET=0

# data needed by the script
ANSIBLE_DIR=''
SUDO=''
UNBUFFER='stdbuf -i0 -o0 -e0'
MYSQL_PASS=''
FULL_LOG_FILE=''
SUCCESS=false
DISTRO='Unknown'

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
	local params=$(getopt -o 'hl:q' -l 'help,log:,quiet' --name "$0" -- "$@")
	eval set -- "$params"

	while true; do
		case "$1" in
			-h|--help)
				show_usage
				exit 0
				;;
			-l|--log)
				FULL_LOG_FILE="$1"
				shift 2
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

	if [ -z "$FULL_LOG_FILE" ]; then
		local log_file=$(mktemp -t install-XXXXXXXX.log)
		FULL_LOG_FILE=$log_file
	fi
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

install_dependencies_debian() {
	info_message -n 'Installing dependencies... '
	(
		local deb_url="https://s3.eu-central-1.amazonaws.com/deskpro/install/ansible-2.1.1.0-0-jessie.deb"
		local deb_file=$(mktemp -t ansible-jessie-XXXX.deb)

		curl -L -s --show-error -o $deb_file $deb_url
		$SUDO apt-get update
		$SUDO apt-get install -y curl aptitude apt-transport-https
		$SUDO dpkg -i $deb_file || $SUDO apt-get -fy install

		rm -f $deb_file
	) >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'
}

install_dependencies_ubuntu() {
	info_message -n 'Installing dependencies... '
	(
		$SUDO apt-get update
		$SUDO apt-get install -y software-properties-common
		$SUDO apt-add-repository -y ppa:ansible/ansible
		$SUDO apt-get update
		$SUDO apt-get install -y curl aptitude ansible
	) >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'
}

install_dependencies_fedora() {
	echo 'Fedora is not supported by this script yet'
	exit 1
}

install_dependencies_centos() {
	info_message -n 'Installing dependencies... '
	(
		$SUDO yum install -y epel-release
		$SUDO yum install -y curl ansible
	) >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'
}

install_dependencies_rhel() {
	echo 'RHEL is not supported by this script yet'
	exit 1
}

detect_repository() {
	local current_dir=$(dirname $0)
	ANSIBLE_DIR=$current_dir/ansible

	if [ ! -e $ANSIBLE_DIR ]; then
		local tmp_dir=$(mktemp -dt dpbuild-XXXXXXXX)

		info_message -n 'Downloading ansible scripts... '

		cd $tmp_dir
		curl -L https://github.com/DeskPRO/install/archive/master.tar.gz 2>>"${FULL_LOG_FILE}" | tar xz

		info_message 'Done'

		ANSIBLE_DIR=$tmp_dir/install-master/ansible
	fi
}

detect_distro() {
	if [ -e /etc/os-release ]; then
		. /etc/os-release

		case $ID in
			fedora)
				install_dependencies_fedora
				;;
			centos)
				install_dependencies_centos
				;;
			rhel)
				install_dependencies_rhel
				;;
			ubuntu)
				install_dependencies_ubuntu
				;;
			debian)
				install_dependencies_debian
				;;
			*)
				echo 'Unknown Linux distribution'
				exit 1
		esac

		DISTRO="$PRETTY_NAME"
	elif [ -e /etc/redhat-release ]; then
		install_dependencies_rhel
		DISTRO=$(cat /etc/redhat-release)
	elif [ -e /etc/debian_version ]; then
		install_dependencies_debian
		DISTRO=$(cat /etc/debian_version)
	else
		echo 'Unknown Linux distribution'
		exit 1
	fi
}

check_root() {
	if [ "$(id -u)" != "0" ]; then
		SUDO='sudo'

		if [ $ARG_QUIET -ne 0 ]; then
			return
		fi

		cat <<-'EOT'
			Most commands from this script will need to run as root.
			You'll be prompted for the sudo password at the right time.
			If you do not want to be prompted, run this script as root
			or using sudo directly instead.

		EOT
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

		sleep 3
	fi
}

change_mysql_password() {
	MYSQL_PASS=$(head -c 4096 /dev/urandom | tr -cd [:alpha:])
	MYSQL_PASS=${MYSQL_PASS:0:32}

	sed -i "s/mysqlpasswordchangeme/\"$MYSQL_PASS\"/" $ANSIBLE_DIR/group_vars/all
}

install_deskpro() {
	cd $ANSIBLE_DIR

	info_message -n 'Installing role dependencies... '
	ansible-galaxy install -r requirements.txt -i -p roles >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'

	$SUDO ansible-playbook -i 127.0.0.1, full-install.yml 2>&1 | $UNBUFFER tee --append ${FULL_LOG_FILE}
}

upload_logs() {
	sed -i "s/$MYSQL_PASS/**********/g" $FULL_LOG_FILE

	curl https://log.deskpro.com/install \
		--silent -k --show-error \
		-F log_file=@$FULL_LOG_FILE \
		-F success=$SUCCESS \
		-F distro="$DISTRO"
}

install_failed() {
	set +o errexit

	check_memory
	upload_logs

	cat <<-EOT
		The installation has failed.

		You can check the full log for in $FULL_LOG_FILE

	EOT

	exit 1
}

main() {
	parse_args "$@"
	check_root
	check_memory
	detect_distro
	detect_repository
	change_mysql_password
	install_deskpro


	SUCCESS=true
	upload_logs
	check_memory

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

trap install_failed ERR

main "$@"
