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
1. Clone this repo:
   ```bash
   git clone [https://github.com/your-repo/cdi-vcd-factory.git](https://github.com/your-repo/cdi-vcd-factory.git)
   cd cdi-vcd-factory
2. Run tool once with `./batch-vcd-creator.sh` to create folder structure
3. Drop your video file(s) in `input` folder
4. Run `./batch-vcd-creator.sh`
5. Watch for errors like `⚠️  WARNING: Buffer starvation detected!`
