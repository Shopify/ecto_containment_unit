## Ecto Containment Unit: a sandboxed, read-only Casper agent
Ecto Containment Unit (ECU) is a mechanism to deploy a restricted Casper agent on your endpoints that still allows your IT team to track the information they need.

## Requirements
1. A JAMF account
1. Administrative access to this JAMF account
1. MacOS X 10.11 (El Capitan) or greater on the endpoint
1. Local sudo access on the endpoint

ECU will refuse to install on anything older than El Capitan, due to changes in the sandboxing policy language. It is known to work on both OS X El Capitan and macOS Sierra.

## Installation
To start, you'll want to clone this repository somewhere, and put your copy up somewhere your users can access it, but nobody else. For example, create a private GitHub repository, and use that to store and distribute your local modifications. It's important that you not fork it, as forks of public repositories must remain public.

As well, depending on how you choose to distribute ECU, you may want to update your `.gitignore` to allow for git storage of `binaries/jamf` and `vars.sh`.

Once you have that sorted, the installation process is reasonably straightforward. This repository provides the framework required to install ECU, but there are a few things you will need to provide:

1. A copy of the `jamf` binary, usually found as `/usr/local/jamf/bin/jamf` after a complete install
1. A properly-populated `vars.sh`, based on `vars.sh.example`

Filling out `vars.sh` is going to be the hard part, and you'll need a few things:
* an Invitation ID
* the URL to your JAMF server
* an Organization name
* the location of your custom scripts path (usually `/Libarary/Scripts/<JAMF Organization>`)
* optional: a list of local users created by your Casper enrollment

Once you have these two things -- `jamf` and `vars.sh` -- in place, just run `./install.sh` and follow along.

## Generating the Invitation ID
This can be done by creating a new email Computer Enrollment Invitation for yourself within your JSS. Make sure to extend the expiration date and “Allow for multiple uses”. Open your invitation email and look at the invitation link, the invitation ID is the sequence of numbers at the end of the invitation hyperlink.  For example, if the link is `http://some-company.jamfcloud.com/enroll?invitation=957265384823673745958372626273892726191` then the invitation ID is `957265384823673745958372626273892726191`.

## Local Casper Accounts
If you want to ensure that remote users are removed by ECU, take note of the remote admin username associated with invitations when they are generated. Add the username to the `LOCAL_CASPER_USERS` string in your `vars.sh`.

## How Do I Know It's Actually Sandboxed?
The fast way: just run `./test.sh`. But this requires that you trust the script, and since this is a security-oriented thing, we encourage you to question it.

If you'd like to poke at the sandboxing a bit more yourself, running things in a sandbox is fairly straightforward. All you need to do is run `sandbox-exec` as root, pass in the path to your profile, and the command you want to run -- see `sandbox-exec(1)` for more details.

For example, if you wanted to see if Casper can read your private SSH keys (once this is installed):

```
% sudo /usr/bin/sandbox-exec -f sandbox_profiles/jamf-ro.sb /bin/cat ${HOME}/.ssh/id_rsa
cat: /Users/test_user/.ssh/id_rsa: Operation not permitted
%
```

Now you know that Casper cannot, in fact, read your private SSH keys. Give it a try with any file you want to make sure it can't access!

(You shouldn't grant local users access to run `sudo /usr/bin/sandbox-exec -f /Library/Sandbox/Profiles/jamf-ro.sb *`, as the sandbox profile does allow write access to some parts of the filesystem, which can be used to elevate local privileges.)

## Having troubles?
If you run into any problems, please open an issue in this repository indicating what's not working as expected and steps to reproduce. We'll have a look at it as soon as we can!
