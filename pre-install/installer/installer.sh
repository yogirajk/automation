#!/bin/bash

# Function to download OKD client
download_okd_client() {
    read -p "Enter the version of OKD client you want to download: " version
    wget https://github.com/openshift/okd/releases/download/$version/openshift-client-linux-$version.tar.gz
    tar -xvf openshift-client-linux-$version.tar.gz
    rm openshift-client-linux-$version.tar.gz
    echo "OKD client (oc) downloaded successfully."
}

# Function to download OKD installer
download_okd_installer() {
    read -p "Enter the version of OKD installer you want to download: " version
    wget https://github.com/openshift/okd/releases/download/$version/openshift-install-linux-$version.tar.gz
    tar -xvf openshift-install-linux-$version.tar.gz
    rm openshift-install-linux-$version.tar.gz
    echo "OKD installer downloaded successfully."
}

# Install required packages: jq, wget
echo "Installing jq and wget..."
if command -v yum &>/dev/null; then
    sudo yum install jq wget -y
elif command -v apt-get &>/dev/null; then
    sudo apt-get install jq wget -y
else
    echo "Error: Cannot install jq and wget. Unsupported package manager."
    exit 1
fi

# Check if the OKD installer file exists
if [ ! -f "openshift-install-linux-$version.tar.gz" ]; then
    # Welcome message
    echo "Welcome to the OKD downloader script!"
    echo "For OKD releases, please visit: https://github.com/okd-project/okd/releases"
    echo ""

    # Function to display menu and get user choice
    display_menu() {
        echo "Select the version of OKD:"
        echo "1. OKD Client (oc)"
        echo "2. OKD Installer"
        echo "3. Continue with other tasks"
        echo "4. Quit"
        read -p "Enter your choice: " choice
    }

    # Main menu to download OKD client or installer
    while :
    do
        display_menu
        case $choice in
            1) download_okd_client ;;
            2) download_okd_installer ;;
            3) break ;;
            4) echo "Exiting." ; exit ;;
            *) echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
fi

# Copy openshift-install and oc binaries to /usr/bin folder
echo "Copying openshift-install and oc binaries to /usr/bin folder..."
sudo cp openshift-install /usr/bin/
sudo cp oc /usr/bin/

# Check if the SSH key files exist
if [ ! -f "~/.ssh/okd_rsa" ] || [ ! -f "~/.ssh/okd_rsa.pub" ]; then
    # Generate SSH key
    ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/okd_rsa

    # Start ssh-agent in the background
    eval "$(ssh-agent -s)"

    # Add SSH private key to the ssh-agent
    ssh-add ~/.ssh/okd_rsa

    # Display the SSH public key
    echo "Your SSH public key is:"
    cat ~/.ssh/okd_rsa.pub

    echo "SSH key generation and configuration completed."
else
    echo "SSH key files already exist."
fi

add_ssh_key_to_install_config() {
    # Check if okd_rsa.pub exists
    if [ ! -f ~/.ssh/okd_rsa.pub ]; then
        echo "Error: okd_rsa.pub file not found."
        return 1
    fi

    # Check if install-config.yaml exists
    if [ ! -f "install-config.yaml" ]; then
        echo "Error: install-config.yaml file not found."
        return 1
    fi

    # Read the contents of okd_rsa.pub
    ssh_pub_key=$(cat ~/.ssh/okd_rsa.pub)

    # Add SSH public key to install-config.yaml
    if ! sed -i "/^sshKey:/a \ \ \ \ sshKey: '$ssh_pub_key'" install-config.yaml; then
        echo "Error: Failed to add SSH public key to install-config.yaml."
        return 1
    fi

    echo "SSH public key added to install-config.yaml."

    return 0
}

create_install_config_backup() {
    # Backup the install-config.yaml file
    timestamp=$(date +"%Y%m%d%H%M%S")
    backup_file="install-config-backup-$timestamp.yaml"
    
    # Perform the backup
    cp "install-config.yaml" "$backup_file"
    if [ $? -eq 0 ]; then
        echo "Backup of install-config.yaml created: $backup_file"
    else
        echo "Error: Failed to create backup of install-config.yaml."
        exit 1
    fi
}

# Function to check if httpd is installed and running
check_httpd() {
    if ! command -v httpd &>/dev/null; then
        echo "Installing httpd..."
        if command -v yum &>/dev/null; then
            sudo yum install -y httpd
        elif command -v apt-get &>/dev/null; then
            sudo apt-get install -y apache2
        else
            echo "Error: Cannot install httpd. Unsupported package manager."
            return 1
        fi
    fi

    # Check if httpd is running
    if ! systemctl is-active --quiet httpd; then
        echo "Starting httpd service..."
        sudo systemctl start httpd || return 1
    fi

    return 0
}

# Function to print outputs of specified commands
print_command_outputs() {
    region="$1"

    # Print infraID from metadata.json
    infraID=$(jq -r .infraID metadata.json)
    echo "infraID: $infraID"

    # Print OpenShift image for the given region
    openshift_image=$(openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.images.aws.regions["'$region'"].image')
    echo "OpenShift Image for $region: $openshift_image"
}

# Check if the install-config.yaml file exists
if [ ! -f "install-config.yaml" ]; then
    echo "Error: install-config.yaml file not found."
    exit 1
fi

# Take user input for region name
read -p "Enter your region name (e.g., ap-south-1): " region_name

add_ssh_key_to_install_config
create_install_config_backup


# Create manifests
if ! openshift-install create manifests --dir=. ; then
    echo "Error: Failed to create manifests."
    exit 1
fi

# Create ignition configs
if ! openshift-install create ignition-configs --dir=. ; then
    echo "Error: Failed to create ignition configs."
    exit 1
fi

# Check and ensure httpd is installed and running
if ! check_httpd ; then
    echo "Error: Failed to check and start httpd."
    exit 1
fi

# Check if /var/www/html/ignitions directory exists
if [ ! -d "/var/www/html/ignitions" ]; then
    if ! sudo mkdir -p /var/www/html/ignitions; then
        echo "Error: Failed to create /var/www/html/ignitions directory."
        exit 1
    fi
fi

# Change permissions of .ign files to 755 and move them to /var/www/html/ignitions
echo "Moving ignition files to /var/www/html/ignitions..."
if ! sudo chmod 755 *.ign || ! sudo mv *.ign /var/www/html/ignitions ; then
    echo "Error: Failed to move ignition files."
    exit 1
fi


# Print command outputs
print_command_outputs "$region_name"

echo "Manifests and Ignition configs created successfully and moved to /var/www/html/ignitions."

