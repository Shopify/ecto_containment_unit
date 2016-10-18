#!/bin/sh

validate_supported_os() {
  local ver_major=0
  local ver_minor=0

  ver_major=$(sw_vers -productVersion | awk 'BEGIN {FS="."} ; {print $1}')
  ver_minor=$(sw_vers -productVersion | awk 'BEGIN {FS="."} ; {print $2}')

  test ${ver_major} -ge ${MINIMUM_OSX_VER_MAJOR} && \
    test ${ver_minor} -ge ${MINIMUM_OSX_VER_MINOR} && \
      return 0

  return 1
}

create_casper_application_preferences() {
  # Sets up a basic set of configuration parameters that points the local
  # JAMF install to the corporate JAMF server

  local plist="/Library/Preferences/com.jamfsoftware.jamf.plist"

  sudo /usr/libexec/PlistBuddy "${plist}" -c "Clear dict"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :max_clock_skew integer 900"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :jss_url string '${JAMF_SERVER_URL}'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :allowInvalidCertificate bool false"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :package_validation_level integer 2"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Print"
}

create_casper_recon_launch_daemon() {
  # Sets up a LaunchDaemon to run a sandboxed `jamf recon` every 12 hours

  local plist="/Library/LaunchDaemons/com.jamfsoftware.recon.plist"

  sudo /usr/libexec/PlistBuddy "${plist}" -c "Clear dict"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :Label string 'com.jamfsoftware.recon.periodically'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments array"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '/usr/bin/sandbox-exec'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '-f'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '/Library/Sandbox/Profiles/jamf-ro.sb'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '${JAMF_BIN_DIR}'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string 'recon'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '-saveFormTo'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :ProgramArguments: string '/var/log/jamf-recon'"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :StartInterval integer ${INVENTORY_PERIOD}"
  sudo /usr/libexec/PlistBuddy "${plist}" -c "Add :UserName string 'root'"

  sudo launchctl load "${plist}"
}

remove_local_casper_users() {
  for user in ${LOCAL_CASPER_USERS}
  do
    /usr/bin/dscl . -list "/Users/${user}" >/dev/null 2>&1 && ( /bin/echo -n " ${user}" ; sudo /usr/bin/dscl . -delete "/Users/${user}" || return 1 )
  done

  return 0
}
