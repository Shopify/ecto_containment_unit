#!/bin/sh

. funcs.sh

if [ -x /usr/local/jamf/bin/jamf ]
then
  sudo -p "We need your sudo password to remove the Casper framework: " /usr/local/jamf/bin/jamf removeFramework
else
  echo "JAMF framework is already removed from this system."
fi

/bin/echo "Removing the periodic recon service..."
sudo launchctl remove "com.jamfsoftware.recon.Every 12 Hours" > /dev/null 2>&1
sudo rm -f /Library/LaunchDaemons/com.jamfsoftware.recon.plist

/bin/echo "Removing the Casper Self Service app..."
sudo rm -rf "/Applications/Casper Self Service.app"

/bin/echo "Ensuring the non-existence of any local Casper users..."
remove_local_casper_users

/bin/echo "Removing sandbox profiles..."
sudo rm -f /Library/Sandbox/Profiles/jamf-keychain.sb
sudo rm -f /Library/Sandbox/Profiles/jamf-ro.sb
