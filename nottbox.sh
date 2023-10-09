#!/bin/bash

if [ -e "/root/nottbox/.env.pushover" ]; then
  source /root/nottbox/.env.pushover
fi

# function to log a message and prune if necessary
log_message() {
  local message="$1"
  local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  # output the message to the terminal/console
  echo "$timestamp - $message" >&1  # Redirect to stdout
  # append the message to the log file
  echo "$timestamp - $message" >> "$LOG_FILE"
  # check and prune log file to a maximum of 100 lines
  if [ $(wc -l < "$LOG_FILE") -gt 50 ]; then
    tail -n 50 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

# function to check if the current time is within a specified time range
is_time_between() {
  local start_hour=$1
  local start_minute=$2
  local end_hour=$3
  local end_minute=$4
  local current_hour=$(date -u -d '-4 hours' +'%H' | sed 's/^0//') # remove leading zeros
  local current_minute=$(date -u -d '-4 hours' +'%M' | sed 's/^0//') # convert to EST (-4 hours) and remove leading zeros

  # convert start and end times to minutes since midnight
  start_minutes=$((start_hour * 60 + start_minute))
  end_minutes=$((end_hour * 60 + end_minute))
  current_minutes=$((current_hour * 60 + current_minute))

  # check if the current time is between the start and end times
  [ "$current_minutes" -ge "$start_minutes" ] && [ "$current_minutes" -lt "$end_minutes" ]
}

is_target_reachable() {
  local target="$1"
  local pings=0

  if is_time_between "$START_HOUR" "$START_MINUTE" "$END_HOUR" "$END_MINUTE"; then
    log_message "Nottbox is currently paused between $START_HOUR:$START_MINUTE and $END_HOUR:$END_MINUTE."
    while is_time_between "$START_HOUR" "$START_MINUTE" "$END_HOUR" "$END_MINUTE"; do
      sleep 60
    done
    log_message "Resuming Nottbox after $END_HOUR:$END_MINUTE"
  fi

  while [ "$pings" -lt 2 ]; do
    if /bin/ping -q -w 1 -c 1 -W 2 "$target" > /dev/null 2>&1; then
      ((pings++))
      sleep 2
    else
      break
    fi
  done

  echo "$pings"
}

# define a function to read a value from the YAML file
read_yaml_value() {
  local key="$1"
  local yaml_file="$2"
  local value
  value=$(grep -E "$key:" "$yaml_file" | sed -e 's/^[[:space:]]*'"$key"':[[:space:]]*//' -e 's/[[:space:]]*$//')
  echo "$value"
}

pushover_message() {
  # send a Pushover notification
  TITLE="$1"
  MESSAGE="$2"

  # check if USER_KEY or API_TOKEN is empty
  if [ -n "$USER_KEY" ] && [ -n "$API_TOKEN" ]; then
    curl -s \
      --form-string "token=$API_TOKEN" \
      --form-string "user=$USER_KEY" \
      --form-string "title=$TITLE" \
      --form-string "message=$MESSAGE" \
      https://api.pushover.net/1/messages.json
    log_message "Sent Pushover notification."
  else
    log_message "USER_KEY or API_TOKEN is empty. Skipping Pushover notification."
  fi
}

# define the Nottbox YAML configuration file path
yaml_file="/root/nottbox/nottbox.yml"

# read values from the YAML file
DOMAIN_OR_IP=$(read_yaml_value "DOMAIN_OR_IP" "$yaml_file")
PING_FREQUENCY_SEC=$(read_yaml_value "PING_FREQUENCY_SEC" "$yaml_file")
DOWNTIME_THRESHOLD_SEC=$(read_yaml_value "DOWNTIME_THRESHOLD_SEC" "$yaml_file")
PAUSE_START=$(read_yaml_value "PAUSE_START" "$yaml_file")
PAUSE_END=$(read_yaml_value "PAUSE_END" "$yaml_file")
LOG_FILE=$(read_yaml_value "LOG_FILE" "$yaml_file")

# convert the comma-separated list of domains and IPs to an array
IFS=', ' read -r -a targets <<< "$DOMAIN_OR_IP"

get_data() {
  info_output=$(mca-cli-op info)
  echo "$info_output" > reboot_needed
  cpu_temp=$(ubnt-systool cputemp)
  cpu_load=$(ubnt-systool cpuload)
  echo "CPU Temp: $cpu_temp°C" >> reboot_needed 
  echo "CPU Load: $cpu_load%" >> reboot_needed 
}
pull_data() {
  data=$(<reboot_needed)
  echo "$data"
}

# check if the file "reboot_needed" exists in the current directory
if [ -e "reboot_needed" ]; then
  pushover_message "$host_name ($public_ip) - Nottbox Alert" "Nottbox had been unable to ping '$DOMAIN_OF_IP' for longer than the configured time of $DOWNTIM_THRESHOLD_SEC seconds so a reboot command was issued. The Unifi device is now back online. \n\n$(pull_data)"    
  log_message "Nottbox had been unable to ping '$DOMAIN_OF_IP' for longer than the configured time of $DOWNTIM_THRESHOLD_SEC seconds so a reboot command was issued. The Unifi device is now back online."
  # delete the file "reboot_needed"
  rm -f "reboot_needed"
fi

# function to split a time string (e.g., "3:45") into hours and minutes
split_time() {
  local time="$1"
  echo "$time" | awk -F':' '{print int($1), int($2)}'
}

# check if PAUSE_START and PAUSE_END are not empty strings
if [ -n "$PAUSE_START" ] && [ -n "$PAUSE_END" ]; then
  # split the PAUSE_START time into hours and minutes
  echo "$(split_time "$PAUSE_START")" > temp_file
  IFS=" " read -r START_HOUR START_MINUTE < temp_file
  rm -f temp_file

  # split the PAUSE_END time into hours and minutes
  echo "$(split_time "$PAUSE_END")" > temp_file
  IFS=" " read -r END_HOUR END_MINUTE < temp_file
  rm -f temp_file

  log_message "Nottbox will pause monitoring between $PAUSE_START and $PAUSE_END nightly update window."
else
  log_message "Nottbox will not pause for a nightly update window because PAUSE_START and/or PAUSE_END was not specified."
fi

# Run the "info" command and store its output in a variable
info_output=$(mca-cli-op info)
# Extract and assign data to variables
model=$(echo "$info_output" | awk -F ': ' '/Model/ {print $2}')
version=$(echo "$info_output" | awk -F ': ' '/Version/ {print $2}')
mac_address=$(echo "$info_output" | awk -F ': ' '/MAC Address/ {print $2}')
ip_address=$(echo "$info_output" | awk -F ': ' '/IP Address/ {print $2}')
hostname=$(echo "$info_output" | awk -F ': ' '/Hostname/ {print $2}')
uptime=$(echo "$info_output" | awk -F ': ' '/Uptime/ {print $2}')
ntp_status=$(echo "$info_output" | awk -F ': ' '/NTP/ {print $2}')
status=$(echo "$info_output" | awk -F ': ' '/Status/ {print $2}')
# print a message when the Nottbox starts
host_name=$(hostname)
public_ip=$(hostname -I | awk '{print $1}')
log_message "Nottbox started at $(date +'%Y-%m-%d %H:%M:%S') on $host_name ($public_ip)"
pushover_message "$host_name ($public_ip) - Nottbox Alert" "Nottbox started on $host_name ($public_ip) \\
Model: $model \\
Version: $version \\
Mac Address: $mac_address \\
IP Address: $ip_address \\
Hostname: $hostname \\
Uptime: $uptime \\
NTP Status: $ntp_status \\
Status: $status"

# function to perform the reboot action
perform_reboot() {
  touch reboot_needed
  get_data
  reboot now
}

while true; do
  any_target_online=false  # Reset the flag at the beginning of each iteration

  for target in "${targets[@]}"; do
    num_successful_pings=$(is_target_reachable "$target")
    if [ "$num_successful_pings" -gt 0 ]; then
      any_target_online=true  # Set to true if any target is reachable
      log_message "Ping to $target succeeded from main loop."
    else
      log_message "Ping to $target failed from main loop."
    fi
  done

  if ! $any_target_online; then
    log_message "All targets are unreachable. Initiating reboot..."
    sleep 3
    perform_reboot
  else
    log_message "Not all targets are unreachable. Checking again in $DOWNTIME_THRESHOLD_SEC seconds..."
  fi

  sleep "$DOWNTIME_THRESHOLD_SEC"
done

