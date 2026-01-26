#!/bin/bash

# ==============================================================================
#  CD-i VIDEO CD FACTORY (v15 - World Standard Edition)
#  - NEW: Full PAL Support (352x288 @ 25fps).
#  - LOGIC: Auto-detects PAL (25/50fps) vs NTSC (23/24/30/60fps).
#  - SETTINGS: High Quality (-K tmpgenc, 8-bit precision, -q 6).
# ==============================================================================

# --- CONFIGURATION ---
INPUT_DIR="./input"
OUTPUT_DIR="./output"
CDI_FIX_DIR="./cdi_fix"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
#  1. SYSTEM CHECK
# ==============================================================================
install_deps() {
    echo -e "${BLUE}🔍 Checking system dependencies...${NC}"
    local MISSING_TOOLS=0
    
    # 1. Check for Standard Tools
    for tool in ffmpeg ffprobe mpeg2enc mplex vcdxbuild curl unzip; do
        if ! command -v $tool &> /dev/null; then 
            MISSING_TOOLS=1
            echo -e "${RED}❌ Missing tool: $tool${NC}"
        fi
    done

    # 2. Check for CHDMAN
    if ! command -v chdman &> /dev/null; then
        MISSING_TOOLS=1
        echo -e "${RED}❌ Missing tool: chdman${NC}"
    fi

    if [ $MISSING_TOOLS -eq 0 ]; then
        echo -e "${GREEN}✅ All tools are installed.${NC}"
        return
    fi

    # 3. Auto-Install Logic
    echo -e "${YELLOW}⚠️  Missing tools detected. Attempting installation...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then echo -e "${RED}❌ Install Homebrew first.${NC}"; exit 1; fi
        brew install ffmpeg mjpegtools vcdimager rom-tools
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y ffmpeg mjpegtools vcdimager curl unzip mame-tools
    else
        echo -e "${RED}❌ Unsupported OS. Please install dependencies manually.${NC}"
        exit 1
    fi
}

# ==============================================================================
#  2. BRIDGE & CONFIG SETUP
# ==============================================================================
setup_bridge() {
    mkdir -p "$CDI_FIX_DIR"

    # Download if missing
    if [ ! -f "$CDI_FIX_DIR/CDI_VCD.APP" ]; then
        curl -L -o "$CDI_FIX_DIR/bridge.zip" http://www.icdia.co.uk/sw_app/vcd_on_cdi_411.zip
        unzip -o -q "$CDI_FIX_DIR/bridge.zip" -d "$CDI_FIX_DIR"
        rm "$CDI_FIX_DIR/bridge.zip"
        
        # FIX: macOS compatible uppercase conversion using 'tr'
        for f in "$CDI_FIX_DIR"/*; do
            DIRNAME=$(dirname "$f")
            BASENAME=$(basename "$f")
            UPPER_NAME=$(echo "$BASENAME" | tr '[:lower:]' '[:upper:]')
            if [ "$BASENAME" != "$UPPER_NAME" ]; then
                mv "$f" "$DIRNAME/$UPPER_NAME" 2>/dev/null
            fi
        done
        
        # Ensure main app is definitely present under the expected name
        mv "$CDI_FIX_DIR/CDI_VCD.APP" "$CDI_FIX_DIR/CDI_VCD.APP" 2>/dev/null
    fi

    # Config Generation
    if [ ! -f "$CDI_FIX_DIR/CDI_VCD.CFG" ]; then
        cat > "$CDI_FIX_DIR/CDI_VCD.CFG" <<EOF
CONTROLS=ALL
CURCOL=YELLOW
PSDCURCOL=RED
PSDCURSHAPE=ARROW
CENTRTRACK=2
AUTOPLAY=AUTO_ON
DUALCHAN=DUAL_ON
TIMECODE_X=64
TIMECODE_Y=100
LOTID_X=64
LOTID_Y=64
ALBUM=STANDARD
EOF
    fi
}

# ==============================================================================
#  3. PROCESSING PIPELINE
# ==============================================================================
process_video() {
    local FILE="$1"
    local FILENAME=$(basename -- "$FILE")
    local NAME="${FILENAME%.*}"
    local CLEAN_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    local LOG_FILE="$OUTPUT_DIR/${CLEAN_NAME}.log"
    
    echo -e "\n${BLUE}🎬 Processing: $FILENAME${NC}"
    echo "----------------------------------------------------------------" > "$LOG_FILE"
    echo "CD-i VCD Factory Log - $(date)" >> "$LOG_FILE"
    echo "File: $FILENAME" >> "$LOG_FILE"
    echo "----------------------------------------------------------------" >> "$LOG_FILE"

    # 3.1 DETECT FRAMERATE & SET STANDARD
    RAW_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$FILE")
    
    if [ -z "$RAW_FPS" ]; then
        echo -e "${RED}❌ Error: Could not detect framerate.${NC}"
        return
    fi

    FPS_INT=$(echo $RAW_FPS | awk -F/ '{ if ($2 == 0) print 0; else print int($1/$2 + 0.5) }')

    # === NEW: PAL VS NTSC LOGIC ===
    # If FPS is 25 or 50, treat as PAL.
    if [ "$FPS_INT" -eq 25 ] || [ "$FPS_INT" -eq 50 ]; then
        MODE_MSG="PAL (25 fps)"
        FFMPEG_RATE="-r 25"
        MPEG2_FLAG="-n p"     # 'p' = PAL Standard
        SCALE_RES="352:288"   # Taller resolution for PAL
    
    # If FPS < 26 (and not 25), treat as NTSC FILM (23.976)
    elif [ "$FPS_INT" -lt 26 ]; then
        MODE_MSG="NTSC FILM (23.976 fps)"
        FFMPEG_RATE="-r 24000/1001"
        MPEG2_FLAG="-n n"     # 'n' = NTSC Standard
        SCALE_RES="352:240"
        
    # Otherwise treat as NTSC VIDEO (29.97)
    else
        MODE_MSG="NTSC VIDEO (29.97 fps)"
        FFMPEG_RATE="-r 30000/1001"
        MPEG2_FLAG="-n n"     # 'n' = NTSC Standard
        SCALE_RES="352:240"
    fi

    echo -e "   ${CYAN}📊 Detected $FPS_INT fps. Mode: $MODE_MSG${NC}"
    echo "Detection: $FPS_INT fps -> Mode: $MODE_MSG | Res: $SCALE_RES" >> "$LOG_FILE"

    # 3.2 ENCODE VIDEO (Videophile Settings)
    echo -e "   ${YELLOW}⚡ Encoding Video Stream...${NC}"
    echo -e "\n--- VIDEO ENCODING LOG ---" >> "$LOG_FILE"
    
    # We use $SCALE_RES for the resolution and $MPEG2_FLAG for the Norm
    (ffmpeg -v info -i "$FILE" \
        -vf "crop='min(iw,ih*4/3)':'min(ih,iw*3/4)',scale=$SCALE_RES" \
        $FFMPEG_RATE -pix_fmt yuv420p -f yuv4mpegpipe - 2>> "$LOG_FILE" \
        | mpeg2enc -v 0 -f 1 $MPEG2_FLAG -a 2 -K tmpgenc -r 32 -4 1 -q 6 -b 1150 -o "temp_video.m1v" 2>> "$LOG_FILE")

    if [ ! -s "temp_video.m1v" ]; then 
        echo -e "${RED}❌ Encoding failed. Check $LOG_FILE.${NC}"
        return
    fi

    # 3.3 ENCODE AUDIO
    echo -e "   ${YELLOW}⚡ Encoding Audio Stream...${NC}"
    ffmpeg -v info -i "$FILE" -ar 44100 -ac 2 -b:a 224k -f mp2 -y "temp_audio.mp2" >> "$LOG_FILE" 2>&1

    # 3.4 MULTIPLEX
    echo -e "   ${YELLOW}📦 Multiplexing...${NC}"
    echo -e "\n--- MULTIPLEX LOG ---" >> "$LOG_FILE"
    mplex -f 1 -b 46 -o "compliant.mpg" "temp_audio.mp2" "temp_video.m1v" >> "$LOG_FILE" 2>&1

    # ERROR CHECKING
    if grep -q "data will arrive too late" "$LOG_FILE"; then
         echo -e "${RED}⚠️  WARNING: Buffer starvation detected!${NC}"
    fi

    # 3.5 GENERATE XML (K3b Style)
    echo -e "   ${YELLOW}📝 Generating XML...${NC}"
    cat > videocd.xml <<EOF
<?xml version="1.0"?>
<!DOCTYPE videocd PUBLIC "-//GNU//DTD VideoCD//EN" "http://www.gnu.org/software/vcdimager/videocd.dtd">
<videocd xmlns="http://www.gnu.org/software/vcdimager/1.0/" class="vcd" version="2.0">
  <info><album-id/><volume-count>1</volume-count><volume-number>1</volume-number><restriction>0</restriction></info>
  <pvd>
    <volume-id>${CLEAN_NAME}</volume-id>
    <system-id>CD-RTOS CD-BRIDGE</system-id>
    <application-id>CDI/CDI_VCD.APP;1</application-id>
  </pvd>
  <filesystem>
    <folder><name>SEGMENT</name></folder>
    <folder>
      <name>CDI</name>
      <file src="${CDI_FIX_DIR}/CDI_IMAG.RTF" format="mixed"><name>CDI_IMAG.RTF</name></file>
      <file src="${CDI_FIX_DIR}/CDI_TEXT.FNT"><name>CDI_TEXT.FNT</name></file>
      <file src="${CDI_FIX_DIR}/CDI_VCD.APP"><name>CDI_VCD.APP</name></file>
      <file src="${CDI_FIX_DIR}/CDI_VCD.CFG"><name>CDI_VCD.CFG</name></file>
    </folder>
  </filesystem>
  <sequence-items>
    <sequence-item src="compliant.mpg" id="sequence-00">
      <default-entry id="entry-000"/>
    </sequence-item>
  </sequence-items>
</videocd>
EOF

    # 3.6 BUILD IMAGE
    echo -e "   ${YELLOW}💿 Building Disc Image...${NC}"
    echo -e "\n--- IMAGE BUILD LOG ---" >> "$LOG_FILE"
    vcdxbuild --progress videocd.xml >> "$LOG_FILE" 2>&1
    
    if [ -f "videocd.bin" ]; then
        mv videocd.bin "$OUTPUT_DIR/${CLEAN_NAME}.bin"
        sed "s|videocd.bin|${CLEAN_NAME}.bin|g" videocd.cue > "$OUTPUT_DIR/${CLEAN_NAME}.cue"
        rm videocd.cue
        echo -e "${GREEN}✅ Finished: $OUTPUT_DIR/${CLEAN_NAME}.bin${NC}"
        
        # 3.7 AUTO-CHD
        if command -v chdman &> /dev/null; then
            echo -e "   ${YELLOW}🗜️  Compressing to CHD...${NC}"
            chdman createcd -i "$OUTPUT_DIR/${CLEAN_NAME}.cue" -o "$OUTPUT_DIR/${CLEAN_NAME}.chd" >> "$LOG_FILE" 2>&1
            if [ -f "$OUTPUT_DIR/${CLEAN_NAME}.chd" ]; then
                echo -e "${GREEN}✅ Created CHD: $OUTPUT_DIR/${CLEAN_NAME}.chd${NC}"
                # Optional: rm "$OUTPUT_DIR/${CLEAN_NAME}.bin" "$OUTPUT_DIR/${CLEAN_NAME}.cue"
            fi
        fi
        echo -e "${CYAN}   Log saved to: $LOG_FILE${NC}"
    else
        echo -e "${RED}❌ Image creation failed.${NC}"
    fi

    rm -f temp_video.m1v temp_audio.mp2 compliant.mpg videocd.xml
}

# ==============================================================================
#  MAIN EXECUTION
# ==============================================================================
install_deps
setup_bridge
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [ -z "$(ls -A $INPUT_DIR)" ]; then
    echo -e "${RED}⚠️  Input folder is empty! Place videos in $INPUT_DIR${NC}"; exit 1
fi

for video in "$INPUT_DIR"/*; do
    [ -e "$video" ] || continue
    FILENAME=$(basename "$video")
    
    # IGNORE NON-VIDEO FILES
    if [[ "$FILENAME" == .* ]] || \
       [[ "$FILENAME" == *.chd ]] || \
       [[ "$FILENAME" == *.bin ]] || \
       [[ "$FILENAME" == *.cue ]] || \
       [[ "$FILENAME" == *.iso ]] || \
       [[ "$FILENAME" == *.log ]]; then 
       continue
    fi
    
    process_video "$video"
done

echo -e "\n${GREEN}🎉 BATCH COMPLETE!${NC}"
