/**
 * Zylix Test Framework - Web Driver
 */

import { BaseDriver, BaseSession } from './base.js';
import type { WebDriverConfig, WebSession } from '../types.js';

export class WebDriverSession extends BaseSession implements WebSession {
    constructor(id: string, config: WebDriverConfig) {
        super(id, config);
    }

    async navigateTo(url: string): Promise<void> {
        await this.client.post(`/session/${this.id}/url`, { url });
    }

    async getUrl(): Promise<string> {
        const response = await this.client.get(`/session/${this.id}/url`);
        return response.value as string;
    }

    async getTitle(): Promise<string> {
        const response = await this.client.get(`/session/${this.id}/title`);
        return response.value as string;
    }

    async executeScript<T>(script: string, args: unknown[] = []): Promise<T> {
        const response = await this.client.post(`/session/${this.id}/execute/sync`, {
            script,
            args,
        });
        return response.value as T;
    }

    async back(): Promise<void> {
        await this.client.post(`/session/${this.id}/back`, {});
    }

    async forward(): Promise<void> {
        await this.client.post(`/session/${this.id}/forward`, {});
    }

    async refresh(): Promise<void> {
        await this.client.post(`/session/${this.id}/refresh`, {});
    }
}

export class WebDriver extends BaseDriver<WebDriverConfig, WebDriverSession> {
    constructor(config: Partial<WebDriverConfig> = {}) {
        super({
            host: config.host ?? '127.0.0.1',
            port: config.port ?? 9515,
            timeout: config.timeout ?? 30000,
            browser: config.browser ?? 'chrome',
            headless: config.headless ?? false,
            viewportWidth: config.viewportWidth ?? 1920,
            viewportHeight: config.viewportHeight ?? 1080,
        });
    }

    async createSession(options?: Partial<WebDriverConfig>): Promise<WebDriverSession> {
        const mergedConfig = { ...this.config, ...options };

        const capabilities: Record<string, unknown> = {
            capabilities: {
                alwaysMatch: {
                    browserName: mergedConfig.browser,
                },
            },
        };

        // Add Chrome-specific options
        if (mergedConfig.browser === 'chrome') {
            const chromeOptions: Record<string, unknown> = {
                args: [],
            };

            if (mergedConfig.headless) {
                (chromeOptions.args as string[]).push('--headless=new');
            }

            if (mergedConfig.viewportWidth && mergedConfig.viewportHeight) {
                (chromeOptions.args as string[]).push(
                    `--window-size=${mergedConfig.viewportWidth},${mergedConfig.viewportHeight}`
                );
            }

            (capabilities.capabilities as Record<string, unknown>).alwaysMatch = {
                ...(capabilities.capabilities as Record<string, unknown>).alwaysMatch as object,
                'goog:chromeOptions': chromeOptions,
            };
        }

        const response = await this.client.post('/session', capabilities);
        const value = response.value as Record<string, string>;
        const sessionId = value.sessionId;

        return new WebDriverSession(sessionId, mergedConfig);
    }
}
