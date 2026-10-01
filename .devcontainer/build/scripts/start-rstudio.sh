#!/usr/bin/env bash
# start-rstudio.sh -- the codespace's postAttachCommand; runs as rstudio each time a
# browser tab attaches. Starts RStudio Server on port 8787 unless it is already up.
# Port 8787 is private to the codespace's owner, so no login screen (WORKSHOP.md §8);
# with RSTUDIO_PASSWORD set it starts with password login instead (§5 step 11d).
set -uo pipefail
PORT=8787
data="${HOME}/.local/share/rstudio-server"
log="${data}/start.log"
mkdir -p "${data}/run"
listening() { curl -s -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/"; }

if listening; then
    echo "[bioinfo-workshop] RStudio is already running on port ${PORT}."
    exit 0
fi

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
        --www-port="${PORT}" \
        --server-daemonize=1 \
        --server-data-dir="${data}/run" \
        --server-pid-file="${data}/rserver.pid" \
        --secure-cookie-key-file="${data}/secure-cookie-key" \
        --database-config-file="${data}/dbconf.conf" >>"${log}" 2>&1
fi

for _ in $(seq 1 30); do
    if listening; then
        echo "[bioinfo-workshop] RStudio is running on port ${PORT} (PORTS tab, label RStudio)."
        exit 0
    fi
    sleep 1
done
echo "[bioinfo-workshop] RStudio did not answer within 30 seconds. Last lines of ${log}:"
tail -n 20 "${log}" 2>/dev/null
exit 1
