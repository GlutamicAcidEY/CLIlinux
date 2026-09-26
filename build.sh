#!/bin/bash

set -e

PROJECT="$HOME/mydos"

echo "=== Building CLIlinux ==="

echo "[1/4] Compiling /init..."
gcc -static \
    -o "$PROJECT/rootfs/init" \
    "$PROJECT/build/init.c"

echo "[1/4] /init compiled successfully."

echo "[2/4] Checking userspace..."

if [ ! -f "$PROJECT/rootfs/bin/cli-shell" ]; then
    echo "ERROR: cli-shell not found."
    exit 1
fi

if [ ! -f "$PROJECT/rootfs/bin/busybox" ]; then
    echo "ERROR: BusyBox not found."
    exit 1
fi

echo "[2/4] Userspace looks good."

echo "[2.5/4] Setting up busybox symlinks..."
"$PROJECT/rootfs/bin/busybox" --install -s "$PROJECT/rootfs/bin"

echo "[Debug] Listing /bin contents:"
ls -la "$PROJECT/rootfs/bin"

echo "[2.5/4] Busybox symlinks created."

echo "[3/4] Creating initramfs..."
cd "$PROJECT/rootfs"

find . -print0 | cpio --null -ov --format=newc \
    > "$PROJECT/build/initramfs.cpio"

echo "[3/4] initramfs created successfully."

while true; do
    read -p "Start QEMU? (y/n): " yn
    case $yn in
        [Yy]* ) 
            echo "Proceeding..."
            qemu-system-x86_64 \
                -kernel "$PROJECT/kernel-src/arch/x86/boot/bzImage" \
                -initrd "$PROJECT/build/initramfs.cpio" \
                -append "console=ttyS0" \
                -nographic
            break
            ;;
        [Nn]* ) 
            echo "Exiting."
            # Add your 'No' code here
            exit
            ;;
        * ) 
            echo "Please answer yes or no."
            ;;
    esac
done

cd "$PROJECT"

qemu-system-x86_64 \
    -kernel "$PROJECT/kernel-src/arch/x86/boot/bzImage" \
    -initrd "$PROJECT/build/initramfs.cpio" \
    -append "console=ttyS0" \
    -nographic
