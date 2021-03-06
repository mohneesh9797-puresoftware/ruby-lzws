#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

./aarch64-unknown-linux-gnu/build.sh
./aarch64_be-unknown-linux-gnu/build.sh

./arm-unknown-linux-gnueabi/build.sh
./armeb-unknown-linux-gnueabi/build.sh

./mips-unknown-linux-gnu/build.sh
./mipsel-unknown-linux-gnu/build.sh
