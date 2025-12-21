// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Zylix Counter WASM Demo', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for WASM to load
    await expect(page.locator('#status')).toContainText('WASM loaded', { timeout: 10000 });
  });

  test('should load WASM module successfully', async ({ page }) => {
    // Check that status shows ready
    const status = page.locator('#status');
    await expect(status).toHaveClass(/ready/);
    await expect(status).toContainText('WASM loaded and initialized');

    // Buttons should be enabled
    await expect(page.locator('#btn-inc')).toBeEnabled();
    await expect(page.locator('#btn-dec')).toBeEnabled();
    await expect(page.locator('#btn-reset')).toBeEnabled();
  });

  test('should display initial counter value of 0', async ({ page }) => {
    const counter = page.locator('#counter');
    await expect(counter).toHaveText('0');
  });

  test('should increment counter on + button click', async ({ page }) => {
    const counter = page.locator('#counter');
    const btnInc = page.locator('#btn-inc');

    await expect(counter).toHaveText('0');

    await btnInc.click();
    await expect(counter).toHaveText('1');

    await btnInc.click();
    await expect(counter).toHaveText('2');

    await btnInc.click();
    await expect(counter).toHaveText('3');
  });

  test('should decrement counter on - button click', async ({ page }) => {
    const counter = page.locator('#counter');
    const btnInc = page.locator('#btn-inc');
    const btnDec = page.locator('#btn-dec');

    // First increment to 3
    await btnInc.click();
    await btnInc.click();
    await btnInc.click();
    await expect(counter).toHaveText('3');

    // Then decrement
    await btnDec.click();
    await expect(counter).toHaveText('2');

    await btnDec.click();
    await expect(counter).toHaveText('1');
  });

  test('should allow negative counter values', async ({ page }) => {
    const counter = page.locator('#counter');
    const btnDec = page.locator('#btn-dec');

    await expect(counter).toHaveText('0');

    await btnDec.click();
    await expect(counter).toHaveText('-1');

    await btnDec.click();
    await expect(counter).toHaveText('-2');
  });

  test('should reset counter to 0', async ({ page }) => {
    const counter = page.locator('#counter');
    const btnInc = page.locator('#btn-inc');
    const btnReset = page.locator('#btn-reset');

    // Increment a few times
    await btnInc.click();
    await btnInc.click();
    await btnInc.click();
    await btnInc.click();
    await btnInc.click();
    await expect(counter).toHaveText('5');

    // Reset
    await btnReset.click();
    await expect(counter).toHaveText('0');
  });

  test('should update state version on each action', async ({ page }) => {
    const version = page.locator('#version');
    const btnInc = page.locator('#btn-inc');

    // Initial version should be 0
    await expect(version).toHaveText('0');

    // Each action increments version
    await btnInc.click();
    await expect(version).toHaveText('1');

    await btnInc.click();
    await expect(version).toHaveText('2');

    await btnInc.click();
    await expect(version).toHaveText('3');
  });

  test('should show memory usage', async ({ page }) => {
    const memory = page.locator('#memory');

    // Memory should be displayed with KB suffix
    await expect(memory).toContainText('KB');
  });

  test('should handle rapid clicks', async ({ page }) => {
    const counter = page.locator('#counter');
    const btnInc = page.locator('#btn-inc');

    // Rapid click 10 times
    for (let i = 0; i < 10; i++) {
      await btnInc.click();
    }

    await expect(counter).toHaveText('10');
  });
});
