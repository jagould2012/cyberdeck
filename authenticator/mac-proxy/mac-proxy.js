#!/usr/bin/env node
/**
 * BLE to WebSocket Proxy for macOS
 * 
 * Runs on Mac, handles BLE advertising and connections,
 * forwards requests to VM server over persistent WebSocket.
 */

import bleno from '@abandonware/bleno';
import WebSocket from 'ws';

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

const wsUrl = `ws://${serverHost}:${serverPort}`;
console.log(`🔗 BLE Proxy - connecting to ${wsUrl}`);

// WebSocket connection
let ws = null;
let isConnected = false;
let pendingRequests = new Map();
let requestId = 0;

function connect() {
	ws = new WebSocket(wsUrl);

	ws.on('open', () => {
		isConnected = true;
		console.log(`✅ Connected to server`);
	});

	ws.on('message', (data) => {
		try {
			const response = JSON.parse(data.toString());

			// Handle broadcast messages
			if (response.type === 'connected') {
				console.log(`🔗 ${response.message}`);
				return;
			}
			if (response.type === 'registrationMode') {
				console.log(`📝 Registration mode: ${response.enabled ? 'enabled' : 'disabled'}`);
				return;
			}

			// Handle request responses
			if (response.id && pendingRequests.has(response.id)) {
				const { resolve } = pendingRequests.get(response.id);
				pendingRequests.delete(response.id);
				resolve(response);
			}
		} catch (error) {
			console.error('Failed to parse message:', error);
		}
	});

	ws.on('close', () => {
		isConnected = false;
		console.log('📡 Disconnected from server, reconnecting in 3s...');
		setTimeout(connect, 3000);
	});

	ws.on('error', (error) => {
		if (error.code === 'ECONNREFUSED') {
			console.log(`⚠️  Cannot connect to ${wsUrl} - is the server running?`);
		} else {
			console.error('WebSocket error:', error.message);
		}
	});
}

/**
 * Send a request to the server and wait for response
 */
function sendRequest(action, data = {}) {
	return new Promise((resolve, reject) => {
		if (!isConnected) {
			reject(new Error('Not connected to server'));
			return;
		}

		const id = ++requestId;
		const timeout = setTimeout(() => {
			pendingRequests.delete(id);
			reject(new Error('Request timeout'));
		}, 5000);

		pendingRequests.set(id, {
			resolve: (response) => {
				clearTimeout(timeout);
				resolve(response);
			},
			reject
		});

		ws.send(JSON.stringify({ id, action, data }));
	});
}

// Create characteristics
const { Characteristic, PrimaryService } = bleno;

const challengeCharacteristic = new Characteristic({
	uuid: CHALLENGE_CHAR_UUID,
	properties: ['read'],
	onReadRequest: async (offset, callback) => {
		try {
			console.log('📖 iPhone reading challenge...');
			const response = await sendRequest('getChallenge');
			console.log('   ✓ Challenge sent to iPhone');
			const data = Buffer.from(JSON.stringify(response.challenge), 'utf-8');
			callback(Characteristic.RESULT_SUCCESS, data.slice(offset));
		} catch (error) {
			console.error('   ✗ Challenge error:', error.message);
			callback(Characteristic.RESULT_UNLIKELY_ERROR);
		}
	}
});

const authCharacteristic = new Characteristic({
	uuid: AUTH_CHAR_UUID,
	properties: ['write'],
	onWriteRequest: async (data, offset, withoutResponse, callback) => {
		try {
			console.log('🔐 iPhone sending auth...');
			const request = JSON.parse(data.toString('utf-8'));
			const response = await sendRequest('authenticate', request);

			if (response.success) {
				console.log('   ✓ Auth successful!');
				callback(Characteristic.RESULT_SUCCESS);
			} else {
				console.log('   ✗ Auth failed:', response.error);
				callback(Characteristic.RESULT_UNLIKELY_ERROR);
			}
		} catch (error) {
			console.error('   ✗ Auth error:', error.message);
			callback(Characteristic.RESULT_UNLIKELY_ERROR);
		}
	}
});

const registerCharacteristic = new Characteristic({
	uuid: REGISTER_CHAR_UUID,
	properties: ['write'],
	onWriteRequest: async (data, offset, withoutResponse, callback) => {
		try {
			console.log('📝 iPhone registering...');
			const request = JSON.parse(data.toString('utf-8'));
			const response = await sendRequest('register', request);

			if (response.success) {
				console.log('   ✓ Registration successful!');
				callback(Characteristic.RESULT_SUCCESS);
			} else {
				console.log('   ✗ Registration failed:', response.error);
				callback(Characteristic.RESULT_UNLIKELY_ERROR);
			}
		} catch (error) {
			console.error('   ✗ Register error:', error.message);
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

// Connect to server first
connect();

// Start BLE
bleno.on('stateChange', (state) => {
	console.log(`📡 Bluetooth: ${state}`);

	if (state === 'poweredOn') {
		bleno.startAdvertising('CyberdeckProxy', [CYBERDECK_SERVICE_UUID], (err) => {
			if (err) {
				console.error('❌ Advertising error:', err);
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
				console.log('✅ BLE advertising - iPhone can now connect');
			}
		});
	}
});

bleno.on('accept', (clientAddress) => {
	console.log(`📱 iPhone connected: ${clientAddress}`);
});

bleno.on('disconnect', (clientAddress) => {
	console.log(`📱 iPhone disconnected`);
});

// Handle shutdown
let isShuttingDown = false;
process.on('SIGINT', () => {
	if (isShuttingDown) {
		process.exit(1);
	}
	isShuttingDown = true;
	console.log('\n🛑 Shutting down...');
	bleno.stopAdvertising();
	if (ws) ws.close();
	setTimeout(() => process.exit(0), 500);
});