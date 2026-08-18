#!/bin/bash
# Reverses everything run.sh/lkp-deps.sh created on the system: the cloned
# lkp-tests source trees, generated automation scripts/logs, test results,
# and the auto_lkp.service background service (if it exists, i.e. the VM
# install option was used).
#
# OS packages installed via apt/dnf (gcc, ruby, perf, etc. from
# dependencies/*.txt) are intentionally left installed - this only cleans
# up what this repo's own scripts created on disk.

loc="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run this as a super user (root), e.g. 'sudo make uninstall'."
    exit 1
fi

echo "=================================================================================="
echo "LKP AUTOMATION UNINSTALL"
echo "=================================================================================="
echo "This will remove, regardless of whether the VM or Host option was originally used:"
echo "  - The cloned lkp-tests source trees (this also breaks the lkp/hackbench/ebizzy/"
echo "    unixbench launchers, since they are symlinked into these trees)"
echo "  - Test result data under /lkp/result"
echo "  - The auto_lkp.service background service, if present"
echo "  - Generated automation scripts/logs under /var/lib and /var/log"
echo ""
echo "OS packages installed via apt/dnf (gcc, ruby, perf, etc.) are left installed."
echo "change-ulimit.service (Anolis-specific) and /etc/sudoers changes are left untouched."
echo "=================================================================================="
read -p "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted, nothing was removed."
    exit 0
fi

# Capture the resolved paths of the commands this repo's install process
# creates (typically symlinks into the lkp-tests tree) before their target
# directories get removed below, so any resulting dangling symlinks can be
# cleaned up afterwards instead of being left behind as broken launchers.
declare -A lkp_commands
for cmd in lkp hackbench ebizzy unixbench; do
    path=$(command -v "$cmd" 2>/dev/null)
    [[ -n "$path" ]] && lkp_commands[$cmd]="$path"
done

echo "Removing auto_lkp.service..."
if [[ -f /etc/systemd/system/auto_lkp.service ]]; then
    systemctl stop auto_lkp.service &> /dev/null
    systemctl disable auto_lkp.service &> /dev/null
    rm -f /etc/systemd/system/auto_lkp.service
    systemctl daemon-reload &> /dev/null
    echo "auto_lkp.service removed."
else
    echo "auto_lkp.service not found, skipping."
fi

echo "Removing generated automation scripts and logs..."
rm -f /var/lib/auto_lkp.sh
rm -rf /var/log/lkp-automation-data
rm -f /tmp/stop_lkp_script

echo "Removing lkp-tests source trees..."
rm -rf /var/lib/lkp-tests /var/lib/.lkp-tests
rm -rf "$loc/lkp-tests"

echo "Removing test result data..."
rm -rf /lkp/result

# Clean up any now-dangling launcher symlinks (e.g. /usr/local/bin/lkp) left
# behind after removing the directories they pointed into.
for cmd in "${!lkp_commands[@]}"; do
    path="${lkp_commands[$cmd]}"
    if [[ -L "$path" && ! -e "$path" ]]; then
        rm -f "$path"
        echo "Removed dangling launcher: $path"
    fi
done

echo "=================================================================================="
echo "Uninstall complete."
echo "Note: change-ulimit.service and any /etc/sudoers changes were left untouched;"
echo "remove those manually if you no longer need them."
echo "=================================================================================="
