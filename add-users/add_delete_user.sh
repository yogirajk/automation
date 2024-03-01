#!/bin/bash

# Function to add a user to the htpasswd file
add_user() {
    local username=$1
    local password=$2
    htpasswd -bB users.htpasswd "$username" "$password"
}

# Function to delete a user from the htpasswd file
delete_user() {
    local username=$1
    sed -i "/^$username:/d" users.htpasswd
}

# Function to create or update the htpass-secret secret
create_secret() {
    oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f -
}

# Ensure the users.htpasswd file exists
touch users.htpasswd

# Get the existing htpasswd data
oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 --decode > users.htpasswd

# Prompt user for action (add/delete)
while true; do
    read -p "Do you want to add (a) or delete (d) users? (a/d): " action
    case $action in
        [Aa]* )
            # Prompt user for username and password pairs to add
            while true; do
                read -p "Enter username (leave blank to finish): " username
                if [ -z "$username" ]; then
                    break
                fi
                read -s -p "Enter password for $username: " password
                echo
                add_user "$username" "$password"
                echo "Added user: $username"
            done
            break
            ;;
        [Dd]* )
            # Prompt user for username to delete
            while true; do
                read -p "Enter username to delete (leave blank to finish): " username
                if [ -z "$username" ]; then
                    break
                fi
                delete_user "$username"
                echo "Deleted user: $username"
            done
            break
            ;;
        * )
            echo "Please enter 'a' to add users or 'd' to delete users."
            ;;
    esac
done

# Create or update the htpass-secret secret
create_secret

echo "Users updated successfully."
