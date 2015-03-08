# Host specific setup notes

## Tanglu

Requires at least bartholomea

## Debian

Requires at least jessie

Additional packages to install before provisioning:
- sudo
- python
- debootstrap from archive.tanglu.org
- tanglu-archive-keyring from archive.tanglu.org

You need to add a user for remote ssh access and add him to the sudo group

# Virtualization Notes

## LXC

If you use apparmor on the host, make sure the container config contains
`lxc.aa_profile = unconfined`
