# Nottbox

Nottbox is a Wattbox-like bash script (that can run as a service) that will reboot a Unifi device if it cannot ping an IP address or hostname for longer than 5 minutes (default). Some devices in my Unifi environment will go offline while remaining physically powered on for no apparent reason. Some days/weeks/months are better than others, but today it happened 3 times - and now we have Nottbox.

If this script proves to be useful to you, it probably means you need to:
    - check to ensure you're running on the latest firmware version on all devices within your Unifi environment, including the network controller
    - get Unifi support to assist or RMA the device
    - investigate purchasing a new device with a higher capacity

BUT if you don't have the money or time to deal with this (or purchase a new beefier device) Nottbox could help you.

Nottbox was intended for Unifi devices but Nottbox should work on most linux operating systems.


## Deployment

SSH into your Unifi device (this must be enabled explicitly within the web management portal)

In the root directory (you should be here by default after login - but you can check with `pwd`), clone the repo and CD into the Nottbox directory:
```shell
git clone https://github.com/sam-morin/nottbox.git
cd nottbox
```

Edit `nottbox.yml` to specify your preferences (if a pause is not needed, leave `PAUSE_START` and `PAUSE_END` blank):
```yml
# Configuration file for Nottbox
DOMAIN_OR_IP: one.one.one.one
DOWNTIME_THRESHOLD_MIN: 5
PAUSE_START: 3:45
PAUSE_END: 4:45
LOG_FILE: /root/nottbox/nottbox.log
```
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
Description=Nottbox is a Wattbox like service that will reboot a Unifi device if it cannot ping a remote host or IP for more than 5 minutes.
After=network.target

[Service]
ExecStart=/root/nottbox/nottbox.sh
Restart=always
User=root
Group=root
Type=simple

[Install]
WantedBy=multi-user.target
```


# Reload daemon, enable and start the service

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