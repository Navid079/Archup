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
timedatectl
echo "Date and time are synchronized"

# List available disks
echo "Select where to install Arch Linux:"
lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme"

# Prompt user to select a disk
read -p "Enter the disk to use (e.g., /dev/sda): " selected_disk

# Confirm the selection
if [ -b "$selected_disk" ]; then
    echo "You have selected $selected_disk."
    echo "Proceeding with installation..."
else
    echo "Invalid disk selection. Please rerun the script and select a valid disk."
    exit
fi
