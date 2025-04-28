#!/bin/bash

# Battery monitoring script for Linux laptops
# Monitors power consumption while charging from external source
# Exits when charging stops (battery runs out)

# Create log file with timestamp
LOG_FILE="battery_monitor_$(date +%Y%m%d_%H%M%S).log"
SUMMARY_FILE="battery_summary_$(date +%Y%m%d_%H%M%S).txt"

echo "Starting battery monitoring..."
echo "Logging to $LOG_FILE"
echo "Press Ctrl+C to stop manually"

# Initialize variables
start_time=$(date +%s)
previous_energy=0
is_charging=false

# Function to check if the laptop is currently charging
check_charging() {
  local status=$(cat /sys/class/power_supply/AC/online 2>/dev/null || 
                 cat /sys/class/power_supply/ADP1/online 2>/dev/null ||
                 cat /sys/class/power_supply/*/online 2>/dev/null | head -n1)
  
  if [ "$status" = "1" ]; then
    return 0  # charging
  else
    return 1  # not charging
  fi
}

# Function to get current power consumption in watts
get_power_consumption() {
  local power=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || 
                cat /sys/class/power_supply/*/power_now 2>/dev/null | head -n1)
  
  # Some systems use current_now and voltage_now instead
  if [ -z "$power" ] || [ "$power" = "0" ]; then
    local current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || 
                    cat /sys/class/power_supply/*/current_now 2>/dev/null | head -n1)
    local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || 
                    cat /sys/class/power_supply/*/voltage_now 2>/dev/null | head -n1)
    
    if [ -n "$current" ] && [ -n "$voltage" ]; then
      power=$(echo "scale=2; $current * $voltage / 1000000000000" | bc)
    fi
  else
    power=$(echo "scale=2; $power / 1000000" | bc)
  fi
  
  echo "$power"
}

# Function to get battery percentage
get_battery_percentage() {
  local capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || 
                   cat /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)
  echo "$capacity"
}

# Function to calculate time difference in human-readable format
format_duration() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))
  printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Wait for charging to begin
echo "Waiting for charging to begin..."
while ! check_charging; do
  sleep 1
done

echo "Charging detected! Monitoring started at $(date)"
is_charging=true
start_time=$(date +%s)

# Write headers to log file
echo "Timestamp,Elapsed_Time,Power_Watts,Battery_Percentage" > "$LOG_FILE"

# Main monitoring loop
total_energy=0
sample_count=0
max_power=0
min_power=999999

while $is_charging; do
  current_time=$(date +%s)
  elapsed_seconds=$((current_time - start_time))
  formatted_time=$(format_duration $elapsed_seconds)
  
  # Get power consumption and battery percentage
  power=$(get_power_consumption)
  battery_percent=$(get_battery_percentage)
  
  # Skip invalid readings
  if [ -n "$power" ] && [ "$power" != "0" ]; then
    # Update statistics
    sample_count=$((sample_count + 1))
    total_energy=$(echo "scale=2; $total_energy + $power" | bc)
    
    # Update min/max power
    if (( $(echo "$power > $max_power" | bc -l) )); then
      max_power=$power
    fi
    
    if (( $(echo "$power < $min_power" | bc -l) )); then
      min_power=$power
    fi
    
    # Log data
    echo "$(date +"%Y-%m-%d %H:%M:%S"),$formatted_time,$power,$battery_percent" >> "$LOG_FILE"
    
    # Display current stats
    echo -ne "Runtime: $formatted_time | Current Power: ${power}W | Battery: ${battery_percent}%\r"
  fi
  
  # Check if still charging
  if ! check_charging; then
    echo -e "\nCharging stopped! Battery likely ran out."
    is_charging=false
  fi
  
  sleep 10  # Sample every 10 seconds
done

end_time=$(date +%s)
total_runtime=$((end_time - start_time))
formatted_total_time=$(format_duration $total_runtime)

# Calculate statistics
if [ $sample_count -gt 0 ]; then
  avg_power=$(echo "scale=2; $total_energy / $sample_count" | bc)
  total_energy_wh=$(echo "scale=2; $avg_power * $total_runtime / 3600" | bc)
else
  avg_power="0"
  total_energy_wh="0"
fi

# Generate summary
echo "======= Battery Monitor Summary =======" > "$SUMMARY_FILE"
echo "Date: $(date +"%Y-%m-%d")" >> "$SUMMARY_FILE"
echo "Start Time: $(date -d @$start_time +"%H:%M:%S")" >> "$SUMMARY_FILE"
echo "End Time: $(date -d @$end_time +"%H:%M:%S")" >> "$SUMMARY_FILE"
echo "Total Runtime: $formatted_total_time" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"
echo "Average Power Consumption: ${avg_power}W" >> "$SUMMARY_FILE"
echo "Minimum Power: ${min_power}W" >> "$SUMMARY_FILE"
echo "Maximum Power: ${max_power}W" >> "$SUMMARY_FILE"
echo "Total Energy Used: ${total_energy_wh}Wh" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"
echo "Detailed log saved to: $LOG_FILE" >> "$SUMMARY_FILE"

# Display summary
cat "$SUMMARY_FILE"
echo "Monitoring complete!"
