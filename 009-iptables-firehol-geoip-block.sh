
||*NOTE*||  Remove any previous script firewall and fail2ban like software if already installed ||*NOTE*||
||*NOTE*||  This script will not work inside any Container Environment ||*NOTE*||


// Install iptables GeoIP addons or plugins //


# Install packages
apt install xtables-addons-common libtext-csv-xs-perl unzip

# Check modules
modprobe xt_geoip
sudo lsmod | grep ^xt_geoip

# Create the directory where the country data should live
mkdir /usr/share/xt_geoip

# Download and install the latest country data
mkdir /tmp/xt_geoip_dl
cd /tmp/xt_geoip_dl

/usr/libexec/xtables-addons/xt_geoip_dl
/usr/libexec/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip *.csv

# Test rules to DROP Singapore
iptables -I INPUT 1 -m geoip --src-cc BR -j DROP	// Test
iptables -nvL										// View
iptables -D INPUT -m geoip --src-cc BR -j DROP		// Remove



######### Automatic script ##########

vim /usr/local/bin/geo-update.sh

____________________________________________________________________________

#!/bin/bash
mkdir -p /tmp/xt_geoip_dl
echo -e "Doing CD TMP \n"
cd /tmp/xt_geoip_dl
sleep 1
echo -e "Downloading \n"
/usr/libexec/xtables-addons/xt_geoip_dl
sleep 1
echo -e "Converting Or Bulding \n"
/usr/libexec/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip *.csv
sleep 2
echo -e "Removing TMP \n"
rm -fr /tmp/xt_geoip_dl
sleep 1
echo -e "Removing Dot CSV TMP \n"
rm -fr /usr/share/xt_geoip/dbip-country-lite.csv
sleep 7
echo -e "Reloading Iptables Rules \n"
manager-netsets.sh reload

____________________________________________________________________________

( Save+Exit )



sudo vim /etc/crontab
@weekly         root    /usr/local/bin/geo-update.sh >/dev/null 2>&1






## manage-netsets.sh #### with GeoIP Block ##
sudo apt -y update
sudo apt -y install curl iptables-persistent ipset nano vim

sudo mkdir -p /etc/ipset

sudo vim /usr/local/bin/manage-netsets.sh





#!/bin/bash

# Optimized Netset management script with GeoIP country blocking
IPSET_DIR="/etc/ipset"
TEMP_DIR="/tmp/netsets"
LOG_FILE="/var/log/netset-manager.log"

# Global list of all managed ipsets
ALL_NETSETS=("firehol_level1" "firehol_level2" "firehol_level3" "spamhaus_drop" "ci_badguys" "et_bl1" "et_bl2" "bl_de1" "bl_agr" "crowdsec_bl" "whitelist_networks" "manual_blacklist")

# GeoIP Configuration
BLOCKED_COUNTRIES="BR,RU,CN,PL,IR"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
## 1. Core Logic Functions
# -----------------------------------------------------------------------------

# Function to create and load a netset (blacklist) from URL
create_netset() {
    local name="$1"
    local url="$2"
    local description="$3"

    log_message "Processing $name: $description"
    mkdir -p "$TEMP_DIR"
    
    # Download netset to a temporary location
    if curl -s --connect-timeout 30 --max-time 120 "$url" -o "$TEMP_DIR/$name.txt"; then
        
        # 1. Ensure the final destination ipset exists first
        ipset create "$name" hash:net hashsize 8192 maxelem 256000 -exist
        
        # 2. Create a temporary ipset and load entries into it
        ipset create "${name}_temp" hash:net hashsize 8192 maxelem 256000 -exist
        
        local count=0
        while read -r line; do
            network=$(echo "$line" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?' | head -1)
            if [[ -n "$network" ]]; then
                # Suppress errors for invalid entries
                ipset add "${name}_temp" "$network" 2>/dev/null && ((count++))
            fi
        done < "$TEMP_DIR/$name.txt"
        
        # 3. Atomically swap and destroy the temporary set
        ipset swap "${name}_temp" "$name" 2>/dev/null
        ipset destroy "${name}_temp" 2>/dev/null
        
        # 4. Save the final ipset
        ipset save "$name" > "$IPSET_DIR/$name.save"
        
        log_message "Loaded $count entries into $name"
    else
        log_message "Failed to download $name from $url"
        return 1
    fi
}

# Function to create and load the whitelist
create_whitelist() {
    local name="whitelist_networks"
    log_message "Creating whitelist: $name"
    
    # Create the ipset for the whitelist
    ipset create "$name" hash:net hashsize 1024 maxelem 10000 -exist
    ipset flush "$name"
    
    local count=0
    
    # Add your trusted networks here. You can add more as needed.
    local hardcoded_nets=(
        "127.0.0.0/8"          # Localhost
        "10.0.0.0/8"           # Private network
        "172.16.0.0/12"        # Private network  
        "192.168.0.0/16"       # Private network
        "8.8.8.8/32"           # Google DNS
        "8.8.4.4/32"           # Google DNS
        "1.1.1.1/32"           # Cloudflare DNS
        "1.0.0.1/32"           # Cloudflare DNS
        "9.9.9.9/32"           # Quad9 DNS
    )
    
    for network in "${hardcoded_nets[@]}"; do
        if ipset add "$name" "$network" 2>/dev/null; then
            ((count++))
        fi
    done
    
    # Save the complete whitelist
    ipset save "$name" > "$IPSET_DIR/$name.save"
    log_message "Created whitelist with $count entries"
}

# Function to create and initialize manual blacklist
create_manual_blacklist() {
    local name="manual_blacklist"
    log_message "Creating manual blacklist: $name"
    
    # Create the ipset for manual blacklist
    ipset create "$name" hash:net hashsize 1024 maxelem 50000 -exist
    
    # Restore existing manual blacklist if saved file exists
    if [[ -f "$IPSET_DIR/$name.save" ]]; then
        ipset restore < "$IPSET_DIR/$name.save" 2>/dev/null
        local count=$(ipset list "$name" | grep -c '^[0-9]')
        log_message "Restored manual blacklist with $count entries"
    else
        log_message "Manual blacklist initialized (empty)"
    fi
}

# Function to setup GeoIP country blocking
setup_geoip_rules() {
    log_message "Setting up GeoIP country blocking"
    
    # Remove existing GeoIP rule if present
    iptables -D INPUT -i ens18 -m geoip --src-cc "$BLOCKED_COUNTRIES" -j DROP 2>/dev/null || true
    
    # Add GeoIP blocking rule (insert at beginning for high priority)
    iptables -I INPUT -i ens18 -m geoip --src-cc "$BLOCKED_COUNTRIES" -j DROP
    
    log_message "Applied GeoIP blocking for countries: $BLOCKED_COUNTRIES"
}

# Function to apply all iptables rules from existing ipsets
apply_all_rules() {
    log_message "Applying all firewall rules with correct precedence"
    
    # Clean old netset-related rules from the chains
    iptables -F INPUT
    iptables -F FORWARD
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    
    # 1. Apply whitelist rules first (highest priority)
    if ipset list "whitelist_networks" >/dev/null 2>&1; then
        iptables -I INPUT 1 -m set --match-set "whitelist_networks" src -j ACCEPT
        log_message "Applied whitelist rules with highest priority"
    fi
    
    # 2. Apply GeoIP country blocking (after whitelist)
    setup_geoip_rules
    
    # 3. Apply manual blacklist rules (high priority, after whitelist and GeoIP)
    if ipset list "manual_blacklist" >/dev/null 2>&1; then
        iptables -A INPUT -m set --match-set "manual_blacklist" src -j DROP
        log_message "Applied manual blacklist rules"
    fi
    
    # 4. Apply blacklist rules (lower priority)
    local blacklists=("firehol_level1" "firehol_level2" "firehol_level3" "spamhaus_drop" "ci_badguys" "et_bl1" "et_bl2" "bl_de1" "bl_agr" "crowdsec_bl")
    
    for blacklist in "${blacklists[@]}"; do
        if ipset list "$blacklist" >/dev/null 2>&1; then
            iptables -A INPUT -m set --match-set "$blacklist" src -j DROP
        fi
    done
    
    log_message "All firewall rules applied successfully"
}

# Function to save current ipset and iptables rules to file
save_rules() {
    log_message "Saving current ipset and iptables rules"
    for set_name in "${ALL_NETSETS[@]}"; do
        if ipset list "$set_name" >/dev/null 2>&1; then
            ipset save "$set_name" > "$IPSET_DIR/$set_name.save"
        fi
    done
    iptables-save > "$IPSET_DIR/iptables.save"
    log_message "All rules saved to disk"
}

# Function to add IP/subnet to whitelist
add_whitelist() {
    local network="$1"
    
    if [[ -z "$network" ]]; then
        echo "Usage: $0 add-whitelist <network>"
        echo "Example: $0 add-whitelist 203.0.113.0/24"
        exit 1
    fi
    
    # Validate network format
    if [[ ! "$network" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        log_message "Invalid network format: $network"
        exit 1
    fi
    
    # Create whitelist if it doesn't exist
    ipset create "whitelist_networks" hash:net hashsize 1024 maxelem 10000 -exist
    
    # Add network to whitelist
    if ipset add "whitelist_networks" "$network" 2>/dev/null; then
        # Save updated whitelist
        ipset save "whitelist_networks" > "$IPSET_DIR/whitelist_networks.save"
        log_message "Added $network to whitelist"
        echo "Successfully added $network to whitelist"
    else
        log_message "Failed to add $network to whitelist (may already exist)"
        echo "Network $network already exists in whitelist or invalid format"
    fi
}

# Function to remove from whitelist
remove_whitelist() {
    local network="$1"
    
    if [[ -z "$network" ]]; then
        echo "Usage: $0 remove-whitelist <network>"
        exit 1
    fi
    
    if ipset test "whitelist_networks" "$network" 2>/dev/null; then
        ipset del "whitelist_networks" "$network"
        ipset save "whitelist_networks" > "$IPSET_DIR/whitelist_networks.save"
        log_message "Removed $network from whitelist"
        echo "Successfully removed $network from whitelist"
    else
        log_message "Network $network not found in whitelist"
        echo "Network $network not found in whitelist"
    fi
}

# Function to show whitelist
show_whitelist() {
    echo "Current Whitelist Networks:"
    if ipset list "whitelist_networks" >/dev/null 2>&1; then
        ipset list "whitelist_networks" | grep -E '^[0-9]+\.' | sort -V
    else
        echo "No whitelist configured"
    fi
}

# -----------------------------------------------------------------------------
## Manual IP Blocking Functions
# -----------------------------------------------------------------------------

# Function to add IP/subnet to manual blacklist
add_manual_block() {
    local network="$1"
    
    if [[ -z "$network" ]]; then
        echo "Usage: $0 block-ip <network>"
        echo "Example: $0 block-ip 192.168.1.100"
        echo "Example: $0 block-ip 203.0.113.0/24"
        exit 1
    fi
    
    # Validate network format
    if [[ ! "$network" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        log_message "Invalid network format: $network"
        echo "Error: Invalid network format: $network"
        exit 1
    fi
    
    # Create manual blacklist if it doesn't exist
    ipset create "manual_blacklist" hash:net hashsize 1024 maxelem 50000 -exist
    
    # Add network to manual blacklist
    if ipset add "manual_blacklist" "$network" 2>/dev/null; then
        # Save updated blacklist
        ipset save "manual_blacklist" > "$IPSET_DIR/manual_blacklist.save"
        log_message "Added $network to manual blacklist"
        echo "Successfully blocked $network"
        
        # Apply rules to make the block effective immediately
        apply_all_rules
    else
        log_message "Failed to add $network to manual blacklist (may already exist)"
        echo "Network $network already exists in manual blacklist or invalid format"
    fi
}

# Function to remove IP/subnet from manual blacklist
remove_manual_block() {
    local network="$1"
    
    if [[ -z "$network" ]]; then
        echo "Usage: $0 unblock-ip <network>"
        echo "Example: $0 unblock-ip 192.168.1.100"
        exit 1
    fi
    
    if ipset test "manual_blacklist" "$network" 2>/dev/null; then
        ipset del "manual_blacklist" "$network"
        ipset save "manual_blacklist" > "$IPSET_DIR/manual_blacklist.save"
        log_message "Removed $network from manual blacklist"
        echo "Successfully unblocked $network"
        
        # Apply rules to make the unblock effective immediately
        apply_all_rules
    else
        log_message "Network $network not found in manual blacklist"
        echo "Network $network not found in manual blacklist"
    fi
}

# Function to show manual blacklist
show_manual_blacklist() {
    echo "Current Manual Blacklist Networks:"
    if ipset list "manual_blacklist" >/dev/null 2>&1; then
        local entries=$(ipset list "manual_blacklist" | grep -E '^[0-9]+\.' | sort -V)
        if [[ -n "$entries" ]]; then
            echo "$entries"
            echo
            echo "Total blocked IPs/networks: $(echo "$entries" | wc -l)"
        else
            echo "No manual blocks configured"
        fi
    else
        echo "No manual blacklist configured"
    fi
}

# Function to check if an IP is blocked
check_ip_status() {
    local ip="$1"
    
    if [[ -z "$ip" ]]; then
        echo "Usage: $0 check-ip <ip>"
        echo "Example: $0 check-ip 192.168.1.100"
        exit 1
    fi
    
    # Validate IP format
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid IP format: $ip"
        exit 1
    fi
    
    echo "Checking status for IP: $ip"
    echo "================================"
    
    # Check whitelist
    if ipset test "whitelist_networks" "$ip" 2>/dev/null; then
        echo "✓ WHITELISTED - This IP is allowed (bypasses all blocks)"
        return 0
    fi
    
    # Check manual blacklist
    if ipset test "manual_blacklist" "$ip" 2>/dev/null; then
        echo "✗ MANUALLY BLOCKED - This IP is in manual blacklist"
        return 0
    fi
    
    # Check other blacklists
    local blocked_in=""
    local blacklists=("firehol_level1" "firehol_level2" "firehol_level3" "spamhaus_drop" "ci_badguys" "et_bl1" "et_bl2" "bl_de1" "bl_agr" "crowdsec_bl")
    
    for blacklist in "${blacklists[@]}"; do
        if ipset list "$blacklist" >/dev/null 2>&1 && ipset test "$blacklist" "$ip" 2>/dev/null; then
            blocked_in="$blocked_in $blacklist"
        fi
    done
    
    if [[ -n "$blocked_in" ]]; then
        echo "✗ BLOCKED - Found in blacklists:$blocked_in"
    else
        echo "○ NOT BLOCKED - IP not found in any blacklists"
        echo "Note: May still be blocked by GeoIP rules for countries: $BLOCKED_COUNTRIES"
    fi
}

# -----------------------------------------------------------------------------
## 2. Command Handlers
# -----------------------------------------------------------------------------

# Function to handle the `update` command
handle_update() {
    log_message "Starting netset update"
    
    # Create and populate whitelist first
    create_whitelist
    
    # Create and initialize manual blacklist
    create_manual_blacklist
    
    # Update blacklists
    create_netset "firehol_level1" "https://iplists.firehol.org/files/firehol_level1.netset" "FireHOL Level1"
    create_netset "firehol_level2" "https://iplists.firehol.org/files/firehol_level2.netset" "FireHOL Level2"
    create_netset "firehol_level3" "https://iplists.firehol.org/files/firehol_level3.netset" "FireHOL Level3"
    create_netset "spamhaus_drop" "https://www.spamhaus.org/drop/drop.txt" "Spamhaus DROP"
    create_netset "ci_badguys" "https://cinsarmy.com/list/ci-badguys.txt" "CI-Badguys"
    create_netset "et_bl1" "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" "ET BLOCK1"
    create_netset "et_bl2" "https://rules.emergingthreats.net/blockrules/compromised-ips.txt" "ET Compro"
    create_netset "bl_de1" "https://lists.blocklist.de/lists/all.txt" "Blsites DE"
    create_netset "bl_agr" "https://feodotracker.abuse.ch/downloads/ipblocklist_aggressive.txt" "BL Aggr"
    create_netset "crowdsec_bl" "http://crowdsecabl.inetsecurity.net:41412/security/blocklist?ipv4only" "CrowdSec BL"

    apply_all_rules
    save_rules

    log_message "Netset update completed"
}

# Function to handle the `restore` command
handle_restore() {
    log_message "Restoring ipsets from saved files"
    for file in "$IPSET_DIR"/*.save; do
        if [[ -f "$file" ]]; then
            ipset restore < "$file"
            log_message "Restored $(basename "$file" .save)"
        fi
    done
    
    apply_all_rules
    save_rules
}

# -----------------------------------------------------------------------------
## 3. Main Execution
# -----------------------------------------------------------------------------

case "$1" in
    "update")
        handle_update
        ;;
    "reload")
        log_message "Reloading firewall rules"
        apply_all_rules
        save_rules
        ;;
    "restore")
        handle_restore
        ;;
    "add-whitelist")
        add_whitelist "$2"
        ;;
    "remove-whitelist")
        remove_whitelist "$2"
        ;;
    "show-whitelist")
        show_whitelist
        ;;
    "block-ip")
        add_manual_block "$2"
        ;;
    "unblock-ip")
        remove_manual_block "$2"
        ;;
    "show-blocked")
        show_manual_blacklist
        ;;
    "check-ip")
        check_ip_status "$2"
        ;;
    "status")
        echo "=== Netset Firewall Status ==="
        echo
        echo "Current IPSets:"
        ipset list -t
        echo
        echo "IPTables Filter Rules:"
        echo "INPUT chain (with line numbers):"
        iptables -L INPUT -n --line-numbers
        echo
        echo "FORWARD chain:"
        iptables -L FORWARD -n --line-numbers | head -10
        echo
        echo "Configuration:"
        echo "Blocked Countries: $BLOCKED_COUNTRIES"
        echo "Blacklist Sources: ${#ALL_NETSETS[@]} ipsets (including CrowdSec + Manual)"
        echo
        show_whitelist
        echo
        show_manual_blacklist
        ;;
    "reset-policy")
        log_message "Resetting iptables to default ACCEPT policy"
        iptables -F INPUT
        iptables -F FORWARD
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        log_message "Firewall reset to allow-all mode"
        ;;
    "save")
        save_rules
        ;;
    *)
        echo "Usage: $0 {update|reload|restore|add-whitelist|remove-whitelist|show-whitelist|block-ip|unblock-ip|show-blocked|check-ip|status|reset-policy|save}"
        echo
        echo "Commands:"
        echo "  update              - Download and apply all blacklists with GeoIP blocking"
        echo "  reload              - Re-apply existing rules with GeoIP blocking"
        echo "  restore             - Restore ipsets from saved files and apply rules"
        echo "  add-whitelist <net> - Add network to whitelist (bypasses all blocks)"
        echo "  remove-whitelist    - Remove network from whitelist"
        echo "  show-whitelist      - Display current whitelist"
        echo "  block-ip <ip/net>   - Manually block specific IP or network"
        echo "  unblock-ip <ip/net> - Remove IP/network from manual blacklist"
        echo "  show-blocked        - Display manually blocked IPs/networks"
        echo "  check-ip <ip>       - Check if an IP is blocked and where"
        echo "  status              - Show current ipsets, iptables rules, and config"
        echo "  reset-policy        - Reset to allow-all policy"
        echo "  save                - Manually save current rules to disk"
        echo
        echo "Configuration:"
        echo "  Blocked Countries: $BLOCKED_COUNTRIES"
        echo "  Blacklist Sources: FireHOL (L1-L3), Spamhaus, CI-Badguys, ET, Blocklist.de, BL-Aggr, CrowdSec, Manual"
        echo
        echo "Rule Priority Order:"
        echo "  1. Whitelist networks (highest priority - always allowed)"
        echo "  2. GeoIP country blocking (blocks: $BLOCKED_COUNTRIES)"
        echo "  3. Manual IP blacklist (user-defined blocks)"
        echo "  4. Automated IP blacklists (10 threat intelligence sources)"
        echo
        echo "Examples:"
        echo "  $0 update                     # Full update with all protections"
        echo "  $0 add-whitelist 203.0.113.5 # Allow specific trusted IP"
        echo "  $0 block-ip 192.168.1.100    # Block specific IP manually"
        echo "  $0 block-ip 10.0.0.0/8       # Block entire network"
        echo "  $0 unblock-ip 192.168.1.100  # Remove IP from manual blacklist"
        echo "  $0 check-ip 8.8.8.8          # Check if IP is blocked"
        echo "  $0 show-blocked               # List all manually blocked IPs"
        echo "  $0 status                     # Check current configuration"
        exit 1
        ;;
esac






chmod +x /usr/local/bin/manage-netsets.sh


sudo vim /etc/systemd/system/netset-manager.service

[Unit]
Description=Netset Manager
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/manage-netsets.sh update
ExecReload=/usr/local/bin/manage-netsets.sh update
StandardOutput=journal
StandardError=journal
User=root

[Install]
WantedBy=multi-user.target

chmod +x /etc/systemd/system/netset-manager.service





sudo vim /etc/systemd/system/netset-manager.timer

[Unit]
Description=Update netsets every day at 2am
Requires=netset-manager.service

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target



chmod +x /etc/systemd/system/netset-manager.timer



sudo systemctl daemon-reload
sudo systemctl enable netset-manager.service
sudo systemctl enable netset-manager.timer
sudo systemctl start netset-manager.timer


sudo systemctl status netset-manager.timer
sudo systemctl status netset-manager.service



sudo systemctl status netset-manager.service		# Check service status 
sudo systemctl status netset-manager.timer			# Check timer status 
sudo journalctl -u netset-manager.service -n 50		# View recent logs 
sudo journalctl -u netset-manager.service -f		# Follow logs in real-time
sudo systemctl start netset-manager.service			# Manual update
sudo systemctl reload netset-manager.service		# Reload rules without updating lists


sudo systemctl list-timers							# List all timers
sudo systemctl list-timers netset-manager.timer		# Check when next update will run
sudo systemctl start netset-manager.timer			# Manually trigger timer


