#!/bin/bash
#
# MAC Address OUI Lookup Tool
# Identifies device manufacturer from MAC address
#
# Usage: ./mac-lookup.sh <MAC_ADDRESS>
#

MAC="${1:-}"

if [ -z "$MAC" ]; then
    echo "Usage: $0 <MAC_ADDRESS>"
    echo "Example: $0 00:31:92:dc:3e:f8"
    exit 1
fi

# Extract OUI (first 3 octets)
OUI=$(echo "$MAC" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]' | tr -d ':')

echo "MAC Address: $MAC"
echo "OUI: $OUI"
echo ""

# Try online lookup via macvendors.com API
echo "Looking up manufacturer..."
VENDOR=$(curl -s "https://api.macvendors.com/${MAC}" 2>/dev/null)

if [ -n "$VENDOR" ] && [ "$VENDOR" != "Not Found" ]; then
    echo "Manufacturer: $VENDOR"
else
    # Try local lookup if ieee-data package is installed
    if [ -f /usr/share/ieee-data/oui.txt ]; then
        VENDOR=$(grep -i "$OUI" /usr/share/ieee-data/oui.txt | head -1)
        if [ -n "$VENDOR" ]; then
            echo "Manufacturer (local): $VENDOR"
        else
            echo "Manufacturer: Unknown (OUI not found)"
        fi
    else
        echo "Manufacturer: Unknown (install ieee-data package for offline lookup)"
    fi
fi

# Known switch/router OUIs
case "$OUI" in
    003192)
        echo ""
        echo "Note: This OUI (00:31:92) is commonly associated with:"
        echo "  - Realtek-based devices"
        echo "  - Generic embedded systems"
        echo "  - Some managed switches"
        ;;
    000EC4|001122|0050C2)
        echo ""
        echo "Note: This OUI may be associated with OMAY switches!"
        ;;
esac
