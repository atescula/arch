#!/bin/bash
# CRITICAL GRUB-BTRFS CONFIGURATION
# Run this script IN CHROOT during archinstall
# Based on: https://www.youtube.com/watch?v=FiK1cGbyaxs

echo "=========================================="
echo "CRITICAL GRUB-BTRFS SETUP (IN CHROOT)"
echo "=========================================="
echo ""
echo "This script configures Grub properly for Btrfs snapshots."
echo "It MUST be run during installation in chroot."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verify we're in the right environment
if [ ! -d "/efi" ]; then
    echo -e "${RED}ERROR: /efi directory not found!${NC}"
    echo "This script must be run in chroot during installation."
    exit 1
fi

echo -e "${YELLOW}Current /efi structure:${NC}"
ls -la /efi/
echo ""
echo -e "${YELLOW}Current /boot structure:${NC}"
ls -la /boot/
echo ""

# Step 1: Fix Grub location (CRUCIAL!)
echo -e "${GREEN}Step 1: Moving Grub from /efi to /boot${NC}"
echo "This ensures kernel, microcode, and grub are all in /boot"
echo ""

if [ -d "/efi/grub" ]; then
    echo "Removing incorrectly placed /efi/grub..."
    rm -rf /efi/grub
    echo -e "${GREEN}✓ Removed /efi/grub${NC}"
else
    echo -e "${YELLOW}⚠ /efi/grub not found (might already be correct)${NC}"
fi

echo ""
echo "Reinstalling Grub with correct paths..."
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=arch

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Grub reinstalled successfully${NC}"
else
    echo -e "${RED}✗ Grub installation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}New /efi structure (should contain only EFI folder):${NC}"
ls -la /efi/
echo ""
echo -e "${YELLOW}New /boot structure (should contain grub, kernel, microcode):${NC}"
ls -la /boot/
echo ""

# Step 2: Configure mkinitcpio for grub-btrfs-overlayfs
echo -e "${GREEN}Step 2: Adding grub-btrfs-overlayfs hook to mkinitcpio${NC}"
echo ""

if grep -q "grub-btrfs-overlayfs" /etc/mkinitcpio.conf; then
    echo -e "${YELLOW}⚠ grub-btrfs-overlayfs already in mkinitcpio.conf${NC}"
else
    echo "Adding grub-btrfs-overlayfs to HOOKS..."
    # Add grub-btrfs-overlayfs at the end of HOOKS line
    sed -i 's/^HOOKS=(\(.*\))$/HOOKS=(\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
    
    if grep -q "grub-btrfs-overlayfs" /etc/mkinitcpio.conf; then
        echo -e "${GREEN}✓ Added grub-btrfs-overlayfs to HOOKS${NC}"
    else
        echo -e "${RED}✗ Failed to add grub-btrfs-overlayfs!${NC}"
        echo "Please manually add 'grub-btrfs-overlayfs' to the end of HOOKS in /etc/mkinitcpio.conf"
    fi
fi

echo ""
echo -e "${YELLOW}Current HOOKS configuration:${NC}"
grep "^HOOKS=" /etc/mkinitcpio.conf
echo ""

# Step 3: Regenerate initramfs
echo -e "${GREEN}Step 3: Regenerating initramfs${NC}"
echo ""
mkinitcpio -P

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Initramfs regenerated successfully${NC}"
else
    echo -e "${RED}✗ Initramfs regeneration failed!${NC}"
    exit 1
fi

# Step 4: Regenerate Grub config
echo ""
echo -e "${GREEN}Step 4: Regenerating Grub configuration${NC}"
echo ""
grub-mkconfig -o /boot/grub/grub.cfg

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Grub config regenerated successfully${NC}"
else
    echo -e "${RED}✗ Grub config regeneration failed!${NC}"
    exit 1
fi

# Step 5: Enable grub-btrfsd service
echo ""
echo -e "${GREEN}Step 5: Enabling grub-btrfsd service${NC}"
echo ""
systemctl enable grub-btrfsd.service

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ grub-btrfsd.service enabled${NC}"
else
    echo -e "${RED}✗ Failed to enable grub-btrfsd.service!${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}GRUB-BTRFS SETUP COMPLETE!${NC}"
echo "=========================================="
echo ""
echo "Final structure:"
echo ""
echo "/efi should contain:"
echo "  └── EFI/"
echo "      ├── BOOT/"
echo "      └── arch/"
echo ""
echo "/boot should contain:"
echo "  ├── amd-ucode.img"
echo "  ├── initramfs-linux.img"
echo "  ├── initramfs-linux-fallback.img"
echo "  ├── vmlinuz-linux"
echo "  └── grub/"
echo "      └── grub.cfg"
echo ""
echo -e "${YELLOW}IMPORTANT: After first boot, configure Snapper and create a snapshot${NC}"
echo -e "${YELLOW}to test that snapshots appear in the Grub boot menu!${NC}"
echo ""
