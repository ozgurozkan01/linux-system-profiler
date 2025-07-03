# Linux System Profiler Script

It is a comprehensive and modular bash script experiment that runs on Linux systems. It monitors the state of system resources, performs basic security checks and presents the user with potential risks in the system.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) <!-- Optional: Add a license badge if you choose one -->

## Features

*   **CPU Status:**
    *   Displays CPU Model Name.
    *   Shows Logical and Physical Core counts.
    *   Calculates *instantaneous* CPU Usage percentage (using `mpstat` or `top`).
    *   Reports *instantaneous* CPU Temperature (using `sensors` or `/sys/class/thermal`). Provides guidance if sensors aren't detected or configured.
    *   Shows *instantaneous* and Maximum CPU Clock Speed (using `lscpu`, `/sys/devices/system/cpu/.../cpufreq`, or `/proc/cpuinfo`).
*   **RAM & Swap Status:**
    *   Displays Total, Available, Used (effective), and Buff/Cache RAM in MiB (using `free`).
    *   Calculates RAM Usage percentage based on available memory.
    *   Shows Total and Used Swap space in MiB and usage percentage (using `free`).
    *   Indicates if Swap is not configured.
*   **RAM Hardware Details (Optional, requires `sudo`):**
    *   Attempts to retrieve RAM Type (e.g., DDR4).
    *   Attempts to retrieve RAM Speed (e.g., 3200 MT/s).
    *   Attempts to retrieve RAM Manufacturer (first detected).
    *   Shows the number of RAM slots filled vs. total slots reported (using `dmidecode`).
*   **Robustness:**
    *   Includes checks for command availability (`mpstat`, `top`, `sensors`, `free`, `dmidecode`).
    *   Uses fallback methods for retrieving information if primary methods fail or tools are missing.
    *   Provides informative messages when data cannot be retrieved.

## Requirements

*   **Bash:** The script interpreter.
*   **Core Linux Utilities:** `lscpu`, `grep`, `sed`, `awk`, `cat`, `head`, `sort`, `timeout` (usually part of `coreutils`).
*   **`free` command:** For RAM/Swap usage (usually part of `procps` or `procps-ng`).

**Optional (for enhanced information):**

*   **`mpstat`:** Preferred for CPU usage (usually part of the `sysstat` package).
*   **`top`:** Fallback for CPU usage (usually part of `procps` or `procps-ng`).
*   **`sensors`:** Preferred for CPU temperature (part of the `lm-sensors` package). You might need to run `sudo sensors-detect` once to configure it.
*   **`dmidecode`:** For detailed RAM hardware information (usually needs to be installed separately, e.g., `sudo apt install dmidecode` or `sudo yum install dmidecode`). **Requires `sudo` privileges to run.**

## Installation and Usage

  - Clone the repository:
    ```bash
    git clone <repo-url>
    cd <repo-directory>
    ```
    *or* **Download the script:** Download the `linspector.sh` file directly.

  - Simply run the script from your terminal:
    ```bash
    ./linspector.sh
    ```
