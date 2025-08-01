#!/bin/bash

# Windows XP QEMU Installation Script
# Automatically creates unattended ISO and installs/boots Windows XP

set -e

echo "=== Windows XP QEMU Manager ==="

# Function to get Windows XP product key from Internet Archive
get_product_key() {
    echo "🔑 Fetching product key from Internet Archive..."
    
    # Download the page and extract the serial key using Windows XP key pattern
    PRODUCT_KEY=$(wget -qO- "https://archive.org/details/WinXPProSP3x86" | grep -o "[A-Z0-9]\{5\}-[A-Z0-9]\{5\}-[A-Z0-9]\{5\}-[A-Z0-9]\{5\}-[A-Z0-9]\{5\}" | head -1)
    
    # Validate the key format (should be 5 groups of 5 characters separated by dashes)
    if [[ $PRODUCT_KEY =~ ^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$ ]]; then
        echo "✅ Found product key: $PRODUCT_KEY"
    else
        echo "❌ Error: Invalid key format found: $PRODUCT_KEY"
        echo "Please check internet connection and try again"
        exit 1
    fi
}

# Function to download Windows XP ISO
download_windows_xp_iso() {
    echo "📥 Downloading Windows XP Professional SP3 from Internet Archive..."
    echo "Source: https://archive.org/download/WinXPProSP3x86/"
    echo "File: en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
    echo ""
    
    # Download with wget, showing progress
    wget -O /isos/xp.iso \
        "https://archive.org/download/WinXPProSP3x86/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
    
    if [ -f "/isos/xp.iso" ] && [ -s "/isos/xp.iso" ]; then
        echo "✅ Successfully downloaded Windows XP ISO"
        echo "📏 Size: $(du -h /isos/xp.iso | cut -f1)"
    else
        echo "❌ Error: Failed to download Windows XP ISO"
        echo "Please check your internet connection and try again"
        exit 1
    fi
}

# Function to create unattended ISO
create_unattended_iso() {
    echo "🔄 Creating unattended Windows XP installation ISO..."
    
    # Check if original Windows XP ISO exists, download if not
    if [ ! -f "/isos/xp.iso" ]; then
        echo "📀 Windows XP ISO not found, downloading..."
        download_windows_xp_iso
    else
        echo "📀 Found existing Windows XP ISO: /isos/xp.iso"
    fi

    # Get the product key dynamically
    get_product_key

    # Create the answer file with dynamic product key
    cat > /tmp/winnt.sif << EOF
[Data]
AutoPartition=1
MsDosInitiated="0"
UnattendedInstall="Yes"

[Unattended]
UnattendMode=FullUnattended
OemSkipEula=Yes
OemPreinstall=No
TargetPath=\WINDOWS
Repartition=Yes
UnattendSwitch=Yes
CrashDumpSetting=0

[GuiUnattended]
AdminPassword="password"
EncryptedAdminPassword=No
AutoLogon=Yes
AutoLogonCount=1
OEMSkipRegional=1
TimeZone=4
OemSkipWelcome=1

[UserData]
ProductKey="$PRODUCT_KEY"
FullName="tb-admin"
OrgName="tb"
ComputerName=XPServer

[Display]
BitsPerPel=32
Xresolution=1024
YResolution=768
Vrefresh=60

[TapiLocation]
CountryCode=1
Dialing=Tone
AreaCode=555

[RegionalSettings]
LanguageGroup="1"
SystemLocale=00000409
UserLocale=00000409
InputLocale=0409:00000409

[Networking]
InstallDefaultComponents=Yes

[Identification]
JoinWorkgroup=WORKGROUP

[Shell]
DefaultStartPanelOff=Yes
DefaultThemesOff=Yes

[GuiRunOnce]
; Copy post-setup script from CD-ROM to hard drive and execute it
Command0="cmd /c copy D:\install\postsetup.bat %SystemDrive%\postsetup.bat"
Command1="%SystemDrive%\postsetup.bat"
EOF

    echo "📝 Created unattended answer file"

    # Create temporary directory for ISO extraction
    rm -rf /tmp/xp-unattended
    mkdir -p /tmp/xp-unattended/iso

    # Extract ISO contents using 7z and preserve file structure
    echo "📂 Extracting Windows XP ISO contents..."
    7z x /isos/xp.iso -o/tmp/xp-unattended/iso >/dev/null
    
    # Ensure all extracted files have proper permissions
    echo "📂 Setting proper file permissions..."
    find /tmp/xp-unattended/iso -type d -exec chmod 755 {} \;
    find /tmp/xp-unattended/iso -type f -exec chmod 644 {} \;

    # Create the post-setup script
    cat > /tmp/postsetup.bat << 'EOF'
@echo off
echo === Post-setup Configuration ===
echo Starting Windows XP post-installation configuration...

:: Create C:\install directory if it doesn't exist for compatibility
if not exist "C:\install" mkdir "C:\install"

:: Delete OOBE (welcome wizard) - suppress errors if file doesn't exist
echo Disabling Windows XP welcome wizard...
if exist "%SystemRoot%\system32\oobe\msoobe.exe" (
    del /f /q "%SystemRoot%\system32\oobe\msoobe.exe" >nul 2>&1
    echo - Welcome wizard disabled
) else (
    echo - Welcome wizard already disabled or not found
)

:: Disable OOBE through registry as backup
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE" /v MediaBootInstall /t REG_DWORD /d 1 /f >nul 2>&1

:: Create tb-guest user account
echo Creating tb-guest user account...
net user tb-guest /add /passwordchg:no /passwordreq:no /comment:"Guest user account" >nul 2>&1
if %errorlevel%==0 (
    net localgroup Users tb-guest /add >nul 2>&1
    echo - tb-guest user created successfully
) else (
    echo - tb-guest user already exists or creation failed
)

:: Configure autologon as tb-admin
echo Configuring autologon for tb-admin...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /d "tb-admin" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /d "password" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /d "%COMPUTERNAME%" /f >nul 2>&1
echo - Autologon configured for tb-admin

:: Force classic logon (disable welcome screen)
echo Configuring classic logon screen...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v LogonType /t REG_DWORD /d 0 /f >nul 2>&1
echo - Classic logon screen enabled

:: Replace desktop GUI with cmd.exe for headless operation
echo Configuring command-line shell...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /d "cmd.exe" /f >nul 2>&1
echo - Desktop replaced with command prompt

:: Create a marker file to indicate post-setup completion
echo Post-setup completed successfully > "C:\postsetup-completed.txt"
echo %date% %time% >> "C:\postsetup-completed.txt"

echo.
echo === Configuration Complete ===
echo Users created: tb-admin (admin) and tb-guest (standard)
echo System will boot into command prompt as tb-admin
echo Post-setup marker file: C:\postsetup-completed.txt
echo.

:: Exit successfully
exit /b 0
EOF

    # Copy the answer file to the ISO root and I386 directory
    echo "📝 Adding unattended answer file to ISO..."
    cp /tmp/winnt.sif /tmp/xp-unattended/iso/
    cp /tmp/winnt.sif /tmp/xp-unattended/iso/I386/
    
    # Create install directory and copy post-setup script
    echo "📝 Adding post-setup script to ISO..."
    mkdir -p /tmp/xp-unattended/iso/install
    cp /tmp/postsetup.bat /tmp/xp-unattended/iso/install/
    
    # Verify the post-setup script was copied correctly
    if [ -f "/tmp/xp-unattended/iso/install/postsetup.bat" ]; then
        echo "✅ Post-setup script added to ISO successfully"
        echo "📋 Script size: $(du -h /tmp/xp-unattended/iso/install/postsetup.bat | cut -f1)"
    else
        echo "❌ Error: Failed to add post-setup script to ISO"
        exit 1
    fi

    # Make the directory structure writable
    chmod -R +w /tmp/xp-unattended/iso

    # Verify El Torito boot image exists
    echo "📂 Verifying Windows XP El Torito boot image..."
    if [ -f "/tmp/xp-unattended/iso/[BOOT]/Boot-NoEmul.img" ]; then
        echo "✅ Windows XP El Torito boot image found"
        BOOT_FILE="[BOOT]/Boot-NoEmul.img"
        BOOT_LOAD_SIZE=4
    else
        echo "❌ Error: Windows XP El Torito boot image not found in extracted ISO."
        echo "Available files in root:"
        ls -la /tmp/xp-unattended/iso/ | head -10
        echo "Available files in [BOOT]:"
        ls -la "/tmp/xp-unattended/iso/[BOOT]/" 2>/dev/null || echo "No [BOOT] directory found"
        exit 1
    fi

    # Create the new unattended ISO with proper boot sector preservation
    echo "🔨 Building unattended installation ISO..."
    
    # Create ISO with Windows XP El Torito boot configuration using xorriso
    echo "Boot file: $BOOT_FILE"
    echo "Creating ISO with xorriso and Windows XP El Torito boot configuration..."
    
    xorriso -as mkisofs \
        -iso-level 2 \
        -J -l -D -N \
        -joliet-long \
        -relaxed-filenames \
        -V "WXPFPP_EN" \
        -b "$BOOT_FILE" \
        -no-emul-boot \
        -boot-load-size $BOOT_LOAD_SIZE \
        -o /isos/xp-unattended.iso \
        /tmp/xp-unattended/iso/ >/dev/null 2>&1

    # Verify the created ISO is valid and bootable
    if [ -f "/isos/xp-unattended.iso" ] && [ -s "/isos/xp-unattended.iso" ]; then
        echo "✅ Created unattended installation ISO"
        echo "📏 Size: $(du -h /isos/xp-unattended.iso | cut -f1)"
        
        # Test ISO integrity
        echo "🔍 Verifying ISO integrity..."
        if file /isos/xp-unattended.iso | grep -q "ISO 9660"; then
            echo "✅ ISO format verified successfully"
        else
            echo "⚠️  Warning: ISO format verification failed, but proceeding anyway"
        fi
    else
        echo "❌ Error: Failed to create unattended ISO or file is empty"
        exit 1
    fi

    # Clean up temporary files
    rm -rf /tmp/xp-unattended /tmp/winnt.sif /tmp/postsetup.bat
}

# Check if unattended ISO exists, create it if not
if [ ! -f "/isos/xp-unattended.iso" ]; then
    echo "📀 Unattended ISO not found, creating it..."
    create_unattended_iso
else
    echo "📀 Found existing unattended ISO: /isos/xp-unattended.iso"
fi

# Create or check VHD
if [ ! -f "/isos/xp.vhd" ]; then
    echo "Creating Windows XP virtual hard disk..."
    qemu-img create -f raw /isos/xp.vhd 5G
    echo "Created 5GB raw disk: /isos/xp.vhd"
    FRESH_INSTALL=true
else
    # Check if Windows XP is already installed by looking for Windows boot sector and NTFS partition
    echo "Checking if Windows XP is already installed..."
    VHD_INFO=$(file /isos/xp.vhd)
    echo "   VHD info: $VHD_INFO"
    
    # Look for Windows XP indicators: MS-MBR, XP, ID=0x7 (NTFS), or "active" partition
    if echo "$VHD_INFO" | grep -q -E "(MS-MBR.*XP|ID=0x7.*active|NTFS.*active|DOS/MBR.*partition)"; then
        echo "✅ Found existing Windows XP installation - booting from hard drive"
        BOOT_FROM_HDD=true
    else
        echo "📀 Empty or unformatted disk - will install Windows XP"
        FRESH_INSTALL=true
    fi
fi

echo ""
if [ "$BOOT_FROM_HDD" = "true" ]; then
    echo "=== Booting Existing Windows XP Installation ==="
    echo "VM Configuration:"
    echo "  - RAM: 2GB"
    echo "  - Disk: /isos/xp.vhd (existing installation)"
    echo "  - Boot: Hard Drive (no CD-ROM needed)"
    echo "  - Network: RTL8139 (Windows XP compatible)"
    echo "  - Display: Command line mode (no graphics)"
    echo ""
    echo "Booting to existing Windows XP installation in headless mode..."
    echo "Note: Windows XP will boot without display (command line only)"
    echo ""
    
    # Start QEMU booting from hard drive in headless mode
    echo "Starting QEMU with existing Windows XP (headless + optimized)..."
    qemu-system-i386 \
      -cpu pentium \
      -m 2G \
      -drive file=/isos/xp.vhd,format=raw,cache=writeback \
      -boot c \
      -nic user,model=rtl8139 \
      -no-acpi \
      -no-hpet \
      -rtc base=localtime \
      -machine pc \
      -accel tcg,thread=multi \
      -smp 2 \
      -display vnc=:1 &
    
    # Get QEMU process ID
    QEMU_PID=$!
    echo "✅ QEMU started in background with PID: $QEMU_PID"
    echo "🔗 Access via web VNC at: http://[ your-server-ip | localhost ]:8888/vnc.html"
    echo "📊 Monitor VM status with: /monitor-vm.sh status"
    echo ""
    echo "🎯 Script completed successfully. Windows XP is booting..."
    echo "💡 Use 'ps aux | grep qemu' to check if QEMU is still running"
else
    echo "=== Starting Windows XP Unattended Installation ==="
    
    # Get product key if not already set
    if [ -z "$PRODUCT_KEY" ]; then
        get_product_key
    fi
    
    echo "VM Configuration:"
    echo "  - RAM: 2GB"
    echo "  - Disk: /isos/xp.vhd"
    echo "  - ISO: xp-unattended.iso (with built-in winnt.sif)"
    echo "  - Mode: Fully Unattended Installation"
    echo "  - Product Key: $PRODUCT_KEY"
    echo "  - Users: tb-admin (admin, password: password), tb-guest (standard user)"
    echo "  - Computer Name: XPServer"
    echo "  - Network: RTL8139 (Windows XP compatible)"
    echo ""
    echo "Installation will proceed automatically without user input..."
    echo "This may take 30-60 minutes depending on system performance."
    echo "Access via web VNC at: http://localhost:8888 (password: password1)"
    echo ""

    # Start QEMU with the unattended ISO
    export DISPLAY=:1
    echo "Starting QEMU with unattended Windows XP ISO (optimized)..."
    qemu-system-i386 \
      -cpu pentium \
      -m 2G \
      -drive file=/isos/xp.vhd,format=raw,if=ide,index=0,cache=writeback \
      -drive file=/isos/xp-unattended.iso,media=cdrom,if=ide,index=1,cache=writeback \
      -boot order=dc \
      -nic user,model=rtl8139 \
      -no-acpi \
      -no-hpet \
      -rtc base=localtime \
      -machine pc \
      -accel tcg,thread=multi \
      -smp 2 \
      -display vnc=:1 &
    
    # Get QEMU process ID
    QEMU_PID=$!
    echo "✅ QEMU started in background with PID: $QEMU_PID"
    echo "🔗 Access via web VNC at: http://[ your-server-ip | localhost ]:8888/vnc.html"
    echo "📊 Monitor installation progress with: /monitor-vm.sh watch"
    echo "📸 Check blue pixels (Windows interface): /monitor-vm.sh blue"
    echo ""
    echo "🎯 Script completed successfully. Windows XP installation started..."
    echo "💡 Installation will take 30-60 minutes. Use monitoring commands above to track progress."
    echo "🔍 Use 'ps aux | grep qemu' to check if QEMU is still running"
fi