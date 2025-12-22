/**
 * Zylix Test Framework - macOS Driver
 */

import { BaseDriver, BaseSession } from './base.js';
import type {
    KeyModifier,
    MacOSDriverConfig,
    MacOSSession,
    WindowInfo,
} from '../types.js';

export class MacOSDriverSession extends BaseSession implements MacOSSession {
    constructor(id: string, config: MacOSDriverConfig) {
        super(id, config);
    }

    async getWindows(): Promise<WindowInfo[]> {
        const response = await this.client.get(`/session/${this.id}/windows`);
        const windows = response.value as Array<Record<string, unknown>>;

        return windows.map(w => ({
            id: w.id as string,
            title: w.title as string | undefined,
            position: {
                x: (w.x as number) ?? 0,
                y: (w.y as number) ?? 0,
            },
            size: {
                width: (w.width as number) ?? 0,
                height: (w.height as number) ?? 0,
            },
        }));
    }

    async activateWindow(windowId: string): Promise<void> {
        await this.client.post(`/session/${this.id}/window/${windowId}/activate`, {});
    }

    async pressKey(key: string, modifiers: KeyModifier[] = []): Promise<void> {
        await this.client.post(`/session/${this.id}/keys`, {
            key,
            modifiers,
        });
    }

    async typeText(text: string): Promise<void> {
        await this.client.post(`/session/${this.id}/type`, { text });
    }
}

export class MacOSDriver extends BaseDriver<MacOSDriverConfig, MacOSDriverSession> {
    constructor(config: Partial<MacOSDriverConfig> = {}) {
        super({
            host: config.host ?? '127.0.0.1',
            port: config.port ?? 8200,
            timeout: config.timeout ?? 30000,
            bundleId: config.bundleId,
        });
    }

    async createSession(options?: Partial<MacOSDriverConfig>): Promise<MacOSDriverSession> {
        const mergedConfig = { ...this.config, ...options };

        const capabilities: Record<string, unknown> = {
            capabilities: {
                bundleId: mergedConfig.bundleId,
                platformName: 'macOS',
            },
        };

        const response = await this.client.post('/session', capabilities);
        const value = response.value as Record<string, string>;
        const sessionId = value.sessionId;

        return new MacOSDriverSession(sessionId, mergedConfig);
    }
}
