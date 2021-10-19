#!/bin/bash
if [ ! -f /var/lib/pgadmin4/pgadmin4.db ]; then
        echo 'Set the default username and password'
        if [ -z "${PGADMIN_DEFAULT_EMAIL}" -o -z "${PGADMIN_DEFAULT_PASSWORD}" ]; then
                echo 'You need to define the PGADMIN_DEFAULT_EMAIL and PGADMIN_DEFAULT_PASSWORD environment variables.'
                exit 1
        fi
        echo ${PGADMIN_DEFAULT_EMAIL} | grep -E "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" > /dev/null
        if [ $? -ne 0 ]; then
                echo "'${PGADMIN_DEFAULT_EMAIL}' does not appear to be a valid email address. Please reset the PGADMIN_DEFAULT_EMAIL environment variable and try again."
                exit 1
        fi

        # Set the default username and password in a
        # backwards compatible way
        source /opt/pgadmin4-6.0/venv/bin/activate
        export PGADMIN_SETUP_EMAIL=${PGADMIN_DEFAULT_EMAIL}
        export PGADMIN_SETUP_PASSWORD=${PGADMIN_DEFAULT_PASSWORD}
        python3 /opt/pgadmin4-6.0/web/setup.py
        chown -R www:www /var/log/pgadmin4
        chown -R www:www /var/lib/pgadmin4
        sleep 5
        echo -e "\033[32m ==> Set the default username and password SUCCESSFUL\033[0m"
fi

service httpd  start
httpd -v
echo -e "\033[32m ==> pgAdmin4 6.0\033[0m"
echo -e "\033[32m ==> START SUCCESSFUL ... \033[0m"
waitterm() {
        local PID
        # any process to block
        tail -f /dev/null &
        PID="$!"
        # setup trap, could do nothing, or just kill the blocker
        trap "kill -TERM ${PID}" TERM INT
        # wait for signal, ignore wait exit code
        wait "${PID}" || true
        # clear trap
        trap - TERM INT
        # wait blocker, ignore blocker exit code
        wait "${PID}" 2>/dev/null || true
}
waitterm

echo "==> STOP"

service httpd stop
echo "==> STOP SUCCESSFUL ..."