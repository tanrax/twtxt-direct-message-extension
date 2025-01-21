#!/bin/bash

# Usage: ./decrypt_message.sh <encrypted_message_b64> <public_key_url> <private_key_path>

# Check for parameters
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <encrypted_message_b64> <public_key_url> <private_key_path>"
    exit 1
fi

# Parameters
ENCRYPTED_MESSAGE_B64="$1"
PUBLIC_KEY_URL="$2"
PRIVATE_KEY_PATH="$3"

# Temporary files
PUBLIC_KEY_PATH="./temp_public_key.pem"
SHARED_KEY_PATH="./temp_shared_key.bin"
ENCRYPTED_MESSAGE_FILE="./temp_message.enc"
DECRYPTED_MESSAGE_FILE="./temp_message.txt"

# Cleanup function to remove temporary files
cleanup() {
    rm -f "$PUBLIC_KEY_PATH" "$SHARED_KEY_PATH" "$ENCRYPTED_MESSAGE_FILE" "$DECRYPTED_MESSAGE_FILE"
}
trap cleanup EXIT

# Download the public key
echo "Downloading public key from $PUBLIC_KEY_URL..."
curl -s "$PUBLIC_KEY_URL" -o "$PUBLIC_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the public key."
    exit 1
fi

# Decode the encrypted message from Base64
echo "Decoding the encrypted message..."
echo "$ENCRYPTED_MESSAGE_B64" | base64 -d > "$ENCRYPTED_MESSAGE_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to decode the encrypted message."
    exit 1
fi

# Calculate the shared key
echo "Calculating the shared key..."
openssl pkeyutl -derive -inkey "$PRIVATE_KEY_PATH" -peerkey "$PUBLIC_KEY_PATH" -out "$SHARED_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to calculate the shared key."
    exit 1
fi

# Decrypt the encrypted message using the shared key
echo "Decrypting the message..."
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$ENCRYPTED_MESSAGE_FILE" -out "$DECRYPTED_MESSAGE_FILE" -pass file:"$SHARED_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to decrypt the message."
    exit 1
fi

# Display the decrypted message
echo "Decrypted message:"
cat "$DECRYPTED_MESSAGE_FILE"

# Cleanup is handled by the trap
