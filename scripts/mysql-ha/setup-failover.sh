#!/bin/bash
#
# MySQL HA Failover Setup Script
# This script sets up the automatic failover system
#

set -e

echo "=========================================="
echo "MySQL HA Failover Setup"
echo "=========================================="

# Check for required tools
echo ""
echo "Checking dependencies..."

if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apt-get update && apt-get install -y jq
fi

if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    apt-get update && apt-get install -y curl
fi

# Create directories
echo ""
echo "Creating directories..."
mkdir -p /etc/mysql-ha
mkdir -p /var/lib/mysql-ha
mkdir -p /var/log

# Copy scripts
echo ""
echo "Installing scripts..."
cp mysql-failover.sh /usr/local/bin/
cp mysql-failover.conf /etc/mysql-ha/
chmod +x /usr/local/bin/mysql-failover.sh

# Create log file
touch /var/log/mysql-failover.log
chmod 644 /var/log/mysql-failover.log

echo ""
echo "=========================================="
echo "Configuration Required"
echo "=========================================="
echo ""
echo "1. Edit /etc/mysql-ha/mysql-failover.conf"
echo "   - Set ROLE (master or slave)"
echo "   - Set THIS_SERVER_IP (Tailscale IP)"
echo "   - Set MASTER_TAILSCALE_IP"
echo "   - Set MySQL credentials"
echo ""
echo "2. Get Cloudflare credentials:"
echo "   a. Create API Token at:"
echo "      https://dash.cloudflare.com/profile/api-tokens"
echo "      Permissions: Zone > DNS > Edit"
echo ""
echo "   b. Get Zone ID from domain overview page"
echo ""
echo "   c. Get DNS Record ID:"
echo "      curl -X GET \"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records\" \\"
echo "        -H \"Authorization: Bearer {API_TOKEN}\" | jq '.result[] | {name, id}'"
echo ""
echo "3. Test the script:"
echo "   /usr/local/bin/mysql-failover.sh"
echo ""
echo "4. Add to cron for automatic monitoring (run every minute):"
echo "   crontab -e"
echo "   */1 * * * * /usr/local/bin/mysql-failover.sh >> /var/log/mysql-failover.log 2>&1"
echo ""
echo "=========================================="

# Function to get Cloudflare DNS record ID
get_cf_record_id() {
    local zone_id="$1"
    local api_token="$2"
    local record_name="$3"

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer ${api_token}" \
        -H "Content-Type: application/json" | \
        jq -r ".result[] | select(.name == \"${record_name}\") | .id"
}

# Offer to configure interactively
echo ""
read -p "Do you want to configure now? (y/n): " configure_now

if [[ "$configure_now" == "y" || "$configure_now" == "Y" ]]; then
    echo ""
    read -p "Server Role (master/slave): " role
    read -p "This server's Tailscale IP: " this_ip
    read -p "Master's Tailscale IP: " master_ip
    read -p "MySQL root password: " mysql_pass

    echo ""
    echo "Cloudflare Configuration:"
    read -p "Cloudflare API Token: " cf_token
    read -p "Zone ID: " zone_id
    read -p "DNS record name (e.g., mysql for mysql.aglz.io): " dns_name

    echo ""
    echo "Fetching DNS Record ID..."
    record_id=$(get_cf_record_id "$zone_id" "$cf_token" "${dns_name}.aglz.io")

    if [[ -z "$record_id" ]]; then
        echo "DNS record not found. You may need to create it first."
        read -p "Enter DNS Record ID manually (or press Enter to skip): " record_id
    else
        echo "Found DNS Record ID: $record_id"
    fi

    # Update config file
    sed -i "s/^ROLE=.*/ROLE=\"${role}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^THIS_SERVER_IP=.*/THIS_SERVER_IP=\"${this_ip}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^MASTER_TAILSCALE_IP=.*/MASTER_TAILSCALE_IP=\"${master_ip}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^MYSQL_PASS=.*/MYSQL_PASS=\"${mysql_pass}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s|^CF_API_TOKEN=.*|CF_API_TOKEN=\"${cf_token}\"|" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^CF_ZONE_ID=.*/CF_ZONE_ID=\"${zone_id}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^CF_RECORD_ID=.*/CF_RECORD_ID=\"${record_id}\"/" /etc/mysql-ha/mysql-failover.conf
    sed -i "s/^CF_DNS_NAME=.*/CF_DNS_NAME=\"${dns_name}\"/" /etc/mysql-ha/mysql-failover.conf

    echo ""
    echo "Configuration saved!"

    # Test the script
    echo ""
    read -p "Test the script now? (y/n): " test_now
    if [[ "$test_now" == "y" || "$test_now" == "Y" ]]; then
        /usr/local/bin/mysql-failover.sh
    fi

    # Add to cron
    echo ""
    read -p "Add to cron for automatic monitoring? (y/n): " add_cron
    if [[ "$add_cron" == "y" || "$add_cron" == "Y" ]]; then
        (crontab -l 2>/dev/null | grep -v "mysql-failover.sh"; echo "*/1 * * * * /usr/local/bin/mysql-failover.sh >> /var/log/mysql-failover.log 2>&1") | crontab -
        echo "Added to crontab!"
        echo "Monitoring will run every minute."
    fi
fi

echo ""
echo "Setup complete!"
echo "Logs: /var/log/mysql-failover.log"
echo "Config: /etc/mysql-ha/mysql-failover.conf"
