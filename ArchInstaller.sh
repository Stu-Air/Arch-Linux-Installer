#! /bin/bash

root_password=""
user_password=""
hostname=""
username=""
continent_city=""
chipset=""     # amd or intel

loadkeys uk

echo "Connecting to wifi"
#iwctl station wlan0 connect Lord\ Voldemodem\ 5G
#    Ping -c 5 www.google.com

echo "Updating system clock"
timedatectl set-ntp true

echo "Syncing packages database"
pacman -Syy --noconfirm

echo "Creating partition tables"
 (
 echo d # 	Delete existing Partition 
 echo   # 	Accept default
 echo d # 	Delete existing Partition
 echo   # 	Accept default
 echo d # 	Delete existing Partition
 echo   # 	Accept default
 echo d # 	Delete existing Partition
 echo   # 	Accept default
 echo g # 	Create u guid
 echo n # 	Create new partition 
 echo   # 	Accept default
 echo   # 	Accept default
 echo +512M #   Create first partition size 
 echo t # 	Select type of partition 
 echo   # 	Accept default
 echo 1 # 	Partition type 1 (EFI)
 echo   # 	Accept default (Partition 1 created)
 echo n #	Create final partition 
 echo   #	Accept default
 echo   #	Accept default
 echo   #	Accept default (Partition 3 created rest of disk) 
 echo w #	Write to disk 
 ) | fdisk /dev/nvme0n1

mkfs.fat -F32 /dev/nvme0n1p1	# Make partition 1 Fat format
mkfs.ext4 /dev/nvme0n1p2	# Make partition 3 Ext4 Format

echo "Mounting System Partition"
mount /dev/nvme0n1p2 /mnt

echo "Installing Arch Linux"
yes '' | pacstrap /mnt base linux-lts linux-firmware linux-lts-headers 
    
echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Configuring new system"
arch-chroot /mnt /bin/bash <<EOF
 
pacman -S --noconfirm sudo acpi acpid nano wget networkmanager wpa_supplicant wireless_tools netctl dialog grub efibootmgr dosfstools os-prober mtools xorg xorg-apps xf86-video-amdgpu mesa dhcpcd amd-ucode pulseaudio-bluetooth bluez bluez-utils fuse2 unzip gvfs xdg-user-dirs
xdg-user-dirs-update
LC_ALL=C xdg-user-dirs-update --force


echo "Setting system clock"
ln -sf /usr/share/zoneinfo/$continent_city /etc/localtime
hwclock --systohc

echo "Setting locales"
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
locale-gen

echo "Setting hostname"
echo $hostname > /etc/hostname

echo "Setting root password"
echo -en "$root_password\n$root_password" | passwd

echo "Creating new user"
useradd -m -G wheel -s /bin/bash $username
echo -en "$user_password\n$user_password" | passwd $username

echo "Setting hosts"
echo "127.0.0.1 	localhost
::1		localhost
127.0.1.1. 	"$hostname".localdomain	"$hostname >> /etc/hosts

echo "Generating initramfs"
mkinitcpio -P

echo "Enabling NetworkManager"
sudo systemctl enable NetworkManager

echo "Adding user as a sudoer"
   echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo

echo "Installing grub"
mkdir /boot/efi
mount /dev/nvme0n1p1 /boot/efi
grub-install --target=x86_64-efi efi-directory=/boot/efi
mkdir /boot/grub/locale
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
grub-mkconfig -o /boot/grub/grub.cfg


echo "Enabling Bluetooth"
sudo systemctl enable bluetooth

echo "configuring swap"
sudo dd if=/dev/zero of=/swapfile bs=1024 count=524288
sudo chown root:root /swapfile
sudo chmod 0600 /swapfile
sudo mkswap /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo swapon -s

# --------------------------------------- EXTRAS BELOW ----------------------#

echo "enable multilib packages"
echo "[multilib]
Include = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf

sudo sh -c 'echo "vm.swappiness=10" >> /etc/sysctl.d/99-swappiness.conf'

pacman -Syu --noconfirm

echo "Mounting second drive"
echo "LABEL=Media                                  /mnt/Media   auto   nosuid,nodev,nofail,x-gvfs-show   0 0" | sudo tee -a /etc/fstab

EOF


umount -R /mnt
echo "Arch Linux is ready. You can reboot now!"
