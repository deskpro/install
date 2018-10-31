#!/usr/bin/env bash

set -o errexit -o errtrace -o noclobber -o nounset -o pipefail

# info parsed by getopt
ARG_QUIET=0

# data needed by the script
ANSIBLE_DIR=''
SUDO=''
UNBUFFER='stdbuf -i0 -o0 -e0'
MYSQL_PASS=''
FULL_LOG_FILE=''
LOG_HELPER="/usr/local/bin/deskpro-log-helper"
LOG_COMMAND="$LOG_HELPER --ignore-errors"
DISTRO='Unknown'
SKIP_LOGS=false

info_message() {
	if [ $ARG_QUIET -eq 0 ]; then
		echo "$@"
	fi
}

log_step() {
	if [ ! -z "$FULL_LOG_FILE" ]; then
		echo "[Executing $1]" >> "$FULL_LOG_FILE"
	fi
}

log_message() {
	if [ ! -z "$FULL_LOG_FILE" ]; then
		echo "[INFO $(date +%s)] $1" >> "$FULL_LOG_FILE"
	fi
}

parse_args() {
	local -r params=$(getopt -o 'hl:q' -l 'help,log:,quiet' --name "$0" -- "$@")
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
		local -r log_file=$(mktemp -t install-XXXXXXXX.log)
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
		$SUDO apt-get install --no-install-recommends -y dirmngr
		$SUDO bash -c 'echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" > /etc/apt/sources.list.d/trusty-ppa.list'
		$SUDO apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367

		$SUDO apt-get update
		$SUDO apt-get install --no-install-recommends -y curl jq aptitude apt-transport-https lsb-release python-pkg-resources python-openssl sudo
		$SUDO apt-get install --no-install-recommends -y ansible

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
		$SUDO apt-get install -y curl jq aptitude ansible
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
		$SUDO yum install -y curl jq redhat-lsb-core ansible
	) >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'
}

install_dependencies_rhel() {
	echo 'RHEL is not supported by this script yet'
	exit 1
}

detect_repository() {
	log_step "detect_repository"

	local current_dir=""

	if [ -t 0 ]; then
		# we only need to change this if we're running from a file, and not if
		# from a `curl | bash` situation
		current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	fi

	ANSIBLE_DIR="$current_dir/ansible"

	if [ ! -e "$ANSIBLE_DIR" ]; then
		local -r tmp_dir=$(mktemp -dt dpbuild-XXXXXXXX)

		log_message "Using tmp dir $tmp_dir"

		info_message -n 'Downloading ansible scripts... '

		cd "$tmp_dir"
		curl -L https://github.com/DeskPRO/install/archive/master.tar.gz 2>>"${FULL_LOG_FILE}" | tar xz

		info_message 'Done'

		ANSIBLE_DIR=$tmp_dir/install-master/ansible
	else
		log_message "Using existing ansible dir at $ANSIBLE_DIR"
	fi
}

detect_distro() {
	log_step "detect_distro"

	if [ -e /etc/os-release ]; then
		. /etc/os-release

		DISTRO="$PRETTY_NAME"

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
	elif [ -e /etc/redhat-release ]; then
		DISTRO=$(cat /etc/redhat-release)
		install_dependencies_rhel
	elif [ -e /etc/debian_version ]; then
		DISTRO=$(cat /etc/debian_version)
		install_dependencies_debian
	else
		echo 'Unknown Linux distribution'
		exit 1
	fi
}

check_root() {
	log_step "check_root"

	if [ "$(id -u)" != "0" ]; then
		SUDO='sudo -E'

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
	log_step "check_memory"

	if [ $ARG_QUIET -ne 0 ]; then
		return
	fi

	local -r total_mem=$(awk '/^MemTotal/ { print $2 }' /proc/meminfo)

	if [ "$total_mem" -lt 1000000 ]; then
		cat <<-EOT
			This DeskPRO install requires at least 1GB of memory to
			work properly. Installation on less than 1GB of memory is
			not supported and may fail for many different reasons.

		EOT

		sleep 3
	fi
}

check_software() {
	local installed_software=()

	local -r test_software=(
		"mysql:"
		"elasticsearch:/usr/share/elasticsearch/bin/elasticsearch"
		"php:"
		"nginx:/usr/sbin/nginx"
	)

	for entry in "${test_software[@]}" ; do
		IFS=":" read -ra software <<< "$entry"

		if command -v "${software[0]}" >/dev/null 2>&1 ; then
			installed_software+=("${software[0]}")
		else
			for path in "${software[@]:1}" ; do
				if test -e "$path"; then
					installed_software+=("${software[0]}")
					break
				fi
			done
		fi
	done

	if [ "${#installed_software[@]}" -ne "0" ]; then
		cat <<-EOT
			This machine currently contains software that should be installed
			by the installer itself. This is not supported and might lead to
			errors during the process. The following programs are already
			installed:

		EOT

		for software in "${installed_software[@]}"; do
			echo -e "\t* $software"
		done

		cat <<-EOT

			It is recommended that you start with a clean machine. If you
			continue, the installation might fail.

		EOT

		if ! confirm "Do you wish to proceed?" ; then
			SKIP_LOGS=true
			exit
		fi
	fi
}

function confirm() {
	local -r message="$1"
	while true; do
		read -r -p "$message [y/n] " answer
		case "$answer" in
			[Yy][Ee][Ss]|[Yy] ) return 0 ;;
			[Nn][Oo]|[Nn] ) return 1 ;;
			* ) echo "Please answer yes or no" ;;
		esac
	done
}

change_mysql_password() {
	log_step "change_mysql_password"

	MYSQL_PASS=$(head -c 4096 /dev/urandom | tr -cd '[:alpha:]')
	MYSQL_PASS=${MYSQL_PASS:0:32}

	(
		sed -i "s/mysqlpasswordchangeme/$MYSQL_PASS/" "$ANSIBLE_DIR/group_vars/all"
	) >>"${FULL_LOG_FILE}" 2>&1
}

run_ansible() {
	local playbook=$1

	$SUDO ansible-playbook -i 127.0.0.1, "$playbook" 2>&1 | $UNBUFFER tee --append "$FULL_LOG_FILE"
}

install_deskpro() {
	log_step "install_deskpro"

	cd "$ANSIBLE_DIR"

	info_message -n 'Installing role dependencies... '
	ansible-galaxy install -r requirements.yml -i -p roles >>"${FULL_LOG_FILE}" 2>&1
	info_message 'Done'

	run_ansible log-helper.yml

	$LOG_COMMAND start
	SECONDS=0

	if run_ansible full-install.yml ; then
		$LOG_COMMAND success --duration $SECONDS
	else
		local -r error_json=$(tail "$FULL_LOG_FILE" | grep ^fatal: | sed 's/.*FAILED! => //')
		local -r error_message=$(jq -r .msg <<< "$error_json")
		$LOG_COMMAND failure --duration $SECONDS --summary "${error_message:0:100}"
	fi
}

upload_logs() {
	if [ "$SKIP_LOGS" = "true" ]; then
		return 0
	fi

	if [ ! -z "$MYSQL_PASS" ]; then
		sed -i "s/$MYSQL_PASS/**********/g" "$FULL_LOG_FILE" || true
	fi

	if [ -e "$LOG_HELPER" ]; then
		$LOG_COMMAND log --file "$FULL_LOG_FILE"
	else
		local -r uuid=$(cat /proc/sys/kernel/random/uuid)
		local -r base_url="http://app-stats.deskpro-service.com/installer/installer"

		local -r kernel="$(uname -a)"
		local -r distro="$DISTRO"

		if command -v curl >/dev/null 2>&1 ; then
			curl -so /dev/null -X POST "$base_url/$uuid/start" -F kernel="$kernel" -F distro="$distro"
			curl -so /dev/null -X POST "$base_url/$uuid/error"
			curl -so /dev/null -X POST "$base_url/$uuid/logs" --data-binary @"$FULL_LOG_FILE"
		elif command -v wget >/dev/null 2>&1 ; then
			wget -qO /dev/null "$base_url/$uuid/start" --post-data "kernel=$kernel&distro=$distro"
			wget -qO /dev/null --method=POST "$base_url/$uuid/error"
			wget -qO /dev/null "$base_url/$uuid/logs" --post-file "$FULL_LOG_FILE"
		fi
	fi

}

install_failed() {
	set +o errexit +o errtrace

	check_memory

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
	check_software
	detect_distro
	detect_repository
	change_mysql_password
	install_deskpro

	check_memory

	if [ $ARG_QUIET -eq 0 ]; then
		local -r ip=$(curl -s https://api.ipify.org)

		cat <<-EOT
			All done! To start using your instance, point your browser
			to the following address and follow the instructions on the
			screen:

			    http://$ip/

		EOT
	fi
}

trap install_failed ERR
trap upload_logs EXIT

main "$@"
