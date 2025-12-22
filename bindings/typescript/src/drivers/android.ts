/**
 * Zylix Test Framework - Android Driver
 */

import { BaseDriver, BaseSession } from './base.js';
import type { AndroidDriverConfig, AndroidSession } from '../types.js';

export class AndroidDriverSession extends BaseSession implements AndroidSession {
    constructor(id: string, config: AndroidDriverConfig) {
        super(id, config);
    }

    async pressBack(): Promise<void> {
        await this.client.post(`/session/${this.id}/back`, {});
    }

    async pressHome(): Promise<void> {
        await this.client.post(`/session/${this.id}/appium/device/press_keycode`, {
            keycode: 3, // KEYCODE_HOME
        });
    }

    async pressRecentApps(): Promise<void> {
        await this.client.post(`/session/${this.id}/appium/device/press_keycode`, {
            keycode: 187, // KEYCODE_APP_SWITCH
        });
    }

    async openNotifications(): Promise<void> {
        await this.client.post(`/session/${this.id}/appium/device/open_notifications`, {});
    }
}

export class AndroidDriver extends BaseDriver<AndroidDriverConfig, AndroidDriverSession> {
    constructor(config: Partial<AndroidDriverConfig> = {}) {
        super({
            host: config.host ?? '127.0.0.1',
            port: config.port ?? 4723,
            timeout: config.timeout ?? 30000,
            packageName: config.packageName,
            activityName: config.activityName,
            deviceId: config.deviceId,
            platformVersion: config.platformVersion ?? '14',
            automationName: config.automationName ?? 'UiAutomator2',
        });
    }

    async createSession(options?: Partial<AndroidDriverConfig>): Promise<AndroidDriverSession> {
        const mergedConfig = { ...this.config, ...options };

        const capabilities: Record<string, unknown> = {
            capabilities: {
                alwaysMatch: {
                    platformName: 'Android',
                    'appium:automationName': mergedConfig.automationName,
                    'appium:platformVersion': mergedConfig.platformVersion,
                },
            },
        };

        const alwaysMatch = (capabilities.capabilities as Record<string, unknown>).alwaysMatch as Record<string, unknown>;

        if (mergedConfig.packageName) {
            alwaysMatch['appium:appPackage'] = mergedConfig.packageName;
        }

        if (mergedConfig.activityName) {
            alwaysMatch['appium:appActivity'] = mergedConfig.activityName;
        }

        if (mergedConfig.deviceId) {
            alwaysMatch['appium:udid'] = mergedConfig.deviceId;
        }

        const response = await this.client.post('/session', capabilities);
        const value = response.value as Record<string, string>;
        const sessionId = value.sessionId;

        return new AndroidDriverSession(sessionId, mergedConfig);
    }
}
