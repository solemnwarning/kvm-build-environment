#!/bin/sh

# pam_securetty.so on FreeBSD doesn't implement the auth facility, but
# pam_exec.so does, so we can use that to emulate it.
#
# Example usage:
#
# auth  sufficient  pam_exec.so  /usr/lib/pam_securetty_auth.sh

grep "^$PAM_TTY\$" /etc/securetty
exit $?
