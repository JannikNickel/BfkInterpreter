#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"

DBG_FLAG=""
for arg in "$@";
do
    if [ "$arg" = "--dbg" ];
    then
        DBG_FLAG="-g"
        break
    fi
done

source $SCRIPT_DIR/build_config.sh
DIR="$SCRIPT_DIR/$OUTPUT_DIR"

mkdir -p "$DIR"

nasm -f elf64 $DBG_FLAG -o "$DIR/${OUTPUT_FILE}.o" "$SCRIPT_DIR/$MAIN_FILE"
ld -m elf_x86_64 -o "$DIR/$OUTPUT_FILE" "$DIR/${OUTPUT_FILE}.o"
