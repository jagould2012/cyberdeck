import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { dirname } from 'path';

/**
 * Manages configuration and registered devices
 */
export class ConfigManager {
	constructor(configPath, publicKeysDir) {
		this.configPath = configPath;
		this.publicKeysDir = publicKeysDir;
		this.config = null;
	}

	async load() {
		try {
			// Ensure directories exist
			await mkdir(dirname(this.configPath), { recursive: true });
			await mkdir(this.publicKeysDir, { recursive: true });

			if (existsSync(this.configPath)) {
				const data = await readFile(this.configPath, 'utf-8');
				this.config = JSON.parse(data);
				console.log(`📋 Loaded config from ${this.configPath}`);
			} else {
				// Create default config
				this.config = this.getDefaultConfig();
				await this.save();
				console.log(`📋 Created default config at ${this.configPath}`);
			}
		} catch (error) {
			console.error('Failed to load config:', error);
			this.config = this.getDefaultConfig();
		}
	}

	getDefaultConfig() {
		return {
			computerName: process.env.COMPUTER_NAME || 'cyberdeck',
			loginUser: process.env.LOGIN_USER || 'pi',
			nonceRotationIntervalMs: 30000,
			registeredDevices: []
		};
	}

	async save() {
		try {
			await writeFile(
				this.configPath,
				JSON.stringify(this.config, null, 2),
				'utf-8'
			);
		} catch (error) {
			console.error('Failed to save config:', error);
		}
	}

	get(key, defaultValue = null) {
		return this.config?.[key] ?? defaultValue;
	}

	set(key, value) {
		this.config[key] = value;
	}

	getRegisteredDevices() {
		return this.config?.registeredDevices || [];
	}

	findDeviceByPublicKey(publicKey) {
		return this.getRegisteredDevices().find(
			device => device.publicKey === publicKey
		);
	}

	isPublicKeyRegistered(publicKey) {
		return this.getRegisteredDevices().some(
			device => device.publicKey === publicKey
		);
	}

	/**
	 * Save a captured public key to the publicKeys directory
	 * This key must be manually moved to config.json to be registered
	 */
	async saveCapturedPublicKey(deviceId, publicKey, metadata = {}) {
		const keyData = {
			deviceId,
			publicKey,
			capturedAt: new Date().toISOString(),
			...metadata
		};

		const filename = `${this.publicKeysDir}/${deviceId}.json`;
		await writeFile(filename, JSON.stringify(keyData, null, 2), 'utf-8');
		console.log(`📝 Captured public key saved to ${filename}`);
		console.log('   To register this device, add it to config.json registeredDevices');

		return filename;
	}
}