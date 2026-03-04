#!/bin/bash
# mail-user.sh - Manage virtual mail users for Postfix + Dovecot
# Supports add, update, reset-password, remove
# Multi-domain aware (e.g. domain.com, domain.in)

PASSWD_FILE="/etc/dovecot/passwd"
VMAILBOX_FILE="/etc/postfix/vmailbox"
VMAILDIR="/var/mail/vhosts"
VM_UID=5000
VM_GID=5000

usage() {
    echo "Usage:"
    echo "  $0 user@domain password                # Add new user"
    echo "  $0 --reset-password user@domain newpassword   # Reset password only"
    echo "  $0 --remove user@domain                # Remove user completely"
    echo "  $0 --list-users domain                # Lists all the users based on domain"
    exit 1
}

add_user() {
    local email=$1
    local password=$2
    local user=$(echo $email | cut -d'@' -f1)
    local domain=$(echo $email | cut -d'@' -f2)

    echo "Adding new user: $email"

    # Hash password
    hashed=$(doveadm pw -s SHA512-CRYPT -p "$password")

    # Add/update in passwd file
    grep -q "^$email:" $PASSWD_FILE && \
        sed -i "s|^$email:.*|$email:$hashed::::::|" $PASSWD_FILE || \
        echo "$email:$hashed::::::" >> $PASSWD_FILE

    # Add to vmailbox if missing
    grep -q "^$email" $VMAILBOX_FILE || echo "$email    $domain/$user/" >> $VMAILBOX_FILE

    # Create maildir if missing
    if [ ! -d "$VMAILDIR/$domain/$user" ]; then
        mkdir -p $VMAILDIR/$domain/$user/{cur,new,tmp,.Sent,.Drafts,.Trash,.Junk}
        chown -R vmail:vmail $VMAILDIR/$domain/$user
        chmod -R 700 $VMAILDIR/$domain/$user
    fi

    # Update postfix maps
    postmap $VMAILBOX_FILE
    systemctl reload postfix dovecot

    echo "User $email added successfully."
}

#update_password() {
#    local email=$1
#    local password=$2
#    local user=$(echo $email | cut -d'@' -f1)
#    local domain=$(echo $email | cut -d'@' -f2)

#    echo "Updating password for: $email"
#    hashed=$(doveadm pw -s SHA512-CRYPT -p "$password")

#    if grep -q "^$email:" $PASSWD_FILE; then
#        sed -i "s|^$email:.*|$email:$hashed::::::|" $PASSWD_FILE
#    else
#        echo "$email:$hashed::::::" >> $PASSWD_FILE
#    fi

#    # Ensure mailbox entry exists
#    grep -q "^$email" $VMAILBOX_FILE || echo "$email    $domain/$user/" >> $VMAILBOX_FILE

#    postmap $VMAILBOX_FILE
#    systemctl reload postfix dovecot

#    echo "Password updated for $email"
#}

reset_password() {
    local email=$1
    local password=$2

    echo "Resetting password for: $email"
    hashed=$(doveadm pw -s SHA512-CRYPT -p "$password")

    if grep -q "^$email:" $PASSWD_FILE; then
        sed -i "s|^$email:.*|$email:$hashed::::::|" $PASSWD_FILE
    else
        echo "$email:$hashed::::::" >> $PASSWD_FILE
    fi

    systemctl reload dovecot
    echo "Password reset done for $email"
}

remove_user() {
    local email=$1
    local user=$(echo $email | cut -d'@' -f1)
    local domain=$(echo $email | cut -d'@' -f2)

    echo "Removing user: $email"

    # Remove from passwd file
    sed -i "/^$email:/d" $PASSWD_FILE

    # Remove from vmailbox
    sed -i "/^$email[[:space:]]/d" $VMAILBOX_FILE

    # Delete mailbox directory
    rm -rf $VMAILDIR/$domain/$user

    postmap $VMAILBOX_FILE
    systemctl reload postfix dovecot

    echo "User $email removed successfully."
}

list_users() {
    local domain1=$1
    local domain2=$2

    #List list of users
    echo "List of email users:"
    echo "--------------------"
    cat /etc/postfix/vmailbox |awk '{print $1}'|grep -E -i "$domain1|$domain2"
}

# --- Main ---
if [ $# -lt 2 ]; then
    usage
fi

case "$1" in
    #--update)
    #    [ $# -eq 3 ] || usage
    #    update_password "$2" "$3"
    #    ;;
    --list-users)
        list_users
        ;;
    --reset-password)
        [ $# -eq 3 ] || usage
        reset_password "$2" "$3"
        ;;
    --remove)
        [ $# -eq 2 ] || usage
        remove_user "$2"
        ;;
    *)
        [ $# -eq 2 ] || usage
        add_user "$1" "$2"
        ;;
esac
