#!/bin/bash

not_installed() {
  dpkg -s "$1" 2>&1 | grep -q 'Version:'
  if [[ "$?" -eq 0 ]]; then
    apt-cache policy "$1" | grep 'Installed: (none)'
    return "$?"
  else
    return 0
  fi
}

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.
apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(
  git
  vim
  atom
  enpass
  nodejs
  vlc
  spotify-client
)

print_pkg_info() {
  local pkg="$1"
  local pkg_version="$2"
  local space_count
  local pack_space_count
  local real_space

  space_count="$(( 20 - ${#pkg} ))" #11
  pack_space_count="$(( 30 - ${#pkg_version} ))"
  real_space="$(( space_count + pack_space_count + ${#pkg_version} ))"
  printf " * $pkg %${real_space}.${#pkg_version}s ${pkg_version}\n"
}

package_check() {
  # Loop through each of our packages that should be installed on the system. If
  # not yet installed, it should be added to the array of packages to install.
  local pkg
  local pkg_version

  for pkg in "${apt_package_check_list[@]}"; do
    if not_installed "${pkg}"; then
      echo " *" "$pkg" [not installed]
      apt_package_install_list+=($pkg)
    else
      pkg_version=$(dpkg -s "${pkg}" 2>&1 | grep 'Version:' | cut -d " " -f 2)
      print_pkg_info "$pkg" "$pkg_version"
    fi
  done
}


package_install() {
  package_check

  if [[ ${#apt_package_install_list[@]} = 0 ]]; then
    echo -e "No apt packages to install.\n"
  else

    # Update all of the package references before installing anything
    echo "Running apt-get update..."
    apt-get -y update

    # Install required packages
    echo "Installing apt-get packages..."
    apt-get -y install ${apt_package_install_list[@]}

    # Clean up apt caches
    apt-get clean
  fi
}

# Enpass repository
if [ -e /etc/apt/sources.list.d/enpass.list ]; then
  echo "deb http://repo.sinew.in/ stable main" > \
    /etc/apt/sources.list.d/enpass.list
fi

# wget -O - http://repo.sinew.in/keys/enpass-linux.key | apt-key add -

# Atom repository
echo "Adding repository for Atom..."
add-apt-repository -y ppa:webupd8team/atom

# Install Google Chrome
if not_installed "google-chrome-stable"; then
  echo "Installing Google Chrome..."
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  gdebi google-chrome-stable_current_amd64.deb
  rm google-chrome-stable_current_amd64.deb
else
  echo "Google Chrome is already installed"
fi

if not_installed "nodejs"; then
  echo "Adding Node.js repository source"
  curl -sL https://deb.nodesource.com/setup_6.x | bash -
fi

if !command -v slack >/dev/null 2>&1; then
  wget https://downloads.slack-edge.com/linux_releases/slack-desktop-2.1.0-amd64.deb
  apt-get install -y ./slack-desktop-2.1.0-amd64.deb
  rm slack-desktop-2.1.0-amd64.deb
else
  echo "Slack is already installed"
fi

if not_installed "spotify-client"; then
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886
  echo deb http://repository.spotify.com stable non-free | tee /etc/apt/sources.list.d/spotify.list
fi

package_install
