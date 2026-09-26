#!/bin/bash

set -e

PROJECT=~/CLIlinux

echo "=== Building CLIlinux ==="

echo "[1/5] Compiling /init..."
gcc -static \
    -o "$PROJECT/rootfs/init" \
    "$PROJECT/build/init.c"

echo "[1/5] /init compiled successfully."

echo "[2/5] Checking userspace..."

if [ ! -f "$PROJECT/rootfs/bin/cli-shell" ]; then
    echo "ERROR: cli-shell not found."
    exit 1
fi

if [ ! -f "$PROJECT/rootfs/bin/busybox" ]; then
    echo "ERROR: BusyBox not found."
    exit 1
fi

echo "[2/5] Userspace looks good."

echo "[2.5/5] Setting up busybox symlinks..."
"$PROJECT/rootfs/bin/busybox" --install -s "$PROJECT/rootfs/bin"

echo "[2.5/5] Busybox symlinks created."

echo "[3/5] Creating initramfs..."
cd "$PROJECT/rootfs"

find . -print0 | cpio --null -ov --format=newc \
    > "$PROJECT/build/initramfs.cpio"

echo "[3/5] initramfs created successfully."

echo "[3.5/5] Building ISO..."
mkdir -p "$PROJECT/iso/boot/grub"
cp "$PROJECT/kernel-src/arch/x86/boot/bzImage" "$PROJECT/iso/boot/vmlinuz"
cp "$PROJECT/build/initramfs.cpio" "$PROJECT/iso/boot/initramfs.img"

cat > "$PROJECT/iso/boot/grub/grub.cfg" << 'EOF'
menuentry "CLIlinux" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o "$PROJECT/mydos.iso" "$PROJECT/iso/" 2>/dev/null || \
    echo "Warning: grub-mkrescue failed. Install: sudo apt install grub-pc-bin xorriso"

echo "[3.5/5] ISO created: $PROJECT/mydos.iso"

cd "$PROJECT"

echo "[4/5] Choose boot method:"
echo "1) QEMU from ISO (slower)"
echo "2) QEMU from initramfs (fastest)"
echo "3) Skip boot"

read -p "Selection (1-3): " choice

case $choice in
    1)
        if [ -f "$PROJECT/mydos.iso" ]; then
            echo "Booting from ISO..."
            qemu-system-x86_64 \
                -cdrom "$PROJECT/mydos.iso" \
                -nographic
        else
            echo "ISO not found. Falling back to initramfs..."
            qemu-system-x86_64 \
                -kernel "$PROJECT/kernel-src/arch/x86/boot/bzImage" \
                -initrd "$PROJECT/build/initramfs.cpio" \
                -append "console=ttyS0" \
                -nographic
        fi
        ;;
    2)
        echo "Booting from initramfs..."
        qemu-system-x86_64 \
            -kernel "$PROJECT/kernel-src/arch/x86/boot/bzImage" \
            -initrd "$PROJECT/build/initramfs.cpio" \
            -append "console=ttyS0" \
            -nographic
        ;;
    3)
        echo "Skipping boot."
        ;;
    *)
        echo "Invalid selection."
        ;;
esac

echo "[5/5] Done!"
