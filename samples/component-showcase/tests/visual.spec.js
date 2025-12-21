// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Visual Regression Tests for Zylix Component Showcase
 *
 * These tests capture screenshots of components and compare them
 * against baseline images to detect visual changes.
 *
 * To update baseline screenshots:
 * npx playwright test --update-snapshots
 */

test.describe('Visual Regression Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for WASM to load
    await expect(page.locator('[data-testid="status"]')).toContainText('WASM loaded', { timeout: 10000 });
    // Wait for animations to settle
    await page.waitForTimeout(500);
  });

  test.describe('Full Page', () => {
    test('should match full page screenshot', async ({ page }) => {
      // Hide dynamic elements that might change
      await page.evaluate(() => {
        // Hide memory usage which can vary
        const memoryEl = document.getElementById('memory-used');
        if (memoryEl) memoryEl.textContent = '0.0 KB';
        // Hide component count which might vary
        const countEl = document.getElementById('component-count');
        if (countEl) countEl.textContent = '0';
        // Stop spinner animation for consistent screenshots
        const spinner = document.querySelector('.zylix-spinner');
        if (spinner) spinner.style.animation = 'none';
      });

      await expect(page).toHaveScreenshot('full-page.png', {
        fullPage: true,
        maxDiffPixelRatio: 0.05, // Allow 5% difference for minor rendering variations
      });
    });
  });

  test.describe('Layout Components', () => {
    test('VStack and HStack layout', async ({ page }) => {
      const layoutStack = page.locator('[data-testid="layout-stack"]');
      await expect(layoutStack).toHaveScreenshot('layout-stack.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Card component', async ({ page }) => {
      const layoutCard = page.locator('[data-testid="layout-card"]');
      await expect(layoutCard).toHaveScreenshot('card-component.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });

  test.describe('Form Components', () => {
    test('Checkbox and Toggle controls', async ({ page }) => {
      const formControls = page.locator('[data-testid="form-controls"]');
      await expect(formControls).toHaveScreenshot('form-controls.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Select and Textarea', async ({ page }) => {
      const formInputs = page.locator('[data-testid="form-inputs"]');
      await expect(formInputs).toHaveScreenshot('form-inputs.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Checkbox checked state', async ({ page }) => {
      // Click to check the first checkbox
      const checkbox = page.locator('[data-testid="checkbox-1"]');
      await checkbox.click();

      const formControls = page.locator('[data-testid="form-controls"]');
      await expect(formControls).toHaveScreenshot('form-controls-checked.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });

  test.describe('Feedback Components', () => {
    test('Alert styles', async ({ page }) => {
      const feedbackAlerts = page.locator('[data-testid="feedback-alerts"]');
      await expect(feedbackAlerts).toHaveScreenshot('alert-styles.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Progress and Spinner', async ({ page }) => {
      // Stop spinner animation for consistent screenshots
      await page.evaluate(() => {
        const spinner = document.querySelector('.zylix-spinner');
        if (spinner) spinner.style.animation = 'none';
      });

      const feedbackProgress = page.locator('[data-testid="feedback-progress"]');
      await expect(feedbackProgress).toHaveScreenshot('progress-spinner.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });

  test.describe('Data Display Components', () => {
    test('Badge and Tag display', async ({ page }) => {
      const dataBadges = page.locator('[data-testid="data-badges"]');
      await expect(dataBadges).toHaveScreenshot('badges-tags.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Accordion collapsed state', async ({ page }) => {
      const dataAccordion = page.locator('[data-testid="data-accordion"]');
      await expect(dataAccordion).toHaveScreenshot('accordion-collapsed.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Accordion expanded state', async ({ page }) => {
      // Expand accordion
      const accordionHeader = page.locator('#accordion1-trigger');
      await accordionHeader.click();

      // Wait for animation
      await page.waitForTimeout(300);

      const dataAccordion = page.locator('[data-testid="data-accordion"]');
      await expect(dataAccordion).toHaveScreenshot('accordion-expanded.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });

  test.describe('Interactive Demo', () => {
    test('Initial state', async ({ page }) => {
      // Normalize dynamic values
      await page.evaluate(() => {
        const memoryEl = document.getElementById('memory-used');
        if (memoryEl) memoryEl.textContent = '0.0 KB';
        const countEl = document.getElementById('component-count');
        if (countEl) countEl.textContent = '0';
      });

      const dynamicContent = page.locator('[data-testid="dynamic-content"]');
      await expect(dynamicContent).toHaveScreenshot('dynamic-initial.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('After creating components', async ({ page }) => {
      // Create some components
      const createBtn = page.locator('[data-testid="btn-create"]');
      await createBtn.click();
      await createBtn.click();

      const dynamicContent = page.locator('[data-testid="dynamic-content"]');
      await expect(dynamicContent).toHaveScreenshot('dynamic-with-components.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });

  test.describe('Theme and Styling', () => {
    test('Header styling', async ({ page }) => {
      const header = page.locator('header');
      await expect(header).toHaveScreenshot('header.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Footer styling', async ({ page }) => {
      const footer = page.locator('footer');
      await expect(footer).toHaveScreenshot('footer.png', {
        maxDiffPixelRatio: 0.02,
      });
    });

    test('Statistics panel', async ({ page }) => {
      // Normalize dynamic values
      await page.evaluate(() => {
        const memoryEl = document.getElementById('memory-used');
        if (memoryEl) memoryEl.textContent = '0.0 KB';
        const countEl = document.getElementById('component-count');
        if (countEl) countEl.textContent = '0';
        const abiEl = document.getElementById('abi-version');
        if (abiEl) abiEl.textContent = '1';
      });

      const stats = page.locator('[data-testid="stats"]');
      await expect(stats).toHaveScreenshot('stats-panel.png', {
        maxDiffPixelRatio: 0.02,
      });
    });
  });
});
