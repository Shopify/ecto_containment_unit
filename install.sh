#!/bin/bash

set -eE

test -z "${DEBUG}" || set -x

if [ ! -f ./vars.sh ]
then
  echo "You still need to define a few things in vars.sh; exiting."
  exit 128
fi

. vars.sh
. funcs.sh

SANDBOX_PROFILES_DIR="/Library/Sandbox/Profiles"
JAMF_BIN_DIR="/usr/local/jamf/bin"

## Set our OS version minimums
# Our sandboxing policy requires OS X 10.11+, so require at least that
# TODO: Figure out what it would take to support 10.10 as well.
MINIMUM_OSX_VER_MAJOR=10
MINIMUM_OSX_VER_MINOR=11

# Zero-out our installation log
tee install.log < /dev/null > /dev/null

# Start our logging
exec &> >(tee -a install.log)

trap "echo '' ; (echo '!!! Uh-oh, looks like something broke! Bug @mutemule in Slack for help:'; cat install.log)" EXIT

# Check to make sure we are running a supported OS
if ! validate_supported_os
then
  trap - EXIT
  echo "Sorry, but you must be running OS X ${MINIMUM_OSX_VER_MAJOR}.${MINIMUM_OSX_VER_MINOR} or greater to use this installer."
  exit 1
fi

# Allow ourselves full access to our temporary install directory
CWD=$(pwd)
/bin/echo -n "Updating our install-time policy to allow full read access to ${CWD} and its children..."
rm -f sandbox_profiles/jamf-install.sb
cp sandbox_profiles/jamf-enroll.sb sandbox_profiles/jamf-install.sb
tee -a sandbox_profiles/jamf-install.sb <<EOPOLICY > /dev/null

(allow file-read*
  (subpath "${CWD}")
)
EOPOLICY
/bin/echo " done!"

sudo -n /bin/echo -n '' || sudo -p "We need your sudo password to install Casper in the Ecto Containment Unit: " true

## Deploy the sandbox profiles
/bin/echo "Deploying the sandbox profiles..."
/bin/echo -n "  keychain access..."
sudo install -m 0644 -o root -g wheel "sandbox_profiles/jamf-keychain.sb" "${SANDBOX_PROFILES_DIR}/jamf-keychain.sb"
/bin/echo " done!"
/bin/echo -n "  casper..."
ESCAPED_CUSTOM_SCRIPTS_PATH="$(echo "${CUSTOM_SCRIPTS_PATH}" | sed -e 's/\(.\)/\\\1/g')"
sed "s/__CUSTOM_SCRIPTS_PATH__/${ESCAPED_CUSTOM_SCRIPTS_PATH}/" "sandbox_profiles/jamf-ro.sb" > "sandbox_profiles/jamf-ro-local.sb"
sudo install -m 0644 -o root -g wheel "sandbox_profiles/jamf-ro-local.sb" "${SANDBOX_PROFILES_DIR}/jamf-ro.sb"
/bin/echo " done!"

## Deploy the JAMF binary
/bin/echo -n "Deploying the JAMF binary..."
sudo install -m 0755 -o root -g wheel -d "${JAMF_BIN_DIR}"
sudo install -m 0755 -o root -g wheel "binaries/jamf" "${JAMF_BIN_DIR}/jamf"
/bin/echo " done!"

## Create our baseline configuration
/bin/echo -n "Creating the skeleton Casper application plist..."
create_casper_application_preferences >> install.log 2>&1
/bin/echo " done!"

## Enroll our system
/bin/echo "Enrolling in Casper now... "
sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-install.sb ${JAMF_BIN_DIR}/jamf enroll -noRecon -noManage -noPolicy -invitation "${INVITATION_ID}" | sed -e 's/^/  /g'

## Remove the unnecessary Casper users
/bin/echo -n "Removing unnecessary local Casper users..."
remove_local_casper_users
/bin/echo " ... and done!"

## Create the recon logging directory
/bin/echo -n "Creating the directory for recon logs..."
sudo install -d -m 0755 -o root -g wheel /var/log/jamf-recon
/bin/echo " done!"

## Create and load the LaunchDaemon
/bin/echo -n "Deploying the launch service..."
create_casper_recon_launch_daemon >> install.log 2>&1
/bin/echo " done!"

## Create the machine <-> user association with JAMF
# This helps IT identify who to contact when there are any questions about a system, like outdated configurations.
# Since Casper can't auto-rectify anything, and runs in a report-only mode.
/bin/echo ""
/bin/echo "Now we need to associate your computer with your Casper user."
/bin/echo -n "Can you please provide your full name? "
read USER_FULLNAME
/bin/echo -n "Thanks! Can you also provide your ${ORGANIZATION_NAME} email address? "
read USER_EMAIL

/bin/echo "Creating the JAMF user association and performing our initial system inventory..."
sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-install.sb ${JAMF_BIN_DIR}/jamf recon -email "${USER_EMAIL}" -realname "${USER_FULLNAME}" -endUsername "${USER_FULLNAME}" -saveFormTo /var/log/jamf-recon | sed -e 's/^/  /g'

## All done!
/bin/echo ""
/bin/echo "You're now running a report-only Casper install!"
/bin/echo "If you want to peek behind the scenes, take a look at 'install.log' and 'sandbox_profiles/jamf-install.sb'."
/bin/echo "On an ongoing basis, if you want to see what Casper is sending out, take a look in /var/log/jamf-recon/."

trap - EXIT
