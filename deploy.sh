#!/bin/bash
set -e # return non-zero exit code if any command fails

# Check if user and server variables are defined
if [ -z "$KILATSEDAP_USER" ] || [ -z "$KILATSEDAP_SERVER" ]; then
  echo "User or server variable is not defined. Exiting..."
  echo "Please set the KILATSEDAP_USER and KILATSEDAP_SERVER environment variables."
  echo "Example: export KILATSEDAP_USER=username"
  echo "         export KILATSEDAP_SERVER=server_address"
  exit 1
fi

# Build the project
pnpm run build > /dev/null

# Copy files to dist
echo "Copying files to dist"
cp package.json dist/. > /dev/null
cp pnpm-lock.yaml dist/. > /dev/null

# Zip the folder
echo "Zipping the folder"
zip -rq chat_be_express.zip dist

# Deploy using scp with environment variables (verbose mode)
echo "Deploying to $KILATSEDAP_USER@$KILATSEDAP_SERVER"
scp -i ~/.ssh/kilatsedap.pem chat_be_express.zip $KILATSEDAP_USER@$KILATSEDAP_SERVER:~/.

# Clean up temporary files
echo "Cleaning up temporary files"
rm chat_be_express.zip

# in server's side, backup the current folder i.e. chat_be_express to chat_be_express_backup
# then, unzip the chat_be_express.zip file
# then, remove the chat_be_express.zip file
# then, restart the pm2 process
# then, remove the chat_be_express_backup folder if pm2 restart is successful

echo "Backing up the current folder"
if ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "[ -d chat_be_express ]"; then
  ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "mv chat_be_express chat_be_express_backup"
fi

echo "Unzipping the chat_be_express.zip file"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "unzip chat_be_express.zip"

echo "Renaming the dist folder to chat_be_express"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "mv dist chat_be_express"

echo "Installing production dependencies"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER 'pushd chat_be_express && eval "$(~/.local/bin/mise activate bash)" && CI=1 mise exec node@20 -- pnpm install --prod && popd'

echo "Removing the chat_be_express.zip file"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "rm chat_be_express.zip"

echo "Restarting the pm2 process"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER 'eval "$(~/.local/bin/mise activate bash)" && mise exec node@20 -- pm2 restart chat_be_express'

echo "Removing the chat_be_express_backup folder if pm2 restart is successful"
ssh -i ~/.ssh/kilatsedap.pem $KILATSEDAP_USER@$KILATSEDAP_SERVER "if [ $? -eq 0 ]; then rm -rf chat_be_express_backup; fi"

echo "Done"