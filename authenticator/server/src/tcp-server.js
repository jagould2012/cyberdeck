import net from 'net';

/**
 * TCP server that receives BLE requests from the Mac proxy
 */
export class TcpBleServer {
	constructor({ authService, pamAuth, configManager, port = 3100 }) {
		this.authService = authService;
		this.pamAuth = pamAuth;
		this.configManager = configManager;
		this.port = port;
		this.server = null;
		this.registrationMode = false;
	}

	start() {
		return new Promise((resolve, reject) => {
			this.server = net.createServer((socket) => {
				console.log(`📡 TCP client connected: ${socket.remoteAddress}`);

				let buffer = '';

				socket.on('data', async (data) => {
					buffer += data.toString();

					// Process complete messages (newline-delimited)
					const lines = buffer.split('\n');
					buffer = lines.pop(); // Keep incomplete line in buffer

					for (const line of lines) {
						if (line.trim()) {
							await this.handleMessage(socket, line.trim());
						}
					}
				});

				socket.on('error', (err) => {
					console.error('TCP socket error:', err.message);
				});

				socket.on('close', () => {
					console.log('📡 TCP client disconnected');
				});
			});

			this.server.on('error', (err) => {
				reject(err);
			});

			this.server.listen(this.port, '0.0.0.0', () => {
				console.log(`📡 TCP BLE server listening on port ${this.port}`);
				resolve();
			});
		});
	}

	async handleMessage(socket, message) {
		try {
			const { action, data } = JSON.parse(message);
			let response;

			switch (action) {
				case 'getChallenge':
					response = this.handleGetChallenge();
					break;

				case 'authenticate':
					response = await this.handleAuthenticate(data);
					break;

				case 'register':
					response = await this.handleRegister(data);
					break;

				default:
					response = { success: false, error: 'Unknown action' };
			}

			socket.write(JSON.stringify(response) + '\n');
		} catch (error) {
			console.error('TCP message error:', error);
			socket.write(JSON.stringify({ success: false, error: error.message }) + '\n');
		}
	}

	handleGetChallenge() {
		const challenge = this.authService.generateChallenge();
		console.log('📤 Sending challenge:', challenge.nonce.substring(0, 16) + '...');
		return { success: true, challenge };
	}

	async handleAuthenticate(data) {
		const { signedNonce, publicKey } = data;
		console.log('🔐 Auth attempt received');

		const result = this.authService.verifyAuthentication(signedNonce, publicKey);

		if (result.valid) {
			console.log(`✅ Auth successful for: ${result.deviceName}`);
			try {
				await this.pamAuth.triggerLogin();
				return { success: true, deviceName: result.deviceName };
			} catch (error) {
				console.error('PAM error:', error);
				return { success: false, error: 'PAM login failed' };
			}
		} else {
			console.log(`❌ Auth failed: ${result.error}`);
			return { success: false, error: result.error };
		}
	}

	async handleRegister(data) {
		if (!this.registrationMode) {
			return { success: false, error: 'Registration mode not enabled' };
		}

		const { deviceId, publicKey, deviceName } = data;
		console.log(`📝 Registration from: ${deviceName || deviceId}`);

		try {
			await this.configManager.saveCapturedPublicKey(deviceId, publicKey, {
				deviceName: deviceName || 'Unknown Device'
			});
			return { success: true };
		} catch (error) {
			return { success: false, error: error.message };
		}
	}

	setRegistrationMode(enabled) {
		this.registrationMode = enabled;
		console.log(`📝 TCP Registration mode: ${enabled ? 'enabled' : 'disabled'}`);
	}

	stop() {
		if (this.server) {
			this.server.close();
			this.server = null;
		}
	}
}