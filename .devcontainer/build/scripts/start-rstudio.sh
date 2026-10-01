#!/usr/bin/env bash
# start-rstudio.sh -- the codespace's postAttachCommand; runs as rstudio each time a
# browser tab attaches. Starts RStudio Server (127.0.0.1:8788) and the small proxy in
# front of it (port 8787, the forwarded port) unless they are already up.
# Port 8787 is private to the codespace's owner, so no login screen (WORKSHOP.md §8);
# with RSTUDIO_PASSWORD set, RStudio starts with password login instead (§5 step 11d).
set -uo pipefail
FRONT=8787
BACK=8788
data="${HOME}/.local/share/rstudio-server"
log="${data}/start.log"
ngx=/tmp/bioinfo-workshop-nginx
mkdir -p "${data}/run" "${ngx}"
back_up()  { curl -sf -o /dev/null --max-time 2 "http://127.0.0.1:${BACK}/"; }
front_up() { curl -sf -o /dev/null --max-time 2 "http://127.0.0.1:${FRONT}/"; }

if back_up && front_up; then
    echo "[bioinfo-workshop] RStudio is already running on port ${FRONT}."
    exit 0
fi

if ! back_up; then
    if [ -n "${RSTUDIO_PASSWORD:-}" ]; then
        echo "[bioinfo-workshop] RSTUDIO_PASSWORD is set: starting RStudio with password login."
        sudo -n /usr/local/share/bioinfo-workshop/start-rstudio-password.sh >>"${log}" 2>&1
    else
        if [ ! -f "${data}/dbconf.conf" ]; then
            printf 'provider=sqlite\ndirectory=%s\n' "${data}" > "${data}/dbconf.conf"
        fi
        rserver \
            --server-user="$(id -un)" \
            --auth-none=1 \
            --www-address=127.0.0.1 \
            --www-port="${BACK}" \
            --server-daemonize=1 \
            --server-data-dir="${data}/run" \
            --server-pid-file="${data}/rserver.pid" \
            --secure-cookie-key-file="${data}/secure-cookie-key" \
            --database-config-file="${data}/dbconf.conf" >>"${log}" 2>&1
    fi
fi

if ! pgrep -u "$(id -u)" -x nginx >/dev/null 2>&1; then
    nginx -c /etc/bioinfo-workshop/nginx.conf -e "${ngx}/error.log" >>"${log}" 2>&1
fi

for _ in $(seq 1 30); do
    if back_up && front_up; then
        echo "[bioinfo-workshop] RStudio is running on port ${FRONT} (PORTS tab, label RStudio)."
        exit 0
    fi
    sleep 1
done
echo "[bioinfo-workshop] RStudio did not answer within 30 seconds. Last lines of ${log}:"
tail -n 20 "${log}" 2>/dev/null
tail -n 5 "${ngx}/error.log" 2>/dev/null
exit 1
