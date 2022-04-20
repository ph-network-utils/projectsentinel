# projectsentinel
 Sends push notifications for unrecognized SSH logins

# Note: This project is incomplete and will not work if run. Check back later


# Usage
You can choose to setup Project Sentinel with or without setting up your own push notification service (runs on Gotify).

To start setting up your own gotify server and sending notifications to it run the setup.sh.
If you already have a gotify server up and running run the setupnoserver.sh

# Requirements project sentinel with gotify server

You need a host that can be reached from the internet, preferred not to have NAT as this will give trouble with Let's Encrypt SSL certificates.
Depending on the prospected usage this can be as small a machine as you'd like.

# Requirements project sentinel without gotify server
Basically anything, this project has been tested on Arch Linux but should be compatible with Ubuntu also.

# TODO
* Option to end session from app notification. We already have the user and IP so this shouldn't be too hard.
* Enable option to change port in gotify server selection.
* Standardize for Docker images
* SMART support?
* Disk space checking
