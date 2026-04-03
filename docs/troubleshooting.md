# Troubleshooting Log: RHEL Container Storage Pitfalls

This document tracks the real-world issues encountered during the development of this orchestrator and their respective solutions.

---
## 🔐 Section 1: Permissions & Security (SELinux)
### Binary Execution & Search Permissions
**Issue**: Systemd returned status 126 (Permission Denied) when attempting to run lvm_auto_manager.sh.
**Technical Insight**:
- Executable Bit: In Linux, files copied or moved might lose the +x bit.
- Path Traversal: For Podman to access a volume at /var/lib/containers/storage/volumes/app_data, the container user (UID 1001) needs +x (search) permissions on every parent directory in the path.

## 🔄 Section 2: Process & Image Lifecycle
- **Issue**: 
**Technical Insight**:
  
## 🌐 Section 3: Networking & Path Alignment
  **Issue**: 
**Technical Insight**:

## 🛡 Section 4: Systemd Safeguards
  **Issue**: 
**Technical Insight**:
