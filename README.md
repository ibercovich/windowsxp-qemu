# Windows XP QEMU Docker

Run Windows XP in a Docker container with unattended installation support.

## Features

- **Unattended Installation** - Fully automated Windows XP setup
- **Web VNC Access** - Browser-based VNC at `http://localhost:8888`
- **Audio Support** - NoVNC client with audio injection
- **Nginx Reverse Proxy** - Clean web interface
- **ARM64/Apple Silicon Support** - Runs on all platforms

## Quick Start

1. **Prepare your files:**

   ```bash
   # Place your files in the iso/ directory:
   iso/
   ├── xp.iso          # Windows XP installation ISO
   └── unattended.iso  # Unattended answer file ISO
   ```

2. **Start the container:**

   ```bash
   docker-compose up -d
   ```

3. **Run unattended installation:**

   ```bash
   docker exec -it winxp-qemu-winxp-qemu-1 /root/start-winxp-unattended-simple.sh
   ```

4. **Monitor installation:**
   - Open [http://localhost:8888](http://localhost:8888) in your browser
   - VNC password: `password1`
   - Installation takes 30-60 minutes

## What It Does

The unattended installation script automatically:

- Creates a 20GB VHD disk if needed
- Mounts both Windows XP and unattended ISOs
- Starts QEMU with optimal settings for Windows XP
- Runs fully automated installation without user input

## Configuration

- **RAM:** 2GB
- **Network:** RTL8139 (Windows XP compatible)
- **Display:** VNC accessible via web browser
- **Admin Password:** Configured in your unattended.iso

## Credits

- [Tech on Fire YouTube](https://www.youtube.com/watch?v=2EEzKlF7miA)
- [Original GitHub repo](https://github.com/theonemule/qemu-docker)
- [google85/qemu-docker](https://github.com/google85/qemu-docker)
