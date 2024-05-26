# Simple Server Health Check

Maintaining server health is paramount for smooth operations, and automating this process can save time and effort. This project provides a simple yet effective solution for monitoring server health using Linux services and Bash scripting.

## Installation

To install and start the monitoring service, run the following command:
```sh
sudo sh install-service.sh
```

This will start the monitoring.service. To check the status of this service, use:

```
systemctl status monitoring.service
```
To stop the service, use:
```
sudo systemctl stop monitoring.service
```

Running the Script Standalone

If you want to run monitoring.sh standalone, execute the following command:

```
sh monitoring.sh .env
```

Ensure that you have your environment variables set up in the .env file before running the script.
