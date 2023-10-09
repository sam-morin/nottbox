# Nottbox - Auto-reboot device on ping failures

A software defined Wattbox cousin - but not really like a Wattbox at all.

[Quick Deployment (script)](#quick-deployment-script) • [Uninstall Nottbox (script)](#uninstall-nottbox-script) • [Manual Deployment](#manual-deployment)

Nottbox is a Wattbox-like bash script (that can run as a service) that will reboot a Unifi device if it cannot ping an IP address or hostname for longer than 2.5 minutes (default - 150 seconds). Some devices in my Unifi environment will go offline while remaining physically powered on for no apparent reason. Some days/weeks/months are better than others, but today it happened 3 times - and now there is Nottbox.

Since Nottbox is just a few bash scripts and a couple of config files, the entire project directory has a very small footprint at under 30KB. 

If Nottbox proves to be useful to you, it probably means you need to:

<ul>
    <li>check to ensure you're running on the latest firmware version on all devices within your Unifi environment, including the network controller</li>
    <li>get Unifi support to assist or RMA the device</li>
    <li>investigate purchasing a new device with a higher capacity</li>
</ul>

BUT life is crazy and not all of us have a ton of time on our hands and/or the salary of a NASA senior aerospace engineer - in cases like these, Nottbox is here.

Nottbox was intended for Unifi devices but it should work on most linux operating systems that use systemd (think OpenWRT).


# Quick Deployment (script)

SSH into your Unifi device (this must be enabled explicitly within the web management portal)

Params (remove from command to disable/negate the below options - omit -u and -t if you don't wish to use Pushover for notifications):
<ul>
    <li>-e | --enable-service : enable the service (so it starts after reboots) (optional, but recommended)</li>
    <li>-u | --user-key : your Pushover User key from https://pushover.net (optional)</li>
    <li>-t | --api-token : your Pushover Nottbox API token from https://pushover.net (optional)</li>
</ul>

Using cURL:
```shell
curl -sSL https://raw.githubusercontent.com/sam-morin/nottbox/main/install-nottbox.sh | bash -s -- -e
```
with Pushover keys specified:
```shell
curl -sSL https://raw.githubusercontent.com/sam-morin/nottbox/main/install-nottbox.sh | bash -s -- -e -u "YourUserKey" -t "YourApiToken"
```
*or wget:*
```shell
wget -qO- https://raw.githubusercontent.com/sam-morin/nottbox/main/install-nottbox.sh | bash -s -- -e
```

### Result:
```sh
...
● nottbox.service - A software defined Wattbox cousin for Unifi devices.
     Loaded: loaded (/etc/systemd/system/nottbox.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2023-10-08 08:47:01 EDT; 2min 51s ago
   Main PID: 411110 (nottbox.sh)
      Tasks: 2 (limit: 2386)
     Memory: 2.7M
        CPU: 134ms
     CGroup: /system.slice/nottbox.service
             ├─411110 /bin/bash /root/nottbox/nottbox.sh
             └─412050 sleep 30

Oct 08 08:47:01 unifi-device-name systemd[1]: Started A software defined Wattbox cousin for Unifi devices..
Oct 08 08:47:01 unifi-device-name nottbox.sh[411110]: Nottbox will pause monitoring between 3:45 and 4:45 nightly update window.
Oct 08 08:47:01 unifi-device-name nottbox.sh[411110]: Nottbox started at 2023-10-08 08:47:01
```
Use `systemctl`:
```shell
systemctl status nottbox
```
to show the status


# Manual deployment

SSH into your Unifi device (this must be enabled explicitly within the web management portal)

In the root directory (you should be here by default after login - but you can check with `pwd`), clone the repo and CD into the Nottbox directory:
```shell
git clone https://github.com/sam-morin/nottbox.git
cd nottbox
```

Edit `nottbox.yml` to specify your preferences (if a pause is not needed, leave `PAUSE_START` and `PAUSE_END` blank):
```yml
# Configuration file for Nottbox
DOMAIN_OR_IP: one.one.one.one, google.com, youtube.com, 8.8.8.8, justthat.com
PING_FREQUENCY_SEC: 30
DOWNTIME_THRESHOLD_SEC: 150
PAUSE_START: 3:45
PAUSE_END: 4:45
LOG_FILE: /root/nottbox/nottbox.log
```
*These are the default values*

*Time is to be defined in 24 hour format*

*If using the pause functionality, please ensure that your timezone is correct by comparing the current hour with the hour returned from this command:*
```shell
date -u -d '-4 hours' +'%H'
```
*Adjust your specified time as necessary. Timezone correction configuration option will be added soon!*


Set execute file permission:
```shell
chmod +x nottbox.sh
```

Run Nottbox:
```shell
sh nottbox.sh
```


## Utilize Nottbox as a systemd service

Copy default Nottbox systemd service unit file to `/etc/systemd/system/nottbox.service`:
```shell
cp nottbox.service /etc/systemd/system/
```

or

Create unit file:
```shell
vi /etc/systemd/system/nottbox.service
```

Paste the following in the editor and then type `:x` and hit Enter to save:
```
[Unit]
Description=A software defined Wattbox cousin for Unifi devices.
After=network.target

[Service]
ExecStart=/root/nottbox/nottbox.sh
Restart=on-failure
RestartSec=2s
User=root
Group=root
Type=simple

[Install]
WantedBy=multi-user.target
```


## Reload daemon, enable and start the service

Reload the systemd manager configuration:
```shell
systemctl daemon-reload
```

Enable the service (only if you want it to start at boot, skip this step otherwise):
```shell
systemctl enable nottbox
```

Finally, start the service:
```shell
systemctl start nottbox
```

Check the service status:
```shell
systemctl status nottbox
```


# Uninstall Nottbox (script)

Params (included by default, remove from command to disable/negate the below options):
<ul>
    <li>-f | --remove-log : delete the log as well (if this is omitted, the log file will be moved to <code>/root/nottbox.log</code> before deleting <code>/root/nottbox/</code>) (optional)</li>
</ul>

Use cURL:
```shell
curl -sSL https://raw.githubusercontent.com/sam-morin/nottbox/main/uninstall-nottbox.sh | bash -s -- -f
```
*or wget:*
```shell
wget -qO- https://raw.githubusercontent.com/sam-morin/nottbox/main/uninstall-nottbox.sh | bash -s -- -f
```

What this does:
<ol>
  <li>Stops the Nottbox service</li>
  <li>Disables the Nottbox service</li>
  <li>Deletes the Nottbox service</li>
  <li>Reloads systemd daemon</li>
  <li>Removes the Nottbox directory</li>
  <li>Uninstalls git & cleans up packages</li>
</ol>



[Quick Deployment (script)](#quick-deployment-script) • [Uninstall Nottbox (script)](#uninstall-nottbox-script) • [Manual Deployment](#manual-deployment)