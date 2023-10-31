#!/bin/bash

# Check for root
if [[ $(id -u) -gt 0 ]]; then
  echo Please run as root!
  exit 1
fi

# Check for JQ
echo Checking for JQ.
if [[ -e /usr/bin/jq ]]; then
  :
else
  if [[ -e /usr/bin/pacman ]]; then
    pacman -Sy jq
  elif [[ -e /usr/bin/apt ]]; then
    apt update -qq
    apt install -yq jq
  fi
fi

echo Use this file if you already have a gotify server up and running.
echo
echo For starters we need to declare some variables
echo
echo Please enter FQDN of the host that is running Gotify
read gotify_server
echo Selected $gotify_server
#echo Please enter port (will default to 443 if left blank)
#read gotify_port
#if [[ -z $gotify_port ]]; then
#  $gotify_addr="https://$gotify_server"
#fi
function readuserinfo() {
  read -p "Username:" gotify_username
  echo
  read -sp Password: gotify_password
  echo
  read -sp "Again to confirm:" gotify_password_conf
  echo
  if [[ $gotify_password != $gotify_password_conf ]];then
    echo Passwords don\'t match!
    echo
    readuserinfo
  fi
}
readuserinfo
echo Trying to login using specified details
response=$(curl -u $gotify_username:$gotify_password https://$gotify_server/application | jq)
if echo $response | grep Unauthorized >/dev/null; then
  echo Wrong username or password!
  echo Please try again.
  readuserinfo
elif echo $response | grep "Could not resolve host" >/dev/null; then
  echo Invalid host selected! Please select a different host!
  exit 1
else
  echo Login succesful
fi

# Declare some variables

function buildmenu () {
echo \#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
N=0
for i in "$@"
do
N=$(expr $N + 1)
echo Option $N is: $i
done
echo \#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
}

function getapptoken() {
echo Your currently active applications are:
curl -u $gotify_username:$gotify_password https://$gotify_server/application | jq
read -p "Please enter your app token: " apptoken
}
getapptoken

function testapptoken() {
echo Apptoken set to $apptoken .
echo Trying to send message using apptoken
testresponse=$(curl -X POST https://$gotify_server/message?token=$apptoken -F "title=Testnotification" -F "message=If you're seeing this the app is correctly configured" -F "priority=8" >/dev/null)
if echo $testresponse | grep "provide a valid access token"; then
echo Invalid token set!
getapptoken
testapptoken
fi
}
testapptoken

# Let's create a menu for our sevices

function enablesshnotifications() {
  echo Writing sendpush file to /usr/bin/sendpush
  cp sendpush /usr/bin/sendpush
  chmod +x /usr/bin/sendpush
  echo Creating directory for Project Sentinel at /opt/projectsentinel
  mkdir -p /opt/projectsentinel
  echo Setting up listener
  cp accepted.sh /opt/projectsentinel/accepted.sh
  if [[ -e /usr/bin/systemd ]]; then
      wget https://pieterhouwen.info/zooi/servicetemplate.txt -O /tmp/servicetemplate
      sed -i 's/dir=""/dir="\/opt\/projectsentinel"' /tmp/servicetemplate
      sed -i 's/cmd=""/cmd="\/opt\/projectsentinel\/accepted.sh"' /tmp/servicetemplate
      sed -i 's/user=""/user="root"' /tmp/servicetemplate
      echo Installing and enabling service
      mv /tmp/servicetemplate /etc/init.d/loginpush
      chmod +x /etc/init.d/loginpush
      update-rc.d loginpush defaults
      service loginpush start
      echo If all was well the daemon should be active and started at boot.

  elif [[ -d /lib/systemd/system ]]; then
      cat<<EOF > /tmp/systemctltemplate
[Unit]
Description=desk
After=network.target

[Service]
ExecStart=command
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

      sed -i 's/command/\/opt\/projectsentinel\/accepted.sh/' /tmp/systemctltemplate
      sed -i 's/desk/Sends push notifications to phone/' /tmp/systemctltemplate
      echo Installing and enabling service
      mv /tmp/systemctltemplate /lib/systemd/system/loginpush.service
      systemctl enable --now loginpush
  fi
}

function enablesmartnotifications() {
  echo Oh yeah, RAID devices are NOT supported! :D
  sleep 2
  echo "Currently mounted disks are:"
  # df -h | grep dev | grep -v loop | grep -v tmpfs | grep -v udev
  lsblk
  read -p "Select the disk which you would like to monitor: " disk
  if [[ ! -e $disk ]]; then
    echo Invalid disk selected! Please check the name and try again.
    enablesmartnotifications
  else
    echo Checking disk for SMART capabilities
    # Check for smartctl
    if [[ -e /usr/sbin/smartctl ]]; then
      :
    else
      if [[ -e /usr/bin/pacman ]]; then
        pacman -Sy smartmontools
      elif [[ -e /usr/bin/apt ]]; then
        echo Updating package repositories and installing smartmontools
        apt update -qq
        apt install -yq smartmontools
      fi
    fi
  fi
    if smartctl -H $disk | grep PASSED >/dev/null; then
      echo SMART detected and disk is in good health.
      echo Setting up scheduled task to run each sunday at 06:00
      if [[ -e /etc/crontab ]]; then
      echo "00 6 * * 7 root /opt/projectsentinel/smartcheck $disk" >>/etc/crontab
      else
      echo You will have to set this up yourself.
      fi
    fi
    if smartctl -H $disk | grep -i "lacks smart capability" >/dev/null; then
      echo SMART is not supported on $disk. Bye.
      exit 1
    else
      :
    fi
 }

buildmenu "SSH login detection" "SMART notifications"
read -p "Please select your desired service: " menunumber
case $menunumber in
  1)
   enablesshnotifications
  ;;
  2)
   enablesmartnotifications
  ;;
esac
