#!/usr/bin/env -S bash -e

# Cleaning the TTY.
clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Installing network manager
network_installer () {
  pacstrap /mnt networkmanager >/dev/null
  systemctl enable NetworkManager --root=/mnt &>/dev/null
}

# User enters a password for the LUKS Container (function).
lukspass_selector () {
    input_print "Please enter a password for the LUKS container (you're not going to see the password): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "You need to enter a password for the LUKS Container, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password for the LUKS container again (you're not going to see the password): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# User enters a hostname (function).
hostname_selector () {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
======================================================================
███████╗ █████╗ ███████╗██╗   ██╗      █████╗ ██████╗  ██████╗██╗  ██╗
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝     ██╔══██╗██╔══██╗██╔════╝██║  ██║
█████╗  ███████║███████╗ ╚████╔╝█████╗███████║██████╔╝██║     ███████║
██╔══╝  ██╔══██║╚════██║  ╚██╔╝ ╚════╝██╔══██║██╔══██╗██║     ██╔══██║
███████╗██║  ██║███████║   ██║        ██║  ██║██║  ██║╚██████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
======================================================================
${RESET}"
info_print "Welcome to mtnstar's arch-setup, automated Arch Linux Desktop setup"

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK="$ENTRY"
    info_print "Arch Linux will be installed on the following disk: $DISK"
    break
done

# Setting up LUKS password.
until lukspass_selector; do : ; done

# User choses the hostname.
until hostname_selector; do : ; done

# User sets up the user password
until userpass_selector; do : ; done

# Warn user about deletion of old partition scheme.
input_print "This will delete the current partition table on $DISK once installation starts. Do you agree [y/N]?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit
fi
info_print "Wiping $DISK."
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart CRYPTROOT 1025MiB 100% \

ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the ESP as FAT32.
info_print "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 "$ESP" &>/dev/null

# Creating a LUKS Container for the root partition.
info_print "Creating LUKS Container for the root partition."
echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null
echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d - 
BTRFS="/dev/mapper/cryptroot"

# Formatting the LUKS Container as BTRFS.
info_print "Formatting the LUKS container as BTRFS."
mkfs.btrfs "$BTRFS" &>/dev/null
mount "$BTRFS" /mnt

# Creating BTRFS subvolumes.
info_print "Creating BTRFS subvolumes."
subvols=(snapshots var_pkgs var_log home root srv)
for subvol in '' "${subvols[@]}"; do
    btrfs su cr /mnt/@"$subvol" &>/dev/null
done

# Mounting the newly created subvolumes.
umount /mnt
info_print "Mounting the newly created subvolumes."
mountopts="ssd,noatime,compress-force=zstd:3,discard=async"
mount -o "$mountopts",subvol=@ "$BTRFS" /mnt
mkdir -p /mnt/{home,root,srv,.snapshots,var/{log,cache/pacman/pkg},boot}
for subvol in "${subvols[@]:2}"; do
    mount -o "$mountopts",subvol=@"$subvol" "$BTRFS" /mnt/"${subvol//_//}"
done
chmod 750 /mnt/root
mount -o "$mountopts",subvol=@snapshots "$BTRFS" /mnt/.snapshots
mount -o "$mountopts",subvol=@var_pkgs "$BTRFS" /mnt/var/cache/pacman/pkg
chattr +C /mnt/var/log
mount "$ESP" /mnt/boot/

# Checking the microcode to install.
microcode_detector

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (it may take a while)."
pacstrap -K /mnt base linux "$microcode" linux-firmware linux-headers sbctl btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac zram-generator sudo ansible git &>/dev/null

# Setting up the hostname.
echo "$hostname" > /mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new fstab."
genfstab -U /mnt >> /mnt/etc/fstab

# just use US locale and keymap
locale="en_US.UTF-8"
kblayout="us-intl"

# Configure selected locale and console keymap
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

# Setting hosts file.
info_print "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Setting up the network.
network_installer

# Configuring /etc/mkinitcpio.conf.
info_print "Configuring /etc/mkinitcpio.conf."
cat > /mnt/etc/mkinitcpio.conf <<EOF
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
EOF

# Setting up LUKS2 encryption in grub.
info_print "Setting up grub config."
UUID=$(blkid -s UUID -o value $CRYPTROOT)
sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&rd.luks.name=$UUID=cryptroot root=$BTRFS," /mnt/etc/default/grub

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, Snapper, GRUB)."
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Create SecureBoot keys. 
    # This isn't strictly necessary, linux-hardened preset expects it and mkinitcpio will fail without it
    sbctl create-keys

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Snapper configuration.
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
    mount -a &>/dev/null
    chmod 750 /.snapshots

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Boot backup hook.
info_print "Configuring /boot backup when pacman transactions are made."
mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

# ZRAM configuration.
info_print "Configuring ZRAM."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF

# Pacman eye-candy features.
info_print "Enabling colours, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf

# Enabling various services.
info_print "Enabling Reflector, automatic snapshots, BTRFS scrubbing and systemd-oomd."
services=(reflector.timer snapper-timeline.timer snapper-cleanup.timer btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var-log.timer btrfs-scrub@\\x2esnapshots.timer grub-btrfsd.service systemd-oomd)
for service in "${services[@]}"; do
    systemctl enable "$service" --root=/mnt &>/dev/null
done

info_print "Cloning ansible setup git repo."
pacman -Sy --noconfirm git
mkdir -p /mnt/home/$username/git/setup
git clone https://github.com/mtnstar/arch-setup /mnt/home/$username/git/setup/arch-setup
chown -R 1000:1000 /mnt/home/$username/git

# Finishing up.
info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
exit
