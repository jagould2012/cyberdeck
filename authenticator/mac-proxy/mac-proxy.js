#!/usr/bin/env node
/**
 * BLE to TCP Proxy for macOS
 * 
 * Runs on Mac, handles BLE advertising and connections,
 * forwards requests to VM server over TCP.
 */

import bleno from '@abandonware/bleno';
import net from 'net';

const CYBERDECK_SERVICE_UUID = 'cd10';
const CHALLENGE_CHAR_UUID = 'cd11';
const AUTH_CHAR_UUID = 'cd12';
const REGISTER_CHAR_UUID = 'cd13';

// Parse command line args
const args = process.argv.slice(2);
let serverHost = 'localhost';
let serverPort = 3100;

for (let i = 0; i < args.length; i++) {
	if (args[i] === '--server' && args[i + 1]) {
		const [host, port] = args[i + 1].split(':');
		serverHost = host;
		serverPort = parseInt(port, 10) || 3100;
	}
}

console.log(`🔗 BLE Proxy - will forward to ${serverHost}:${serverPort}`);

/**
 * Send a request to the VM server and get response
 */
function sendToServer(action, data) {
	return new Promise((resolve, reject) => {
		const client = new net.Socket();
		const timeout = setTimeout(() => {
			client.destroy();
			reject(new Error('Connection timeout'));
		}, 5000);

		client.connect(serverPort, serverHost, () => {
			const request = JSON.stringify({ action, data });
			client.write(request + '\n');
		});

		let response = '';
		client.on('data', (chunk) => {
			response += chunk.toString();
			if (response.includes('\n')) {
				clearTimeout(timeout);
				client.destroy();
				try {
					resolve(JSON.parse(response.trim()));
				} catch (e) {
					reject(new Error('Invalid response'));
				}
			}
		});

		client.on('error', (err) => {
			clearTimeout(timeout);
			reject(err);
		});
	});
}

// Create characteristics
const { Characteristic, PrimaryService } = bleno;

const challengeCharacteristic = new Characteristic({
	uuid: CHALLENGE_CHAR_UUID,
	properties: ['read'],
	onReadRequest: async (offset, callback) => {
		try {
			console.log('📖 Challenge read request');
			const response = await sendToServer('getChallenge', {});
			const data = Buffer.from(JSON.stringify(response.challenge), 'utf-8');
			callback(Characteristic.RESULT_SUCCESS, data.slice(offset));
		} catch (error) {
			console.error('❌ Challenge error:', error.message);
			callback(Characteristic.RESULT_UNLIKELY_ERROR);
		}
	}
});

const authCharacteristic = new Characteristic({
	uuid: AUTH_CHAR_UUID,
	properties: ['write'],
	onWriteRequest: async (data, offset, withoutResponse, callback) => {
		try {
			console.log('🔐 Auth write request');
			const request = JSON.parse(data.toString('utf-8'));
			const response = await sendToServer('authenticate', request);

			if (response.success) {
				console.log('✅ Auth successful');
				callback(Characteristic.RESULT_SUCCESS);
			} else {
				console.log('❌ Auth failed:', response.error);
				callback(Characteristic.RESULT_UNLIKELY_ERROR);
			}
		} catch (error) {
			console.error('❌ Auth error:', error.message);
			callback(Characteristic.RESULT_UNLIKELY_ERROR);
		}
	}
});

const registerCharacteristic = new Characteristic({
	uuid: REGISTER_CHAR_UUID,
	properties: ['write'],
	onWriteRequest: async (data, offset, withoutResponse, callback) => {
		try {
			console.log('📝 Register write request');
			const request = JSON.parse(data.toString('utf-8'));
			const response = await sendToServer('register', request);

			if (response.success) {
				console.log('✅ Registration successful');
				callback(Characteristic.RESULT_SUCCESS);
			} else {
				console.log('❌ Registration failed:', response.error);
				callback(Characteristic.RESULT_UNLIKELY_ERROR);
			}
		} catch (error) {
			console.error('❌ Register error:', error.message);
			callback(Characteristic.RESULT_UNLIKELY_ERROR);
		}
	}
});

const service = new PrimaryService({
	uuid: CYBERDECK_SERVICE_UUID,
	characteristics: [
		challengeCharacteristic,
		authCharacteristic,
		registerCharacteristic
	]
});

// Start BLE
bleno.on('stateChange', (state) => {
	console.log(`📡 Bluetooth state: ${state}`);

	if (state === 'poweredOn') {
		bleno.startAdvertising('CyberdeckProxy', [CYBERDECK_SERVICE_UUID], (err) => {
			if (err) {
				console.error('❌ Advertising error:', err);
			} else {
				console.log('📡 Advertising started');
			}
		});
	} else {
		bleno.stopAdvertising();
	}
});

bleno.on('advertisingStart', (err) => {
	if (!err) {
		bleno.setServices([service], (err) => {
			if (err) {
				console.error('❌ Set services error:', err);
			} else {
				console.log('✅ BLE Proxy ready - waiting for connections');
			}
		});
	}
});

bleno.on('accept', (clientAddress) => {
	console.log(`📱 Client connected: ${clientAddress}`);
});

bleno.on('disconnect', (clientAddress) => {
	console.log(`📱 Client disconnected: ${clientAddress}`);
});

// Handle shutdown
process.on('SIGINT', () => {
	console.log('\n🛑 Shutting down...');
	bleno.stopAdvertising(() => {
		process.exit(0);
	});
});