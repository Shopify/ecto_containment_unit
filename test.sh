#!/bin/bash

test -z "${DEBUG}" || set -x

RED="[31m"
GREEN="[32m"
RESET="[m"

FAILURES=0

fail() {
  FAILURES=$((${FAILURES} + 1))
  local msg="${1:-nope.}"
  echo "${RED}${msg}${RESET}"
}

pass() {
  local msg="${1:-yup!}"
  echo "${GREEN}${msg}${RESET}"
}

### Make sure we have a functioning local setup
## Make sure we have a jamf binary to deploy
/bin/echo -n "Checking for the existence of the jamf binary... "
test -f binaries/jamf && pass || fail

## Make sure we have a vars.sh defined
/bin/echo -n "Checking for the existence of vars.sh... "
test -f vars.sh && pass || fail

## Validate the contents of vars.sh
/bin/echo "Checking for appropriate variable definitions in vars.sh... "
. vars.sh
for setting in INVITATION_ID INVENTORY_PERIOD ORGANIZATION_NAME CUSTOM_SCRIPTS_PATH LOCAL_CASPER_USERS
do
  /bin/echo -n "  ${setting}: "
  test -n "${!setting}" && pass "yup! (${!setting})"|| fail
done
/bin/echo ""

### Validate we have sudo access
/bin/echo "Checking to see we have appropriate access with sudo... "
sudo -l > /dev/null 2>&1 && pass "  We can sudo!" > /dev/null 2>&1 || fail "  We can't sudo."
/bin/echo ""

### Make sure we can't read various shell files
/bin/echo "Making sure we can't read your shell files... "
shellfiles=".bash_history .bashrc .zshrc .histfile"
for shellfile in ${shellfiles}
do
  if [ -f ${HOME}/${shellfile} ]
  then
    /bin/echo -n "  ${shellfile}: "
    sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-ro.sb cat ${shellfile} > /dev/null 2>/dev/null && fail "yup." || pass "nope!"
  fi
done
/bin/echo ""

### Make sure we can't read SSH private keys
/bin/echo -n "Making sure we can't read SSH private keys... "
keyfiles=$(ls -1 ${HOME}/.ssh/id_* | egrep -v '\.pub$')
if [ -z "${keyfiles}" ]
then
  echo "no keyfiles found; nothing to test!"
else
  echo ""
  for keyfile in ${keyfiles}
  do
    /bin/echo -n "  ${keyfile}: "
    sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-ro.sb cat ${keyfile} > /dev/null 2>/dev/null && fail "yup." || pass "nope!"
  done
fi
/bin/echo ""

### Make sure we can't read the GnuPG private keyring
if [ -f ${HOME}/.gnupg/secring.gpg ]
then
  /bin/echo -n "Making sure we can't read private GnuPG keys... "
  sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-ro.sb cat ${HOME}/.gnupg/secring.gpg > /dev/null 2>/dev/null && fail "yup." || pass "nope!"
  /bin/echo ""
fi

### And the summary
if [ ${FAILURES} -eq 0 ]
then
  pass "Huzzah! Everything is working as expected."
else
  fail "Boo! Looks like there's something broken. You'll need to fix this before you can install Ecto Containment Unit!"
fi
