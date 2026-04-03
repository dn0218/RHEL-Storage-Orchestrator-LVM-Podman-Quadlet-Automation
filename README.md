# RHEL-Storage-Orchestrator: LVM & Podman Quadlet Automation

![RHEL 9](https://img.shields.io/badge/OS-RHEL%209.7-red)
![Podman](https://img.shields.io/badge/Container-Podman-purple)
![LVM2](https://img.shields.io/badge/Storage-LVM2-orange)

## 📌 Project Overview
This project demonstrates an enterprise-grade automated storage and container orchestration solution on **RHEL 9**. It solves the common "Disk Full" or "Storage Provisioning" pain point by integrating **LVM (Logical Volume Manager)** directly into the **Podman Quadlet** lifecycle.

### Core Workflow:
1.  **Systemd** triggers the container service.
2.  **ExecStartPre** runs a parametric LVM script to detect, create, or extend storage on-the-fly.
3.  **Podman Quadlet** mounts the newly prepared LVM volume with correct **SELinux** contexts.
4.  **UBI-based Nginx** serves content from the high-availability storage.

## 🛠 Architecture
- **OS**: Red Hat Enterprise Linux 9.7
- **Storage**: LVM2 (with XFS `xfs_growfs` support)
- **Container Engine**: Podman (Quadlet for Systemd integration)
- **Base Image**: `registry.access.redhat.com/ubi9/nginx-122`



## 🚀 Key Features
- **Smart Scenario Detection**: Automatically identifies if it needs to `CREATE` a new volume or `EXTEND` an existing one.
- **Quadlet Native**: Uses RHEL 9's latest `.container` unit files instead of legacy scripts.
- **SELinux Hardening**: Fully compliant with `container_file_t` and `:Z` relabeling.
- **Parametric Design**: Easily change mount points, disk paths, or VG/LV names via CLI flags.

## 📂 Project Structure
```text
.
├── scripts/
│   └── lvm_auto_manager.sh    # The core LVM logic (Create/Extend/Wipe)
├── quadlet/
│   └── web-server.container   # Systemd-Podman integration unit
├── docs/
│   └── troubleshooting.md     # Detailed fix logs for common RHEL pitfalls
└── README.md                  # This file
```

## ⚡ Quick Start
1. Install the LVM Manager
```bash
sudo cp scripts/lvm_auto_manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/lvm_auto_manager.sh
```
2. Deploy the Quadlet
```bash
sudo cp quadlet/web-server.container /etc/containers/systemd/
sudo systemctl daemon-reload
sudo systemctl start web-server
```

## 📊 Result Preview
When the script runs, it provides a clear state report:
```bash
[danny@rhel /]$ sudo ./lvm_auto_manager.sh -m /mnt/test_vol -d /dev/sda -v vg_test -l lv_test -s 500M
🚀 Starting Task: EXTEND on /mnt/test_vol
📈 Extending /dev/vg_test/lv_test by 500M...
  File system xfs found on vg_test/lv_test mounted at /mnt/test_vol.
  Size of logical volume vg_test/lv_test changed from 3.00 GiB (768 extents) to <3.49 GiB (893 extents).
  Extending file system xfs to <3.49 GiB (3745513472 bytes) on vg_test/lv_test...
xfs_growfs /dev/vg_test/lv_test
meta-data=/dev/mapper/vg_test-lv_test isize=512    agcount=12, agsize=65536 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=786432, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 786432 to 914432
xfs_growfs done
  Extended file system xfs on vg_test/lv_test.
  Logical volume vg_test/lv_test successfully resized.
--- Final State ---
```
