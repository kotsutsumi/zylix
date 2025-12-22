/**
 * Zylix Test Framework - watchOS Driver
 */

import { IOSDriver, IOSDriverSession } from './ios.js';
import type {
    CrownDirection,
    CompanionDeviceInfo,
    WatchOSDriverConfig,
    WatchOSSession,
} from '../types.js';

export class WatchOSDriverSession extends IOSDriverSession implements WatchOSSession {
    constructor(id: string, config: WatchOSDriverConfig) {
        super(id, config);
    }

    /**
     * Rotate the Digital Crown
     * @param direction - 'up' (clockwise) or 'down' (counter-clockwise)
     * @param velocity - Rotation speed (0.0 to 1.0)
     */
    async rotateDigitalCrown(direction: CrownDirection, velocity: number = 0.5): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/digitalCrown/rotate`, {
            direction,
            velocity,
        });
    }

    /**
     * Press the Side Button
     * @param durationMs - Press duration in milliseconds
     */
    async pressSideButton(durationMs: number = 100): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/sideButton/press`, {
            duration: durationMs,
        });
    }

    /**
     * Double-press the Side Button (Apple Pay / Wallet)
     */
    async doublePresssSideButton(): Promise<void> {
        await this.client.post(`/session/${this.id}/wda/sideButton/doublePress`, {});
    }

    /**
     * Get companion iPhone device info
     */
    async getCompanionDeviceInfo(): Promise<CompanionDeviceInfo | null> {
        try {
            const response = await this.client.get(`/session/${this.id}/wda/companion/info`);
            const value = response.value as Record<string, unknown>;

            if (!value) {
                return null;
            }

            return {
                deviceName: value.deviceName as string | undefined,
                udid: value.udid as string | undefined,
                isPaired: Boolean(value.isPaired),
            };
        } catch {
            return null;
        }
    }
}

export class WatchOSDriver extends IOSDriver {
    protected readonly watchConfig: WatchOSDriverConfig;

    constructor(config: Partial<WatchOSDriverConfig> = {}) {
        super({
            host: config.host ?? '127.0.0.1',
            port: config.port ?? 8100,
            timeout: config.timeout ?? 30000,
            bundleId: config.bundleId,
            deviceUdid: config.deviceUdid,
            useSimulator: config.useSimulator ?? true,
            simulatorType: config.simulatorType ?? 'Apple Watch Series 9 (45mm)',
            platformVersion: config.platformVersion ?? '11.0',
        });

        this.watchConfig = {
            ...this.config,
            companionDeviceUdid: config.companionDeviceUdid,
            watchosVersion: config.watchosVersion ?? '11.0',
        };
    }

    async createSession(options?: Partial<WatchOSDriverConfig>): Promise<WatchOSDriverSession> {
        const mergedConfig = { ...this.watchConfig, ...options };

        const capabilities: Record<string, unknown> = {
            capabilities: {
                alwaysMatch: {
                    platformName: 'iOS',
                    'appium:automationName': 'XCUITest',
                    'appium:deviceName': mergedConfig.simulatorType,
                    'appium:platformVersion': mergedConfig.watchosVersion,
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

        if (mergedConfig.companionDeviceUdid) {
            (capabilities.capabilities as Record<string, unknown>).alwaysMatch = {
                ...(capabilities.capabilities as Record<string, unknown>).alwaysMatch as object,
                'appium:companionUdid': mergedConfig.companionDeviceUdid,
            };
        }

        const response = await this.client.post('/session', capabilities);
        const value = response.value as Record<string, string>;
        const sessionId = value.sessionId;

        return new WatchOSDriverSession(sessionId, mergedConfig);
    }
}
