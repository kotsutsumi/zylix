// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Zylix Test Framework - Web E2E Demo
 *
 * These tests demonstrate the patterns used by Zylix's Zig-based
 * test framework, implemented using Playwright for comparison.
 */

test.describe('Session Lifecycle', () => {
    test('should create and manage browser session', async ({ page }) => {
        // Navigate to page (equivalent to Zylix session.navigateTo)
        await page.goto('https://example.com');

        // Verify page loaded
        await expect(page).toHaveTitle('Example Domain');
    });
});

test.describe('Element Finding', () => {
    test('should find elements by CSS selector', async ({ page }) => {
        await page.goto('https://example.com');

        // Find by CSS (equivalent to Zylix Selector.css)
        const heading = page.locator('h1');
        await expect(heading).toHaveText('Example Domain');
    });

    test('should find elements by text content', async ({ page }) => {
        await page.goto('https://example.com');

        // Find by text (equivalent to Zylix Selector.byText)
        const link = page.getByText('More information');
        await expect(link).toBeVisible();
    });

    test('should find elements by accessibility', async ({ page }) => {
        await page.goto('https://example.com');

        // Find by role (accessibility-first approach)
        const mainHeading = page.getByRole('heading', { level: 1 });
        await expect(mainHeading).toHaveText('Example Domain');
    });
});

test.describe('Navigation', () => {
    test('should navigate to URL', async ({ page }) => {
        await page.goto('https://example.com');
        await expect(page).toHaveURL('https://example.com/');
    });

    test('should get current URL', async ({ page }) => {
        await page.goto('https://example.com');
        const url = page.url();
        expect(url).toContain('example.com');
    });

    test('should get page title', async ({ page }) => {
        await page.goto('https://example.com');
        const title = await page.title();
        expect(title).toBe('Example Domain');
    });
});

test.describe('Element Interaction', () => {
    test('should click elements', async ({ page }) => {
        await page.goto('https://example.com');

        // Click link (equivalent to Zylix element.tap)
        await page.getByRole('link', { name: 'More information' }).click();

        // Should navigate away
        await expect(page).not.toHaveURL('https://example.com/');
    });
});

test.describe('Screenshots', () => {
    test('should capture screenshot', async ({ page }) => {
        await page.goto('https://example.com');

        // Capture screenshot (equivalent to Zylix takeScreenshot)
        const screenshot = await page.screenshot();
        expect(screenshot).toBeTruthy();
        expect(screenshot.length).toBeGreaterThan(0);
    });

    test('should capture element screenshot', async ({ page }) => {
        await page.goto('https://example.com');

        const heading = page.locator('h1');
        const screenshot = await heading.screenshot();
        expect(screenshot).toBeTruthy();
    });
});

test.describe('JavaScript Execution', () => {
    test('should execute JavaScript', async ({ page }) => {
        await page.goto('https://example.com');

        // Execute script (equivalent to Zylix executeScript)
        const result = await page.evaluate(() => {
            return document.title;
        });

        expect(result).toBe('Example Domain');
    });

    test('should return values from JavaScript', async ({ page }) => {
        await page.goto('https://example.com');

        const result = await page.evaluate(() => {
            return {
                title: document.title,
                url: window.location.href,
                headingCount: document.querySelectorAll('h1').length,
            };
        });

        expect(result.title).toBe('Example Domain');
        expect(result.headingCount).toBe(1);
    });
});
