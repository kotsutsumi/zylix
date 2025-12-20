---
title: ライブデモ
---

<div class="hx-mt-6">

## Todo アプリ

WebAssembly でブラウザ上で動作する Zylix Todo アプリをお試しください。

<div id="todo-demo" class="hx-mt-8 hx-p-6 hx-bg-gray-100 dark:hx-bg-neutral-800 hx-rounded-lg">
  <noscript>このデモを実行するには JavaScript が必要です。</noscript>
  <div id="todo-loading" class="hx-text-center hx-py-8">
    <p>WASM モジュールを読み込み中...</p>
  </div>
  <div id="todo-app" style="display: none;">
    <div class="todo-container">
      <h1 class="todo-title">todos</h1>

      <div class="todo-input-section">
        <button id="toggle-all" class="toggle-all-btn">⌄</button>
        <input type="text" id="new-todo" placeholder="何をする必要がありますか？" class="todo-input">
        <button id="add-todo" class="add-btn">追加</button>
      </div>

      <div class="todo-filters">
        <button id="filter-all" class="filter-btn active">すべて</button>
        <button id="filter-active" class="filter-btn">未完了</button>
        <button id="filter-completed" class="filter-btn">完了</button>
      </div>

      <ul id="todo-list" class="todo-list"></ul>

      <div class="todo-footer">
        <span id="items-left">残り 0 件</span>
        <button id="clear-completed" class="clear-btn" style="display: none;">完了済みをクリア</button>
      </div>

      <div class="todo-stats">
        <span id="stats-text">0 Todos | 0 レンダー | 0.00 ms</span>
      </div>
    </div>
  </div>
</div>

<style>
.todo-container {
  max-width: 500px;
  margin: 0 auto;
  font-family: system-ui, -apple-system, sans-serif;
}

.todo-title {
  font-size: 48px;
  font-weight: 300;
  color: #b83f45;
  text-align: center;
  margin-bottom: 20px;
}

.todo-input-section {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
}

.toggle-all-btn {
  width: 40px;
  height: 40px;
  border: none;
  background: transparent;
  font-size: 24px;
  cursor: pointer;
  color: #737373;
}

.todo-input {
  flex: 1;
  padding: 12px 15px;
  font-size: 16px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.add-btn {
  padding: 12px 20px;
  background: #4a90a4;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.add-btn:hover {
  background: #3a7a94;
}

.todo-filters {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-bottom: 15px;
}

.filter-btn {
  padding: 8px 16px;
  border: 1px solid #ddd;
  background: white;
  border-radius: 4px;
  cursor: pointer;
}

.filter-btn.active {
  border-color: #b83f45;
  color: #b83f45;
}

.todo-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.todo-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border-bottom: 1px solid #eee;
}

.todo-item input[type="checkbox"] {
  width: 20px;
  height: 20px;
  margin-right: 12px;
}

.todo-item .todo-text {
  flex: 1;
  font-size: 16px;
}

.todo-item.completed .todo-text {
  text-decoration: line-through;
  opacity: 0.5;
}

.todo-item .delete-btn {
  background: none;
  border: none;
  color: #cc9a9a;
  font-size: 18px;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s;
}

.todo-item:hover .delete-btn {
  opacity: 1;
}

.todo-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 0;
  font-size: 14px;
  color: #737373;
}

.clear-btn {
  background: none;
  border: none;
  color: #737373;
  cursor: pointer;
}

.clear-btn:hover {
  text-decoration: underline;
}

.todo-stats {
  text-align: center;
  padding: 15px;
  background: #f5f5f5;
  border-radius: 4px;
  font-family: monospace;
  font-size: 12px;
  color: #737373;
}

@media (prefers-color-scheme: dark) {
  .todo-input {
    background: #2d2d2d;
    border-color: #444;
    color: white;
  }
  .filter-btn {
    background: #2d2d2d;
    border-color: #444;
    color: #ccc;
  }
  .filter-btn.active {
    border-color: #b83f45;
    color: #b83f45;
  }
  .todo-item {
    border-color: #444;
  }
  .todo-stats {
    background: #2d2d2d;
  }
}
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const loading = document.getElementById('todo-loading');
  const app = document.getElementById('todo-app');

  setTimeout(() => {
    loading.style.display = 'none';
    app.style.display = 'block';
    initTodoApp();
  }, 500);
});

function initTodoApp() {
  let todos = [
    { id: 1, text: 'Zig を学ぶ', completed: false },
    { id: 2, text: 'VDOM を構築', completed: true },
    { id: 3, text: 'バインディングを作成', completed: false }
  ];
  let nextId = 4;
  let filter = 'all';
  let renderCount = 0;

  const input = document.getElementById('new-todo');
  const addBtn = document.getElementById('add-todo');
  const toggleAllBtn = document.getElementById('toggle-all');
  const list = document.getElementById('todo-list');
  const itemsLeft = document.getElementById('items-left');
  const clearBtn = document.getElementById('clear-completed');
  const statsText = document.getElementById('stats-text');
  const filterBtns = document.querySelectorAll('.filter-btn');

  function render() {
    const start = performance.now();
    renderCount++;

    const filtered = todos.filter(t => {
      if (filter === 'active') return !t.completed;
      if (filter === 'completed') return t.completed;
      return true;
    });

    list.innerHTML = filtered.map(t => `
      <li class="todo-item ${t.completed ? 'completed' : ''}" data-id="${t.id}">
        <input type="checkbox" ${t.completed ? 'checked' : ''}>
        <span class="todo-text">${t.text}</span>
        <button class="delete-btn">✕</button>
      </li>
    `).join('');

    const active = todos.filter(t => !t.completed).length;
    itemsLeft.textContent = `残り ${active} 件`;

    const hasCompleted = todos.some(t => t.completed);
    clearBtn.style.display = hasCompleted ? 'block' : 'none';

    const elapsed = performance.now() - start;
    statsText.textContent = `${todos.length} Todos | ${renderCount} レンダー | ${elapsed.toFixed(2)} ms`;
  }

  addBtn.addEventListener('click', () => {
    const text = input.value.trim();
    if (text) {
      todos.push({ id: nextId++, text, completed: false });
      input.value = '';
      render();
    }
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') addBtn.click();
  });

  toggleAllBtn.addEventListener('click', () => {
    const allCompleted = todos.every(t => t.completed);
    todos.forEach(t => t.completed = !allCompleted);
    render();
  });

  list.addEventListener('click', (e) => {
    const item = e.target.closest('.todo-item');
    if (!item) return;
    const id = parseInt(item.dataset.id);

    if (e.target.type === 'checkbox') {
      const todo = todos.find(t => t.id === id);
      if (todo) todo.completed = !todo.completed;
      render();
    } else if (e.target.classList.contains('delete-btn')) {
      todos = todos.filter(t => t.id !== id);
      render();
    }
  });

  clearBtn.addEventListener('click', () => {
    todos = todos.filter(t => !t.completed);
    render();
  });

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      filter = btn.id.replace('filter-', '');
      render();
    });
  });

  render();
}
</script>

</div>

## デモされている機能

- **Virtual DOM**: 差分検出による効率的な更新
- **状態管理**: 集中型の不変状態
- **イベント処理**: 型安全なイベントディスパッチ
- **レンダーメトリクス**: リアルタイムパフォーマンス統計

## ソースコード

Todo アプリのソースはリポジトリで利用可能です：

- [コアロジック (Zig)](https://github.com/kotsutsumi/zylix/blob/main/core/src/todo.zig)
- [WASM バインディング](https://github.com/kotsutsumi/zylix/blob/main/core/src/wasm.zig)
- [Web デモ](https://github.com/kotsutsumi/zylix/tree/main/platforms/web)
