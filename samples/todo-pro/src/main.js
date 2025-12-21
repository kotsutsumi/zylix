// Todo Pro - Beginner Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - State management
// - Form handling
// - Local storage persistence
// - Dark/light theme
// - Categories and tags
// - Due dates with notifications
// - Search and filter

import { ZylixApp, Component, State, Storage } from 'zylix';

// ============================================================================
// Utilities
// ============================================================================

/**
 * Escapes HTML special characters to prevent XSS attacks
 */
function escapeHtml(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

/**
 * Escapes a value for use in HTML attributes
 */
function escapeAttr(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;');
}

/**
 * Generates a unique ID using crypto.randomUUID with fallback
 */
function generateId() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
    }
    // Fallback for older browsers
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = date - now;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days < 0) return 'Overdue';
    if (days === 0) return 'Today';
    if (days === 1) return 'Tomorrow';
    if (days < 7) return `In ${days} days`;

    return date.toLocaleDateString();
}

// ============================================================================
// Types
// ============================================================================

const Priority = {
    LOW: 'low',
    MEDIUM: 'medium',
    HIGH: 'high'
};

const Category = {
    PERSONAL: 'personal',
    WORK: 'work',
    SHOPPING: 'shopping',
    HEALTH: 'health'
};

// ============================================================================
// State Management
// ============================================================================

class TodoStore extends State {
    constructor() {
        super({
            todos: [],
            filter: 'all',
            searchQuery: '',
            selectedCategory: null,
            theme: 'light'
        });

        this.loadFromStorage();
    }

    loadFromStorage() {
        const saved = Storage.get('todo-pro-data');
        if (saved) {
            this.setState({
                todos: saved.todos || [],
                theme: saved.theme || 'light'
            });
            // Apply theme on load
            if (typeof document !== 'undefined') {
                document.documentElement.setAttribute('data-theme', saved.theme || 'light');
            }
        }
    }

    saveToStorage() {
        Storage.set('todo-pro-data', {
            todos: this.state.todos,
            theme: this.state.theme
        });
    }

    addTodo(todo) {
        const newTodo = {
            id: generateId(),
            text: todo.text,
            completed: false,
            category: todo.category || Category.PERSONAL,
            priority: todo.priority || Priority.MEDIUM,
            tags: todo.tags || [],
            dueDate: todo.dueDate || null,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        this.setState({
            todos: [...this.state.todos, newTodo]
        });
        this.saveToStorage();
        this.scheduleNotification(newTodo);
    }

    toggleTodo(id) {
        this.setState({
            todos: this.state.todos.map(todo =>
                todo.id === id
                    ? { ...todo, completed: !todo.completed, updatedAt: new Date().toISOString() }
                    : todo
            )
        });
        this.saveToStorage();
    }

    deleteTodo(id) {
        this.setState({
            todos: this.state.todos.filter(todo => todo.id !== id)
        });
        this.saveToStorage();
    }

    updateTodo(id, updates) {
        this.setState({
            todos: this.state.todos.map(todo =>
                todo.id === id
                    ? { ...todo, ...updates, updatedAt: new Date().toISOString() }
                    : todo
            )
        });
        this.saveToStorage();
    }

    setFilter(filter) {
        this.setState({ filter });
    }

    setSearchQuery(query) {
        this.setState({ searchQuery: query });
    }

    setCategory(category) {
        this.setState({ selectedCategory: category });
    }

    toggleTheme() {
        const newTheme = this.state.theme === 'light' ? 'dark' : 'light';
        this.setState({ theme: newTheme });
        this.saveToStorage();
        // Theme DOM update is handled by UI layer subscription
    }

    getFilteredTodos() {
        let filtered = [...this.state.todos];

        // Filter by completion status
        if (this.state.filter === 'active') {
            filtered = filtered.filter(todo => !todo.completed);
        } else if (this.state.filter === 'completed') {
            filtered = filtered.filter(todo => todo.completed);
        }

        // Filter by category
        if (this.state.selectedCategory) {
            filtered = filtered.filter(todo => todo.category === this.state.selectedCategory);
        }

        // Filter by search query
        if (this.state.searchQuery) {
            const query = this.state.searchQuery.toLowerCase();
            filtered = filtered.filter(todo =>
                todo.text.toLowerCase().includes(query) ||
                todo.tags.some(tag => tag.toLowerCase().includes(query))
            );
        }

        // Sort by priority and due date
        filtered.sort((a, b) => {
            const priorityOrder = { high: 0, medium: 1, low: 2 };
            if (priorityOrder[a.priority] !== priorityOrder[b.priority]) {
                return priorityOrder[a.priority] - priorityOrder[b.priority];
            }
            if (a.dueDate && b.dueDate) {
                return new Date(a.dueDate) - new Date(b.dueDate);
            }
            return a.dueDate ? -1 : 1;
        });

        return filtered;
    }

    scheduleNotification(todo) {
        if (!todo.dueDate || typeof window === 'undefined' || !('Notification' in window)) return;

        const dueTime = new Date(todo.dueDate).getTime();
        const now = Date.now();
        const delay = dueTime - now - (30 * 60 * 1000); // 30 minutes before

        if (delay > 0) {
            setTimeout(() => {
                if (Notification.permission === 'granted') {
                    new Notification('Todo Pro Reminder', {
                        body: `"${todo.text}" is due soon!`,
                        icon: '/icon.png'
                    });
                }
            }, delay);
        }
    }
}

// ============================================================================
// Components
// ============================================================================

class TodoItem extends Component {
    render() {
        const { todo } = this.props;
        const priorityClass = `priority-${escapeAttr(todo.priority)}`;
        const categoryClass = `category-${escapeAttr(todo.category)}`;
        const escapedId = escapeAttr(todo.id);

        return `
            <div class="todo-item ${todo.completed ? 'completed' : ''} ${priorityClass}">
                <div class="todo-checkbox" data-action="toggle" data-id="${escapedId}">
                    ${todo.completed ? '✓' : '○'}
                </div>
                <div class="todo-content">
                    <span class="todo-text">${escapeHtml(todo.text)}</span>
                    <div class="todo-meta">
                        <span class="todo-category ${categoryClass}">${escapeHtml(todo.category)}</span>
                        ${todo.dueDate ? `<span class="todo-due">${escapeHtml(formatDate(todo.dueDate))}</span>` : ''}
                        ${todo.tags.map(tag => `<span class="todo-tag">#${escapeHtml(tag)}</span>`).join('')}
                    </div>
                </div>
                <div class="todo-actions">
                    <button class="btn-edit" data-action="edit" data-id="${escapedId}">✎</button>
                    <button class="btn-delete" data-action="delete" data-id="${escapedId}">×</button>
                </div>
            </div>
        `;
    }
}

class TodoForm extends Component {
    constructor(props) {
        super(props);
        this.state = {
            text: '',
            category: Category.PERSONAL,
            priority: Priority.MEDIUM,
            tags: '',
            dueDate: ''
        };
    }

    render() {
        return `
            <form class="todo-form" data-action="submit-form">
                <input
                    type="text"
                    class="todo-input"
                    name="text"
                    placeholder="What needs to be done?"
                    value="${escapeAttr(this.state.text)}"
                />
                <div class="todo-form-options">
                    <select class="select-category" name="category">
                        <option value="personal" ${this.state.category === 'personal' ? 'selected' : ''}>Personal</option>
                        <option value="work" ${this.state.category === 'work' ? 'selected' : ''}>Work</option>
                        <option value="shopping" ${this.state.category === 'shopping' ? 'selected' : ''}>Shopping</option>
                        <option value="health" ${this.state.category === 'health' ? 'selected' : ''}>Health</option>
                    </select>
                    <select class="select-priority" name="priority">
                        <option value="low" ${this.state.priority === 'low' ? 'selected' : ''}>Low</option>
                        <option value="medium" ${this.state.priority === 'medium' ? 'selected' : ''}>Medium</option>
                        <option value="high" ${this.state.priority === 'high' ? 'selected' : ''}>High</option>
                    </select>
                    <input
                        type="date"
                        class="input-date"
                        name="dueDate"
                        value="${escapeAttr(this.state.dueDate)}"
                    />
                    <input
                        type="text"
                        class="input-tags"
                        name="tags"
                        placeholder="Tags (comma separated)"
                        value="${escapeAttr(this.state.tags)}"
                    />
                </div>
                <button type="submit" class="btn-add">Add Todo</button>
            </form>
        `;
    }
}

class FilterBar extends Component {
    render() {
        const { filter, searchQuery, selectedCategory } = this.props;

        return `
            <div class="filter-bar">
                <input
                    type="search"
                    class="search-input"
                    name="search"
                    placeholder="Search todos..."
                    value="${escapeAttr(searchQuery)}"
                    data-action="search"
                />
                <div class="filter-buttons">
                    <button class="filter-btn ${filter === 'all' ? 'active' : ''}" data-action="filter" data-filter="all">All</button>
                    <button class="filter-btn ${filter === 'active' ? 'active' : ''}" data-action="filter" data-filter="active">Active</button>
                    <button class="filter-btn ${filter === 'completed' ? 'active' : ''}" data-action="filter" data-filter="completed">Completed</button>
                </div>
                <select class="category-filter" data-action="category-filter">
                    <option value="">All Categories</option>
                    <option value="personal" ${selectedCategory === 'personal' ? 'selected' : ''}>Personal</option>
                    <option value="work" ${selectedCategory === 'work' ? 'selected' : ''}>Work</option>
                    <option value="shopping" ${selectedCategory === 'shopping' ? 'selected' : ''}>Shopping</option>
                    <option value="health" ${selectedCategory === 'health' ? 'selected' : ''}>Health</option>
                </select>
            </div>
        `;
    }
}

class TodoStats extends Component {
    render() {
        const { todos } = this.props;
        const total = todos.length;
        const completed = todos.filter(t => t.completed).length;
        const active = total - completed;
        const overdue = todos.filter(t => !t.completed && t.dueDate && new Date(t.dueDate) < new Date()).length;

        return `
            <div class="todo-stats">
                <div class="stat">
                    <span class="stat-value">${total}</span>
                    <span class="stat-label">Total</span>
                </div>
                <div class="stat">
                    <span class="stat-value">${active}</span>
                    <span class="stat-label">Active</span>
                </div>
                <div class="stat">
                    <span class="stat-value">${completed}</span>
                    <span class="stat-label">Completed</span>
                </div>
                <div class="stat stat-warning">
                    <span class="stat-value">${overdue}</span>
                    <span class="stat-label">Overdue</span>
                </div>
            </div>
        `;
    }
}

// ============================================================================
// App
// ============================================================================

class TodoProApp extends Component {
    constructor() {
        super();
        this.store = new TodoStore();
        this.store.subscribe(() => this.render());
        this.boundHandleClick = this.handleClick.bind(this);
        this.boundHandleSubmit = this.handleSubmit.bind(this);
        this.boundHandleInput = this.handleInput.bind(this);
        this.boundHandleChange = this.handleChange.bind(this);
    }

    mount(container) {
        this.container = container;
        this.render();
        this.attachEventListeners();
    }

    attachEventListeners() {
        if (!this.container) return;

        this.container.addEventListener('click', this.boundHandleClick);
        this.container.addEventListener('submit', this.boundHandleSubmit);
        this.container.addEventListener('input', this.boundHandleInput);
        this.container.addEventListener('change', this.boundHandleChange);
    }

    handleClick(event) {
        const target = event.target.closest('[data-action]');
        if (!target) return;

        const action = target.dataset.action;
        const id = target.dataset.id;

        switch (action) {
            case 'toggle':
                this.store.toggleTodo(id);
                break;
            case 'delete':
                this.store.deleteTodo(id);
                break;
            case 'edit':
                // For now, just log - could open modal
                console.log('Edit todo:', id);
                break;
            case 'filter':
                this.store.setFilter(target.dataset.filter);
                break;
            case 'toggle-theme':
                this.store.toggleTheme();
                // Update DOM theme
                document.documentElement.setAttribute('data-theme', this.store.state.theme);
                break;
        }
    }

    handleSubmit(event) {
        const form = event.target.closest('[data-action="submit-form"]');
        if (!form) return;

        event.preventDefault();

        const formData = new FormData(form);
        const text = formData.get('text')?.trim();

        if (!text) return;

        this.store.addTodo({
            text: text,
            category: formData.get('category') || Category.PERSONAL,
            priority: formData.get('priority') || Priority.MEDIUM,
            tags: (formData.get('tags') || '').split(',').map(t => t.trim()).filter(Boolean),
            dueDate: formData.get('dueDate') || null
        });

        form.reset();
    }

    handleInput(event) {
        const target = event.target;
        if (target.dataset.action === 'search') {
            this.store.setSearchQuery(target.value);
        }
    }

    handleChange(event) {
        const target = event.target;
        if (target.dataset.action === 'category-filter') {
            this.store.setCategory(target.value || null);
        }
    }

    render() {
        const { theme, filter, searchQuery, selectedCategory } = this.store.state;
        const filteredTodos = this.store.getFilteredTodos();

        const html = `
            <div class="app ${escapeAttr(theme)}">
                <header class="header">
                    <h1>Todo Pro</h1>
                    <button class="theme-toggle" data-action="toggle-theme">
                        ${theme === 'light' ? '🌙' : '☀️'}
                    </button>
                </header>

                ${new TodoStats({ todos: this.store.state.todos }).render()}

                ${new TodoForm({ onAdd: (todo) => this.store.addTodo(todo) }).render()}

                ${new FilterBar({
                    filter,
                    searchQuery,
                    selectedCategory
                }).render()}

                <div class="todo-list">
                    ${filteredTodos.length === 0
                        ? '<div class="empty-state">No todos found. Add one above!</div>'
                        : filteredTodos.map(todo =>
                            new TodoItem({
                                todo,
                                onToggle: () => this.store.toggleTodo(todo.id),
                                onDelete: () => this.store.deleteTodo(todo.id)
                            }).render()
                        ).join('')
                    }
                </div>

                <footer class="footer">
                    <p>Built with Zylix v0.6.0</p>
                </footer>
            </div>
        `;

        if (this.container) {
            this.container.innerHTML = html;
        }

        return html;
    }
}

// ============================================================================
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: TodoProApp
});

// Request notification permission
if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
}

app.mount();

export { TodoProApp, TodoStore, escapeHtml, escapeAttr, generateId };
