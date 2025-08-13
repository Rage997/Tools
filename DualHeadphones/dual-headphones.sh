#!/bin/bash
# dual-headphones.sh - Combine two Bluetooth headphones into one output on Ubuntu 25

# Get all connected Bluetooth sinks
BT_SINKS=$(pactl list short sinks | awk '/bluez_output/ {print $2}')

# Check if we have at least two
COUNT=$(echo "$BT_SINKS" | wc -l)
if [ "$COUNT" -lt 2 ]; then
    echo "Error: Found only $COUNT Bluetooth sink(s). Connect two headphones first."
    echo "Connected sinks:"
    echo "$BT_SINKS"
    exit 1
fi

# Get the first two sinks
SINK1=$(echo "$BT_SINKS" | sed -n '1p')
SINK2=$(echo "$BT_SINKS" | sed -n '2p')

echo "Creating combined sink for:"
echo " - $SINK1"
echo " - $SINK2"

# Remove previous combined sink if it exists
pactl unload-module module-combine-sink 2>/dev/null

# Create new combined sink
pactl load-module module-combine-sink slaves="$SINK1,$SINK2" sink_name=dual_sink
pactl set-default-sink dual_sink

echo "✅ Combined sink 'dual_sink' created and set as default."
echo "Now play your movie — audio will go to both headphones."

