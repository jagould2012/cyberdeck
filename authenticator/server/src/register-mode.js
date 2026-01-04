#!/usr/bin/env node
/**
 * Put the server into registration mode for a limited time
 * Usage: node register-mode.js [duration-seconds]
 */

import net from 'net';

const SOCKET_PATH = '/tmp/cyberdeck-login.sock';
const DEFAULT_DURATION = 60;

const duration = parseInt(process.argv[2], 10) || DEFAULT_DURATION;

console.log(`🔐 Requesting registration mode for ${duration} seconds...`);

const client = net.createConnection(SOCKET_PATH, () => {
	client.write(JSON.stringify({
		command: 'enterRegistrationMode',
		durationMs: duration * 1000
	}));
});

client.on('data', (data) => {
	const response = JSON.parse(data.toString());
	if (response.success) {
		console.log('✅ Server is now in registration mode');
		console.log(`   Open the iOS app and go to Settings → Register Device`);
		console.log(`   Registration mode will expire in ${duration} seconds`);
	} else {
		console.error('❌ Failed:', response.error);
	}
	client.end();
});

client.on('error', (error) => {
	if (error.code === 'ENOENT') {
		console.error('❌ Server is not running (socket not found)');
		console.error('   Start the server first: docker-compose up -d');
	} else {
		console.error('❌ Error:', error.message);
	}
	process.exit(1);
});