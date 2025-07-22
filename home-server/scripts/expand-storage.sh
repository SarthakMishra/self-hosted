#!/bin/bash
# MergerFS Storage Pool Expansion Helper Script
# Makes it easy to expand your storage pool when you add new drives

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}📈 MERGERFS STORAGE POOL EXPANSION${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo "This script will help you expand your MergerFS storage pool"
echo "by adding new drives with zero downtime."
echo ""

# Check if we're in the right directory
if [[ ! -f "$PROJECT_DIR/playbooks/expand-storage.yml" ]]; then
    echo -e "${RED}❌ Error: Cannot find expand-storage.yml playbook${NC}"
    echo "Please run this script from the home-server directory"
    exit 1
fi

# Check if inventory exists
if [[ ! -f "$PROJECT_DIR/inventory/hosts.yml" ]]; then
    echo -e "${RED}❌ Error: Cannot find inventory/hosts.yml${NC}"
    echo "Please configure your inventory file first"
    exit 1
fi

# Function to check if ansible is installed
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}❌ Error: ansible-playbook not found${NC}"
        echo "Please install Ansible first:"
        echo "  pip install ansible"
        exit 1
    fi
}

# Function to show current pool status
show_current_status() {
    echo -e "${YELLOW}📊 Checking current storage pool status...${NC}"
    echo ""
    
    if ansible docker_servers -i "$PROJECT_DIR/inventory/hosts.yml" -m shell -a "df -h /srv/storage 2>/dev/null || echo 'Pool not found'" -b 2>/dev/null | grep -v "SUCCESS" | tail -n +2; then
        echo ""
    else
        echo -e "${RED}❌ Cannot connect to server or MergerFS pool not found${NC}"
        echo "Please ensure:"
        echo "1. Server is accessible via SSH"
        echo "2. MergerFS pool has been set up"
        echo "3. Run main setup playbook first if needed"
        exit 1
    fi
}

# Function to show detected drives
show_available_drives() {
    echo -e "${YELLOW}🔍 Detecting available drives for expansion...${NC}"
    echo ""
    
    # Run a quick detection to show what's available
    ansible docker_servers -i "$PROJECT_DIR/inventory/hosts.yml" -m shell -a "lsblk -d -o NAME,SIZE,TYPE | grep disk | grep -v 'loop\|sr'" -b 2>/dev/null | grep -v "SUCCESS" | tail -n +2
    echo ""
}

# Function to run the expansion playbook
run_expansion() {
    echo -e "${GREEN}🚀 Starting storage pool expansion...${NC}"
    echo ""
    echo "The playbook will:"
    echo "✅ Detect new drives automatically"
    echo "✅ Allow you to select which drives to add"
    echo "✅ Safely format and add drives to pool"
    echo "✅ Expand pool capacity with zero downtime"
    echo ""
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""
    
    # Run the expansion playbook
    cd "$PROJECT_DIR"
    ansible-playbook -i inventory/hosts.yml playbooks/expand-storage.yml
}

# Function to show final status
show_final_status() {
    echo ""
    echo -e "${GREEN}📊 Checking expanded storage pool status...${NC}"
    echo ""
    
    ansible docker_servers -i "$PROJECT_DIR/inventory/hosts.yml" -m shell -a "df -h /srv/storage" -b 2>/dev/null | grep -v "SUCCESS" | tail -n +2
    echo ""
    
    echo -e "${GREEN}🎉 Storage pool expansion completed!${NC}"
    echo ""
    echo "💡 Tips:"
    echo "• Files will automatically use the new space"
    echo "• Run 'mergerfs.balance /srv/storage' to redistribute existing files"
    echo "• Monitor pool with 'df -h /srv/storage'"
    echo ""
}

# Main execution
main() {
    check_ansible
    show_current_status
    show_available_drives
    
    echo -e "${BLUE}Do you want to proceed with storage expansion? [y/N]${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        run_expansion
        show_final_status
    else
        echo "Expansion cancelled."
        exit 0
    fi
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Expansion cancelled by user${NC}"; exit 130' INT

# Run main function
main "$@" 