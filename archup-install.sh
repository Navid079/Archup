#!/bin/bash

echo "Archup Version 1.0.0"
echo "Starting up..."

# Check internet connection
if ping -c 1 archlinux.org &> /dev/null
then
	echo "Internet connection is available"
else
	echo "No internet connection."
	echo "Please fix the problem and rerun the script"
	exit
fi

# Update date and time
timedatectl &> /dev/null
echo "Date and time are synchronized"

# List available disks
echo "Select where to install Arch Linux:"
lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme"

# Prompt user to select a disk
read -p "Enter the disk to use (e.g., /dev/sda): " selected_disk < /dev/tty

# Confirm the selection
if [ -b "$selected_disk" ]; then
    echo "You have selected $selected_disk."
else
    echo "Invalid disk selection. Please rerun the script and select a valid disk."
    exit
fi

# Data loss warning
echo "======== WARNING ========"
echo "You will lose all your data in $selected_disk"
read -p "Do you want to proceed? [y/N]" proceed < /dev/tty
if [[ "$proceed" =~ ^[Yy]$ ]]; then
    echo "Proceeding with installation on $selected_disk..."
else
    echo "Installation aborted by the user."
    exit
fi

# Variables
efi_size=1  # Default EFI size in GiB
swap_size=0
home_percentage=0
last_partition="root"

# Prompt for partition table type
read -p "Enter partition table type (gpt/msdos): " partition_type < /dev/tty
if [[ "$partition_type" != "gpt" && "$partition_type" != "msdos" ]]; then
    echo "Invalid partition table type. Must be 'gpt' or 'msdos'."
    exit 1
fi

# Prompt for home separation
read -p "Do you want a separate /home partition? [y/N]: " separate_home < /dev/tty
if [[ "$separate_home" =~ ^[Yy]$ ]]; then
    read -p "Enter the percentage of disk to allocate for /home (e.g., 25): " home_percentage < /dev/tty
    if ! [[ "$home_percentage" =~ ^[0-9]+$ ]] || (( home_percentage <= 0 || home_percentage >= 100 )); then
        echo "Invalid percentage. Must be an integer between 1 and 99."
        exit 1
    fi
    last_partition="home"
else
    echo "No separate /home partition will be created."
fi

# Prompt for swap space
read -p "Do you want a separate swap partition? [y/N]: " separate_swap < /dev/tty
if [[ "$separate_swap" =~ ^[Yy]$ ]]; then
    read -p "Enter the size of the swap partition in GiB (e.g., 2): " swap_size < /dev/tty
    if ! [[ "$swap_size" =~ ^[0-9]+$ ]] || (( swap_size <= 0 )); then
        echo "Invalid swap size. Must be a positive integer."
        exit 1
    fi
    last_partition="swap"
else
    echo "No separate swap partition will be created. You can create a swapfile later if needed."
    swap_size=0
fi

# Get disk size
disk_size=$(lsblk -b -n -d -o SIZE "$selected_disk")
disk_size_gib=$((disk_size / 1024 / 1024 / 1024))  # Convert to GiB

# Calculate partition sizes
root_size=$disk_size_gib
if [[ "$separate_home" =~ ^[Yy]$ ]]; then
    home_size=$(echo "$disk_size_gib * $home_percentage / 100" | bc)
    home_size=${home_size%.*}  # Convert to integer
    root_size=$((disk_size_gib - home_size))
fi

if [[ "$separate_swap" =~ ^[Yy]$ ]]; then
    root_size=$((root_size - swap_size))
fi

if [[ "$partition_type" == "gpt" ]]; then
    root_start=$((efi_size * 1024 + 1))
else
    root_start=1  # Start directly from the beginning for msdos
fi

# Verify root size is valid
if ((root_size <= 0)); then
    echo "Error: Calculated root size is invalid. Check your inputs."
    exit 1
fi

# Display partition layout
echo "Partition layout:"
[[ "$partition_type" == "gpt" ]] && echo "1. EFI: $efi_size GiB"
echo "2. Root: $root_size GiB"
[[ "$separate_home" =~ ^[Yy]$ ]] && echo "3. Home: $home_size GiB"
[[ "$separate_swap" =~ ^[Yy]$ ]] && echo "4. Swap: $swap_size GiB"

# Confirm layout
read -p "Do you want to proceed with this partition layout? [y/N]: " proceed < /dev/tty
if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    echo "Partitioning aborted."
    exit
fi

# Partition the disk
echo "Creating partitions on $selected_disk..."
parted -s "$selected_disk" mklabel "$partition_type"

# Create EFI partition if GPT
if [[ "$partition_type" == "gpt" ]]; then
    parted -s "$selected_disk" mkpart EFI fat32 1MiB "$((efi_size * 1024))MiB"
    parted -s "$selected_disk" set 1 esp on
    echo "Created EFI partition (1 GiB)."
fi

# Calculate root end
if [[ last_partition == "root" ]]; then
	root_end="100%"
else
	root_end="$((root_start + root_size * 1024 - 1))MiB"
fi

# Create root partition
parted -s "$selected_disk" mkpart primary ext4 "${root_start}MiB" "$root_end"
echo "Created root partition ($root_size GiB)."

# Calculate home end
if [[ last_partition == "home" ]]; then
	home_end="100%"
else
	home_end="$((home_start + home_size * 1024 - 1))MiB"
fi

# Create home partition if applicable
if [[ "$separate_home" =~ ^[Yy]$ ]]; then
    home_start=$((root_start + root_size * 1024))
    parted -s "$selected_disk" mkpart primary ext4 "${home_start}MiB" "$home_end"
    echo "Created home partition ($home_size GiB)."
fi

# Create swap partition if applicable
if [[ "$separate_swap" =~ ^[Yy]$ ]]; then
    swap_start=$((home_start + home_size * 1024))
    parted -s "$selected_disk" mkpart primary linux-swap "${swap_start}MiB" 100%
    echo "Created swap partition ($swap_size GiB)."
fi

# Print the final partition table
parted -s "$selected_disk" print
echo "Partitioning completed successfully."

