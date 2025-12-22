/**
 * Zylix Test Framework - Base Driver
 */

import { HttpClient } from '../client.js';
import { ZylixElement } from '../element.js';
import { toWebDriverSelector } from '../selectors.js';
import type {
    DriverConfig,
    Element,
    ElementNotFoundError,
    Selector,
    Session,
    TimeoutError,
} from '../types.js';
import { ElementNotFoundError as ElementNotFoundErrorClass, TimeoutError as TimeoutErrorClass } from '../types.js';

export abstract class BaseSession implements Session {
    protected client: HttpClient;

    constructor(
        public readonly id: string,
        protected readonly config: DriverConfig
    ) {
        this.client = new HttpClient(
            config.host ?? '127.0.0.1',
            config.port,
            config.timeout ?? 30000
        );
    }

    async find(selector: Selector): Promise<Element> {
        const { using, value } = toWebDriverSelector(selector);

        const response = await this.client.post(`/session/${this.id}/element`, {
            using,
            value,
        });

        const result = response.value as Record<string, string>;
        const elementId = result.ELEMENT ?? result['element-6066-11e4-a52e-4f735466cecf'];

        if (!elementId) {
            throw new ElementNotFoundErrorClass(selector);
        }

        return new ZylixElement(elementId, this.id, this.client);
    }

    async findAll(selector: Selector): Promise<Element[]> {
        const { using, value } = toWebDriverSelector(selector);

        const response = await this.client.post(`/session/${this.id}/elements`, {
            using,
            value,
        });

        const results = response.value as Array<Record<string, string>>;

        return results.map(result => {
            const elementId = result.ELEMENT ?? result['element-6066-11e4-a52e-4f735466cecf'];
            return new ZylixElement(elementId, this.id, this.client);
        });
    }

    async waitFor(selector: Selector, timeout: number = 10000): Promise<Element> {
        const startTime = Date.now();
        const pollInterval = 500;

        while (Date.now() - startTime < timeout) {
            try {
                const element = await this.find(selector);
                if (element.exists) {
                    return element;
                }
            } catch (error) {
                // Element not found yet, continue polling
            }

            await new Promise(resolve => setTimeout(resolve, pollInterval));
        }

        throw new TimeoutErrorClass(`Element not found within ${timeout}ms`, { selector });
    }

    async takeScreenshot(): Promise<Buffer> {
        const response = await this.client.get(`/session/${this.id}/screenshot`);
        const base64 = response.value as string;
        return Buffer.from(base64, 'base64');
    }

    async getSource(): Promise<string> {
        const response = await this.client.get(`/session/${this.id}/source`);
        return response.value as string;
    }
}

export abstract class BaseDriver<TConfig extends DriverConfig, TSession extends Session> {
    protected client: HttpClient;

    constructor(protected readonly config: TConfig) {
        this.client = new HttpClient(
            config.host ?? '127.0.0.1',
            config.port,
            config.timeout ?? 30000
        );
    }

    async isAvailable(): Promise<boolean> {
        return this.client.isAvailable();
    }

    abstract createSession(options?: Partial<TConfig>): Promise<TSession>;

    async deleteSession(sessionId: string): Promise<void> {
        await this.client.delete(`/session/${sessionId}`);
    }
}
