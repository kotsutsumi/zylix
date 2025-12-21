// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Zylix Component Showcase v0.7.0', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for WASM to load
    await expect(page.locator('[data-testid="status"]')).toContainText('WASM loaded', { timeout: 10000 });
  });

  test.describe('WASM Initialization', () => {
    test('should load WASM module successfully', async ({ page }) => {
      const status = page.locator('[data-testid="status"]');
      await expect(status).toHaveClass(/ready/);
      await expect(status).toContainText('WASM loaded and initialized');
    });

    test('should display component count', async ({ page }) => {
      const componentCount = page.locator('[data-testid="component-count"]');
      // After initialization, should have some components created
      await expect(componentCount).not.toHaveText('0');
    });

    test('should display memory usage', async ({ page }) => {
      const memoryUsed = page.locator('[data-testid="memory-used"]');
      await expect(memoryUsed).toContainText('KB');
    });

    test('should display ABI version', async ({ page }) => {
      const abiVersion = page.locator('[data-testid="abi-version"]');
      await expect(abiVersion).not.toHaveText('-');
    });
  });

  test.describe('Layout Components', () => {
    test('VStack should render with vertical layout', async ({ page }) => {
      const vstack = page.locator('[data-testid="vstack"]');
      await expect(vstack).toBeVisible();
      await expect(vstack).toHaveClass(/zylix-vstack/);
    });

    test('Card component should render with border and background', async ({ page }) => {
      const card = page.locator('[data-testid="card"]');
      await expect(card).toBeVisible();
      await expect(card).toHaveClass(/zylix-card/);
    });

    test('Badge should display count', async ({ page }) => {
      const badge = page.locator('[data-testid="badge"]');
      await expect(badge).toBeVisible();
      await expect(badge).toHaveText('3');
    });

    test('Tag should display label', async ({ page }) => {
      const tag = page.locator('[data-testid="tag"]');
      await expect(tag).toBeVisible();
      await expect(tag).toHaveText('Feature');
    });
  });

  test.describe('Form Components', () => {
    test('Checkbox should be clickable', async ({ page }) => {
      const checkbox = page.locator('[data-testid="checkbox-1"]');
      await expect(checkbox).toBeVisible();
      await expect(checkbox).not.toBeChecked();

      await checkbox.click();
      await expect(checkbox).toBeChecked();

      await checkbox.click();
      await expect(checkbox).not.toBeChecked();
    });

    test('Pre-checked checkbox should be checked', async ({ page }) => {
      const checkbox = page.locator('[data-testid="checkbox-2"]');
      await expect(checkbox).toBeChecked();
    });

    test('Toggle switch should work', async ({ page }) => {
      const toggle = page.locator('[data-testid="toggle-1"]');
      await expect(toggle).toBeVisible();
      await expect(toggle).not.toBeChecked();

      await toggle.click();
      await expect(toggle).toBeChecked();
    });

    test('Select should have options', async ({ page }) => {
      const select = page.locator('[data-testid="select"]');
      await expect(select).toBeVisible();

      await select.selectOption('opt2');
      await expect(select).toHaveValue('opt2');
    });

    test('Textarea should accept input', async ({ page }) => {
      const textarea = page.locator('[data-testid="textarea"]');
      await expect(textarea).toBeVisible();

      await textarea.fill('Hello from Playwright!');
      await expect(textarea).toHaveValue('Hello from Playwright!');
    });
  });

  test.describe('Feedback Components', () => {
    test('Alerts should render all styles', async ({ page }) => {
      await expect(page.locator('[data-testid="alert-info"]')).toBeVisible();
      await expect(page.locator('[data-testid="alert-success"]')).toBeVisible();
      await expect(page.locator('[data-testid="alert-warning"]')).toBeVisible();
      await expect(page.locator('[data-testid="alert-error"]')).toBeVisible();
    });

    test('Info alert should have correct styling', async ({ page }) => {
      const alert = page.locator('[data-testid="alert-info"]');
      await expect(alert).toHaveClass(/info/);
      await expect(alert).toContainText('info alert');
    });

    test('Progress bar should be visible', async ({ page }) => {
      const progress = page.locator('[data-testid="progress"]');
      await expect(progress).toBeVisible();
      await expect(progress).toHaveClass(/zylix-progress/);
    });

    test('Progress value should be displayed', async ({ page }) => {
      const progressValue = page.locator('[data-testid="progress-value"]');
      await expect(progressValue).toContainText('%');
    });

    test('Spinner should be animating', async ({ page }) => {
      const spinner = page.locator('[data-testid="spinner"]');
      await expect(spinner).toBeVisible();
      await expect(spinner).toHaveClass(/zylix-spinner/);
    });
  });

  test.describe('Data Display Components', () => {
    test('Tags should render with correct labels', async ({ page }) => {
      await expect(page.locator('[data-testid="tag-layout"]')).toHaveText('Layout');
      await expect(page.locator('[data-testid="tag-form"]')).toHaveText('Form');
      await expect(page.locator('[data-testid="tag-feedback"]')).toHaveText('Feedback');
      await expect(page.locator('[data-testid="tag-navigation"]')).toHaveText('Navigation');
    });

    test('Notification badge should show count', async ({ page }) => {
      const badge = page.locator('[data-testid="notification-badge"]');
      await expect(badge).toHaveText('5');
    });

    test('Accordion should toggle content visibility', async ({ page }) => {
      const accordion = page.locator('[data-testid="accordion"]');
      const content = page.locator('[data-testid="accordion-content"]');

      // Initially collapsed
      await expect(content).not.toBeVisible();

      // Click to expand
      await accordion.locator('.zylix-accordion-header').click();
      await expect(accordion).toHaveClass(/expanded/);
      await expect(content).toBeVisible();

      // Click to collapse
      await accordion.locator('.zylix-accordion-header').click();
      await expect(accordion).not.toHaveClass(/expanded/);
      await expect(content).not.toBeVisible();
    });
  });

  test.describe('Interactive Demo', () => {
    test('Create Component button should add dynamic card', async ({ page }) => {
      const createBtn = page.locator('[data-testid="btn-create"]');
      const dynamicContent = page.locator('[data-testid="dynamic-content"]');

      // Click create button
      await createBtn.click();

      // Should create first dynamic card
      const firstCard = page.locator('[data-testid="dynamic-card-1"]');
      await expect(firstCard).toBeVisible();
      await expect(firstCard).toContainText('Component #1');
    });

    test('Multiple component creation should work', async ({ page }) => {
      const createBtn = page.locator('[data-testid="btn-create"]');

      // Create 3 components
      await createBtn.click();
      await createBtn.click();
      await createBtn.click();

      await expect(page.locator('[data-testid="dynamic-card-1"]')).toBeVisible();
      await expect(page.locator('[data-testid="dynamic-card-2"]')).toBeVisible();
      await expect(page.locator('[data-testid="dynamic-card-3"]')).toBeVisible();
    });

    test('Update Progress button should change progress value', async ({ page }) => {
      const updateBtn = page.locator('[data-testid="btn-update"]');
      const progressValue = page.locator('[data-testid="progress-value"]');

      // Get initial value
      const initialText = await progressValue.textContent();
      const initialValue = parseInt(initialText || '0');

      // Click update
      await updateBtn.click();

      // Value should change
      const newText = await progressValue.textContent();
      const newValue = parseInt(newText || '0');

      // Progress increases by 15% (wrapping at 101)
      const expectedValue = (initialValue + 15) % 101;
      expect(newValue).toBe(expectedValue);
    });

    test('Reset button should clear dynamic content', async ({ page }) => {
      const createBtn = page.locator('[data-testid="btn-create"]');
      const resetBtn = page.locator('[data-testid="btn-reset"]');

      // Create some components
      await createBtn.click();
      await createBtn.click();

      // Verify they exist
      await expect(page.locator('[data-testid="dynamic-card-1"]')).toBeVisible();
      await expect(page.locator('[data-testid="dynamic-card-2"]')).toBeVisible();

      // Reset
      await resetBtn.click();

      // Dynamic cards should be removed
      await expect(page.locator('[data-testid="dynamic-card-1"]')).not.toBeVisible();
      await expect(page.locator('[data-testid="dynamic-card-2"]')).not.toBeVisible();
    });

    test('Component count should update on create', async ({ page }) => {
      const createBtn = page.locator('[data-testid="btn-create"]');
      const componentCount = page.locator('[data-testid="component-count"]');

      // Get initial count
      const initialText = await componentCount.textContent();
      const initialCount = parseInt(initialText || '0');

      // Create a component
      await createBtn.click();

      // Count should increase
      const newText = await componentCount.textContent();
      const newCount = parseInt(newText || '0');

      expect(newCount).toBeGreaterThan(initialCount);
    });
  });

  test.describe('Accessibility', () => {
    test('All buttons should be focusable', async ({ page }) => {
      const buttons = page.locator('button.zylix-button');
      const count = await buttons.count();

      expect(count).toBeGreaterThan(0);

      for (let i = 0; i < count; i++) {
        const button = buttons.nth(i);
        await expect(button).toBeEnabled();
      }
    });

    test('Form inputs should be accessible', async ({ page }) => {
      const checkbox1 = page.locator('[data-testid="checkbox-1"]');
      const select = page.locator('[data-testid="select"]');
      const textarea = page.locator('[data-testid="textarea"]');

      // All should be focusable and interactive
      await checkbox1.focus();
      await expect(checkbox1).toBeFocused();

      await select.focus();
      await expect(select).toBeFocused();

      await textarea.focus();
      await expect(textarea).toBeFocused();
    });
  });
});
