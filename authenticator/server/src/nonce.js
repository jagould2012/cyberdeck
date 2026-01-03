import { randomBytes } from 'crypto';

/**
 * Manages nonce generation and validation for replay attack prevention
 */
export class NonceManager {
	constructor({ rotationIntervalMs = 30000 } = {}) {
		this.rotationIntervalMs = rotationIntervalMs;
		this.currentNonce = null;
		this.previousNonce = null;
		this.nonceTimestamp = null;
		this.usedNonces = new Set();
		this.rotationTimer = null;

		// Generate initial nonce
		this.rotate();
	}

	/**
	 * Generate a new cryptographically secure nonce
	 */
	generateNonce() {
		return randomBytes(32).toString('base64');
	}

	/**
	 * Rotate to a new nonce
	 */
	rotate() {
		this.previousNonce = this.currentNonce;
		this.currentNonce = this.generateNonce();
		this.nonceTimestamp = Date.now();

		// Clear old used nonces (keep last 100 to prevent memory leak)
		if (this.usedNonces.size > 100) {
			const toRemove = [...this.usedNonces].slice(0, 50);
			toRemove.forEach(n => this.usedNonces.delete(n));
		}

		console.log('🔄 Nonce rotated');
	}

	/**
	 * Start automatic nonce rotation
	 */
	startRotation() {
		if (this.rotationTimer) return;

		this.rotationTimer = setInterval(() => {
			this.rotate();
		}, this.rotationIntervalMs);

		console.log(`🔄 Nonce rotation started (every ${this.rotationIntervalMs}ms)`);
	}

	/**
	 * Stop automatic nonce rotation
	 */
	stopRotation() {
		if (this.rotationTimer) {
			clearInterval(this.rotationTimer);
			this.rotationTimer = null;
		}
	}

	/**
	 * Get current nonce for advertisement
	 */
	getCurrentNonce() {
		return this.currentNonce;
	}

	/**
	 * Get nonce timestamp
	 */
	getTimestamp() {
		return this.nonceTimestamp;
	}

	/**
	 * Validate a nonce from an authentication attempt
	 * Accepts current or previous nonce (for timing tolerance)
	 * Immediately invalidates nonce after successful use
	 */
	validateAndConsume(nonce) {
		// Check if nonce was already used
		if (this.usedNonces.has(nonce)) {
			console.warn('⚠️  Nonce replay detected!');
			return false;
		}

		// Check against current and previous nonce
		if (nonce !== this.currentNonce && nonce !== this.previousNonce) {
			console.warn('⚠️  Invalid nonce');
			return false;
		}

		// Mark nonce as used
		this.usedNonces.add(nonce);

		// Immediately rotate to prevent any replay
		this.rotate();

		return true;
	}

	/**
	 * Get advertisement data containing nonce and timestamp
	 */
	getAdvertisementData() {
		return {
			nonce: this.currentNonce,
			timestamp: this.nonceTimestamp
		};
	}
}