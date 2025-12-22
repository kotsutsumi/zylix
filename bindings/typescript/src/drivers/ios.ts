/**
 * Zylix Test Framework - iOS Driver
 */

import { BaseDriver, BaseSession } from './base.js';
import type { IOSDriverConfig, IOSSession } from '../types.js';

export class IOSDriverSession extends BaseSession implements IOSSession {
    constructor(id: string, config: IOSDriverConfig) {
        super(id, config);
    }

    async tapAt(x: number, y: number): Promise<void> {
        await this.client.post(`/session/${this.id}/actions`, {
            actions: [
                {
                    type: 'pointer',
                    id: 'finger1',
                    parameters: { pointerType: 'touch' },
                    actions: [
                        { type: 'pointerMove', duration: 0, x, y },
                        { type: 'pointerDown', button: 0 },
                        { type: 'pointerUp', button: 0 },
                    ],
                },
            ],
        });
    }

    async swipe(
        startX: number,
        startY: number,
        endX: number,
        endY: number,
        durationMs: number = 500
    ): Promise<void> {
        await this.client.post(`/session/${this.id}/actions`, {
            actions: [
                {
                    type: 'pointer',
                    id: 'finger1',
                    parameters: { pointerType: 'touch' },
                    actions: [
                        { type: 'pointerMove', duration: 0, x: startX, y: startY },
                        { type: 'pointerDown', button: 0 },
                        { type: 'pointerMove', duration: durationMs, x: endX, y: endY },
                        { type: 'pointerUp', button: 0 },
                    ],
                },
            ],
        });
    }

    async shake(): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/shake`, {});
    }

    async lock(): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/lock`, {});
    }

    async unlock(): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/unlock`, {});
    }
}

export class IOSDriver extends BaseDriver<IOSDriverConfig, IOSDriverSession> {
    constructor(config: Partial<IOSDriverConfig> = {}) {
        super({
            host: config.host ?? '127.0.0.1',
            port: config.port ?? 8100,
            timeout: config.timeout ?? 30000,
            bundleId: config.bundleId,
            deviceUdid: config.deviceUdid,
            useSimulator: config.useSimulator ?? true,
            simulatorType: config.simulatorType ?? 'iPhone 15 Pro',
            platformVersion: config.platformVersion ?? '17.0',
        });
    }

    async createSession(options?: Partial<IOSDriverConfig>): Promise<IOSDriverSession> {
        const mergedConfig = { ...this.config, ...options };

        const capabilities: Record<string, unknown> = {
            capabilities: {
                alwaysMatch: {
                    platformName: 'iOS',
                    'appium:automationName': 'XCUITest',
                    'appium:deviceName': mergedConfig.simulatorType,
                    'appium:platformVersion': mergedConfig.platformVersion,
                },
            },
        };

        if (mergedConfig.bundleId) {
            (capabilities.capabilities as Record<string, unknown>).alwaysMatch = {
                ...(capabilities.capabilities as Record<string, unknown>).alwaysMatch as object,
                'appium:bundleId': mergedConfig.bundleId,
            };
        }

        if (mergedConfig.deviceUdid) {
            (capabilities.capabilities as Record<string, unknown>).alwaysMatch = {
                ...(capabilities.capabilities as Record<string, unknown>).alwaysMatch as object,
                'appium:udid': mergedConfig.deviceUdid,
            };
        }

        const response = await this.client.post('/session', capabilities);
        const value = response.value as Record<string, string>;
        const sessionId = value.sessionId;

        return new IOSDriverSession(sessionId, mergedConfig);
    }
}
