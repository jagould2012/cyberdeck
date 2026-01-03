import bleno from '@abandonware/bleno';
import {
	CYBERDECK_SERVICE_UUID,
	CHALLENGE_CHAR_UUID,
	AUTH_CHAR_UUID,
	REGISTER_CHAR_UUID
} from './ble-advertiser.js';

const { Characteristic, PrimaryService } = bleno;

/**
 * BLE GATT server providing authentication services
 */
export class BlePeripheral {
	constructor({ authService, pamAuth, configManager, onSuccessfulAuth }) {
		this.authService = authService;
		this.pamAuth = pamAuth;
		this.configManager = configManager;
		this.onSuccessfulAuth = onSuccessfulAuth;
		this.registrationMode = false;
		this.service = null;
	}

	async initialize() {
		return new Promise((resolve, reject) => {
			const setup = () => {
				this.createService();
				resolve();
			};

			if (bleno.state === 'poweredOn') {
				setup();
			} else {
				bleno.once('stateChange', (state) => {
					if (state === 'poweredOn') {
						setup();
					} else {
						reject(new Error(`Bluetooth not available: ${state}`));
					}
				});
			}
		});
	}

	createService() {
		const self = this;

		// Challenge characteristic - clients read this to get current challenge
		const challengeCharacteristic = new Characteristic({
			uuid: CHALLENGE_CHAR_UUID,
			properties: ['read'],
			onReadRequest: (offset, callback) => {
				try {
					const challenge = self.authService.generateChallenge();
					const data = Buffer.from(JSON.stringify(challenge), 'utf-8');
					callback(Characteristic.RESULT_SUCCESS, data.slice(offset));
				} catch (error) {
					console.error('Error generating challenge:', error);
					callback(Characteristic.RESULT_UNLIKELY_ERROR);
				}
			}
		});

		// Auth characteristic - clients write signed response here
		const authCharacteristic = new Characteristic({
			uuid: AUTH_CHAR_UUID,
			properties: ['write'],
			onWriteRequest: async (data, offset, withoutResponse, callback) => {
				try {
					const request = JSON.parse(data.toString('utf-8'));
					const { signedNonce, publicKey } = request;

					console.log('🔑 Authentication attempt received');

					const result = self.authService.verifyAuthentication(signedNonce, publicKey);

					if (result.valid) {
						console.log(`✅ Authentication successful for device: ${result.deviceName}`);

						// Trigger PAM login
						try {
							await self.pamAuth.triggerLogin();
							self.onSuccessfulAuth?.();
							callback(Characteristic.RESULT_SUCCESS);
						} catch (pamError) {
							console.error('PAM login failed:', pamError);
							callback(Characteristic.RESULT_UNLIKELY_ERROR);
						}
					} else {
						console.warn(`❌ Authentication failed: ${result.error}`);
						callback(Characteristic.RESULT_UNLIKELY_ERROR);
					}
				} catch (error) {
					console.error('Auth error:', error);
					callback(Characteristic.RESULT_UNLIKELY_ERROR);
				}
			}
		});

		// Registration characteristic - for capturing new public keys
		const registerCharacteristic = new Characteristic({
			uuid: REGISTER_CHAR_UUID,
			properties: ['write'],
			onWriteRequest: async (data, offset, withoutResponse, callback) => {
				if (!self.registrationMode) {
					console.warn('⚠️  Registration attempted but not in registration mode');
					callback(Characteristic.RESULT_UNLIKELY_ERROR);
					return;
				}

				try {
					const request = JSON.parse(data.toString('utf-8'));
					const { deviceId, publicKey, deviceName } = request;

					console.log(`📝 Registration request from: ${deviceName || deviceId}`);

					// Save to publicKeys directory
					await self.configManager.saveCapturedPublicKey(deviceId, publicKey, {
						deviceName: deviceName || 'Unknown Device'
					});

					callback(Characteristic.RESULT_SUCCESS);
				} catch (error) {
					console.error('Registration error:', error);
					callback(Characteristic.RESULT_UNLIKELY_ERROR);
				}
			}
		});

		this.service = new PrimaryService({
			uuid: CYBERDECK_SERVICE_UUID,
			characteristics: [
				challengeCharacteristic,
				authCharacteristic,
				registerCharacteristic
			]
		});
	}

	async startServices() {
		return new Promise((resolve, reject) => {
			bleno.setServices([this.service], (error) => {
				if (error) {
					console.error('Failed to set services:', error);
					reject(error);
				} else {
					console.log('🔌 BLE services started');
					resolve();
				}
			});
		});
	}

	async stopServices() {
		return new Promise((resolve) => {
			bleno.setServices([], () => {
				console.log('🔌 BLE services stopped');
				resolve();
			});
		});
	}

	setRegistrationMode(enabled) {
		this.registrationMode = enabled;
		console.log(`📝 Registration mode: ${enabled ? 'enabled' : 'disabled'}`);
	}

	async shutdown() {
		await this.stopServices();
	}
}