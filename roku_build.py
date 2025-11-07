#!/usr/bin/env python3
"""
Roku Build Script - Alternative to makefile
Works on all systems (Linux, macOS, Windows) and all shells (bash, fish, zsh, etc.)

Usage:
    python3 roku_build.py pkg              # Create package
    python3 roku_build.py install           # Install app
    python3 roku_build.py remove            # Remove app
    python3 roku_build.py run               # Remove and install
    python3 roku_build.py check-target      # Check Roku connection

Environment Variables:
    ROKU_DEV_TARGET  - IP address of Roku device (required)
    DEVPASSWORD      - Roku device developer password (optional, for device auth)
    APP_KEY_PASS     - Package signing password from genkey (optional, for packaging)
"""

import os
import sys
import subprocess
import shutil
import zipfile
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse
import http.client

# Configuration
APPNAME = "Hydravion"
VERSION = "2.1.15"
ROKU_DEV_TARGET = os.environ.get("ROKU_DEV_TARGET", "")
DEVPASSWORD = os.environ.get("DEVPASSWORD", "")
APP_KEY_PASS = os.environ.get("APP_KEY_PASS", "")  # Package signing password (from genkey)

# Paths
BASE_DIR = Path(__file__).parent
DIST_DIR = BASE_DIR / "dist"
APPS_DIR = DIST_DIR / "apps"
PKG_DIR = DIST_DIR / "packages"
ZIP_FILE = APPS_DIR / f"{APPNAME}.zip"
DEV_SERVER_TMP = Path(tempfile.gettempdir()) / "dev_server_out"


def check_roku_target():
    """Check if ROKU_DEV_TARGET is set and device is reachable."""
    if not ROKU_DEV_TARGET:
        print("ERROR: ROKU_DEV_TARGET is not set.")
        print("Please set it in your environment:")
        print("  bash/zsh: export ROKU_DEV_TARGET=192.168.1.19")
        print("  fish:     set -x ROKU_DEV_TARGET 192.168.1.19")
        return False
    
    print(f"Checking dev server at {ROKU_DEV_TARGET}...")
    
    # Check dev web server (port 80)
    try:
        conn = http.client.HTTPConnection(ROKU_DEV_TARGET, timeout=5)
        conn.request("GET", "/")
        response = conn.getresponse()
        status = response.status
        
        if status in [200, 401]:
            print(f"Dev server is ready (HTTP status: {status})")
            return True
        else:
            print(f"WARNING: Unexpected HTTP status {status} (expected 200 or 401)")
            return True  # Still continue
    except Exception as e:
        print(f"ERROR: Device server is not responding on port 80 at {ROKU_DEV_TARGET}")
        print(f"Error: {e}")
        print("\nPlease verify:")
        print("  1. ROKU_DEV_TARGET is set to the correct IP address")
        print("  2. The Roku device is powered on and on the same network")
        print("  3. Developer Mode is enabled on the Roku device")
        print("  4. The developer web server is enabled")
        if not DEVPASSWORD:
            print("  5. If the server requires a password, set DEVPASSWORD in your environment")
        return False


def create_zip():
    """Create the application zip file."""
    print(f"*** Creating {APPNAME}.zip ***")
    
    APPS_DIR.mkdir(parents=True, exist_ok=True)
    
    if ZIP_FILE.exists():
        print(f"  >> removing old application zip {ZIP_FILE}")
        ZIP_FILE.unlink()
    
    print(f"  >> creating application zip {ZIP_FILE}")
    
    # Create zip file
    with zipfile.ZipFile(ZIP_FILE, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Add PNG files without compression
        for png_file in BASE_DIR.rglob("*.png"):
            if png_file.is_file():
                arcname = png_file.relative_to(BASE_DIR)
                zipf.write(png_file, arcname, compress_type=zipfile.ZIP_STORED)
        
        # Add all other files (excluding certain patterns)
        exclude_patterns = [
            "*.pkg", "dist", ".git", ".vscode", "out", "*.DS_Store",
            "makefile", "*.md", "storeassets*", "keys*", ".*"
        ]
        
        for file_path in BASE_DIR.rglob("*"):
            if file_path.is_file() and file_path.suffix != ".png":
                # Check if file should be excluded
                rel_path = file_path.relative_to(BASE_DIR)
                should_exclude = False
                
                for pattern in exclude_patterns:
                    if pattern in str(rel_path) or rel_path.name.startswith('.'):
                        should_exclude = True
                        break
                
                if not should_exclude:
                    arcname = rel_path
                    zipf.write(file_path, arcname)
    
    print(f"*** packaging {APPNAME} complete ***")
    return True


def install_app():
    """Install the app on the Roku device."""
    if not check_roku_target():
        return False
    
    if not ZIP_FILE.exists():
        print("ERROR: Zip file not found. Run 'pkg' or 'install' first.")
        return False
    
    print(f"Installing {APPNAME}...")
    
    # Build curl command
    url = f"http://{ROKU_DEV_TARGET}/plugin_install"
    curl_cmd = [
        "curl",
        "--user", f"rokudev:{DEVPASSWORD}" if DEVPASSWORD else "rokudev",
        "--digest",
        "--silent",
        "--show-error",
        "-F", "mysubmit=Install",
        "-F", f"archive=@{ZIP_FILE}",
        "--output", str(DEV_SERVER_TMP),
        "--write-out", "%{http_code}",
        url
    ]
    
    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, check=False)
        http_status = result.stdout.strip()
        
        if http_status != "200":
            print(f"ERROR: Device returned HTTP {http_status}")
            return False
        
        # Check response
        if DEV_SERVER_TMP.exists():
            with open(DEV_SERVER_TMP, 'r') as f:
                content = f.read()
                if "Success" in content or "success" in content.lower():
                    print("Result: Success")
                    return True
                else:
                    print(f"Result: {content[:200]}")
                    return False
    except Exception as e:
        print(f"ERROR: Failed to install app: {e}")
        return False


def remove_app():
    """Remove the app from the Roku device."""
    if not check_roku_target():
        return False
    
    print("Removing dev app...")
    
    url = f"http://{ROKU_DEV_TARGET}/plugin_install"
    curl_cmd = [
        "curl",
        "--user", f"rokudev:{DEVPASSWORD}" if DEVPASSWORD else "rokudev",
        "--digest",
        "--silent",
        "--show-error",
        "-F", "mysubmit=Delete",
        "-F", "archive=",
        "--output", str(DEV_SERVER_TMP),
        "--write-out", "%{http_code}",
        url
    ]
    
    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, check=False)
        http_status = result.stdout.strip()
        
        if http_status != "200":
            print(f"ERROR: Device returned HTTP {http_status}")
            return False
        
        print("Result: Success")
        return True
    except Exception as e:
        print(f"ERROR: Failed to remove app: {e}")
        return False


def create_package():
    """Create a .pkg file from the installed app."""
    if not check_roku_target():
        return False
    
    PKG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Get package signing password (different from DEVPASSWORD)
    # This is the password you set when generating your developer key with 'genkey'
    if APP_KEY_PASS:
        password = APP_KEY_PASS
    else:
        import getpass
        print("Note: This is the package SIGNING password (from genkey), not DEVPASSWORD.")
        print("Set APP_KEY_PASS environment variable to avoid this prompt.")
        password = getpass.getpass("Package signing password: ")
    
    print(f"Packaging {APPNAME}/{VERSION}...")
    
    # First, install the app
    if not install_app():
        print("ERROR: Failed to install app before packaging")
        return False
    
    # Create package
    pkg_time = int(time.time() * 1000)
    url = f"http://{ROKU_DEV_TARGET}/plugin_package"
    
    curl_cmd = [
        "curl",
        "--user", f"rokudev:{DEVPASSWORD}" if DEVPASSWORD else "rokudev",
        "--digest",
        "--silent",
        "--show-error",
        "-F", "mysubmit=Package",
        "-F", f"app_name={APPNAME}/{VERSION}",
        "-F", f"passwd={password}",
        "-F", f"pkg_time={pkg_time}",
        "--output", str(DEV_SERVER_TMP),
        "--write-out", "%{http_code}",
        url
    ]
    
    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, check=False)
        http_status = result.stdout.strip()
        
        if http_status != "200":
            print(f"ERROR: Device returned HTTP {http_status}")
            return False
        
        # Extract package link
        if not DEV_SERVER_TMP.exists():
            print("ERROR: No response from device")
            return False
        
        with open(DEV_SERVER_TMP, 'r') as f:
            content = f.read()
            if "Success" not in content:
                print(f"ERROR: Package creation failed: {content[:200]}")
                return False
        
        # Extract package link (simplified - may need better parsing)
        import re
        match = re.search(r'<a href="pkgs//([^"]+)"', content)
        if not match:
            print("ERROR: Could not extract package link from response")
            return False
        
        pkg_link = match.group(1)
        pkg_url = f"http://{ROKU_DEV_TARGET}/pkgs/{pkg_link}"
        
        # Download package
        timestamp = time.strftime("%Y-%m-%d_%H-%M-%S")
        pkg_file = PKG_DIR / f"{APPNAME}_{timestamp}.pkg"
        
        print(f"Downloading package from {pkg_url}...")
        
        curl_cmd = [
            "curl",
            "--user", f"rokudev:{DEVPASSWORD}" if DEVPASSWORD else "rokudev",
            "--digest",
            "--silent",
            "--show-error",
            "--output", str(pkg_file),
            "--write-out", "%{http_code}",
            pkg_url
        ]
        
        result = subprocess.run(curl_cmd, capture_output=True, text=True, check=False)
        http_status = result.stdout.strip()
        
        if http_status != "200":
            print(f"ERROR: Failed to download package: HTTP {http_status}")
            return False
        
        print(f"*** Package {APPNAME} complete: {pkg_file} ***")
        
        # Copy to Desktop if it exists
        desktop = Path.home() / "Desktop"
        if desktop.exists():
            shutil.copy2(pkg_file, desktop / pkg_file.name)
            print(f"Copied to Desktop: {desktop / pkg_file.name}")
        
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to create package: {e}")
        return False


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == "pkg":
        if not create_zip():
            sys.exit(1)
        if not create_package():
            sys.exit(1)
    elif command == "install":
        if not create_zip():
            sys.exit(1)
        if not install_app():
            sys.exit(1)
    elif command == "remove":
        if not remove_app():
            sys.exit(1)
    elif command == "run":
        remove_app()  # Ignore errors
        if not create_zip():
            sys.exit(1)
        if not install_app():
            sys.exit(1)
    elif command == "check-target":
        if not check_roku_target():
            sys.exit(1)
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()

