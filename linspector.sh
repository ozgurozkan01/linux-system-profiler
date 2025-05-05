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

show_cpu_status