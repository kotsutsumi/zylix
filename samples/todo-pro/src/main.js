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

import { ZylixApp, Component, State, Router, Storage } from 'zylix';

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
            id: Date.now(),
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
        document.documentElement.setAttribute('data-theme', newTheme);
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
        if (!todo.dueDate || !('Notification' in window)) return;

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
        const { todo, onToggle, onDelete, onEdit } = this.props;
        const priorityClass = `priority-${todo.priority}`;
        const categoryClass = `category-${todo.category}`;

        return `
            <div class="todo-item ${todo.completed ? 'completed' : ''} ${priorityClass}">
                <div class="todo-checkbox" onclick="handleToggle(${todo.id})">
                    ${todo.completed ? '✓' : '○'}
                </div>
                <div class="todo-content">
                    <span class="todo-text">${todo.text}</span>
                    <div class="todo-meta">
                        <span class="todo-category ${categoryClass}">${todo.category}</span>
                        ${todo.dueDate ? `<span class="todo-due">${formatDate(todo.dueDate)}</span>` : ''}
                        ${todo.tags.map(tag => `<span class="todo-tag">#${tag}</span>`).join('')}
                    </div>
                </div>
                <div class="todo-actions">
                    <button class="btn-edit" onclick="handleEdit(${todo.id})">✎</button>
                    <button class="btn-delete" onclick="handleDelete(${todo.id})">×</button>
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

    handleSubmit(e) {
        e.preventDefault();
        if (!this.state.text.trim()) return;

        this.props.onAdd({
            text: this.state.text,
            category: this.state.category,
            priority: this.state.priority,
            tags: this.state.tags.split(',').map(t => t.trim()).filter(Boolean),
            dueDate: this.state.dueDate || null
        });

        this.setState({
            text: '',
            tags: '',
            dueDate: ''
        });
    }

    render() {
        return `
            <form class="todo-form" onsubmit="handleFormSubmit(event)">
                <input
                    type="text"
                    class="todo-input"
                    placeholder="What needs to be done?"
                    value="${this.state.text}"
                    oninput="handleTextChange(event)"
                />
                <div class="todo-form-options">
                    <select class="select-category" onchange="handleCategoryChange(event)">
                        <option value="personal" ${this.state.category === 'personal' ? 'selected' : ''}>Personal</option>
                        <option value="work" ${this.state.category === 'work' ? 'selected' : ''}>Work</option>
                        <option value="shopping" ${this.state.category === 'shopping' ? 'selected' : ''}>Shopping</option>
                        <option value="health" ${this.state.category === 'health' ? 'selected' : ''}>Health</option>
                    </select>
                    <select class="select-priority" onchange="handlePriorityChange(event)">
                        <option value="low" ${this.state.priority === 'low' ? 'selected' : ''}>Low</option>
                        <option value="medium" ${this.state.priority === 'medium' ? 'selected' : ''}>Medium</option>
                        <option value="high" ${this.state.priority === 'high' ? 'selected' : ''}>High</option>
                    </select>
                    <input
                        type="date"
                        class="input-date"
                        value="${this.state.dueDate}"
                        onchange="handleDateChange(event)"
                    />
                    <input
                        type="text"
                        class="input-tags"
                        placeholder="Tags (comma separated)"
                        value="${this.state.tags}"
                        oninput="handleTagsChange(event)"
                    />
                </div>
                <button type="submit" class="btn-add">Add Todo</button>
            </form>
        `;
    }
}

class FilterBar extends Component {
    render() {
        const { filter, searchQuery, selectedCategory, onFilterChange, onSearchChange, onCategoryChange } = this.props;

        return `
            <div class="filter-bar">
                <input
                    type="search"
                    class="search-input"
                    placeholder="Search todos..."
                    value="${searchQuery}"
                    oninput="handleSearchChange(event)"
                />
                <div class="filter-buttons">
                    <button class="filter-btn ${filter === 'all' ? 'active' : ''}" onclick="setFilter('all')">All</button>
                    <button class="filter-btn ${filter === 'active' ? 'active' : ''}" onclick="setFilter('active')">Active</button>
                    <button class="filter-btn ${filter === 'completed' ? 'active' : ''}" onclick="setFilter('completed')">Completed</button>
                </div>
                <select class="category-filter" onchange="handleCategoryFilter(event)">
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
    }

    render() {
        const { theme, filter, searchQuery, selectedCategory } = this.store.state;
        const filteredTodos = this.store.getFilteredTodos();

        return `
            <div class="app ${theme}">
                <header class="header">
                    <h1>Todo Pro</h1>
                    <button class="theme-toggle" onclick="toggleTheme()">
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
    }
}

// ============================================================================
// Utilities
// ============================================================================

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
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: TodoProApp
});

// Request notification permission
if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
}

app.mount();

export { TodoProApp, TodoStore };
