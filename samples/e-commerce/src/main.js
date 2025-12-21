// E-Commerce - Intermediate Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - Routing
// - HTTP requests
// - Authentication
// - Product catalog
// - Shopping cart
// - Order management

import { ZylixApp, Component, State, Router, Http, Storage } from 'zylix';

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
 * Escapes a value for use in URLs
 */
function escapeUrl(str) {
    if (str == null) return '';
    return encodeURIComponent(String(str));
}

// ============================================================================
// Types
// ============================================================================

const OrderStatus = {
    PENDING: 'pending',
    PROCESSING: 'processing',
    SHIPPED: 'shipped',
    DELIVERED: 'delivered'
};

// ============================================================================
// API Client
// ============================================================================

const api = {
    baseUrl: '/api',

    async getProducts(params = {}) {
        const query = new URLSearchParams(params).toString();
        return Http.get(`${this.baseUrl}/products?${query}`);
    },

    async getProduct(id) {
        return Http.get(`${this.baseUrl}/products/${id}`);
    },

    async searchProducts(query) {
        return Http.get(`${this.baseUrl}/products/search?q=${encodeURIComponent(query)}`);
    },

    async login(email, password) {
        return Http.post(`${this.baseUrl}/auth/login`, { email, password });
    },

    async register(data) {
        return Http.post(`${this.baseUrl}/auth/register`, data);
    },

    async getOrders() {
        return Http.get(`${this.baseUrl}/orders`);
    },

    async createOrder(order) {
        return Http.post(`${this.baseUrl}/orders`, order);
    }
};

// ============================================================================
// State Management
// ============================================================================

class AppStore extends State {
    constructor() {
        super({
            user: null,
            products: [],
            cart: [],
            orders: [],
            isLoading: false,
            error: null
        });

        this.loadFromStorage();
    }

    loadFromStorage() {
        const cart = Storage.get('e-commerce-cart') || [];
        const user = Storage.get('e-commerce-user');
        this.setState({ cart, user });
    }

    // Auth
    async login(email, password) {
        this.setState({ isLoading: true, error: null });
        try {
            const user = await api.login(email, password);
            this.setState({ user, isLoading: false });
            Storage.set('e-commerce-user', user);
            return user;
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
            throw error;
        }
    }

    async register(data) {
        this.setState({ isLoading: true, error: null });
        try {
            const user = await api.register(data);
            this.setState({ user, isLoading: false });
            Storage.set('e-commerce-user', user);
            return user;
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
            throw error;
        }
    }

    logout() {
        this.setState({ user: null });
        Storage.remove('e-commerce-user');
        Router.push('/');
    }

    // Products
    async loadProducts(params = {}) {
        this.setState({ isLoading: true });
        try {
            const products = await api.getProducts(params);
            this.setState({ products, isLoading: false });
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
        }
    }

    async searchProducts(query) {
        this.setState({ isLoading: true });
        try {
            const products = await api.searchProducts(query);
            this.setState({ products, isLoading: false });
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
        }
    }

    // Cart
    addToCart(product, quantity = 1) {
        const cart = [...this.state.cart];
        const existingIndex = cart.findIndex(item => item.product.id === product.id);

        if (existingIndex >= 0) {
            cart[existingIndex].quantity += quantity;
        } else {
            cart.push({ product, quantity });
        }

        this.setState({ cart });
        Storage.set('e-commerce-cart', cart);
    }

    removeFromCart(productId) {
        const cart = this.state.cart.filter(item => item.product.id !== productId);
        this.setState({ cart });
        Storage.set('e-commerce-cart', cart);
    }

    updateCartQuantity(productId, quantity) {
        if (quantity <= 0) {
            return this.removeFromCart(productId);
        }

        const cart = this.state.cart.map(item =>
            item.product.id === productId
                ? { ...item, quantity }
                : item
        );
        this.setState({ cart });
        Storage.set('e-commerce-cart', cart);
    }

    clearCart() {
        this.setState({ cart: [] });
        Storage.remove('e-commerce-cart');
    }

    getCartTotal() {
        return this.state.cart.reduce((total, item) =>
            total + (item.product.price * item.quantity), 0
        );
    }

    getCartCount() {
        return this.state.cart.reduce((count, item) => count + item.quantity, 0);
    }

    // Orders
    async loadOrders() {
        this.setState({ isLoading: true });
        try {
            const orders = await api.getOrders();
            this.setState({ orders, isLoading: false });
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
        }
    }

    async createOrder(shippingInfo) {
        this.setState({ isLoading: true });
        try {
            const order = await api.createOrder({
                items: this.state.cart,
                shipping: shippingInfo,
                total: this.getCartTotal()
            });
            this.clearCart();
            this.setState({ isLoading: false });
            return order;
        } catch (error) {
            this.setState({ error: error.message, isLoading: false });
            throw error;
        }
    }
}

// ============================================================================
// Components
// ============================================================================

class Header extends Component {
    render() {
        const { user, cartCount, onLogout } = this.props;

        return `
            <header class="header">
                <div class="header-left">
                    <a href="/" class="logo">ShopZylix</a>
                    <nav class="nav">
                        <a href="/products">Products</a>
                        <a href="/categories">Categories</a>
                    </nav>
                </div>
                <div class="header-right">
                    <div class="search-box">
                        <input type="search" placeholder="Search products..." data-action="search" />
                    </div>
                    <a href="/cart" class="cart-icon">
                        🛒 <span class="cart-badge">${cartCount}</span>
                    </a>
                    ${user
                        ? `
                            <div class="user-menu">
                                <span>${escapeHtml(user.name)}</span>
                                <div class="dropdown">
                                    <a href="/orders">Orders</a>
                                    <a href="/profile">Profile</a>
                                    <button data-action="logout">Logout</button>
                                </div>
                            </div>
                        `
                        : `
                            <a href="/login" class="btn btn-primary">Login</a>
                        `
                    }
                </div>
            </header>
        `;
    }
}

class ProductCard extends Component {
    render() {
        const { product, onAddToCart } = this.props;
        const escapedId = escapeAttr(product.id);
        const rating = Math.max(0, Math.min(5, Math.round(product.rating || 0)));

        return `
            <div class="product-card">
                <a href="/products/${escapeUrl(product.id)}">
                    <img src="${escapeAttr(product.image)}" alt="${escapeAttr(product.name)}" class="product-image" />
                </a>
                <div class="product-info">
                    <h3 class="product-name">${escapeHtml(product.name)}</h3>
                    <p class="product-category">${escapeHtml(product.category)}</p>
                    <div class="product-rating">
                        ${'★'.repeat(rating)}${'☆'.repeat(5 - rating)}
                        <span>(${escapeHtml(product.reviewCount)})</span>
                    </div>
                    <div class="product-price">
                        ${product.originalPrice > product.price
                            ? `<span class="original-price">$${escapeHtml(product.originalPrice.toFixed(2))}</span>`
                            : ''
                        }
                        <span class="current-price">$${escapeHtml(product.price.toFixed(2))}</span>
                    </div>
                    <button class="btn btn-primary" data-action="add-to-cart" data-product-id="${escapedId}">
                        Add to Cart
                    </button>
                </div>
            </div>
        `;
    }
}

class ProductGrid extends Component {
    render() {
        const { products, isLoading } = this.props;

        if (isLoading) {
            return `<div class="loading">Loading products...</div>`;
        }

        if (products.length === 0) {
            return `<div class="empty-state">No products found.</div>`;
        }

        return `
            <div class="product-grid">
                ${products.map(product =>
                    new ProductCard({ product }).render()
                ).join('')}
            </div>
        `;
    }
}

class CartItem extends Component {
    render() {
        const { item, onUpdateQuantity, onRemove } = this.props;
        const { product, quantity } = item;
        const escapedId = escapeAttr(product.id);

        return `
            <div class="cart-item">
                <img src="${escapeAttr(product.image)}" alt="${escapeAttr(product.name)}" class="cart-item-image" />
                <div class="cart-item-details">
                    <h4>${escapeHtml(product.name)}</h4>
                    <p class="price">$${escapeHtml(product.price.toFixed(2))}</p>
                </div>
                <div class="cart-item-quantity">
                    <button data-action="update-quantity" data-product-id="${escapedId}" data-quantity="${quantity - 1}">-</button>
                    <span>${escapeHtml(quantity)}</span>
                    <button data-action="update-quantity" data-product-id="${escapedId}" data-quantity="${quantity + 1}">+</button>
                </div>
                <div class="cart-item-total">
                    $${escapeHtml((product.price * quantity).toFixed(2))}
                </div>
                <button class="btn-remove" data-action="remove-from-cart" data-product-id="${escapedId}">×</button>
            </div>
        `;
    }
}

class CartPage extends Component {
    render() {
        const { cart, total, onCheckout } = this.props;

        if (cart.length === 0) {
            return `
                <div class="cart-empty">
                    <h2>Your cart is empty</h2>
                    <a href="/products" class="btn btn-primary">Continue Shopping</a>
                </div>
            `;
        }

        return `
            <div class="cart-page">
                <h1>Shopping Cart</h1>
                <div class="cart-items">
                    ${cart.map(item =>
                        new CartItem({ item }).render()
                    ).join('')}
                </div>
                <div class="cart-summary">
                    <div class="summary-row">
                        <span>Subtotal</span>
                        <span>$${escapeHtml(total.toFixed(2))}</span>
                    </div>
                    <div class="summary-row">
                        <span>Shipping</span>
                        <span>FREE</span>
                    </div>
                    <div class="summary-row total">
                        <span>Total</span>
                        <span>$${escapeHtml(total.toFixed(2))}</span>
                    </div>
                    <button class="btn btn-primary btn-lg" data-action="checkout">
                        Proceed to Checkout
                    </button>
                </div>
            </div>
        `;
    }
}

class LoginPage extends Component {
    constructor() {
        super();
        this.state = {
            email: '',
            password: '',
            error: null
        };
    }

    render() {
        return `
            <div class="auth-page">
                <div class="auth-card">
                    <h1>Login</h1>
                    ${this.state.error ? `<div class="error">${escapeHtml(this.state.error)}</div>` : ''}
                    <form data-action="login-form">
                        <div class="form-group">
                            <label>Email</label>
                            <input type="email" name="email" required />
                        </div>
                        <div class="form-group">
                            <label>Password</label>
                            <input type="password" name="password" required />
                        </div>
                        <button type="submit" class="btn btn-primary btn-block">Login</button>
                    </form>
                    <p class="auth-link">
                        Don't have an account? <a href="/register">Register</a>
                    </p>
                </div>
            </div>
        `;
    }
}

class OrderHistory extends Component {
    render() {
        const { orders, isLoading } = this.props;

        if (isLoading) {
            return `<div class="loading">Loading orders...</div>`;
        }

        if (orders.length === 0) {
            return `
                <div class="empty-state">
                    <h2>No orders yet</h2>
                    <a href="/products" class="btn btn-primary">Start Shopping</a>
                </div>
            `;
        }

        return `
            <div class="orders-page">
                <h1>Order History</h1>
                <div class="orders-list">
                    ${orders.map(order => `
                        <div class="order-card">
                            <div class="order-header">
                                <span class="order-id">Order #${escapeHtml(order.id)}</span>
                                <span class="order-date">${escapeHtml(new Date(order.createdAt).toLocaleDateString())}</span>
                                <span class="order-status status-${escapeAttr(order.status)}">${escapeHtml(order.status)}</span>
                            </div>
                            <div class="order-items">
                                ${order.items.map(item => `
                                    <div class="order-item">
                                        <span>${escapeHtml(item.product.name)} × ${escapeHtml(item.quantity)}</span>
                                        <span>$${escapeHtml((item.product.price * item.quantity).toFixed(2))}</span>
                                    </div>
                                `).join('')}
                            </div>
                            <div class="order-total">
                                <span>Total:</span>
                                <span>$${escapeHtml(order.total.toFixed(2))}</span>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>
        `;
    }
}

// ============================================================================
// App
// ============================================================================

class ECommerceApp extends Component {
    constructor() {
        super();
        this.store = new AppStore();
        this.store.subscribe(() => this.render());

        this.setupRoutes();
        this.boundHandleClick = this.handleClick.bind(this);
        this.boundHandleSubmit = this.handleSubmit.bind(this);
        this.boundHandleInput = this.handleInput.bind(this);
    }

    setupRoutes() {
        Router.on('/', () => this.renderHome());
        Router.on('/products', () => this.renderProducts());
        Router.on('/products/:id', (params) => this.renderProduct(params.id));
        Router.on('/cart', () => this.renderCart());
        Router.on('/checkout', () => this.renderCheckout());
        Router.on('/login', () => this.renderLogin());
        Router.on('/register', () => this.renderRegister());
        Router.on('/orders', () => this.renderOrders());
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
    }

    handleClick(event) {
        const target = event.target.closest('[data-action]');
        if (!target) return;

        const action = target.dataset.action;
        const productId = target.dataset.productId;

        switch (action) {
            case 'add-to-cart':
                const product = this.store.state.products.find(p => String(p.id) === productId);
                if (product) {
                    this.store.addToCart(product);
                }
                break;
            case 'update-quantity':
                const quantity = parseInt(target.dataset.quantity, 10);
                this.store.updateCartQuantity(productId, quantity);
                break;
            case 'remove-from-cart':
                this.store.removeFromCart(productId);
                break;
            case 'checkout':
                Router.push('/checkout');
                break;
            case 'logout':
                this.store.logout();
                break;
        }
    }

    handleSubmit(event) {
        const form = event.target.closest('[data-action]');
        if (!form) return;

        event.preventDefault();
        const action = form.dataset.action;

        if (action === 'login-form') {
            const formData = new FormData(form);
            const email = formData.get('email');
            const password = formData.get('password');
            this.store.login(email, password)
                .then(() => Router.push('/'))
                .catch(err => console.error('Login failed:', err));
        }
    }

    handleInput(event) {
        const target = event.target;
        if (target.dataset.action === 'search') {
            this.store.searchProducts(target.value);
        }
    }

    render() {
        const { user } = this.store.state;
        const cartCount = this.store.getCartCount();

        return `
            <div class="app">
                ${new Header({ user, cartCount }).render()}
                <main class="main" id="main-content">
                    ${this.renderCurrentRoute()}
                </main>
                <footer class="footer">
                    <p>© 2024 ShopZylix - Built with Zylix v0.6.0</p>
                </footer>
            </div>
        `;
    }

    renderCurrentRoute() {
        return Router.render();
    }

    renderHome() {
        this.store.loadProducts({ featured: true });
        const { products, isLoading } = this.store.state;

        return `
            <div class="home-page">
                <section class="hero">
                    <h1>Welcome to ShopZylix</h1>
                    <p>Discover amazing products at great prices</p>
                    <a href="/products" class="btn btn-primary btn-lg">Shop Now</a>
                </section>
                <section class="featured">
                    <h2>Featured Products</h2>
                    ${new ProductGrid({ products, isLoading }).render()}
                </section>
            </div>
        `;
    }

    renderProducts() {
        const { products, isLoading } = this.store.state;
        return new ProductGrid({ products, isLoading }).render();
    }

    renderCart() {
        const { cart } = this.store.state;
        const total = this.store.getCartTotal();
        return new CartPage({ cart, total }).render();
    }

    renderLogin() {
        return new LoginPage().render();
    }

    renderOrders() {
        const { orders, isLoading } = this.store.state;
        return new OrderHistory({ orders, isLoading }).render();
    }
}

// ============================================================================
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: ECommerceApp
});

app.mount();

export { ECommerceApp, AppStore, escapeHtml, escapeAttr, escapeUrl };
