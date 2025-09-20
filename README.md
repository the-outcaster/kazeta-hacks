# Kazeta Hacks
Unofficial repository for Kazeta-related services.

**WARNING: user assumes all risks associated with running any of these scripts!**

## Unlock the filesystem and connect to Ethernet
Before any commands can be run below, you'll need to log in to your Kazeta console, unlock the filesystem, and connect to the Internet via Ethernet. Please connect a keyboard and Ethernet jack.

Once Kazeta starts:
1. Open the console with `CTRL + ALT + F3`
2. Login with username and password of `gamer`.
3. Unlock the filesystem with `sudo frzr-unlock`. Enter password of `gamer` when prompted.
4. Connect to the Internet with `sudo ethernet-connect`.

## Enable SSH
Allowing SSH to your Kazeta machine will make it easier to run terminal commands from a remote computer. To do so:
```
sudo pacman -S openssh
sudo systemctl start sshd
sudo systemctl enable sshd
```
Find the IP address of your Kazeta machine with `ip addr`, then on your client, type `ssh gamer@<IP address of Kazeta machine>`.

(Note: if you get a permission denied error when trying to connect, change `PasswordAuthentication` in `/etc/ssh/sshd_config` from `no` to `yes`.)

## Enable volume control on handhelds
