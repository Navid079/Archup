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

while true; do
	# Choose partition table type (GPT/MBR)
	echo "Select partition type:"
	echo "1) GPT"
	echo "2) MBR"
	echo "3) I don't know, help me please :("
	read choice < /dev/tty
	if [[ $choice == 1 ]]; then
		echo "GPT selected"
		partition_type="gpt"
		break
	elif [[ $choice == 2 ]]; then
		echo "MBR selected"
		partition_type="msdos"
		break
	elif [[ $choice == 3 ]]; then
		echo "If your system is a modern one, it's more likely that\
			you should choose GPT. But if you are trying to install\
			Arch Linux on your grandma's computer, choose MBR"
	else
		echo "Invalid input"
	fi
done

