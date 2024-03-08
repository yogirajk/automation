#!/bin/bash

# Welcome message
echo "Welcome to the OKD downloader script!"
echo "For OKD releases, please visit: https://github.com/okd-project/okd/releases"
echo ""

# Function to display menu and get user choice
display_menu() {
    echo "Select the version of OKD:"
    echo "1. OKD Client (oc)"
    echo "2. OKD Installer"
    echo "3. Quit"
    read -p "Enter your choice: " choice
}

# Function to download the OKD client
download_oc() {
    read -p "Enter the version of OKD client you want to download: " version
    wget https://github.com/openshift/okd/releases/download/$version/openshift-client-linux-$version.tar.gz
    tar -xvf openshift-client-linux-$version.tar.gz
    rm openshift-client-linux-$version.tar.gz
    echo "OKD client (oc) downloaded successfully."
}

# Function to download the OKD installer
download_installer() {
    read -p "Enter the version of OKD installer you want to download: " version
    wget https://github.com/openshift/okd/releases/download/$version/openshift-install-linux-$version.tar.gz
    tar -xvf openshift-install-linux-$version.tar.gz
    rm openshift-install-linux-$version.tar.gz
    echo "OKD installer downloaded successfully."
}

# Main script
while :
do
    display_menu
    case $choice in
        1) download_oc ;;
        2) download_installer ;;
        3) echo "Exiting." ; exit ;;
        *) echo "Invalid choice. Please enter a valid option." ;;
    esac
done

