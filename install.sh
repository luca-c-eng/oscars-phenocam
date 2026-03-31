#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# oscars-phenocam — Automated Installation Script
# =============================================================================
# Usage (run as any user with sudo privileges):
#
#  curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/dev/v1.3.0/install.sh | bash
#
# What this script does:
#   1. Checks prerequisites (OS, hardware, network)
#   2. Installs system dependencies (git, exiftool) at pinned versions
#   3. Clones the repository from GitHub
#   4. Verifies all expected files are present
#   5. Enables the camera in raspi-config (non-interactive)
#   6. Deploys the software to system directories
#   7. Creates configuration file templates
#   8. Installs and enables systemd units and udev rules
#   9. Runs a first capture+upload cycle as system health check
#  10. Reports installation status
#
# After installation, configure:
#   sudo nano /etc/phenocam/settings.txt        (adjust SITENAME, hours, etc.)
#   sudo nano /etc/phenocam/ftp_credentials.txt (FTP server credentials)
# =============================================================================

# ── Constants ─────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/luca-c-eng/oscars-phenocam.git"
REPO_BRANCH="dev/v1.3.0"
INSTALL_DIR="/opt/oscars-phenocam"
SOFTWARE_DIR="${INSTALL_DIR}/software"
LIB_DIR="/usr/local/lib/phenocam"
CONFIG_DIR="/etc/phenocam"
LOG_DIR="/var/log/phenocam"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"

# Pinned dependency versions (tested and verified)
EXIFTOOL_VERSION="13.25+dfsg-1"
EXPECTED_FILE_COUNT=40

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ── Helpers ───────────────────────────────────────────────────────────────────
log_step()  { echo -e "\n${BLUE}${BOLD}▶ $*${NC}"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $*"; }
log_err()   { echo -e "  ${RED}✗${NC} $*"; }
log_fatal() { echo -e "\n${RED}${BOLD}FATAL: $*${NC}\n"; exit 1; }

# ── Step 1 — Prerequisites ────────────────────────────────────────────────────
log_step "Checking prerequisites..."

# Must not run as root
[[ "$EUID" -ne 0 ]] || log_fatal "Do not run this script as root. Run as a regular user with sudo privileges."

# Must have sudo
sudo -n true 2>/dev/null || log_fatal "This script requires passwordless sudo, or run: sudo -v first."

# Check OS
if grep -q "trixie" /etc/os-release 2>/dev/null; then
  log_ok "OS: Debian 13 trixie (Raspberry Pi OS)"
else
  log_warn "Unexpected OS version. This script was tested on Debian 13 trixie."
  log_warn "Proceeding, but some steps may fail."
fi

# Check architecture
ARCH="$(uname -m)"
if [[ "$ARCH" == "aarch64" ]]; then
  log_ok "Architecture: aarch64 (64-bit ARM)"
else
  log_warn "Unexpected architecture: $ARCH. Expected aarch64."
fi

# Check network
if ip route get 1.1.1.1 >/dev/null 2>&1; then
  log_ok "Network: internet connectivity confirmed"
else
  log_fatal "No internet connectivity. Connect the RPi to the network and retry."
fi

# ── Step 2 — Install dependencies ────────────────────────────────────────────
log_step "Installing system dependencies..."

sudo apt-get update -qq

# Install git (not pre-installed on RPi OS Lite)
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get install -y git
  log_ok "git installed"
else
  log_ok "git already present: $(git --version)"
fi

# Install exiftool at pinned version
INSTALLED_EXIFTOOL="$(dpkg-query -W -f='${Version}' libimage-exiftool-perl 2>/dev/null || true)"
if [[ "$INSTALLED_EXIFTOOL" == "$EXIFTOOL_VERSION" ]]; then
  log_ok "exiftool already at pinned version: $EXIFTOOL_VERSION"
else
  sudo apt-get install -y "libimage-exiftool-perl=${EXIFTOOL_VERSION}" || {
    log_warn "Pinned version $EXIFTOOL_VERSION not available. Installing latest available..."
    sudo apt-get install -y libimage-exiftool-perl
  }
  INSTALLED_EXIFTOOL="$(dpkg-query -W -f='${Version}' libimage-exiftool-perl 2>/dev/null || true)"
  log_ok "exiftool installed: $INSTALLED_EXIFTOOL"
  if [[ "$INSTALLED_EXIFTOOL" != "$EXIFTOOL_VERSION" ]]; then
    log_warn "Installed version ($INSTALLED_EXIFTOOL) differs from pinned ($EXIFTOOL_VERSION)."
    log_warn "Software will likely work, but report this for future VERSIONS.txt update."
  fi
fi

# Freeze exiftool version (prevent apt upgrade from changing it)
sudo apt-mark hold libimage-exiftool-perl >/dev/null
log_ok "exiftool version frozen (apt-mark hold)"

# Verify other required tools
for tool in rpicam-still curl sftp flock; do
  if command -v "$tool" >/dev/null 2>&1; then
    log_ok "$tool: $(which "$tool")"
  else
    log_fatal "$tool not found. Is this Raspberry Pi OS Lite (64-bit)?"
  fi
done

# Verify runuser path
if [[ -x /usr/sbin/runuser ]]; then
  log_ok "runuser: /usr/sbin/runuser"
else
  log_fatal "runuser not found at /usr/sbin/runuser."
fi

# ── Step 3 — Clone repository ─────────────────────────────────────────────────
log_step "Cloning repository..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
  log_warn "Repository already exists at $INSTALL_DIR. Pulling latest changes..."
  sudo git -C "$INSTALL_DIR" pull --ff-only
else
   sudo git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi
log_ok "Repository cloned to: $INSTALL_DIR"

# ── Step 4 — Verify file count ────────────────────────────────────────────────
log_step "Verifying downloaded files..."

ACTUAL_COUNT="$(find "$INSTALL_DIR" -type f | wc -l)"
if [[ "$ACTUAL_COUNT" -ge "$EXPECTED_FILE_COUNT" ]]; then
  log_ok "File count: $ACTUAL_COUNT (expected >= $EXPECTED_FILE_COUNT)"
else
  log_fatal "File count mismatch: found $ACTUAL_COUNT, expected $EXPECTED_FILE_COUNT. Clone may be incomplete."
fi

# Verify critical files exist
CRITICAL_FILES=(
  "${SOFTWARE_DIR}/bin/phenocam-capture.sh"
  "${SOFTWARE_DIR}/bin/phenocam-upload.sh"
  "${SOFTWARE_DIR}/bin/phenocam-run.sh"
  "${SOFTWARE_DIR}/bin/phenocam-usb-attach.sh"
  "${SOFTWARE_DIR}/bin/phenocam-usb-detach.sh"

  "${SOFTWARE_DIR}/scripts/common.sh"
  "${SOFTWARE_DIR}/scripts/config_read.sh"
  "${SOFTWARE_DIR}/scripts/cycle.sh"
  "${SOFTWARE_DIR}/scripts/meta_build.sh"
  "${SOFTWARE_DIR}/scripts/queue_manager.sh"
  "${SOFTWARE_DIR}/scripts/upload_sftp.sh"
  "${SOFTWARE_DIR}/scripts/upload_ftp.sh"
  "${SOFTWARE_DIR}/scripts/uploader_daemon.sh"

  "${SOFTWARE_DIR}/config/phenocam.logrotate"

  "${SOFTWARE_DIR}/systemd/phenocam-init.service"
  "${SOFTWARE_DIR}/systemd/phenocam-capture.timer"
  "${SOFTWARE_DIR}/systemd/99-phenocam-usb.rules"
)

for f in "${CRITICAL_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    log_ok "Found: $(basename "$f")"
  else
    log_fatal "Critical file missing: $f"
  fi
done

# ── Step 5 — Enable camera ────────────────────────────────────────────────────
log_step "Enabling camera interface..."

# Check if camera is already detected
if vcgencmd get_camera 2>/dev/null | grep -q "detected=1"; then
  log_ok "Camera already enabled and detected"
else
  # Enable camera via raspi-config non-interactive
  sudo raspi-config nonint do_camera 0 2>/dev/null || true
  log_warn "Camera enabled in raspi-config. A reboot will be required after installation."
  log_warn "After reboot, run: vcgencmd get_camera  (expected: supported=1 detected=1)"
fi

# ── Step 6 — Deploy software ──────────────────────────────────────────────────
log_step "Deploying software..."

# Create system user
if id phenocam >/dev/null 2>&1; then
  log_ok "User phenocam already exists"
else
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin phenocam
  log_ok "User phenocam created (uid=$(id -u phenocam))"
fi

# Add phenocam to video group
sudo usermod -aG video phenocam
log_ok "phenocam added to video group"

# Create directory structure
sudo mkdir -p \
  "${LIB_DIR}/bin" \
  "${LIB_DIR}/scripts" \
  "${CONFIG_DIR}/keys" \
  "${LOG_DIR}" \
  "/var/lib/phenocam/queue"
log_ok "Directory structure created"

# Set config directory group BEFORE creating config files
sudo chown -R root:phenocam "${CONFIG_DIR}"
log_ok "Config directory group set to phenocam"

# Copy scripts
sudo cp "${SOFTWARE_DIR}/scripts/"*.sh "${LIB_DIR}/scripts/"
sudo cp "${SOFTWARE_DIR}/bin/"*.sh     "${LIB_DIR}/bin/"
sudo chmod +x "${LIB_DIR}/bin/"*.sh "${LIB_DIR}/scripts/"*.sh
log_ok "Scripts deployed and made executable ($(find "${LIB_DIR}" -name "*.sh" | wc -l) files)"

# Set permissions
sudo chmod 750 \
  "${CONFIG_DIR}" \
  "${CONFIG_DIR}/keys" \
  "${LOG_DIR}" \
  "/var/lib/phenocam" \
  "/var/lib/phenocam/queue"
sudo chown phenocam:phenocam "${LOG_DIR}" "/var/lib/phenocam" "/var/lib/phenocam/queue"
log_ok "Permissions set"

# ── Step 7 — Create configuration templates ───────────────────────────────────
log_step "Creating configuration files..."

# settings.txt — create only if not already present
if [[ ! -f "${CONFIG_DIR}/settings.txt" ]]; then
  sudo tee "${CONFIG_DIR}/settings.txt" > /dev/null << 'SETTINGS'
mysite
+1
Europe/Rome
6
22
30
eth0
phenocam
auto
20
80
/media:/mnt
90
general
nd
nd
nd
nd
nd
nd
SETTINGS
  log_ok "settings.txt created (edit to set your SITENAME and parameters)"
  log_warn "ACTION REQUIRED: sudo nano ${CONFIG_DIR}/settings.txt — set SITENAME (line 1)"
else
  log_ok "settings.txt already exists — not overwritten"
fi

# server.txt — empty placeholder for SFTP
if [[ ! -f "${CONFIG_DIR}/server.txt" ]]; then
  sudo touch "${CONFIG_DIR}/server.txt"
  log_ok "server.txt created (empty — SFTP disabled)"
fi

# ftp_credentials.txt — placeholder only
if [[ ! -f "${CONFIG_DIR}/ftp_credentials.txt" ]]; then
  sudo tee "${CONFIG_DIR}/ftp_credentials.txt" > /dev/null << 'FTP'
YOUR_FTP_HOST_OR_IP
YOUR_FTP_PORT
/your/remote/base/path
your_ftp_username
your_ftp_password
FTP
  log_ok "ftp_credentials.txt created (placeholder — edit with real values)"
  log_warn "ACTION REQUIRED: sudo nano ${CONFIG_DIR}/ftp_credentials.txt — set real FTP credentials"
else
  log_ok "ftp_credentials.txt already exists — not overwritten"
fi

# known_hosts — empty placeholder for SFTP
if [[ ! -f "${CONFIG_DIR}/known_hosts" ]]; then
  sudo touch "${CONFIG_DIR}/known_hosts"
  log_ok "known_hosts created (empty)"
fi

# Generate SSH key pair for SFTP (only if not already present)
if [[ ! -f "${CONFIG_DIR}/keys/phenocam_key" ]]; then
  sudo ssh-keygen -t ed25519 \
    -f "${CONFIG_DIR}/keys/phenocam_key" \
    -N "" \
    -C "phenocam@$(hostname)" \
    -q
  log_ok "SSH key pair generated: ${CONFIG_DIR}/keys/phenocam_key"
else
  log_ok "SSH key pair already exists — not regenerated"
fi

log_ok "SSH public key (send to SFTP server administrator):"
echo ""
sudo cat "${CONFIG_DIR}/keys/phenocam_key.pub"
echo ""

# ── Step 8 — Install systemd units and udev rules ─────────────────────────────
log_step "Installing systemd units and udev rules..."

# Copy systemd units
for unit in \
  phenocam-capture.service phenocam-capture.timer \
  phenocam-upload.service  phenocam-upload.timer \
  phenocam-init.service    run-phenocam.mount; do
  sudo cp "${SOFTWARE_DIR}/systemd/${unit}" "${SYSTEMD_DIR}/"
  log_ok "Installed: $unit"
done

# Install logrotate configuration
if [[ -f "${SOFTWARE_DIR}/config/phenocam.logrotate" ]]; then
  sudo cp "${SOFTWARE_DIR}/config/phenocam.logrotate" /etc/logrotate.d/phenocam
  sudo chmod 644 /etc/logrotate.d/phenocam
  log_ok "logrotate configuration installed: /etc/logrotate.d/phenocam"
else
  log_warn "phenocam.logrotate not found — log rotation not installed"
fi

# Install udev rule
sudo cp "${SOFTWARE_DIR}/systemd/99-phenocam-usb.rules" "${UDEV_DIR}/"
sudo udevadm control --reload-rules
log_ok "udev rule installed and reloaded (USB hot-plug enabled)"

# Reload systemd
sudo systemctl daemon-reload
log_ok "systemd daemon reloaded"

# ── Step 9 — Enable and start ─────────────────────────────────────────────────
log_step "Enabling and starting PhenoCam..."

sudo systemctl enable --now phenocam-init.service
log_ok "phenocam-init.service: enabled and started (first capture+upload cycle running...)"

# Wait for init service to complete
TIMEOUT=120
ELAPSED=0
while systemctl is-active phenocam-init.service >/dev/null 2>&1; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    log_warn "phenocam-init.service taking longer than expected ($TIMEOUT s)."
    break
  fi
done

# Check init result
if systemctl is-failed phenocam-init.service >/dev/null 2>&1; then
  log_err "phenocam-init.service failed. Check: sudo journalctl -u phenocam-init.service"
else
  log_ok "phenocam-init.service completed successfully"
fi

# Enable timers
sudo systemctl enable --now phenocam-capture.timer phenocam-upload.timer
log_ok "phenocam-capture.timer enabled (fires at :00 and :30 every hour)"
log_ok "phenocam-upload.timer enabled (fires every 9 minutes)"

# ── Step 10 — Final report ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Installation complete — PhenoCam v$(cat "${SOFTWARE_DIR}/VERSION")${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Log:${NC}    sudo cat /var/log/phenocam/phenocam.log | tail -20"
echo -e "  ${BOLD}Status:${NC} sudo systemctl status phenocam-capture.timer phenocam-upload.timer"
echo -e "  ${BOLD}Camera:${NC} sudo /usr/local/lib/phenocam/bin/diag_camera.sh"
echo -e "  ${BOLD}Upload:${NC} sudo /usr/local/lib/phenocam/bin/diag_upload.sh"
echo ""

# Check if reboot needed (camera was just enabled)
if vcgencmd get_camera 2>/dev/null | grep -q "detected=0"; then
  echo -e "${YELLOW}${BOLD}  ⚠  REBOOT REQUIRED: camera was just enabled.${NC}"
  echo -e "${YELLOW}     Run: sudo reboot${NC}"
  echo ""
fi

# Remind about required configuration
echo -e "${YELLOW}${BOLD}  Required actions before the system can upload images:${NC}"
echo -e "${GREEN}  1. Set station name:${NC}"
echo -e "${GREEN}     sudo nano /etc/phenocam/settings.txt${NC}"
echo -e "${YELLOW}     (edit SITENAME on line 1 at minimum)${NC}"
echo ""
echo -e "${YELLOW}  Choose your upload protocol:${NC}"
echo ""
echo -e "${YELLOW}  FTP — edit credentials:${NC}"
echo -e "${GREEN}     sudo nano /etc/phenocam/ftp_credentials.txt${NC}"
echo ""
echo -e "${YELLOW}  SFTP (recommended for security — SSH key, no password over network):${NC}"
echo -e "${GREEN}     1. Send the public key above to your SFTP server administrator${NC}"
echo -e "${GREEN}     2. sudo nano /etc/phenocam/server.txt  (add one or more server hostnames)${NC}"
echo -e "${GREEN}     3. sudo ssh-keyscan -H <hostname> >> /etc/phenocam/known_hosts${NC}"
echo -e "${GREEN}     4. Edit line 8 of settings.txt (SFTP_USER)${NC}"
echo -e "${GREEN}     5. Edit line 14 of settings.txt (REMOTE_LAYOUT: general or icos)${NC}"
echo ""
