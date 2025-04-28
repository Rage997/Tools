#!/bin/bash

# Ubuntu Battery Monitoring Script with fixed method detection
# Monitors total power consumption while charging from external source
# Exits when charging stops (battery runs out)

# Create log file with timestamp
LOG_FILE="battery_monitor_$(date +%Y%m%d_%H%M%S).log"
SUMMARY_FILE="battery_summary_$(date +%Y%m%d_%H%M%S).txt"

echo "Starting battery monitoring..."
echo "Logging to $LOG_FILE"
echo "Press Ctrl+C to stop manually"

# Initialize variables
start_time=$(date +%s)
previous_time=$start_time
total_energy_wh=0
is_charging=false
system_power_method="unknown"

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

# Function to get system power consumption in watts using multiple methods
get_system_power_consumption() {
  # You can force a specific method by uncommenting one of these lines:
  # METHOD="power_now"
  # METHOD="current_voltage"
  # METHOD="upower"
  # METHOD="rapl" 
  # METHOD="sensors"
  # METHOD="estimate"
  
  # If method is specified, use that method only
  if [ -n "$METHOD" ]; then
    case $METHOD in
      "power_now")
        local power_now=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || 
                         cat /sys/class/power_supply/*/power_now 2>/dev/null | head -n1)
        if [ -n "$power_now" ]; then
          system_power_method="power_now"
          echo "scale=2; $power_now / 1000000" | bc
          return
        fi
        ;;
      "current_voltage")
        local current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || 
                       cat /sys/class/power_supply/*/current_now 2>/dev/null | head -n1)
        local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || 
                       cat /sys/class/power_supply/*/voltage_now 2>/dev/null | head -n1)
        if [ -n "$current" ] && [ -n "$voltage" ]; then
          system_power_method="current_voltage"
          echo "scale=2; $current * $voltage / 1000000000000" | bc
          return
        fi
        ;;
      "upower")
        if command -v upower &> /dev/null; then
          local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep "energy-rate" | awk '{print $2}')
          if [ -n "$energy_rate" ]; then
            system_power_method="upower"
            echo "$energy_rate"
            return
          fi
        fi
        ;;
      "rapl")
        local rapl_files=$(find /sys/class/powercap/intel-rapl/intel-rapl:0/ -name energy_uj 2>/dev/null)
        if [ -n "$rapl_files" ]; then
          local start_energy=$(cat $rapl_files)
          sleep 1
          local end_energy=$(cat $rapl_files)
          local energy_diff=$((end_energy - start_energy))
          if [ $energy_diff -gt 0 ]; then
            local rapl_power=$(echo "scale=2; $energy_diff / 1000000" | bc)
            system_power_method="rapl"
            echo "$rapl_power"
            return
          fi
        fi
        ;;
      "sensors")
        if command -v sensors &> /dev/null; then
          local cpu_power=$(sensors | grep -i "power" | head -n1 | awk '{print $4}' | tr -d 'W')
          if [ -n "$cpu_power" ]; then
            system_power_method="sensors"
            echo "$cpu_power"
            return
          fi
        fi
        ;;
      "estimate")
        system_power_method="estimate"
        echo "15"
        return
        ;;
    esac
    
    # If forced method failed, fall back to estimate
    system_power_method="estimate_fallback"
    echo "15"
    return
  fi
  
  # Method 1: Direct power_now reading
  local power_now=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || 
                   cat /sys/class/power_supply/*/power_now 2>/dev/null | head -n1)
  
  if [ -n "$power_now" ] && [ "$power_now" != "0" ]; then
    system_power_method="power_now"
    echo "scale=2; $power_now / 1000000" | bc
    return
  fi
  
  # Method 2: Using current_now and voltage_now
  local current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || 
                 cat /sys/class/power_supply/*/current_now 2>/dev/null | head -n1)
  local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || 
                 cat /sys/class/power_supply/*/voltage_now 2>/dev/null | head -n1)
  
  if [ -n "$current" ] && [ -n "$voltage" ] && [ "$current" != "0" ]; then
    system_power_method="current_voltage"
    echo "scale=2; $current * $voltage / 1000000000000" | bc
    return
  fi
  
  # Method 3: Using upower if available
  if command -v upower &> /dev/null; then
    local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep "energy-rate" | awk '{print $2}')
    if [ -n "$energy_rate" ] && [ "$energy_rate" != "0" ]; then
      system_power_method="upower"
      echo "$energy_rate"
      return
    fi
  fi
  
  # Method 4: Using RAPL interface if available (Intel CPUs)
  local rapl_files=$(find /sys/class/powercap/intel-rapl/intel-rapl:0/ -name energy_uj 2>/dev/null)
  
  if [ -n "$rapl_files" ]; then
    # Need to take two measurements and calculate difference
    local start_energy=$(cat $rapl_files)
    sleep 1
    local end_energy=$(cat $rapl_files)
    local energy_diff=$((end_energy - start_energy))
    
    if [ $energy_diff -gt 0 ]; then
      local rapl_power=$(echo "scale=2; $energy_diff / 1000000" | bc)
      system_power_method="rapl"
      echo "$rapl_power"
      return
    fi
  fi
  
  # Method 5: Try to get CPU power using sensors if available
  if command -v sensors &> /dev/null; then
    local cpu_power=$(sensors | grep -i "power" | head -n1 | awk '{print $4}' | tr -d 'W')
    if [ -n "$cpu_power" ] && [ "$cpu_power" != "0" ]; then
      system_power_method="sensors"
      echo "$cpu_power"
      return
    fi
  fi
  
  # Method 6: Use a simple heuristic based on your laptop model
  # This will check if it's likely a gaming laptop with high-end CPU
  if command -v lscpu &> /dev/null; then
    local cpu_model=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    
    if [[ $cpu_model == *"i9"* ]] || [[ $cpu_model == *"i7"* ]] || [[ $cpu_model == *"Ryzen 7"* ]] || [[ $cpu_model == *"Ryzen 9"* ]]; then
      system_power_method="cpu_heuristic"
      echo "25"  # High-end CPU
    else
      system_power_method="cpu_heuristic"
      echo "15"  # Standard CPU
    fi
    return
  fi
  
  # If all methods failed, use a reasonable estimate for system power
  system_power_method="estimate"
  echo "15"
}

# Function to get GPU power consumption in watts. It works only with NVIDIA GPUs
get_gpu_power_consumption() {
  if command -v nvidia-smi &> /dev/null; then
    local gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
    if [ -n "$gpu_power" ]; then
      echo "$gpu_power"
    else
      echo "0"
    fi
  else
    echo "0"
  fi
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

# Debug function to show available power measurement methods
debug_power_methods() {
  echo "Debugging power measurement methods:"
  
  echo -n "1. power_now: "
  if [ -e /sys/class/power_supply/BAT0/power_now ]; then
    echo "Available - $(cat /sys/class/power_supply/BAT0/power_now) μW"
  else
    echo "Not available"
  fi
  
  echo -n "2. current_now/voltage_now: "
  if [ -e /sys/class/power_supply/BAT0/current_now ] && [ -e /sys/class/power_supply/BAT0/voltage_now ]; then
    echo "Available - $(cat /sys/class/power_supply/BAT0/current_now) μA, $(cat /sys/class/power_supply/BAT0/voltage_now) μV"
  else
    echo "Not available"
  fi
  
  echo -n "3. upower: "
  if command -v upower &> /dev/null; then
    echo "Available - $(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep 'energy-rate' || echo 'No energy-rate info')"
  else
    echo "Not available (upower not installed)"
  fi
  
  echo -n "4. RAPL interface: "
  if [ -d /sys/class/powercap/intel-rapl ]; then
    echo "Available - $(find /sys/class/powercap/intel-rapl -name energy_uj | wc -l) energy monitors"
  else
    echo "Not available"
  fi
  
  echo -n "5. lm-sensors: "
  if command -v sensors &> /dev/null; then
    echo "Available - $(sensors | grep -i 'power' || echo 'No power sensors detected')"
  else
    echo "Not available (lm-sensors not installed)"
  fi
}

# Wait for charging to begin
echo "Waiting for charging to begin..."
while ! check_charging; do
  sleep 1
done

echo "Charging detected! Monitoring started at $(date)"
is_charging=true
start_time=$(date +%s)
previous_time=$start_time

# Run debug to show available methods
debug_power_methods

# Test system power measurement
system_power=$(get_system_power_consumption)
echo "System power measurement method: $system_power_method"
echo "Initial system power reading: ${system_power}W"

# Write headers to log file
echo "Timestamp,Elapsed_Time,System_Power_W,GPU_Power_W,Total_Power_W,Energy_Wh,Battery_Percentage,PowerMethod" > "$LOG_FILE"

# Main monitoring loop
sample_count=0
max_power=0
min_power=999999

while $is_charging; do
  current_time=$(date +%s)
  elapsed_seconds=$((current_time - start_time))
  formatted_time=$(format_duration $elapsed_seconds)
  
  # Get power consumption and battery percentage
  system_power=$(get_system_power_consumption)
  gpu_power=$(get_gpu_power_consumption)
  total_power=$(echo "scale=2; $system_power + $gpu_power" | bc)
  battery_percent=$(get_battery_percentage)
  
  # Skip invalid readings
  if [ -n "$total_power" ] && [ "$total_power" != "0" ]; then
    # Update statistics
    time_diff=$((current_time - previous_time))
    energy_this_interval=$(echo "scale=4; $total_power * $time_diff / 3600" | bc)
    total_energy_wh=$(echo "scale=2; $total_energy_wh + $energy_this_interval" | bc)

    sample_count=$((sample_count + 1))

    # Update min/max power
    if (( $(echo "$total_power > $max_power" | bc -l) )); then
      max_power=$total_power
    fi
    
    if (( $(echo "$total_power < $min_power" | bc -l) )); then
      min_power=$total_power
    fi
    
    # Log data
    echo "$(date +"%Y-%m-%d %H:%M:%S"),$formatted_time,$system_power,$gpu_power,$total_power,$total_energy_wh,$battery_percent,$system_power_method" >> "$LOG_FILE"
    
    # Display current stats with power method
    echo -ne "Runtime: $formatted_time | System: ${system_power}W (${system_power_method}) | GPU: ${gpu_power}W | Total: ${total_power}W | Energy: ${total_energy_wh}Wh | Battery: ${battery_percent}%    \r"
    
    # Update previous time for next interval
    previous_time=$current_time
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

# Calculate average power
if [ $total_runtime -gt 0 ]; then
  avg_power=$(echo "scale=2; $total_energy_wh * 3600 / $total_runtime" | bc)
else
  avg_power="0"
fi

# Generate summary
echo "======= Battery Monitor Summary =======" > "$SUMMARY_FILE"
echo "Date: $(date +"%Y-%m-%d")" >> "$SUMMARY_FILE"
echo "Start Time: $(date -d @$start_time +"%H:%M:%S")" >> "$SUMMARY_FILE"
echo "End Time: $(date -d @$end_time +"%H:%M:%S")" >> "$SUMMARY_FILE"
echo "Total Runtime: $formatted_total_time" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"
echo "System Power Measurement Method: $system_power_method" >> "$SUMMARY_FILE"
echo "Average Power Consumption: ${avg_power}W" >> "$SUMMARY_FILE"
echo "Minimum Power: ${min_power}W" >> "$SUMMARY_FILE"
echo "Maximum Power: ${max_power}W" >> "$SUMMARY_FILE"
echo "Total Energy Used: ${total_energy_wh}Wh" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"
echo "Detailed log saved to: $LOG_FILE" >> "$SUMMARY_FILE"

# Display summary
cat "$SUMMARY_FILE"
echo "Monitoring complete!"