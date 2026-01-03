import bleno from '@abandonware/bleno';

// Custom service UUID for Cyberdeck Login
export const CYBERDECK_SERVICE_UUID = 'cd10';
export const CHALLENGE_CHAR_UUID = 'cd11';
export const AUTH_CHAR_UUID = 'cd12';
export const REGISTER_CHAR_UUID = 'cd13';

/**
 * Handles BLE advertising with computer name, nonce, and timestamp
 */
export class BleAdvertiser {
	constructor({ computerName, nonceManager }) {
		this.computerName = computerName;
		this.nonceManager = nonceManager;
		this.isAdvertising = false;
	}

	/**
	 * Start BLE advertising
	 */
	async startAdvertising() {
		return new Promise((resolve, reject) => {
			const startAd = () => {
				// Build advertisement data
				const advertisementData = this.buildAdvertisementData();

				bleno.startAdvertising(
					this.computerName,
					[CYBERDECK_SERVICE_UUID],
					(error) => {
						if (error) {
							console.error('❌ Failed to start advertising:', error);
							reject(error);
						} else {
							this.isAdvertising = true;
							console.log(`📡 BLE advertising started as "${this.computerName}"`);
							resolve();
						}
					}
				);
			};

			if (bleno.state === 'poweredOn') {
				startAd();
			} else {
				bleno.once('stateChange', (state) => {
					if (state === 'poweredOn') {
						startAd();
					} else {
						reject(new Error(`Bluetooth state: ${state}`));
					}
				});
			}
		});
	}

	/**
	 * Stop BLE advertising
	 */
	async stopAdvertising() {
		return new Promise((resolve) => {
			if (!this.isAdvertising) {
				resolve();
				return;
			}

			bleno.stopAdvertising(() => {
				this.isAdvertising = false;
				console.log('📡 BLE advertising stopped');
				resolve();
			});
		});
	}

	/**
	 * Build advertisement data buffer
	 * Includes: computer name prefix, truncated for BLE limits
	 */
	buildAdvertisementData() {
		// BLE advertisement has limited space (~31 bytes)
		// We put detailed data in the GATT characteristic instead
		return {
			localName: this.computerName.substring(0, 20),
			serviceUuids: [CYBERDECK_SERVICE_UUID]
		};
	}

	/**
	 * Update advertisement with new nonce
	 * Called when nonce rotates
	 */
	async updateAdvertisement() {
		if (this.isAdvertising) {
			await this.stopAdvertising();
			await this.startAdvertising();
		}
	}
}