# Fermentor
## A refridgerator temperature controller 

Add to roots crontab file
>@reboot /home/pi/git/fermentor/Fermentor.sh

Add to /boot/config.txt
>dtoverlay=w1-gpio,gpiopin=4,pullup=on

## TODO-list
* Change name for logfile.log -> logfile.csv
