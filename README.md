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
- Arch Linux

In case of support needed please contact the author of this script.

### Dependencies

`lkp-deps.sh` installs the OS packages and Ruby gems required to build and run the LKP jobs. The
package list is defined once using canonical (RPM-style) names and automatically translated to the
correct package name for whichever package manager is detected (`apt`, `dnf`/`yum`, `pacman`,
`zypper`, `apk`), so the same list works across all the supported distros without spurious
"package not found" failures. `perf` is installed separately since its package name/availability is
kernel-version-specific on Debian/Ubuntu.