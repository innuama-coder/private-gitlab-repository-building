#!/bin/zsh
set -euo pipefail

if ! /usr/bin/id kunora >/dev/null 2>&1; then
  password=$(/usr/bin/openssl rand -base64 32)
  /usr/sbin/sysadminctl \
    -addUser kunora \
    -fullName "Kunora Service" \
    -home /Users/kunora \
    -shell /bin/zsh \
    -password "$password"
  unset password
fi

/usr/sbin/dseditgroup -o edit -a kunora -t user com.apple.access_ssh
/usr/bin/dscl . -create /Users/kunora IsHidden 1
/usr/bin/install -d -m 700 -o kunora -g staff /Users/kunora/.ssh

if [[ ! -f /Users/kunora/.ssh/id_ed25519_team_network ]]; then
  /usr/bin/sudo -u kunora /usr/bin/ssh-keygen \
    -q -t ed25519 \
    -f /Users/kunora/.ssh/id_ed25519_team_network \
    -N "" \
    -C kunora@local-macbook
fi

/usr/sbin/chown -R kunora:staff /Users/kunora/.ssh
/bin/chmod 700 /Users/kunora/.ssh
/bin/chmod 600 /Users/kunora/.ssh/id_ed25519_team_network
/bin/chmod 644 /Users/kunora/.ssh/id_ed25519_team_network.pub
