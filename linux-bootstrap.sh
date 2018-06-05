#!/bin/bash
mkdir -p /var/log/airscout
mkdir -p /var/airscout
aws s3 cp s3://airscout-sw-builds/linux/scripts/setup-env.sh /var/airscout/setup-env.sh
chmod +x /var/airscout/setup-env.sh
/var/airscout/setup-env.sh >/var/log/airscout/setup-env.log 2>&1