# MiSTer CD-i VCD Factory

A robust, cross-platform batch tool to convert modern video files into **Philips CD-i compatible** Video CD (VCD) disc images.

Designed for use with the **MiSTer FPGA CD-i Core** and accurate emulators (MAME/cdiemu).

## Features
- **Strict Compliance:** Uses `mpeg2enc` to enforce CD-i hardware limits.
- **Dependency Management:** Automatically installs required tools on macOS and Linux.
- **Bridge Files:** Automatically fetches the required "Green Book/White Book" bridge files.

## Prerequisites
- **macOS:** Homebrew installed.
- **Linux:** Debian/Ubuntu based system.

## Usage
1. Copy sh script to a local folder, for example:
   `mkdir -p ~/mister_cdi_vcd_creator && cd ~/mister_cdi_vcd_creator && curl -kLO https://raw.githubusercontent.com/mrchrisster/mister_cdi_vcd_creator/batch-vcd-creator.sh`
Run /media/fat/Scripts/MiSTer_SAM_on.sh and let SAM do the auto install to download the other installation files.
3. Run tool once with `./batch-vcd-creator.sh` to create folder structure
4. Drop your video file(s) in `input` folder
5. Run `./batch-vcd-creator.sh`
6. Watch for errors like `⚠️  WARNING: Buffer starvation detected!`
