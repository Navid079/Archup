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
