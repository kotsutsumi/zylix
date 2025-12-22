/**
 * Zylix Test Framework - HTTP Client
 */

import { ConnectionError, ZylixError } from './types.js';

export interface HttpResponse {
    status: number;
    value: unknown;
}

export class HttpClient {
    constructor(
        private readonly host: string,
        private readonly port: number,
        private readonly timeout: number = 30000
    ) {}

    get baseUrl(): string {
        return `http://${this.host}:${this.port}`;
    }

    async isAvailable(): Promise<boolean> {
        try {
            const response = await this.get('/status');
            return response.status === 0 || response.status === 200;
        } catch {
            return false;
        }
    }

    async get(path: string): Promise<HttpResponse> {
        return this.request('GET', path);
    }

    async post(path: string, body?: unknown): Promise<HttpResponse> {
        return this.request('POST', path, body);
    }

    async delete(path: string): Promise<HttpResponse> {
        return this.request('DELETE', path);
    }

    private async request(
        method: string,
        path: string,
        body?: unknown
    ): Promise<HttpResponse> {
        const url = `${this.baseUrl}${path}`;

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);

        try {
            const options: RequestInit = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                signal: controller.signal,
            };

            if (body !== undefined) {
                options.body = JSON.stringify(body);
            }

            const response = await fetch(url, options);
            const data = await response.json();

            // WebDriver protocol response format
            if (typeof data === 'object' && data !== null) {
                if ('status' in data && 'value' in data) {
                    return data as HttpResponse;
                }
                // W3C WebDriver format
                if ('value' in data) {
                    return { status: 0, value: data.value };
                }
            }

            return { status: 0, value: data };
        } catch (error) {
            if (error instanceof Error) {
                if (error.name === 'AbortError') {
                    throw new ZylixError(`Request timeout: ${path}`, 'TIMEOUT');
                }
                throw new ConnectionError(`Failed to connect to ${url}: ${error.message}`);
            }
            throw new ConnectionError(`Failed to connect to ${url}`);
        } finally {
            clearTimeout(timeoutId);
        }
    }
}
