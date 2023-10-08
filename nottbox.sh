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

# define a function to read a value from the YAML file
read_yaml_value() {
  local key="$1"
  local yaml_file="$2"
  local value
  value=$(grep -E "$key:" "$yaml_file" | sed -e 's/^[[:space:]]*'"$key"':[[:space:]]*//' -e 's/[[:space:]]*$//')
  echo "$value"
}

pushover_message() {
  # Send a Pushover notification
  TITLE="$1"
  MESSAGE="$2"

  # Check if USER_KEY or API_TOKEN is empty
  if [ -n "$USER_KEY" ] && [ -n "$API_TOKEN" ]; then
    curl -s \
      --form-string "token=$API_TOKEN" \
      --form-string "user=$USER_KEY" \
      --form-string "title=$TITLE" \
      --form-string "message=$MESSAGE" \
      https://api.pushover.net/1/messages.json
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

# Check if the file "reboot_needed" exists in the current directory
if [ -e "reboot_needed" ]; then
  pushover_message "Nottbox Unifi reboot complete." "Nottbox had been unable to ping '$DOMAIN_OF_IP' for longer than the configured time of $DOWNTIM_THRESHOLD_SEC seconds so a reboot command was issued. The Unifi device is now back online."    
  log_message "Nottbox Unifi reboot complete." "Nottbox had been unable to ping '$DOMAIN_OF_IP' for longer than the configured time of $DOWNTIM_THRESHOLD_SEC seconds so a reboot command was issued. The Unifi device is now back online."
  # Delete the file "reboot_needed"
  rm -f "reboot_needed"
fi

# function to split a time string (e.g., "3:45") into hours and minutes
split_time() {
  local time="$1"
  echo "$time" | awk -F':' '{print int($1), int($2)}'
}

# check if PAUSE_START and PAUSE_END are not empty strings
if [ -n "$PAUSE_START" ] && [ -n "$PAUSE_END" ]; then
  # Split the PAUSE_START time into hours and minutes
  echo "$(split_time "$PAUSE_START")" > temp_file
  IFS=" " read -r START_HOUR START_MINUTE < temp_file
  rm -f temp_file

  # Split the PAUSE_END time into hours and minutes
  echo "$(split_time "$PAUSE_END")" > temp_file
  IFS=" " read -r END_HOUR END_MINUTE < temp_file
  rm -f temp_file

  log_message "Nottbox will pause monitoring between $PAUSE_START and $PAUSE_END nightly update window."
else
  log_message "Nottbox will not pause for a nightly update window because PAUSE_START and/or PAUSE_END was not specified."
fi

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

# function to check internet connectivity
check_internet() {
  if is_time_between "$START_HOUR" "$START_MINUTE" "$END_HOUR" "$END_MINUTE"; then
    log_message "Nottbox is currently paused between $START_HOUR:$START_MINUTE and $END_HOUR:$END_MINUTE."
    while is_time_between "$START_HOUR" "$START_MINUTE" "$END_HOUR" "$END_MINUTE"; do
      sleep 60
    done
    log_message "Resuming Nottbox after $END_HOUR:$END_MINUTE"
  fi
  
  if /bin/ping -q -w 1 -c 1 "$DOMAIN_OR_IP" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# print a message when the Nottbox starts
log_message "Nottbox started at $(date +'%Y-%m-%d %H:%M:%S') on $host_name ($local_ip)"
host_name=$(hostname)
local_ip=$(hostname -I | awk '{print $1}')
pushover_message "Nottbox started at $(date +'%Y-%m-%d %H:%M:%S') on $host_name ($local_ip)"

# main loop
while true; do
  if ! check_internet; then
    log_message "Internet connection lost. Waiting for 5 minutes..."
    sleep $DOWNTIME_THRESHOLD_SEC
    
    if ! check_internet; then
      log_message "Internet still not available. Rebooting..."
      touch reboot_needed
      /bin/vbash -ic 'sudo shutdown -r now'
    fi
  fi
  sleep $PING_FREQUENCY_SEC
done
