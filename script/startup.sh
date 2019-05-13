#!/bin/bash

set -e

# Expect to be passed either 'web' or 'worker' as parameter
APP_MODE="${1-web}"

(>&2 echo "startup mode $APP_MODE")
case "$APP_MODE" in
    web)
        (>&2 echo "startup reach web")
        if [[ "$MAINTENANCE_MODE" == "true" ]] ; then
            exec /usr/sbin/nginx -p /opt/app -c config/nginx_maintenance.conf
        else
            rm -f tmp/pids/server.pid

            (>&2 echo "startup reach passenger")
            exec bundle exec passenger \
                 start \
                 -p "${PORT-3000}" \
                 --log-file "/dev/stdout" \
                 --min-instances "${PASSENGER_MIN_INSTANCES-1}" \
                 --max-pool-size "${PASSENGER_MAX_POOL_SIZE-1}"
        fi
        ;;
    worker)
        if [[ "$MAINTENANCE_MODE" == "true" ]] ; then
            # Do nothing
            exec sleep 86400
        else
            (>&2 echo "startup reach rake jobs:work")
            exec bundle exec rake jobs:work
        fi
        ;;
    shredder)
        if [[ "$MAINTENANCE_MODE" == "true" || "$ENABLE_SHREDDER" != "true" ]] ; then
            # Do nothing
            exec sleep 86400
        else
            (>&2 echo "startup reach rake sharetribe:marketplace:run_shredder")
            exec bundle exec rake sharetribe:marketplace:run_shredder["${SHREDDER_SLEEP_TIME-1.5},${SHREDDER_QUERY_SLEEP_TIME-0.2}"]
        fi
        ;;
    *)
        echo "Unknown process type. Must be either 'web', 'worker' or 'shredder'!"
        exit 1
        ;;
esac
