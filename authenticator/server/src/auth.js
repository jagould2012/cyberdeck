import nacl from 'tweetnacl';
import pkg from 'tweetnacl-util';
const { decodeBase64, encodeBase64 } = pkg;
/**
 * Handles cryptographic authentication
 * Uses Ed25519 for signing/verification
 */
export class AuthService {
	constructor(configManager, nonceManager) {
		this.configManager = configManager;
		this.nonceManager = nonceManager;
	}

	/**
	 * Verify a signed authentication response
	 * @param {string} signedNonce - Base64 encoded signed nonce
	 * @param {string} publicKey - Base64 encoded public key
	 * @returns {Object} - { valid: boolean, deviceName?: string, error?: string }
	 */
	verifyAuthentication(signedNonce, publicKey) {
		try {
			// Check if public key is registered
			const device = this.configManager.findDeviceByPublicKey(publicKey);
			if (!device) {
				return { valid: false, error: 'Public key not registered' };
			}

			// Decode the signed message and public key
			const signedMessage = decodeBase64(signedNonce);
			const publicKeyBytes = decodeBase64(publicKey);

			// Verify signature and extract message
			const message = nacl.sign.open(signedMessage, publicKeyBytes);
			if (!message) {
				return { valid: false, error: 'Invalid signature' };
			}

			// Extract nonce from message
			const messageStr = new TextDecoder().decode(message);
			const { nonce, timestamp } = JSON.parse(messageStr);

			// Validate nonce
			if (!this.nonceManager.validateAndConsume(nonce)) {
				return { valid: false, error: 'Invalid or expired nonce' };
			}

			// Validate timestamp (allow 60 second window)
			const now = Date.now();
			if (Math.abs(now - timestamp) > 60000) {
				return { valid: false, error: 'Timestamp out of range' };
			}

			return {
				valid: true,
				deviceName: device.name
			};

		} catch (error) {
			console.error('Authentication error:', error);
			return { valid: false, error: 'Authentication failed' };
		}
	}

	/**
	 * Generate a challenge for authentication
	 */
	generateChallenge() {
		return {
			nonce: this.nonceManager.getCurrentNonce(),
			timestamp: this.nonceManager.getTimestamp(),
			computerName: this.configManager.get('computerName')
		};
	}
}

/**
 * Utility function to generate a new Ed25519 key pair
 * Used for testing or initial setup
 */
export function generateKeyPair() {
	const keyPair = nacl.sign.keyPair();
	return {
		publicKey: encodeBase64(keyPair.publicKey),
		secretKey: encodeBase64(keyPair.secretKey)
	};
}

/**
 * Sign a message with a secret key
 * Used for testing
 */
export function signMessage(message, secretKeyBase64) {
	const secretKey = decodeBase64(secretKeyBase64);
	const messageBytes = new TextEncoder().encode(
		typeof message === 'string' ? message : JSON.stringify(message)
	);
	const signed = nacl.sign(messageBytes, secretKey);
	return encodeBase64(signed);
}