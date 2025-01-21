---
title: Direct Message Extension
date: 2025-01-18
---

## Purpose

The **Direct Message Extension** introduces a secure way for two users to send encrypted messages to each other within the twtxt ecosystem. Direct messages (DMs) leverage public/private key cryptography to ensure that only the intended recipient can read the message. This extension also enables metadata to specify a user's public key, ensuring compatibility with encryption protocol (Curve25519).

## Overview of Direct Message Format

Direct messages are encoded and include the recipient's username and the encrypted message payload. This allows the message to remain private while adhering to the structure and principles of the twtxt format.

A typical direct message will contain the following structure:

```text
!<nick url> <encrypted_message>
```

Here:
- `nick` is the intended recipient's nickname.
- `url` is the public URL to the recipient's twtxt feed.
- `<encrypted_message>` is the ciphertext encrypted using the recipient's public key.

## Requirements

1. **Public Key Declaration**:
   A new metadata field named `public_key` must be present in the user's twtxt feed. This field should contain a URL pointing to the user’s public key file.

   Example:

   ```text
   # nick        = example
   # url         = https://example.com/twtxt.txt
   # avatar      = https://example.com/avatar.png
   # description = An example feed
   # public_key  = https://example.com/public_key.pem
   ```

   The public key must be in a valid PEM format.

2. **Encryption of DMs**:
   Direct messages must be encrypted using the recipient's public key to ensure confidentiality. Any modern cryptographic library supporting EC (Elliptic Curve) public/private key encryption can be used for this purpose.

3. **DM Syntax**:
   Direct messages must explicitly target the recipient using the `!<nick url>` syntax before the encrypted payload.

   Example:

   ```text
   2025-01-18T18:20:00Z !<joe https://example.com/twtxt.txt> 1234567890abcdef=
   ```

   Here, `1234567890abcdef=` represents the Base64 encoded ciphertext.

## Format Details

### Public Key Metadata

The mandatory `public_key` metadata field allows feed authors to publish their public key. Clients can use this key to encrypt messages for the feed author. The key must be accessible via a secure HTTPS link. This ensures that only the author can decrypt the message using their private key.

```text
# public_key  = https://example.com/public_key.pem
```

### Encryption Process

When sending a direct message:
1. Retrieve the recipient's public key from their `public_key` metadata URL.
2. Encrypt the plaintext message using the public key.
3. Encode the ciphertext (Base64).
4. Add the new line to the twtxt feed with the recipient's `nick` and `url` followed by the encrypted message.

### Example Workflow

Let’s assume two users, `alice` and `bob`, want to communicate privately.

1. **Key Generation**:
   Alice and Bob each generate a public/private key pair using Curve25519 algorithm with `openssl`:

   ```bash
   openssl genpkey -algorithm X25519 -out alice_private_key.pem
   openssl pkey -pubout -in alice_private_key.pem -out alice_public_key.pem
   ```

    ```bash
    openssl genpkey -algorithm X25519 -out bob_private_key.pem
    openssl pkey -pubout -in bob_private_key.pem -out bob_public_key.pem
    ```

2. **Setup**:

   Alice declares her public key in her `twtxt.txt` metadata:

   ```text
   # nick        = alice
   # url         = https://alice.example.com/twtxt.txt
   # public_key  = https://alice.example.com/alice_public_key.pem
   ```

   Bob does the same in his feed:

   ```text
   # nick        = bob
   # url         = https://bob.example.com/twtxt.txt
   # public_key  = https://bob.example.com/bob_public_key.pem
   ```

2. **Encrypting the Message**:

   Bob wants to send a private message to Alice. Using Alice's `public_key`, Bob encrypts his message using Openssl:

   1. First, Bob retrieves Alice's public key:

   ```bash
    wcurl https://alice.example.com/alice_public_key.pem > alice_public_key.pem
    ```

    2. Calculate the share key:

    Bob use his private key and Alice's public key to calculate the shared key:

    ```bash
    openssl pkeyutl -derive -inkey bob_private_key.pem -peerkey alice_public_key.pem -out shared_key.bin
    ```

    Then, Bob encrypts the message using the shared key. The message is storage in `message.enc`:

   ```bash
    echo -n "Hi Alice, let’s meet tomorrow at 5 PM!" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -out message.enc -pass file:shared_key.bin
   ```

   3. Bob encodes the encrypted message in Base64:

   ```bash
    base64 -w 0 < message.enc > message.enc.b64
   ```

    Check `message.enc.b64` for the encrypted message: `U2FsdGVkX1+mVLsw62BUyjcjnAVtU/EP04gS9GuTsD8xW66BH3V+kb828lMswrDntCtKgauLDZEDRCmpAo3lcQ==`

    This will be the string of the direct message.

3. **Sending the Message**:

   Bob appends the encrypted message to his feed:

   ```text
   2025-01-18T18:20:00Z !<alice https://alice.example.com/twtxt.txt> U2FsdGVkX1+mVLsw62BUyjcjnAVtU/EP04gS9GuTsD8xW66BH3V+kb828lMswrDntCtKgauLDZEDRCmpAo3lcQ==
   ```

4. **Reading the Message**:
   Alice’s client fetches the message from Bob’s feed and review if the message is for her. She would see `!<alice https://alice.example.com/twtxt.txt>`.

   Using her private key, Alice decrypts the message:

   1. First, Alice retrieves Bob's public key:

   ```bash
    wcurl https://bob.example.com/bob_public_key.pem > bob_public_key.pem
    ```

    2. Calculate the share key:

    Alice use her private key and Bob's public key to calculate the shared key:

    ```bash
    openssl pkeyutl -derive -inkey alice_private_key.pem -peerkey bob_public_key.pem -out shared_key.bin
    ```

    3. Alice decodes the encrypted message from Base64:

    ```bash
    echo 'U2FsdGVkX1+mVLsw62BUyjcjnAVtU/EP04gS9GuTsD8xW66BH3V+kb828lMswrDntCtKgauLDZEDRCmpAo3lcQ==' | base64 -d > message_from_bob.enc
    ```

    4. Alice decrypts the message using the shared key.

    ```bash
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in message_from_bob.enc -out message_from_bob.txt -pass file:shared_key.bin
    ```

    Check `message_from_bob.txt` for the decrypted message.

    ```bash
    cat message_from_bob.txt
    ```

   Resulting in the plaintext message: `Hi Alice, let’s meet tomorrow at 5 PM!`

## Security Considerations

1. **Key Verification**:
   Users should ensure public keys are genuine and match the feed owner to mitigate man-in-the-middle attacks.

2. **Encrypted Payload Visibility**:
   While the payload is encrypted, all users viewing the feed will see the recipient `nick` and `url`. This preserves openness but prevents eavesdroppers from reading the message.

3. **Private Key Security**:
   Users must securely store their private keys and avoid exposing them. A compromised private key can lead to the decryption of all previously sent messages.

4. **Replay Attacks**:
   Clients should implement measures to detect and ignore duplicate messages to prevent replay attacks.

## Supported Twtxt Clients

For clients to support the **Direct Message Extension**, they must:
1. Parse metadata to retrieve the `public_key` field.
2. Implement encryption and decryption using public/private key cryptography.
3. Render direct messages prefixed with `!<nick url>`.
4. If a client does not support this extension, it should ignore direct messages.

## Changelog

* 2025-01-18: Initial draft.

---
