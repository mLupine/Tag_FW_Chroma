#!/usr/bin/env bash
#
# Build script for OpenEPaperLink Chroma Tag Firmware
# Builds all supported tag variants
#
# Supported platforms: macOS, Linux
#

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Darwin*)    PLATFORM="macOS";;
    Linux*)     PLATFORM="Linux";;
    *)          PLATFORM="Unknown";;
esac

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  OpenEPaperLink Chroma Tag Firmware Builder${NC}"
echo -e "${BLUE}  Platform: ${PLATFORM}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# Required SDCC version
REQUIRED_SDCC_VERSION="4.2.0"

# Supported builds
declare -a BUILDS=(
    "chroma29"
    "chroma29_8151"
    "chroma42"
    "chroma42_8176"
    "chroma74y"
    "chroma74r"
)

# Function to check if SDCC is available and at the right version
check_sdcc() {
    if ! command -v sdcc &> /dev/null; then
        return 1
    fi

    SDCC_VERSION=$(sdcc -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [ "$SDCC_VERSION" != "$REQUIRED_SDCC_VERSION" ]; then
        echo -e "${YELLOW}Warning: Found SDCC ${SDCC_VERSION}, but ${REQUIRED_SDCC_VERSION} is recommended${NC}"
        echo -e "${YELLOW}Proceeding anyway, but build may fail or produce incorrect code${NC}"
        return 0
    fi

    echo -e "${GREEN}✓ Found SDCC ${SDCC_VERSION}${NC}"
    return 0
}

# Function to install SDCC on macOS
install_sdcc_macos() {
    echo -e "${YELLOW}SDCC not found. Attempting to install via Homebrew...${NC}"

    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Error: Homebrew not found. Please install Homebrew first:${NC}"
        echo -e "${RED}  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        return 1
    fi

    echo "Installing SDCC..."
    brew install sdcc

    if check_sdcc; then
        echo -e "${GREEN}✓ SDCC installed successfully${NC}"
        return 0
    else
        echo -e "${RED}Error: SDCC installation failed${NC}"
        return 1
    fi
}

# Function to build SDCC locally
build_sdcc_local() {
    echo -e "${YELLOW}Attempting to build SDCC ${REQUIRED_SDCC_VERSION} locally...${NC}"

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"

    if [ -f "sdcc/build_sdcc.sh" ]; then
        echo "Building SDCC (this will take a while)..."
        cd sdcc
        ./build_sdcc.sh
        cd ..

        # Source the setup script to add to PATH
        if [ -f "sdcc/setup_sdcc.sh" ]; then
            source sdcc/setup_sdcc.sh

            if check_sdcc; then
                echo -e "${GREEN}✓ SDCC built and configured successfully${NC}"
                return 0
            fi
        fi
    fi

    echo -e "${RED}Error: Could not build SDCC locally${NC}"
    return 1
}

# Function to setup SDCC
setup_sdcc() {
    echo "Checking for SDCC ${REQUIRED_SDCC_VERSION}..."

    if check_sdcc; then
        return 0
    fi

    echo -e "${YELLOW}SDCC ${REQUIRED_SDCC_VERSION} not found${NC}"

    # Try platform-specific installation
    if [ "$PLATFORM" = "macOS" ]; then
        if install_sdcc_macos; then
            return 0
        fi
    fi

    # Fallback to local build
    echo
    read -p "Would you like to build SDCC locally? This will take 10-20 minutes. (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if build_sdcc_local; then
            return 0
        fi
    fi

    echo -e "${RED}Error: SDCC ${REQUIRED_SDCC_VERSION} is required but not available${NC}"
    echo -e "${RED}Please install SDCC manually:${NC}"
    echo -e "${RED}  macOS: brew install sdcc${NC}"
    echo -e "${RED}  Linux: See README.md for instructions${NC}"
    return 1
}

# Function to build a single variant
build_variant() {
    local BUILD_NAME=$1
    echo
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Building: ${BUILD_NAME}${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"

    make clean BUILD="${BUILD_NAME}" > /dev/null 2>&1 || true

    if make BUILD="${BUILD_NAME}"; then
        echo -e "${GREEN}✓ ${BUILD_NAME} built successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ ${BUILD_NAME} build failed${NC}"
        return 1
    fi
}

# Function to display build summary
build_summary() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Build Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    local TOTAL=${#BUILDS[@]}
    local SUCCESS=0
    local FAILED=0

    for BUILD in "${BUILDS[@]}"; do
        local BUILD_DIR="builds/${BUILD}"
        if [ -d "$BUILD_DIR" ] && [ -f "$BUILD_DIR/main.bin" ]; then
            local SIZE=$(stat -f%z "$BUILD_DIR/main.bin" 2>/dev/null || stat -c%s "$BUILD_DIR/main.bin" 2>/dev/null || echo "?")
            echo -e "${GREEN}✓${NC} ${BUILD}: ${SIZE} bytes"
            SUCCESS=$((SUCCESS + 1))
        else
            echo -e "${RED}✗${NC} ${BUILD}: Build failed or output missing"
            FAILED=$((FAILED + 1))
        fi
    done

    echo
    echo -e "Total: ${TOTAL} | ${GREEN}Success: ${SUCCESS}${NC} | ${RED}Failed: ${FAILED}${NC}"

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All builds completed successfully!${NC}"
        echo
        echo "Binary files are located in:"
        echo "  $(pwd)/builds/<variant>/main.bin"
        return 0
    else
        echo -e "${RED}Some builds failed. Check the output above for details.${NC}"
        return 1
    fi
}

# Main script execution
main() {
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"

    # Check if we're in the right directory
    if [ ! -d "Chroma_Tag_FW/OEPL" ]; then
        echo -e "${RED}Error: This script must be run from the Tag_FW_Chroma root directory${NC}"
        exit 1
    fi

    # Setup SDCC
    if ! setup_sdcc; then
        exit 1
    fi

    echo
    echo -e "${BLUE}Starting build process...${NC}"

    # Change to build directory
    cd Chroma_Tag_FW/OEPL

    # Build all variants
    BUILD_FAILED=0
    for BUILD in "${BUILDS[@]}"; do
        if ! build_variant "$BUILD"; then
            BUILD_FAILED=1
        fi
    done

    # Return to root directory
    cd "$SCRIPT_DIR"

    # Display summary
    cd Chroma_Tag_FW/OEPL
    build_summary
    SUMMARY_EXIT=$?

    cd "$SCRIPT_DIR"

    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    if [ $SUMMARY_EXIT -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Parse command line arguments
CLEAN_ONLY=false
HELP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_ONLY=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            HELP=true
            shift
            ;;
    esac
done

if [ "$HELP" = true ]; then
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Build all supported Chroma tag firmware variants"
    echo
    echo "Options:"
    echo "  -c, --clean    Clean build directories and exit"
    echo "  -h, --help     Show this help message"
    echo
    echo "Supported builds:"
    for BUILD in "${BUILDS[@]}"; do
        echo "  - $BUILD"
    done
    echo
    exit 0
fi

if [ "$CLEAN_ONLY" = true ]; then
    echo "Cleaning build directories..."
    cd Chroma_Tag_FW/OEPL
    for BUILD in "${BUILDS[@]}"; do
        make clean BUILD="$BUILD" > /dev/null 2>&1 || true
    done
    echo -e "${GREEN}Clean complete${NC}"
    exit 0
fi

# Run main function
main
