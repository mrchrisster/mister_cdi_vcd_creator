# MiSTer CD-i VCD Factory

A robust, cross-platform batch tool to convert modern video files into **Philips CD-i compatible** Video CD (VCD) disc images.

Designed for use with the **MiSTer FPGA CD-i Core** and accurate emulators (MAME/cdiemu).

## Features
- **Strict Compliance:** Uses `mpeg2enc` to enforce CD-i hardware limits.
- **Dependency Management:** Tells you what tools are required on macOS and Linux.
- **Bridge Files:** Automatically fetches the required "Green Book/White Book" bridge files.
- **Format detection:** PAL / NTSC
- **Multiple output formats:** bin/cue and chd support

## Prerequisites
- **macOS:** Homebrew installed.
- **Linux:** Debian/Ubuntu based system.
- Tools needed: ffmpeg, mjpegtools, vcdimager, rom-tools (on macOS) or mame-tools (on Linux).

## Usage
1. Copy sh script to a local folder on your computer. Here is an all in one command to install:  
   ```mkdir -p ~/mister_cdi_vcd_creator && cd ~/mister_cdi_vcd_creator && curl -kLO https://raw.githubusercontent.com/mrchrisster/mister_cdi_vcd_creator/refs/heads/main/batch-vcd-creator.sh && chmod +x batch-vcd-creator.sh```
  
2. Install tools needed listed in prerequisites or simply launch the script to install tools.
3. Run script once with `./batch-vcd-creator.sh` to create folder structure. It will say `⚠️  Input folder is empty! Place videos in ./input`
4. Drop your video file(s) in `input` folder
5. Run `./batch-vcd-creator.sh`
6. Watch for errors like `⚠️  WARNING: Buffer starvation detected!`

## Credits
Thanks to slamy for creating the CDI core for MiSTer. Check his MPEG1 handbook which helped a lot when creating this:  
https://github.com/Slamy/MPEG1_Handbook/tree/main
