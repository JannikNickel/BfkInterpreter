#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"

source $SCRIPT_DIR/build_config.sh
bash "$SCRIPT_DIR/build.sh"

$SCRIPT_DIR/$OUTPUT_DIR/$OUTPUT_FILE $1
