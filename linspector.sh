#!/bin/bash

echo " =============== LINSPECTOR STARTING =============== "
echo

show_cpu_status()
{
  echo " ------- CPU STATUS ------- "

  model_name=$(lscpu | grep 'Model name:' | sed 's/Model name:\s*//')

  logical_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
  sockets=$(lscpu | grep '^Socket(s):' | awk '{print $2}')
  cores_per_socket=$(lscpu | grep '^Core(s) per socket:' | awk '{print $4}')
  physical_cores="Could not be calculated!!!"
  if [[ "$sockets" =~ ^[0-9]+$ ]] && [[ "$cores_per_socket" =~ ^[0-9]+$ ]]; then
    physical_cores=$((sockets * cores_per_socket))
  fi

  cpu_usage="Could not be calculated!!!"

  if command -v mpstat &> /dev/null; then
      idle_raw=$(LC_ALL=C mpstat 1 1 | awk 'NR>1 && /all/ {print $NF}')
      read -r idle <<< "$idle_raw"
      if [[ "$idle" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          cpu_usage=$(LC_ALL=C awk -v idle="$idle" 'BEGIN { printf "%.1f%%", 100 - idle }')
      else
          if command -v top &> /dev/null; then
            idle_raw=$(LC_ALL=C top -bn1 | grep '%Cpu(s):' | sed 's/.*,\s*\([0-9.]*\)\s*%id.*/\1/' | head -n 1)
            read -r idle <<< "$idle_raw"
            if [[ "$idle" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                cpu_usage=$(LC_ALL=C awk -v idle="$idle" 'BEGIN { printf "%.1f%%", 100 - idle }')
            fi
          fi
      fi
  elif command -v top &> /dev/null; then
      idle_raw=$(LC_ALL=C top -bn1 | grep '%Cpu(s):' | sed 's/.*,\s*\([0-9.]*\)\s*%id.*/\1/' | head -n 1)
      read -r idle <<< "$idle_raw"
      if [[ "$idle" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          cpu_usage=$(LC_ALL=C awk -v idle="$idle" 'BEGIN { printf "%.1f%%", 100 - idle }')
      fi
  fi
  if [[ "$cpu_usage" == "Could not be calculated!!!" ]]; then
      cpu_usage=" (need mpstat/top or failed to print output.)"
  fi

  cpu_temp="Not Taken"
  temp_found=0
  if command -v sensors &> /dev/null; then
      sensor_output=$(LC_ALL=C sensors)
      pkg_temp=$(echo "$sensor_output" | grep -iE '^(Package id 0|Composite|Tdie|Tctl):' | head -n 1 | awk '{print $NF}' | sed 's/+//;s/°C//')
      core0_temp=$(echo "$sensor_output" | grep -iE '^Core 0:' | head -n 1 | awk '{print $3}' | sed 's/+//;s/°C//')
      generic_temp=$(echo "$sensor_output" | grep -iE 'temp1_input:|Physical id 0:' | head -n 1 | awk '{print $2}' | sed 's/+//;s/°C//')
      if [[ "$pkg_temp" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          cpu_temp="${pkg_temp}°C (Package/Composite)"
          temp_found=1
      elif [[ "$core0_temp" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          cpu_temp="${core0_temp}°C (Core 0)"
          temp_found=1
      elif [[ "$generic_temp" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          cpu_temp="${generic_temp}°C (General Sensor)"
          temp_found=1
      fi
      if [ $temp_found -eq 0 ] && [ -n "$sensor_output" ]; then
          cpu_temp="Not Taken (Unexpected Format)"
      elif [ $temp_found -eq 0 ]; then
          cpu_temp="Not Taken (Could not read sensors.)"
      fi
  fi
  if [ $temp_found -eq 0 ] && [ -d /sys/class/thermal ]; then
      for zone in /sys/class/thermal/thermal_zone*; do
        if [ -r "${zone}/type" ] && [ -r "${zone}/temp" ]; then
          type=$(cat "${zone}/type")
          temp_mC=$(cat "${zone}/temp")
          if [[ "$type" == *"x86_pkg_temp"* || "$type" == *"cpu"* || "$type" == "acpitz"* ]]; then
              if [[ "$temp_mC" =~ ^[0-9]+$ ]]; then
                  temp_C=$(LC_ALL=C awk -v temp="$temp_mC" 'BEGIN { printf "%.1f", temp / 1000 }')
                  cpu_temp="${temp_C}°C (${type})"
                  temp_found=1
                  break
              fi
          fi
        fi
      done
      if [ $temp_found -eq 0 ]; then
        cpu_temp="Not Taken (under "/sys/class/thermal" no CPU sensor.)"
      fi
  fi
  if [ $temp_found -eq 0 ] && ! command -v sensors &> /dev/null; then
      cpu_temp="Not Taken (lm-sensors not setup?)"
  elif [ $temp_found -eq 0 ]; then
      cpu_temp="Not Taken (Sensor might not be configured? Try 'sudo sensors-detect')"
  fi

  current_mhz=""
  max_mhz=$(lscpu | grep 'CPU MAX MHz:' | awk '{print $4}')

  current_mhz=$(lscpu | grep 'CPU MHz:' | awk '{print $3}')

  if ! [[ "$current_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
          current_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
          if [[ "$current_khz" =~ ^[0-9]+$ ]]; then
              current_mhz=$(awk -v khz="$current_khz" 'BEGIN { printf "%.2f", khz / 1000 }')
          fi
      fi
  fi

  if ! [[ "$current_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      current_mhz=$(LC_ALL=C grep 'cpu MHz' /proc/cpuinfo | head -n 1 | awk '{print $NF}')
  fi

  if ! [[ "$max_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ]; then
          max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
          if [[ "$max_khz" =~ ^[0-9]+$ ]]; then
              max_mhz=$(awk -v khz="$max_khz" 'BEGIN { printf "%.2f", khz / 1000 }')
          fi
    elif [ -r /proc/cpuinfo ]; then
          max_mhz=$(LC_ALL=C grep 'cpu MHz' /proc/cpuinfo | awk '{print $NF}' | sort -nr | head -n 1)
    fi
  fi

  current_ghz="N/A"
  max_ghz="N/A"

  if [[ "$current_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      current_mhz_dot=$(echo "$current_mhz" | sed 's/,/./')
      current_ghz=$(LC_ALL=C awk -v mhz="$current_mhz_dot" 'BEGIN { printf "%.2f GHz", mhz / 1000 }')
  fi
  if [[ "$max_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      max_mhz_dot=$(echo "$max_mhz" | sed 's/,/./')
      max_ghz=$(LC_ALL=C awk -v mhz="$max_mhz_dot" 'BEGIN { printf "%.2f GHz", mhz / 1000 }')
  fi

  echo "CPU Model                 : ${model_name:-Getting Information Failed}"
  echo "CPU Core Amount           : ${logical_cores:-NONE} Logical / ${physical_cores:-NONE} Physical"
  echo "Instantaneous Usage       : $cpu_usage"
  echo "Instantaneous Temperature : $cpu_temp"
  echo "Instantaneous Speed       : $current_ghz"
  echo "Maximum Speed             : $max_ghz"
}

show_ram_status()
{
  echo " ------- RAM & SWAP STATUS ------- "

  if ! command -v free &> /dev/null; then
    echo "RAM/Swap Usage    : N/A ('free' command not found)"
    if [ -r /proc/meminfo ]; then
      local total_kb total_mb
      total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
      if [[ "$total_kb" =~ ^[0-9]+$ ]]; then
        total_mb=$((total_kb / 1024))
        echo "Total RAM (approx): ${total_mb} MiB (from /proc/meminfo)"
      fi
    fi
    echo " --------------------------- "
    return 1
  fi

  local mem_info
  mem_info=$(LC_ALL=C free -m)

  local total_ram free_ram buff_cache_ram available_ram effectively_used_ram ram_usage_percent
  total_ram=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')
  free_ram=$(echo "$mem_info" | awk '/^Mem:/ {print $4}')
  buff_cache_ram=$(echo "$mem_info" | awk '/^Mem:/ {print $6}')
  available_ram=$(echo "$mem_info" | awk '/^Mem:/ {print $7}')

  if [[ ! "$total_ram" =~ ^[0-9]+$ ]]; then
      echo "RAM Usage         : N/A (Failed to parse 'free' output)"
  else
      effectively_used_ram=$((total_ram - available_ram))
      ram_usage_percent="0.0%"
      if [[ "$total_ram" -gt 0 ]]; then
          ram_usage_percent=$(awk -v total="$total_ram" -v available="$available_ram" \
                               'BEGIN {if (total > 0) printf "%.1f%%", ((total-available)/total)*100; else print "0.0%"}')
      fi
      echo "RAM - Total               : ${total_ram} MiB"
      echo "RAM - Available           : ${available_ram} MiB (Ready for new applications)"
      echo "RAM - Used                : ${effectively_used_ram} MiB (${ram_usage_percent})"
      echo "RAM - Buff/Cache          : ${buff_cache_ram} MiB (Used by system, mostly reclaimable)"
  fi

  local total_swap used_swap swap_usage_percent="0.0%"
  if echo "$mem_info" | grep -q '^Swap:'; then
      total_swap=$(echo "$mem_info" | awk '/^Swap:/ {print $2}')
      used_swap=$(echo "$mem_info" | awk '/^Swap:/ {print $3}')

      if [[ ! "$total_swap" =~ ^[0-9]+$ ]]; then
           echo "Swap Usage        : N/A (Failed to parse Swap info)"
      elif [[ "$total_swap" -eq 0 ]]; then
           echo "Swap Usage        : Not Configured (Total: 0 MiB)"
      else
          if [[ "$used_swap" =~ ^[0-9]+$ ]]; then
              swap_usage_percent=$(awk -v used="$used_swap" -v total="$total_swap" \
                                   'BEGIN {if (total > 0) printf "%.1f%%", (used/total)*100; else print "0.0%"}')
          fi
          echo "Swap - Total              : ${total_swap} MiB"
          echo "Swap - Used               : ${used_swap} MiB (${swap_usage_percent}) [High usage indicates RAM pressure!]"
      fi
  else
      echo "Swap Usage        : Not Reported by 'free'"
  fi

  echo
  echo " ------- RAM Hardware Details ------- "

  local ram_type="N/A"
  local ram_speed="N/A"
  local ram_slots_filled="N/A"
  local ram_manufacturer="N/A"

  if command -v dmidecode &> /dev/null; then
    local dmidecode_output dmidecode_error exit_code_dmidecode
    dmidecode_output=$(timeout 5 sudo dmidecode -t memory 2>&1)
    exit_code_dmidecode=$?

    if [ $exit_code_dmidecode -ne 0 ]; then
        echo "RAM Hardware Info : N/A (sudo dmidecode failed or timed out. Code: ${exit_code_dmidecode})"
    elif [ -z "$dmidecode_output" ]; then
        echo "RAM Hardware Info : N/A (sudo dmidecode produced no output)"
    else
        ram_type=$(echo "$dmidecode_output" | grep -E '^\s*Type:' | grep -vE 'Unknown|Other' | head -n 1 | sed -e 's/^[[:space:]]*Type:[[:space:]]*//')
        ram_speed=$(echo "$dmidecode_output" | grep -E '^\s*Configured Memory Speed:' | grep -vE 'Unknown|0 MHz|0 MT' | head -n 1 | sed -e 's/^[[:space:]]*Configured Memory Speed:[[:space:]]*//')
        if [ -z "$ram_speed" ]; then
           ram_speed=$(echo "$dmidecode_output" | grep -E '^\s*Configured Clock Speed:' | grep -vE 'Unknown|0 MHz|0 MT' | head -n 1 | sed -e 's/^[[:space:]]*Configured Clock Speed:[[:space:]]*//')
        fi
        if [ -z "$ram_speed" ]; then
           ram_speed=$(echo "$dmidecode_output" | grep -E '^\s*Speed:' | grep -vE 'Unknown|0 MHz|0 MT' | head -n 1 | sed -e 's/^[[:space:]]*Speed:[[:space:]]*//')
        fi
        ram_manufacturer=$(echo "$dmidecode_output" | grep -E '^\s*Manufacturer:' | grep -vE 'Empty|Unknown|NO DIMM' | head -n 1 | sed -e 's/^[[:space:]]*Manufacturer:[[:space:]]*//')

        ram_slots_filled=$(echo "$dmidecode_output" | grep -c -E "^\s*Size: [1-9][0-9]* (MB|GB|TB)")

        total_ram_slots=$(echo "$dmidecode_output" | grep -E '^\s*Number Of Devices:' | head -n 1 | sed -e 's/^[[:space:]]*Number Of Devices:[[:space:]]*//')

        if [ -z "$ram_type" ]; then ram_type="N/A"; fi
        if [ -z "$ram_speed" ]; then ram_speed="N/A"; fi
        if [ -z "$ram_manufacturer" ]; then ram_manufacturer="N/A"; fi
        if ! [[ "$ram_slots_filled" =~ ^[0-9]+$ ]]; then
             ram_slots_filled="N/A"
        elif [ "$ram_slots_filled" -eq 0 ]; then
             ram_slots_filled="0"
        fi

    fi
  else
      echo "RAM Hardware Info : N/A ('dmidecode' command not found)"
  fi

  echo "RAM Type                  : $ram_type"
  echo "RAM Speed                 : $ram_speed"
  echo "Manufacturer              : $ram_manufacturer"
  echo "RAM Slots (Used/Total)    : $ram_slots_filled / $total_ram_slots"
}

show_cpu_status
echo
show_ram_status
echo