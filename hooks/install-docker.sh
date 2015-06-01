# Adapted from get.docker.com
# installs latest docker from ppa
# does not exit

export DEBIAN_FRONTEND=noninteractive

sh_c='sh -c'
url='https://get.docker.com/'

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

echo_docker_as_nonroot() {
	your_user=your-user
	[ "$user" != 'root' ] && your_user="$user"
	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	cat <<-EOF

	If you would like to use Docker as a non-root user, you should now consider
	adding your user to the "docker" group with something like:

	  sudo usermod -aG docker $your_user

	Remember that you will have to log out and back in for this to take effect!

	EOF
}

docker_install (){
    did_apt_get_update=
    apt_get_update() {
        if [ -z "$did_apt_get_update" ]; then
            ( set -x; $sh_c 'sleep 3; apt-get update' )
	    did_apt_get_update=1
        fi
    }

    # aufs is preferred over devicemapper; try to ensure the driver is available.
    if ! grep -q aufs /proc/filesystems && ! $sh_c 'modprobe aufs'; then
        if uname -r | grep -q -- '-generic' && dpkg -l 'linux-image-*-generic' | grep -q '^ii' 2>/dev/null; then
	    kern_extras="linux-image-extra-$(uname -r) linux-image-extra-virtual"

	    apt_get_update
	    ( set -x; $sh_c 'sleep 3; apt-get install -y -q '"$kern_extras" ) || true

	    if ! grep -q aufs /proc/filesystems && ! $sh_c 'modprobe aufs'; then
	        echo >&2 'Warning: tried to install '"$kern_extras"' (for AUFS)'
	        echo >&2 ' but we still have no AUFS.  Docker may not work. Proceeding anyways!'
	        ( set -x; sleep 10 )
	    fi
        else
	    echo >&2 'Warning: current kernel is not supported by the linux-image-extra-virtual'
	    echo >&2 ' package.  We have no AUFS support.  Consider installing the packages'
	    echo >&2 ' linux-image-virtual kernel and linux-image-extra-virtual for AUFS support.'
	    ( set -x; sleep 10 )
        fi
    fi

    # install apparmor utils if they're missing and apparmor is enabled in the kernel
# otherwise Docker will fail to start
    if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = 'Y' ]; then
        if command -v apparmor_parser &> /dev/null; then
	    echo 'apparmor is enabled in the kernel and apparmor utils were already installed'
        else
	    echo 'apparmor is enabled in the kernel, but apparmor_parser missing'
	    apt_get_update
	    ( set -x; $sh_c 'sleep 3; apt-get install -y -q apparmor' )
        fi
    fi

    if [ ! -e /usr/lib/apt/methods/https ]; then
        apt_get_update
        ( set -x; $sh_c 'sleep 3; apt-get install -y -q apt-transport-https ca-certificates' )
    fi

    if [ -z "$curl" ]; then
        apt_get_update
        ( set -x; $sh_c 'sleep 3; apt-get install -y -q curl ca-certificates' )
        curl='curl -sSL'
    fi
    (
        set -x
        if [ "https://get.docker.com/" = "$url" ]; then
	    $sh_c "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9"
        elif [ "https://test.docker.com/" = "$url" ]; then
					$sh_c "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 740B314AE3941731B942C66ADF4FD13717AAD7D6"
        else
	    $sh_c "$curl ${url}gpg | apt-key add -"
        fi
        $sh_c "echo deb ${url}ubuntu docker main > /etc/apt/sources.list.d/docker.list"
        $sh_c 'sleep 3; apt-get update; apt-get install -y -q lxc-docker'
    )
    if command_exists docker && [ -e /var/run/docker.sock ]; then
        (
	    set -x
	    $sh_c 'docker version'
        ) || true
    fi
    echo_docker_as_nonroot
}
