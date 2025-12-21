// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Zylix TodoMVC WASM Demo', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for WASM to load
    await expect(page.locator('#status')).toContainText('WASM loaded', { timeout: 10000 });
  });

  test('should load WASM module successfully', async ({ page }) => {
    const status = page.locator('#status');
    await expect(status).toHaveClass(/ready/);
    await expect(status).toContainText('WASM loaded and initialized');

    // Input should be enabled
    await expect(page.locator('#new-todo')).toBeEnabled();
  });

  test('should display empty state initially', async ({ page }) => {
    // Main section and footer should be hidden when no todos
    await expect(page.locator('#main')).toHaveClass(/hidden/);
    await expect(page.locator('#footer')).toHaveClass(/hidden/);
  });

  test('should add a new todo', async ({ page }) => {
    const newTodo = page.locator('#new-todo');
    const todoList = page.locator('#todo-list');

    await newTodo.fill('Buy groceries');
    await newTodo.press('Enter');

    // Should show the todo item
    await expect(todoList.locator('.todo-item')).toHaveCount(1);
    await expect(todoList.locator('.todo-item label')).toHaveText('Buy groceries');

    // Input should be cleared
    await expect(newTodo).toHaveValue('');

    // Main and footer should be visible
    await expect(page.locator('#main')).not.toHaveClass(/hidden/);
    await expect(page.locator('#footer')).not.toHaveClass(/hidden/);
  });

  test('should add multiple todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');
    const todoList = page.locator('#todo-list');

    await newTodo.fill('First todo');
    await newTodo.press('Enter');

    await newTodo.fill('Second todo');
    await newTodo.press('Enter');

    await newTodo.fill('Third todo');
    await newTodo.press('Enter');

    await expect(todoList.locator('.todo-item')).toHaveCount(3);
    await expect(page.locator('#active-count')).toHaveText('3');
  });

  test('should not add empty todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');
    const todoList = page.locator('#todo-list');

    await newTodo.fill('   ');
    await newTodo.press('Enter');

    await expect(todoList.locator('.todo-item')).toHaveCount(0);
  });

  test('should toggle todo completion', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Test todo');
    await newTodo.press('Enter');

    const todoItem = page.locator('.todo-item').first();
    const toggle = todoItem.locator('.toggle');

    // Initially not completed
    await expect(todoItem).not.toHaveClass(/completed/);
    await expect(toggle).not.toBeChecked();

    // Toggle to completed
    await toggle.click();
    await expect(todoItem).toHaveClass(/completed/);
    await expect(toggle).toBeChecked();

    // Toggle back to active
    await toggle.click();
    await expect(todoItem).not.toHaveClass(/completed/);
    await expect(toggle).not.toBeChecked();
  });

  test('should update active count on toggle', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Todo 1');
    await newTodo.press('Enter');
    await newTodo.fill('Todo 2');
    await newTodo.press('Enter');

    await expect(page.locator('#active-count')).toHaveText('2');

    // Complete first todo
    await page.locator('.todo-item').first().locator('.toggle').click();
    await expect(page.locator('#active-count')).toHaveText('1');

    // Complete second todo
    await page.locator('.todo-item').nth(1).locator('.toggle').click();
    await expect(page.locator('#active-count')).toHaveText('0');
  });

  test('should delete todo', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('To be deleted');
    await newTodo.press('Enter');

    await expect(page.locator('.todo-item')).toHaveCount(1);

    // Hover and click destroy button
    const todoItem = page.locator('.todo-item').first();
    await todoItem.hover();
    await todoItem.locator('.destroy').click();

    await expect(page.locator('.todo-item')).toHaveCount(0);
  });

  test('should filter active todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Active todo');
    await newTodo.press('Enter');
    await newTodo.fill('Completed todo');
    await newTodo.press('Enter');

    // Complete second todo
    await page.locator('.todo-item').nth(1).locator('.toggle').click();

    // Filter to active
    await page.locator('#filter-active').click();
    await expect(page.locator('.todo-item')).toHaveCount(1);
    await expect(page.locator('.todo-item label')).toHaveText('Active todo');
  });

  test('should filter completed todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Active todo');
    await newTodo.press('Enter');
    await newTodo.fill('Completed todo');
    await newTodo.press('Enter');

    // Complete second todo
    await page.locator('.todo-item').nth(1).locator('.toggle').click();

    // Filter to completed
    await page.locator('#filter-completed').click();
    await expect(page.locator('.todo-item')).toHaveCount(1);
    await expect(page.locator('.todo-item label')).toHaveText('Completed todo');
  });

  test('should show all todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Active todo');
    await newTodo.press('Enter');
    await newTodo.fill('Completed todo');
    await newTodo.press('Enter');

    // Complete second todo
    await page.locator('.todo-item').nth(1).locator('.toggle').click();

    // Filter to completed first
    await page.locator('#filter-completed').click();
    await expect(page.locator('.todo-item')).toHaveCount(1);

    // Then show all
    await page.locator('#filter-all').click();
    await expect(page.locator('.todo-item')).toHaveCount(2);
  });

  test('should toggle all todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Todo 1');
    await newTodo.press('Enter');
    await newTodo.fill('Todo 2');
    await newTodo.press('Enter');
    await newTodo.fill('Todo 3');
    await newTodo.press('Enter');

    const toggleAll = page.locator('#toggle-all');

    // Toggle all to completed
    await toggleAll.click();
    await expect(page.locator('.todo-item.completed')).toHaveCount(3);
    await expect(page.locator('#active-count')).toHaveText('0');

    // Toggle all back to active
    await toggleAll.click();
    await expect(page.locator('.todo-item.completed')).toHaveCount(0);
    await expect(page.locator('#active-count')).toHaveText('3');
  });

  test('should clear completed todos', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Active todo');
    await newTodo.press('Enter');
    await newTodo.fill('Completed 1');
    await newTodo.press('Enter');
    await newTodo.fill('Completed 2');
    await newTodo.press('Enter');

    // Complete last two todos
    await page.locator('.todo-item').nth(1).locator('.toggle').click();
    await page.locator('.todo-item').nth(2).locator('.toggle').click();

    // Clear completed button should be visible
    const clearCompleted = page.locator('#clear-completed');
    await expect(clearCompleted).not.toHaveClass(/hidden/);

    // Click clear completed
    await clearCompleted.click();

    // Only active todo should remain
    await expect(page.locator('.todo-item')).toHaveCount(1);
    await expect(page.locator('.todo-item label')).toHaveText('Active todo');

    // Clear completed button should be hidden
    await expect(clearCompleted).toHaveClass(/hidden/);
  });

  test('should update item plural correctly', async ({ page }) => {
    const newTodo = page.locator('#new-todo');
    const itemPlural = page.locator('#item-plural');

    // Add one item - should say "item"
    await newTodo.fill('One item');
    await newTodo.press('Enter');
    await expect(itemPlural).toHaveText('');

    // Add second item - should say "items"
    await newTodo.fill('Two items');
    await newTodo.press('Enter');
    await expect(itemPlural).toHaveText('s');

    // Complete one - back to "item"
    await page.locator('.todo-item').first().locator('.toggle').click();
    await expect(itemPlural).toHaveText('');
  });

  test('should handle URL hash for filtering', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    await newTodo.fill('Test todo');
    await newTodo.press('Enter');
    await page.locator('.todo-item').first().locator('.toggle').click();

    await newTodo.fill('Active todo');
    await newTodo.press('Enter');

    // Navigate via URL hash
    await page.goto('/#/active');
    await expect(page.locator('.todo-item')).toHaveCount(1);
    await expect(page.locator('#filter-active')).toHaveClass(/selected/);

    await page.goto('/#/completed');
    await expect(page.locator('.todo-item')).toHaveCount(1);
    await expect(page.locator('#filter-completed')).toHaveClass(/selected/);

    await page.goto('/#/');
    await expect(page.locator('.todo-item')).toHaveCount(2);
    await expect(page.locator('#filter-all')).toHaveClass(/selected/);
  });

  test('should handle rapid interactions', async ({ page }) => {
    const newTodo = page.locator('#new-todo');

    // Add 10 todos rapidly
    for (let i = 1; i <= 10; i++) {
      await newTodo.fill(`Todo ${i}`);
      await newTodo.press('Enter');
    }

    await expect(page.locator('.todo-item')).toHaveCount(10);
    await expect(page.locator('#active-count')).toHaveText('10');

    // Toggle all rapidly
    for (const toggle of await page.locator('.todo-item .toggle').all()) {
      await toggle.click();
    }

    await expect(page.locator('.todo-item.completed')).toHaveCount(10);
    await expect(page.locator('#active-count')).toHaveText('0');
  });
});
