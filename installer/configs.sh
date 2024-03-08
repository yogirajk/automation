#!/bin/bash

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
            exit 1
        fi
    fi

    # Check if httpd is running
    if ! systemctl is-active --quiet httpd; then
        echo "Starting httpd service..."
        sudo systemctl start httpd
    fi
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

# Create manifests
openshift-install create manifests --dir=.

# Create ignition configs
openshift-install create ignition-configs --dir=.

# Check and ensure httpd is installed and running
check_httpd

# Check if /var/www/html/ignitions directory exists
if [ ! -d "/var/www/html/ignitions" ]; then
    sudo mkdir -p /var/www/html/ignitions
fi

# Change permissions of .ign files to 755 and move them to /var/www/html/ignitions
echo "Moving ignition files to /var/www/html/ignitions..."
sudo chmod 755 *.ign
sudo mv *.ign /var/www/html/ignitions

# Print command outputs
print_command_outputs "$region_name"

echo "Manifests and Ignition configs created successfully and moved to /var/www/html/ignitions."

