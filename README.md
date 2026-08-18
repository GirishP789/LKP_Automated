# LKP_Automated

## Overview
This tool helps you to install and execute the LKP(Linux Kernel Performance) jobs.

These jobs selectively include:
    1. Hackbench
    2. Ebizzy
    3. Unixbench

## Getting Started

### Pre-Requisites
Ensure you have 'git' and 'make' installed on your system.

> [!NOTE]
> Always run this script with Super User priviledges.

### Installation & Usage 

1. Clone the Repository:
```bash
    $ git clone https://github.com/PKAditya/LKP_Automated.git
    $ cd LKP_Automated
```

2. Run the setup:
```bash
    $ sudo make
```

3. Select the relevant option:
```
    Option "1" : VM   - Install LKP and run the jobs automatically in the background
    Option "2" : Host - Install LKP only, run the jobs manually later (Recommended for Hosts)
```

Once you run the setup step, selecting option 1 (VM) will create a `auto_lkp.service` systemd
service that runs the LKP jobs in the background and automatically restarts the full run from the
beginning every time the system is booted (it does not resume from a previous run). This works the
same way across every distro listed below since it only relies on systemd; on SELinux-enforcing
distros the script automatically relabels the files it creates so the service is allowed to run.

Option 2 (Host) only installs LKP and its dependencies; no service is created, and you run the job
splits under `<lkp_dir>/splits` manually with `lkp run <file>.yaml`.

### Managing the service

1. To temporarily stop the service
```bash
    $ sudo systemctl stop auto_lkp.service
```

2. To permanently disable the service
```bash
    $ sudo systemctl disable auto_lkp.service
```

### Uninstalling

```bash
    $ sudo make uninstall
```

This removes everything the setup created, regardless of whether you originally chose the VM or
Host option: the cloned lkp-tests source trees (this also breaks the `lkp`/`hackbench`/`ebizzy`/
`unixbench` launchers, since they're symlinked into these trees), test result data under
`/lkp/result`, the generated automation scripts/logs under `/var/lib` and `/var/log`, and the
`auto_lkp.service` background service if it exists. It prompts for confirmation before removing
anything.

OS packages installed via `apt`/`dnf` (gcc, ruby, perf, etc.) are left installed, and
`change-ulimit.service` and any `/etc/sudoers` changes are left untouched — remove those manually
if you no longer need them.

### supported systems:

Current version of this script only supports limited number of distros, these include

- Ubuntu
- Velinux
- Centos
- Euler
- Anolis
- CloudOS
- Rocky Linux
- Oracle
- Redhat

Only `apt` (Ubuntu/Velinux) and `dnf`/`yum` (all the other distros above) are supported package
managers; other package managers/distros (e.g. Arch Linux, openSUSE) are not supported.

In case of support needed please contact the author of this script.

### Dependencies

`lkp-deps.sh` installs the OS packages and Ruby gems required to build and run the LKP jobs. The
actual dependency lists live outside the script, in plain text files under `dependencies/`, so they
can be updated without touching any bash code:

- `dependencies/packages.txt` — OS packages, grouped by package manager family: `[apt]`
  (Ubuntu/Velinux) or `[yum]` (CentOS/Euler/Anolis/CloudOS/Rocky/Oracle/Redhat, also matches `dnf`),
  each a flat list of real package names (one per line, exactly as that package manager expects —
  no translation/lookup happens). `lkp-deps.sh` only loads the block matching whichever family it
  detects. See the comments at the top of the file for the full format.
- `dependencies/gems.txt` — Ruby gems, one per line (optionally with version flags, e.g.
  `bundler -v 2.5.19`).

New dependencies can be added by editing the `.txt` files instead of the script — just add a line
with the real package name under the right family. Add it under both `[apt]` and `[yum]` if it's
needed on both. `perf` is the one exception: it's installed by a small dedicated function in
`lkp-deps.sh` since its package name/availability is kernel-version-specific on Debian/Ubuntu.