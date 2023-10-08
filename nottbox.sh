#!/bin/bash

# define the Nottbox YAML configuration file path
yaml_file="/root/nottbox/nottbox.yml"

# define a function to read a value from the YAML file
read_yaml_value() {
  local key="$1"
  local yaml_file="$2"
  local value
  value=$(grep -E "$key:" "$yaml_file" | sed -e 's/^[[:space:]]*'"$key"':[[:space:]]*//' -e 's/[[:space:]]*$//')
  echo "$value"
}

# read values from the YAML file
DOMAIN_OR_IP=$(read_yaml_value "DOMAIN_OR_IP" "$yaml_file")
DOWNTIME_THRESHOLD_MIN=$(read_yaml_value "DOWNTIME_THRESHOLD_MIN" "$yaml_file")
PAUSE_START=$(read_yaml_value "PAUSE_START" "$yaml_file")
PAUSE_END=$(read_yaml_value "PAUSE_END" "$yaml_file")
LOG_FILE=$(read_yaml_value "LOG_FILE" "$yaml_file")

DOWNTIME_THRESHOLD_SEC=$((DOWNTIME_THRESHOLD_MIN * 60))

# function to split a time string (e.g., "3:45") into hours and minutes
split_time() {
  local time="$1"
  echo "$time" | awk -F':' '{print $1, $2}'
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

  echo "Nottbox will pause monitoring between $PAUSE_START and $PAUSE_END nightly update window."
else
  echo "Nottbox will not pause for a nightly update window because PAUSE_START and/or PAUSE_END was not specified."
fi

# function to log a message and prune if necessary
log_message() {
  local message="$1"
  local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  echo "$timestamp - $message" >> "$LOG_FILE"
  # check and prune log file to a maximum of 30 lines
  if [ $(wc -l < "$LOG_FILE") -gt 30 ]; then
    tail -n 30 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
  # output the message to the terminal/console
  echo "$timestamp - $message"
}

# function to check if the current time is within a specified time range
is_time_between() {
  local start_hour=$1
  local start_minute=$2
  local end_hour=$3
  local end_minute=$4
  local current_hour=$(date -u -d '-4 hours' +'%H') # convert to EST (-4 hours)
  local current_minute=$(date -u -d '-4 hours' +'%M') # convert to EST (-4 hours)

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
    echo "Nottbox is currently paused between $START_HOUR:$START_MINUTE and $END_HOUR:$END_MINUTE."
    while is_time_between "$START_HOUR" "$START_MINUTE" "$END_HOUR" "$END_MINUTE"; do
      sleep 60 # sleep for 60 seconds to pause the Nottbox
    done
    echo "Resuming Nottbox after $END_HOUR:$END_MINUTE"
  fi
  
  if /bin/ping -q -w 1 -c 1 "$DOMAIN_OR_IP" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# print a message when the Nottbox starts
echo "Nottbox started at $(date +'%Y-%m-%d %H:%M:%S')"

# main loop
while true; do
  if ! check_internet; then
    log_message "Internet connection lost. Waiting for 5 minutes..."
    sleep $DOWNTIME_THRESHOLD_SEC
    
    if ! check_internet; then
      log_message "Internet still not available. Rebooting..."
      /bin/vbash -ic 'sudo shutdown -r now'
    fi
  fi
  sleep 60  # check every 60 seconds
done
