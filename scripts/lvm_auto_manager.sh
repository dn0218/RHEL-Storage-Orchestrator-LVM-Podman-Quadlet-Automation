#!/bin/bash
# =================================================================
# Project: RHEL Storage Orchestrator - LVM Parametric Module （ENG VERISON）
# Author: Danny (Updated for Automation)
# Usage: ./lvm_auto_manager.sh -m /mnt/data -d /dev/sdb -v vg_app -l lv_app -s 2G
# =================================================================

[[ $EUID -ne 0 ]] && echo "❌ Must run as root" && exit 1

# Ensure systemd environment can locate LVM and filesystem tools
export PATH=$PATH:/usr/sbin:/sbin:/usr/local/sbin

# Default values
SIZE="1G"
FORCE=false

usage() {
    echo "Usage: $0 -m <mount_point> -d <disk> -v <vg_name> -l <lv_name> [-s <size>] [-f]"
    echo "  -f: Force cleanup (destructive operation)"
    exit 1
}

# --- Step 1: Parse Arguments ---
while getopts "m:d:v:l:s:f" opt; do
    case $opt in
        m) TARGET_MOUNT=$(echo "$OPTARG" | sed 's:/*$::') ;;
        d) CHOSEN_DISK="$OPTARG" ;;
        v) VG_NAME="$OPTARG" ;;
        l) LV_NAME="$OPTARG" ;;
        s) SIZE="$OPTARG" ;;
        f) FORCE=true ;;
        *) usage ;;
    esac
done

if [[ -z "$TARGET_MOUNT" || -z "$CHOSEN_DISK" || -z "$VG_NAME" || -z "$LV_NAME" ]]; then
    usage
fi

# --- Step 2: State Detection (Decoupled Logic) ---
MOUNT_INFO=$(findmnt -nvo SOURCE,FSTYPE "$TARGET_MOUNT" 2>/dev/null)
DEVICE_PATH="/dev/$VG_NAME/$LV_NAME"

# Scenario detection
if [[ -n "$MOUNT_INFO" ]]; then
    CURRENT_DEV=$(echo "$MOUNT_INFO" | awk '{print $1}')
    if [[ "$CURRENT_DEV" == *"$LV_NAME"* ]]; then
        SCENARIO="EXTEND"
    else
        SCENARIO="CONFLICT"
    fi
else
    SCENARIO="CREATE"
fi

echo "🚀 Starting task: $SCENARIO on $TARGET_MOUNT"

# --- Step 3: Execution Logic ---
case $SCENARIO in
"CREATE")
        [[ ! -d "$TARGET_MOUNT" ]] && mkdir -p "$TARGET_MOUNT"
        
        # If LV already exists, skip creation and mount directly
        if lvs "$VG_NAME/$LV_NAME" &>/dev/null; then
            echo "ℹ️  Logical volume $LV_NAME already exists. Skipping creation and attempting mount..."
            
            mount "$DEVICE_PATH" "$TARGET_MOUNT" || {
                echo "❌ Mount failed. Please verify filesystem integrity."
                exit 1
            }

            if [ ! -f "$TARGET_MOUNT/index.html" ]; then
                echo "📄 Initializing default index page..."
                echo "<h1>LVM Volume Auto-Provisioned on $(date)</h1>" > "$TARGET_MOUNT/index.html"
                
                # Fix SELinux context to ensure accessibility (e.g. containers, web services)
                restorecon -v "$TARGET_MOUNT/index.html"
            fi

        else
            if $FORCE; then
                echo "⚠️  Performing force cleanup on $CHOSEN_DISK (destructive)..."
                umount -l "$CHOSEN_DISK"* 2>/dev/null
                wipefs -a "$CHOSEN_DISK"
            fi

            # LVM creation pipeline
            if ! pvs "$CHOSEN_DISK" &>/dev/null; then
                echo "📦 Initializing Physical Volume..."
                pvcreate -f "$CHOSEN_DISK" || exit 1
            fi
            
            if ! vgs "$VG_NAME" &>/dev/null; then
                echo "📦 Creating Volume Group: $VG_NAME"
                vgcreate "$VG_NAME" "$CHOSEN_DISK"
            fi

            echo "💎 Creating Logical Volume: $LV_NAME (Size: $SIZE)"
            lvcreate -y -L "$SIZE" -n "$LV_NAME" "$VG_NAME" --wipesignatures y || exit 1
            
            echo "🧱 Formatting filesystem (XFS)..."
            mkfs.xfs "$DEVICE_PATH"

            echo "🔗 Mounting to $TARGET_MOUNT"
            mount "$DEVICE_PATH" "$TARGET_MOUNT"
        fi
        ;;

    "EXTEND")
        echo "📈 Extending $DEVICE_PATH by $SIZE..."

        # Check available free space in VG
        FREE_PE=$(vgs --noheadings -o vg_free_count "$VG_NAME" | tr -d ' ')
        
        if [ "$FREE_PE" -eq 0 ] && [[ "$CHOSEN_DISK" != $(pvs --noheadings -o pv_name -S vg_name="$VG_NAME") ]]; then
            echo "➕ Adding new disk $CHOSEN_DISK to Volume Group $VG_NAME"
            vgextend "$VG_NAME" "$CHOSEN_DISK"
        fi
        
        lvextend -L +"$SIZE" -r "$DEVICE_PATH"
        ;;

    "CONFLICT")
        echo "❌ Error: Mount point $TARGET_MOUNT is already occupied by another device."
        exit 1
        ;;
esac

# --- Step 4: Final State Report ---
echo "--- Final State ---"
df -hT "$TARGET_MOUNT" | tail -n 1
