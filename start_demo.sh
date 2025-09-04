#!/bin/bash

# Snowflake GDPR Right to be Forgotten Demo - Quick Start Script
set -e

echo "🛡️  Snowflake GDPR Right to be Forgotten Demo"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if Python is available and version is 3.9+
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed. Please install Python 3.9+ and try again.${NC}"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
    echo -e "${RED}❌ Python 3.9+ required. Found Python $PYTHON_VERSION. Please upgrade and try again.${NC}"
    exit 1
fi

echo -e "${CYAN}✅ Python $PYTHON_VERSION found (compatible)${NC}"

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}❌ pip3 is not installed. Please install pip and try again.${NC}"
    exit 1
fi

# Install Python dependencies
echo -e "\n${YELLOW}📦 Installing Python dependencies...${NC}"
pip3 install -r requirements.txt

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

# Check if .env file exists (from previous setup)
if [ -f ".env" ]; then
    echo -e "\n${CYAN}📋 Found existing configuration file (.env)${NC}"
    read -p "Do you want to use existing Snowflake credentials? (y/n): " use_existing
    
    if [[ $use_existing =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Using existing configuration${NC}"
        
        # Run the demo directly
        echo -e "\n${YELLOW}🚀 Starting interactive demo...${NC}"
        python3 gdpr_demo.py interactive
        exit 0
    fi
fi

# Run interactive setup
echo -e "\n${YELLOW}🔧 Setting up Snowflake GDPR demo...${NC}"
echo -e "${CYAN}You'll be prompted for your Snowflake connection details.${NC}"
echo ""

python3 setup_snowflake_demo.py --interactive

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Setup completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}🎯 Available demo commands:${NC}"
    echo "  • Interactive mode:     python3 gdpr_demo.py interactive"
    echo "  • Full demo scenario:   python3 gdpr_demo.py full-demo -e anna.mueller@email.de"
    echo "  • Data discovery:       python3 gdpr_demo.py discover -e anna.mueller@email.de"
    echo "  • Compliance dashboard: python3 gdpr_demo.py dashboard"
    echo ""
    echo -e "${YELLOW}📚 Demo customers available:${NC}"
    echo "  • anna.mueller@email.de     (German customer with full consent)"
    echo "  • jean.dupont@email.fr      (French customer, consent withdrawn)"
    echo "  • maria.garcia@email.es     (Spanish customer, partial consent)"
    echo "  • consent.withdrawn@email.de (Customer with withdrawn consent)"
    echo ""
    
    # Ask if user wants to start interactive demo
    read -p "Start interactive demo now? (y/n): " start_demo
    
    if [[ $start_demo =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}🚀 Starting interactive demo...${NC}"
        python3 gdpr_demo.py interactive
    else
        echo -e "\n${CYAN}💡 You can start the demo anytime with: python3 gdpr_demo.py interactive${NC}"
    fi
else
    echo -e "\n${RED}❌ Setup failed. Please check the errors above.${NC}"
    echo -e "${YELLOW}💡 You can try running setup manually with: python3 setup_snowflake_demo.py --interactive${NC}"
    exit 1
fi

