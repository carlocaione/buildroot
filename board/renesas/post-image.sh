#!/bin/bash

BOARD_DIR="$(dirname $0)"
mkimage=$HOST_DIR/bin/mkimage

cp $BOARD_DIR/renesas.its $BINARIES_DIR

(cd $BINARIES_DIR && $mkimage -f renesas.its renesas.itb)
