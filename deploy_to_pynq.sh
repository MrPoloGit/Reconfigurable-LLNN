#!/bin/bash

# ---- CONFIG ----
PYNQ_IP="${PYNQ_IP:-192.168.0.13}"
PYNQ_USER="${PYNQ_USER:-xilinx}"
REMOTE_DIR="${REMOTE_DIR:-/home/xilinx}"
MODEL="${MODEL:-model1}"
MODEL_DIR="${MODEL_DIR:-data/sv/${MODEL}_soft}"
BUILD_DIR="${BUILD_DIR:-build/${MODEL}_soft/vivado}"
REMOTE_BASENAME="${REMOTE_BASENAME:-actual_llnn}"

# ---- HELPERS ----
find_latest_file() {
    local search_dir="$1"
    local pattern="$2"

    find "$search_dir" -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-
}

# ---- FIND FILES ----
# Prefer canonical SoftLUT outputs in MODEL_DIR, then known Vivado outputs in BUILD_DIR,
# then fall back to latest matches.
if [ -f "$MODEL_DIR/llnn.bit" ]; then
    BIT_FILE="$MODEL_DIR/llnn.bit"
elif [ -f "$BUILD_DIR/llnn_bd_wrapper.bit" ]; then
    BIT_FILE="$BUILD_DIR/llnn_bd_wrapper.bit"
elif [ -f "$BUILD_DIR/llnn_overlay.runs/impl_1/llnn_bd_wrapper.bit" ]; then
    BIT_FILE="$BUILD_DIR/llnn_overlay.runs/impl_1/llnn_bd_wrapper.bit"
else
    BIT_FILE=$(find_latest_file "$MODEL_DIR" "*.bit")
    if [ -z "$BIT_FILE" ]; then
        BIT_FILE=$(find_latest_file "$BUILD_DIR" "*.bit")
    fi
fi

if [ -f "$MODEL_DIR/llnn.hwh" ]; then
    HWH_FILE="$MODEL_DIR/llnn.hwh"
elif [ -f "$BUILD_DIR/llnn_bd.hwh" ]; then
    HWH_FILE="$BUILD_DIR/llnn_bd.hwh"
elif [ -f "$BUILD_DIR/llnn_overlay.gen/sources_1/bd/llnn_bd/hw_handoff/llnn_bd.hwh" ]; then
    HWH_FILE="$BUILD_DIR/llnn_overlay.gen/sources_1/bd/llnn_bd/hw_handoff/llnn_bd.hwh"
else
    HWH_FILE=$(find_latest_file "$MODEL_DIR" "*.hwh")
    if [ -z "$HWH_FILE" ]; then
        HWH_FILE=$(find_latest_file "$BUILD_DIR" "*.hwh")
    fi
fi

# ---- CHECK FILES EXIST ----
if [ -z "$BIT_FILE" ]; then
    echo "ERROR: No .bit file found in MODEL_DIR=$MODEL_DIR or BUILD_DIR=$BUILD_DIR"
    exit 1
fi

if [ -z "$HWH_FILE" ]; then
    echo "ERROR: No .hwh file found in MODEL_DIR=$MODEL_DIR or BUILD_DIR=$BUILD_DIR"
    exit 1
fi

echo "Found files:"
echo "  BIT: $BIT_FILE"
echo "  HWH: $HWH_FILE"
echo ""
echo "Remote names will be:"
echo "  $REMOTE_DIR/$REMOTE_BASENAME.bit"
echo "  $REMOTE_DIR/$REMOTE_BASENAME.hwh"
echo ""

# ---- COPY FILES (OVERWRITES EXISTING FILES) ----
echo "Copying files to PYNQ board..."
scp "$BIT_FILE" "$PYNQ_USER@$PYNQ_IP:$REMOTE_DIR/$REMOTE_BASENAME.bit" || exit 1
scp "$HWH_FILE" "$PYNQ_USER@$PYNQ_IP:$REMOTE_DIR/$REMOTE_BASENAME.hwh" || exit 1

LOCAL_SHA256=$(sha256sum "$BIT_FILE" | awk '{print $1}')

echo ""
echo "Done."
echo "Files copied to:"
echo "  $PYNQ_USER@$PYNQ_IP:$REMOTE_DIR/$REMOTE_BASENAME.bit"
echo "  $PYNQ_USER@$PYNQ_IP:$REMOTE_DIR/$REMOTE_BASENAME.hwh"
echo ""
echo "Local bitstream sha256:"
echo "  $LOCAL_SHA256"
echo ""
echo "Run this on the board to verify exact file identity:"
echo "  sha256sum $REMOTE_DIR/$REMOTE_BASENAME.bit"
echo ""
echo "Load on PYNQ with:"
echo "  from pynq import Overlay"
echo "  ol = Overlay('/home/xilinx/$REMOTE_BASENAME.bit')"
