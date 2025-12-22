/**
 * Zylix Test Framework - Element Implementation
 */

import type { HttpClient } from './client.js';
import type { Element, ElementRect, SwipeDirection } from './types.js';

export class ZylixElement implements Element {
    constructor(
        public readonly id: string,
        private readonly sessionId: string,
        private readonly client: HttpClient
    ) {}

    get exists(): boolean {
        return this.id.length > 0;
    }

    async tap(): Promise<void> {
        await this.client.post(
            `/session/${this.sessionId}/element/${this.id}/click`,
            {}
        );
    }

    async doubleTap(): Promise<void> {
        // Perform two taps in quick succession
        await this.tap();
        await new Promise(resolve => setTimeout(resolve, 50));
        await this.tap();
    }

    async longPress(durationMs: number = 1000): Promise<void> {
        const rect = await this.getRect();
        const centerX = rect.x + rect.width / 2;
        const centerY = rect.y + rect.height / 2;

        await this.client.post(`/session/${this.sessionId}/actions`, {
            actions: [
                {
                    type: 'pointer',
                    id: 'finger1',
                    parameters: { pointerType: 'touch' },
                    actions: [
                        { type: 'pointerMove', duration: 0, x: centerX, y: centerY },
                        { type: 'pointerDown', button: 0 },
                        { type: 'pause', duration: durationMs },
                        { type: 'pointerUp', button: 0 },
                    ],
                },
            ],
        });
    }

    async type(text: string): Promise<void> {
        await this.client.post(
            `/session/${this.sessionId}/element/${this.id}/value`,
            { text, value: text.split('') }
        );
    }

    async clear(): Promise<void> {
        await this.client.post(
            `/session/${this.sessionId}/element/${this.id}/clear`,
            {}
        );
    }

    async swipe(direction: SwipeDirection): Promise<void> {
        const rect = await this.getRect();
        const centerX = rect.x + rect.width / 2;
        const centerY = rect.y + rect.height / 2;

        let endX = centerX;
        let endY = centerY;
        const distance = 200;

        switch (direction) {
            case 'up':
                endY = centerY - distance;
                break;
            case 'down':
                endY = centerY + distance;
                break;
            case 'left':
                endX = centerX - distance;
                break;
            case 'right':
                endX = centerX + distance;
                break;
        }

        await this.client.post(`/session/${this.sessionId}/actions`, {
            actions: [
                {
                    type: 'pointer',
                    id: 'finger1',
                    parameters: { pointerType: 'touch' },
                    actions: [
                        { type: 'pointerMove', duration: 0, x: centerX, y: centerY },
                        { type: 'pointerDown', button: 0 },
                        { type: 'pointerMove', duration: 300, x: endX, y: endY },
                        { type: 'pointerUp', button: 0 },
                    ],
                },
            ],
        });
    }

    async getText(): Promise<string> {
        const response = await this.client.get(
            `/session/${this.sessionId}/element/${this.id}/text`
        );
        return String(response.value ?? '');
    }

    async getAttribute(name: string): Promise<string | null> {
        const response = await this.client.get(
            `/session/${this.sessionId}/element/${this.id}/attribute/${name}`
        );
        return response.value as string | null;
    }

    async getRect(): Promise<ElementRect> {
        const response = await this.client.get(
            `/session/${this.sessionId}/element/${this.id}/rect`
        );
        const rect = response.value as Record<string, number>;
        return {
            x: rect.x ?? 0,
            y: rect.y ?? 0,
            width: rect.width ?? 0,
            height: rect.height ?? 0,
        };
    }

    async isVisible(): Promise<boolean> {
        const response = await this.client.get(
            `/session/${this.sessionId}/element/${this.id}/displayed`
        );
        return Boolean(response.value);
    }

    async isEnabled(): Promise<boolean> {
        const response = await this.client.get(
            `/session/${this.sessionId}/element/${this.id}/enabled`
        );
        return Boolean(response.value);
    }
}
