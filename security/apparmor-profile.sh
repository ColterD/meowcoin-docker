# security/apparmor-profile
#include <tunables/global>

profile docker-meowcoin flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  
  network,
  capability,
  file,
  umount,
  
  deny @{PROC}/{*,**^[0-9]*/} w,
  deny @{PROC}/sys/kernel/shmmax w,
  deny @{PROC}/sys/kernel/shmall w,
  deny @{PROC}/sys/kernel/shmmni w,
  
  # Allow access to blockchain data
  /home/meowcoin/.meowcoin/** rwk,
  
  # Allow specific writable directories
  /tmp/** rwm,
  /var/run/** rwm,
  /var/log/meowcoin/** rwk,
  /var/lib/meowcoin/** rwk,
  
  # Restrict system access
  deny /bin/** wl,
  deny /sbin/** wl,
  deny /usr/bin/** wl,
  deny /usr/sbin/** wl,
  
  # Allow specific binaries with restrictions
  /usr/bin/meowcoind r,
  /usr/bin/meowcoin-cli r,
  
  # Allow SSL/TLS operations
  /etc/ssl/** r,
  
  # Allow specific configuration access
  /etc/meowcoin/** r,
  
  # Allow plugin operations with restrictions
  /etc/meowcoin/plugins/** r,
  /var/lib/meowcoin/plugin-data/** rw,
  /var/lib/meowcoin/plugin-state/** rw,
}