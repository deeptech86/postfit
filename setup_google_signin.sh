#!/bin/bash

# Google Sign-In Setup Helper Script
# This script helps configure Google Sign-In for the MomCare app

set -e

echo "🔧 Google Sign-In Setup Helper"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="/Users/dipmacmini/Documents/postFit/PostFit"
PROJECT_FILE="$PROJECT_DIR/PostFit.xcodeproj"

# Step 1: Check if Xcode project exists
echo -e "${BLUE}Step 1: Checking Xcode project...${NC}"
if [ -d "$PROJECT_FILE" ]; then
    echo -e "${GREEN}✅ Xcode project found${NC}"
else
    echo -e "${RED}❌ Xcode project not found at $PROJECT_FILE${NC}"
    exit 1
fi

# Step 2: Prompt for Google Client ID
echo ""
echo -e "${BLUE}Step 2: Configure Google OAuth Client ID${NC}"
echo "Have you created a Google OAuth Client ID? (y/n)"
read -r has_client_id

if [ "$has_client_id" = "y" ]; then
    echo "Enter your Google Client ID (format: XXXXX.apps.googleusercontent.com):"
    read -r client_id

    # Validate format
    if [[ $client_id == *.apps.googleusercontent.com ]]; then
        echo -e "${GREEN}✅ Client ID format looks correct${NC}"

        # Calculate reversed client ID
        reversed_id=$(echo "$client_id" | awk -F. '{for(i=NF;i>0;i--) printf "%s%s",$i,(i>1?".":"")}')
        echo -e "${GREEN}Reversed Client ID: $reversed_id${NC}"

        # Update Constants.swift
        constants_file="$PROJECT_DIR/PostFit/Core/Utilities/Constants.swift"
        if [ -f "$constants_file" ]; then
            # Create backup
            cp "$constants_file" "$constants_file.backup"

            # Replace placeholder with actual client ID
            sed -i '' "s/YOUR_GOOGLE_CLIENT_ID_HERE.apps.googleusercontent.com/$client_id/g" "$constants_file"

            echo -e "${GREEN}✅ Updated Constants.swift with your Client ID${NC}"
            echo -e "${YELLOW}💾 Backup created at $constants_file.backup${NC}"
        else
            echo -e "${RED}❌ Constants.swift not found${NC}"
        fi

        # Save reversed client ID for later
        echo "$reversed_id" > /tmp/google_reversed_client_id.txt

    else
        echo -e "${RED}❌ Invalid Client ID format. Expected: XXXXX.apps.googleusercontent.com${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Please create a Google OAuth Client ID first:${NC}"
    echo "   1. Go to https://console.cloud.google.com/"
    echo "   2. Create a new project or select existing"
    echo "   3. Enable Google Sign-In API"
    echo "   4. Create OAuth Client ID for iOS"
    echo "   5. Bundle ID: com.momcare.postfit"
    echo ""
    echo "Then run this script again."
    exit 0
fi

# Step 3: Check if GoogleSignIn package is added
echo ""
echo -e "${BLUE}Step 3: Checking GoogleSignIn package...${NC}"
workspace_dir="$PROJECT_FILE/project.xcworkspace/xcshareddata/swiftpm"

if [ -d "$workspace_dir" ]; then
    if grep -q "GoogleSignIn" "$workspace_dir"/*.* 2>/dev/null; then
        echo -e "${GREEN}✅ GoogleSignIn package appears to be configured${NC}"
    else
        echo -e "${YELLOW}⚠️  GoogleSignIn package not detected${NC}"
        echo "You need to add it manually in Xcode:"
        echo "  1. Open $PROJECT_FILE in Xcode"
        echo "  2. File → Add Package Dependencies"
        echo "  3. Search: https://github.com/google/GoogleSignIn-iOS"
        echo "  4. Add both GoogleSignIn and GoogleSignInSwift"
    fi
else
    echo -e "${YELLOW}⚠️  No Swift packages detected${NC}"
    echo "You need to add GoogleSignIn package in Xcode:"
    echo "  1. Open $PROJECT_FILE in Xcode"
    echo "  2. File → Add Package Dependencies"
    echo "  3. Search: https://github.com/google/GoogleSignIn-iOS"
    echo "  4. Add both GoogleSignIn and GoogleSignInSwift"
fi

# Step 4: Instructions for URL Scheme
echo ""
echo -e "${BLUE}Step 4: Configure URL Scheme in Xcode${NC}"
if [ -f /tmp/google_reversed_client_id.txt ]; then
    reversed_id=$(cat /tmp/google_reversed_client_id.txt)
    echo -e "${YELLOW}You need to add this URL scheme manually in Xcode:${NC}"
    echo ""
    echo -e "${GREEN}URL Scheme: $reversed_id${NC}"
    echo ""
    echo "Steps:"
    echo "  1. Open $PROJECT_FILE in Xcode"
    echo "  2. Select PostFit project → PostFit target"
    echo "  3. Go to Info tab"
    echo "  4. Find or add 'URL Types' section"
    echo "  5. Add new URL Type:"
    echo "     - Identifier: $client_id"
    echo "     - URL Schemes: $reversed_id"
    echo "     - Role: Editor"
else
    echo -e "${YELLOW}⚠️  Run step 2 first to calculate reversed client ID${NC}"
fi

# Step 5: Verification
echo ""
echo -e "${BLUE}Step 5: Verification${NC}"
echo "After completing the Xcode steps above, verify:"
echo "  □ GoogleSignIn package added"
echo "  □ URL scheme configured"
echo "  □ Constants.swift has real Client ID"
echo "  □ Project builds successfully"
echo ""

# Step 6: Open Xcode
echo -e "${BLUE}Step 6: Open Xcode?${NC}"
echo "Would you like to open the project in Xcode now? (y/n)"
read -r open_xcode

if [ "$open_xcode" = "y" ]; then
    echo "Opening Xcode..."
    open "$PROJECT_FILE"
    echo -e "${GREEN}✅ Xcode opened${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next steps in Xcode:${NC}"
    echo "  1. Add GoogleSignIn package (File → Add Package Dependencies)"
    echo "  2. Configure URL scheme in Info tab"
    echo "  3. Build and test (⌘B then ⌘R)"
fi

echo ""
echo -e "${GREEN}🎉 Setup helper complete!${NC}"
echo "See GOOGLE_SIGNIN_SETUP.md for detailed instructions."
echo ""
