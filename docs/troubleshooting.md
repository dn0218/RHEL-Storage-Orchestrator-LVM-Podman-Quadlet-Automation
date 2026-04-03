# Troubleshooting Log: RHEL Container Storage Pitfalls

This document tracks the real-world issues encountered during the development of this orchestrator and their respective solutions.

---
## 🔐 Section 1: Permissions & Security (SELinux)
### Binary Execution & Search Permissions
**Issue**: Systemd returned status 126 (Permission Denied) when attempting to run lvm_auto_manager.sh.
<img width="1011" height="163" alt="image" src="https://github.com/user-attachments/assets/c56091bc-7107-4c34-bede-0b7526c6cd8c" />

```bash
[danny@rhel /]$ journalctl -xeu web-server.service
░░ An ExecStart= process belonging to unit web-server.service has exited.
░░ 
░░ The process' exit code is 'exited' and its exit status is 126.
```
**Technical Insight**:
- Executable Bit: In Linux, files copied or moved might lose the +x bit.
- Path Traversal: For Podman to access a volume at /var/lib/containers/storage/volumes/app_data, the container user (UID 1001) needs +x (search) permissions on every parent directory in the path.
**Resolution**:
```bash
[danny@rhel /]$ sudo chmod +x /usr/local/bin/lvm_auto_manager.sh
[danny@rhel /]$ sudo chmod o+x /var/lib/containers/storage/volumes
```

### SELinux Context Mismatch (The 403 Forbidden)
**Issue**: Files existed on the LVM volume, but Nginx returned 403 Forbidden.
<img width="537" height="142" alt="image" src="https://github.com/user-attachments/assets/ddf0cbeb-a577-4f19-8235-da25bdd42932" />

**Technical Insight**:RHEL enforces SELinux policies. If a volume is mounted via LVM, it often defaults to unlabeled_t or system_u:object_r:man_t. Podman requires the container_file_t type to allow the container process to "read" the host's files.
**Resolution**:Utilizing the :Z flag in the Quadlet file (e.g., Volume=...:Z) tells Podman to automatically relabel the volume. Manual intervention using chcon or restorecon can be used for verification.
```bash
[danny@rhel /]$ sudo chcon -R -t container_file_t /var/lib/containers/storage/volumes/app_data
```
<img width="693" height="78" alt="image" src="https://github.com/user-attachments/assets/023add49-6825-4bc6-9789-96e1423ee752" />



## 🔄 Section 2: Process & Image Lifecycle
### Non-Interactive Automation (LVM Signatures)
**Issue**: lvcreate hung indefinitely during the Systemd ExecStartPre phase.
**Technical Insight**: When lvcreate detects an existing filesystem signature (like an old ext4 header on a new volume), it prompts for confirmation: Wipe it? [y/n]. Systemd is non-interactive; it cannot provide the "y", leading to a timeout and service failure.
**Resolution**: Forced non-interactive mode.
  <img width="777" height="107" alt="image" src="https://github.com/user-attachments/assets/19ace1fa-1bd0-4c8a-b5bf-615f837b48a0" />

### S2I (Source-to-Image) Logic & Entrypoint Overrides
**Issue**: The container exited with status 0 immediately after starting, without serving traffic.
<img width="985" height="196" alt="image" src="https://github.com/user-attachments/assets/c4fb9a70-0582-4097-abea-5be70858d968" />
**Technical Insight**:The Red Hat ubi9/nginx-122 image is built using the S2I framework. By default, it checks the source directory (/opt/app-root/src) for buildable code. If it finds only an index.html (and not a full S2I structure), it prints a "Usage" message and shuts down gracefully.
**Resolution**:By-pass the S2I detection logic by explicitly defining the Nginx execution command.

<img width="296" height="62" alt="image" src="https://github.com/user-attachments/assets/d5cac4eb-f5a2-4a25-8e57-29743b1d84bc" />
```bash
Exec=nginx -g "daemon off;"
```

  
## 🌐 Section 3: Networking & Path Alignment

### Port 8080 Collision
**Issue**: bind: address already in use.

<img width="865" height="58" alt="image" src="https://github.com/user-attachments/assets/d372c502-4313-4e35-9c59-b6876103b9b6" />

**Technical Insight**:On RHEL, port 8080 is a "hot" port. It is commonly used by Cockpit (web console), various Java applications, or even the rootless Podman network driver (pasta).
**Resolution**:Remapped the external host port to 8888 while keeping the internal container port at 8080 to match the UBI image's non-privileged port requirement.
<img width="345" height="73" alt="image" src="https://github.com/user-attachments/assets/81b25055-91cd-42f4-8ae8-bdd1dfdaf263" />

### 403 Forbidden (Directory Alignment)
**Issue**: Nginx returns 403 even though files exist on the LVM volume.
**Technical Insight**:Standard Nginx uses /usr/share/nginx/html. However, Red Hat UBI Nginx images are optimized for OpenShift and use /opt/app-root/src as the default root.
**Resolution**:Re-align volume mapping to /opt/app-root/src.
<img width="693" height="78" alt="image" src="https://github.com/user-attachments/assets/d10365f8-2f3f-444e-9d1d-9e3344b04343" />


## 🛡 Section 4: Systemd Safeguards
### "start-limit-hit"
**Issue**: Service entered failed (Result: start-limit-hit).
<img width="830" height="75" alt="image" src="https://github.com/user-attachments/assets/2c963c89-a2a1-4762-b898-53b640104462" />
**Technical Insight**:Systemd has a protection mechanism (StartLimitBurst). If a service fails to start multiple times (e.g., 5 times in 10 seconds), Systemd stops trying to prevent CPU/Log exhaustion.
**Resolution**: 
- 1. Resolve the underlying 126 or 403 error.
  2. Reset the unit state to allow manual restarts.
     ```bash
     [danny@rhel /]$ sudo systemctl reset-failed web-server
     ```

Author: Danny (dn0218)
  
