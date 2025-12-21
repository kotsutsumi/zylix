// Chat - Advanced Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - WebSocket real-time messaging
// - User presence
// - File attachments
// - Push notifications
// - Typing indicators

import { ZylixApp, Component, State, Http, Storage } from 'zylix';

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
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

function formatTime(timestamp) {
    if (!timestamp) return '';

    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m`;
    if (diff < 86400000) return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

// ============================================================================
// Types
// ============================================================================

const MessageType = {
    TEXT: 'text',
    IMAGE: 'image',
    FILE: 'file',
    SYSTEM: 'system'
};

const UserStatus = {
    ONLINE: 'online',
    AWAY: 'away',
    BUSY: 'busy',
    OFFLINE: 'offline'
};

// ============================================================================
// WebSocket Connection
// ============================================================================

class ChatWebSocket {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
        this.handlers = new Map();
        this.messageQueue = [];
        this.token = null;
        this.reconnectTimer = null;
    }

    connect(token) {
        this.token = token;

        return new Promise((resolve, reject) => {
            try {
                // Check if WebSocket is available
                if (typeof WebSocket === 'undefined' && typeof window !== 'undefined') {
                    this.ws = new window.WebSocket(`${this.url}?token=${encodeURIComponent(token)}`);
                } else if (typeof WebSocket !== 'undefined') {
                    this.ws = new WebSocket(`${this.url}?token=${encodeURIComponent(token)}`);
                } else {
                    reject(new Error('WebSocket not available'));
                    return;
                }

                this.ws.onopen = () => {
                    console.log('[Chat] Connected');
                    this.reconnectAttempts = 0;
                    this.flushQueue();
                    resolve();
                };

                this.ws.onclose = (event) => {
                    console.log('[Chat] Disconnected', event.code, event.reason);
                    if (!event.wasClean) {
                        this.scheduleReconnect();
                    }
                };

                this.ws.onerror = (error) => {
                    console.error('[Chat] Error:', error);
                    reject(error);
                };

                this.ws.onmessage = (event) => {
                    try {
                        const message = JSON.parse(event.data);
                        this.handleMessage(message);
                    } catch (e) {
                        console.error('[Chat] Failed to parse message:', e);
                    }
                };
            } catch (error) {
                reject(error);
            }
        });
    }

    disconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        if (this.ws) {
            this.ws.close(1000, 'User disconnect');
            this.ws = null;
        }
        this.token = null;
    }

    scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.log('[Chat] Max reconnect attempts reached');
            return;
        }

        this.reconnectAttempts++;
        // Exponential backoff with jitter
        const baseDelay = Math.min(30000, Math.pow(2, this.reconnectAttempts) * 1000);
        const jitter = Math.random() * 1000;
        const delay = baseDelay + jitter;

        console.log(`[Chat] Reconnecting in ${Math.round(delay / 1000)}s (attempt ${this.reconnectAttempts})`);

        this.reconnectTimer = setTimeout(() => {
            if (this.token && (!this.ws || this.ws.readyState !== WebSocket.OPEN)) {
                this.connect(this.token).catch(err => {
                    console.error('[Chat] Reconnect failed:', err);
                });
            }
        }, delay);
    }

    send(type, payload) {
        const message = { type, payload, timestamp: Date.now() };

        if (this.ws?.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        } else {
            // Queue messages when disconnected
            this.messageQueue.push(message);
        }
    }

    flushQueue() {
        while (this.messageQueue.length > 0 && this.ws?.readyState === WebSocket.OPEN) {
            const message = this.messageQueue.shift();
            this.ws.send(JSON.stringify(message));
        }
    }

    handleMessage(message) {
        const handler = this.handlers.get(message.type);
        if (handler) {
            handler(message.payload);
        }
    }

    on(type, handler) {
        this.handlers.set(type, handler);
    }

    off(type) {
        this.handlers.delete(type);
    }

    isConnected() {
        return this.ws?.readyState === WebSocket.OPEN;
    }
}

// ============================================================================
// State Management
// ============================================================================

class ChatStore extends State {
    constructor() {
        super({
            user: null,
            conversations: [],
            activeConversation: null,
            messages: [],
            onlineUsers: [],
            typingUsers: [],
            isConnected: false,
            isLoading: false,
            error: null
        });

        this.ws = new ChatWebSocket('wss://chat.example.com/ws');
        this.setupWebSocket();
        this.typingTimeout = null;
    }

    setupWebSocket() {
        this.ws.on('message', (msg) => this.handleNewMessage(msg));
        this.ws.on('typing', (data) => this.handleTyping(data));
        this.ws.on('presence', (data) => this.handlePresence(data));
        this.ws.on('read', (data) => this.handleReadReceipt(data));
        this.ws.on('error', (data) => this.handleError(data));
    }

    async login(email, password) {
        this.setState({ isLoading: true, error: null });
        try {
            const response = await Http.post('/api/auth/login', { email, password });
            const { user, token } = response;

            Storage.set('chat-token', token);
            Storage.set('chat-user', user);

            await this.ws.connect(token);

            this.setState({ user, isConnected: true, isLoading: false });
            await this.loadConversations();

            return user;
        } catch (error) {
            this.setState({ isLoading: false, error: error.message });
            throw error;
        }
    }

    logout() {
        this.ws.disconnect();
        Storage.remove('chat-token');
        Storage.remove('chat-user');
        this.setState({
            user: null,
            conversations: [],
            messages: [],
            isConnected: false,
            error: null
        });
    }

    async loadConversations() {
        try {
            const conversations = await Http.get('/api/conversations');
            this.setState({ conversations });
        } catch (error) {
            this.setState({ error: error.message });
        }
    }

    async selectConversation(conversationId) {
        this.setState({ isLoading: true, error: null });
        try {
            const messages = await Http.get(`/api/conversations/${encodeURIComponent(conversationId)}/messages`);

            this.setState({
                activeConversation: conversationId,
                messages,
                isLoading: false
            });

            // Mark as read
            this.ws.send('read', { conversationId });
        } catch (error) {
            this.setState({ isLoading: false, error: error.message });
        }
    }

    sendMessage(content, type = MessageType.TEXT) {
        const { activeConversation, user } = this.state;
        if (!activeConversation || !content.trim()) return;

        const message = {
            id: generateId(),
            conversationId: activeConversation,
            senderId: user.id,
            content,
            type,
            timestamp: new Date().toISOString(),
            status: 'sending'
        };

        // Optimistic update
        this.setState({
            messages: [...this.state.messages, message]
        });

        // Send via WebSocket
        this.ws.send('message', {
            id: message.id,
            conversationId: activeConversation,
            content,
            type
        });
    }

    async uploadFile(file) {
        const formData = new FormData();
        formData.append('file', file);

        try {
            const response = await Http.post('/api/upload', formData);
            return response.url;
        } catch (error) {
            this.setState({ error: error.message });
            throw error;
        }
    }

    sendTypingIndicator(isTyping) {
        const { activeConversation } = this.state;
        if (!activeConversation) return;

        this.ws.send('typing', {
            conversationId: activeConversation,
            isTyping
        });
    }

    handleNewMessage(message) {
        const { activeConversation, messages, conversations } = this.state;

        // Update messages if in active conversation
        if (message.conversationId === activeConversation) {
            // Check if this is an update to an existing message (by id)
            const existingIndex = messages.findIndex(m => m.id === message.id);
            if (existingIndex >= 0) {
                const updatedMessages = [...messages];
                updatedMessages[existingIndex] = { ...updatedMessages[existingIndex], ...message, status: 'sent' };
                this.setState({ messages: updatedMessages });
            } else {
                this.setState({
                    messages: [...messages, message]
                });
            }
        }

        // Update conversation preview
        const updatedConversations = conversations.map(conv =>
            conv.id === message.conversationId
                ? {
                    ...conv,
                    lastMessage: message,
                    unreadCount: conv.id === activeConversation ? 0 : (conv.unreadCount || 0) + 1
                }
                : conv
        );

        this.setState({ conversations: updatedConversations });

        // Show notification
        this.showNotification(message);
    }

    handleTyping(data) {
        const { typingUsers } = this.state;
        const { userId, conversationId, isTyping } = data;

        if (isTyping) {
            if (!typingUsers.some(u => u.id === userId && u.conversationId === conversationId)) {
                this.setState({
                    typingUsers: [...typingUsers, { id: userId, conversationId }]
                });
            }
        } else {
            this.setState({
                typingUsers: typingUsers.filter(u => !(u.id === userId && u.conversationId === conversationId))
            });
        }
    }

    handlePresence(data) {
        const { onlineUsers } = this.state;
        const { userId, status } = data;

        if (status === UserStatus.ONLINE) {
            if (!onlineUsers.includes(userId)) {
                this.setState({ onlineUsers: [...onlineUsers, userId] });
            }
        } else if (status === UserStatus.OFFLINE) {
            this.setState({
                onlineUsers: onlineUsers.filter(id => id !== userId)
            });
        }
    }

    handleReadReceipt(data) {
        const { messages } = this.state;
        const { messageId, readBy } = data;

        this.setState({
            messages: messages.map(msg =>
                msg.id === messageId
                    ? { ...msg, readBy: [...(msg.readBy || []), readBy] }
                    : msg
            )
        });
    }

    handleError(data) {
        console.error('[Chat] Server error:', data);
        this.setState({ error: data.message || 'An error occurred' });
    }

    showNotification(message) {
        if (typeof window === 'undefined' || !('Notification' in window)) return;
        if (Notification.permission !== 'granted') return;
        if (document.hasFocus()) return;
        if (message.senderId === this.state.user?.id) return;

        new Notification('New Message', {
            body: message.content.substring(0, 100),
            icon: '/chat-icon.png',
            tag: message.id
        });
    }
}

// ============================================================================
// Components
// ============================================================================

class ConversationList extends Component {
    render() {
        const { conversations, activeId, onlineUsers } = this.props;

        return `
            <div class="conversation-list">
                <div class="list-header">
                    <h2>Messages</h2>
                    <button class="btn-new-chat" data-action="new-chat">+</button>
                </div>
                <div class="list-search">
                    <input type="search" placeholder="Search conversations..." data-action="search-conversations" />
                </div>
                <div class="list-items">
                    ${conversations.map(conv => {
                        const isOnline = conv.participants?.some(p => onlineUsers.includes(p.id)) || false;
                        const isActive = conv.id === activeId;

                        return `
                            <div class="conversation-item ${isActive ? 'active' : ''}"
                                 data-action="select-conversation"
                                 data-conversation-id="${escapeAttr(conv.id)}">
                                <div class="avatar ${isOnline ? 'online' : ''}">
                                    <img src="${escapeAttr(conv.avatar || '/default-avatar.png')}" alt="${escapeAttr(conv.name)}" />
                                </div>
                                <div class="conv-info">
                                    <div class="conv-name">${escapeHtml(conv.name)}</div>
                                    <div class="conv-preview">${escapeHtml(conv.lastMessage?.content || '')}</div>
                                </div>
                                <div class="conv-meta">
                                    <div class="conv-time">${escapeHtml(formatTime(conv.lastMessage?.timestamp))}</div>
                                    ${conv.unreadCount > 0 ? `<div class="unread-badge">${conv.unreadCount}</div>` : ''}
                                </div>
                            </div>
                        `;
                    }).join('')}
                </div>
            </div>
        `;
    }
}

class MessageBubble extends Component {
    render() {
        const { message, isOwn, showAvatar } = this.props;

        const renderContent = () => {
            switch (message.type) {
                case MessageType.IMAGE:
                    return `<img src="${escapeAttr(message.content)}" class="message-image" alt="Image" loading="lazy" />`;
                case MessageType.FILE:
                    return `<a href="${escapeAttr(message.content)}" class="message-file" download>📎 ${escapeHtml(message.fileName || 'File')}</a>`;
                default:
                    return `<p>${escapeHtml(message.content)}</p>`;
            }
        };

        return `
            <div class="message ${isOwn ? 'own' : 'other'}">
                ${!isOwn && showAvatar ? `
                    <div class="message-avatar">
                        <img src="${escapeAttr(message.sender?.avatar || '/default-avatar.png')}" alt="" />
                    </div>
                ` : ''}
                <div class="message-content">
                    ${renderContent()}
                    <div class="message-meta">
                        <span class="message-time">${escapeHtml(formatTime(message.timestamp))}</span>
                        ${isOwn ? `
                            <span class="message-status">
                                ${message.status === 'sending' ? '⏳' :
                                  message.readBy?.length > 0 ? '✓✓' : '✓'}
                            </span>
                        ` : ''}
                    </div>
                </div>
            </div>
        `;
    }
}

class MessageList extends Component {
    render() {
        const { messages, currentUserId, typingUsers } = this.props;

        let lastSenderId = null;

        return `
            <div class="message-list">
                ${messages.map((message) => {
                    const isOwn = message.senderId === currentUserId;
                    const showAvatar = message.senderId !== lastSenderId;
                    lastSenderId = message.senderId;

                    return new MessageBubble({ message, isOwn, showAvatar }).render();
                }).join('')}

                ${typingUsers.length > 0 ? `
                    <div class="typing-indicator">
                        <span class="typing-dots">
                            <span></span><span></span><span></span>
                        </span>
                        <span class="typing-text">
                            ${typingUsers.length === 1 ? 'typing...' : `${typingUsers.length} people typing...`}
                        </span>
                    </div>
                ` : ''}
            </div>
        `;
    }
}

class MessageInput extends Component {
    render() {
        return `
            <form class="message-input" data-action="submit-message">
                <label class="attach-btn">
                    📎
                    <input type="file" hidden data-action="file-upload" />
                </label>
                <input
                    type="text"
                    class="input-field"
                    name="message"
                    placeholder="Type a message..."
                    data-action="message-input"
                    autocomplete="off"
                />
                <button type="button" class="emoji-btn" data-action="emoji-picker">😊</button>
                <button type="submit" class="send-btn">➤</button>
            </form>
        `;
    }
}

class ChatHeader extends Component {
    render() {
        const { conversation, isOnline, typingUsers } = this.props;

        if (!conversation) return '';

        return `
            <div class="chat-header">
                <div class="header-info">
                    <div class="avatar ${isOnline ? 'online' : ''}">
                        <img src="${escapeAttr(conversation.avatar || '/default-avatar.png')}" alt="" />
                    </div>
                    <div class="header-text">
                        <div class="header-name">${escapeHtml(conversation.name)}</div>
                        <div class="header-status">
                            ${typingUsers.length > 0
                                ? 'typing...'
                                : isOnline ? 'Online' : 'Offline'
                            }
                        </div>
                    </div>
                </div>
                <div class="header-actions">
                    <button class="btn-call" data-action="call">📞</button>
                    <button class="btn-video" data-action="video-call">📹</button>
                    <button class="btn-info" data-action="info">ℹ️</button>
                </div>
            </div>
        `;
    }
}

// ============================================================================
// App
// ============================================================================

class ChatApp extends Component {
    constructor() {
        super();
        this.store = new ChatStore();
        this.store.subscribe(() => this.render());
        this.typingTimeout = null;
        this.isTyping = false;

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

        switch (action) {
            case 'select-conversation':
                this.store.selectConversation(target.dataset.conversationId);
                break;
            case 'new-chat':
                console.log('New chat clicked');
                break;
            case 'emoji-picker':
                console.log('Emoji picker clicked');
                break;
            case 'call':
            case 'video-call':
            case 'info':
                console.log(`${action} clicked`);
                break;
        }
    }

    handleSubmit(event) {
        const form = event.target.closest('[data-action="submit-message"]');
        if (form) {
            event.preventDefault();
            const input = form.querySelector('[name="message"]');
            if (input?.value.trim()) {
                this.store.sendMessage(input.value.trim());
                input.value = '';
                this.stopTyping();
            }
            return;
        }

        const loginForm = event.target.closest('[data-action="login"]');
        if (loginForm) {
            event.preventDefault();
            const formData = new FormData(loginForm);
            this.store.login(formData.get('email'), formData.get('password'));
        }
    }

    handleInput(event) {
        const target = event.target;
        if (target.dataset.action === 'message-input') {
            this.startTyping();
        }
    }

    handleChange(event) {
        const target = event.target;
        if (target.dataset.action === 'file-upload' && target.files?.[0]) {
            this.handleFileUpload(target.files[0]);
            target.value = '';
        }
    }

    startTyping() {
        if (!this.isTyping) {
            this.isTyping = true;
            this.store.sendTypingIndicator(true);
        }

        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
            this.stopTyping();
        }, 2000);
    }

    stopTyping() {
        if (this.isTyping) {
            this.isTyping = false;
            this.store.sendTypingIndicator(false);
        }
        clearTimeout(this.typingTimeout);
    }

    async handleFileUpload(file) {
        try {
            const url = await this.store.uploadFile(file);
            const type = file.type.startsWith('image/') ? MessageType.IMAGE : MessageType.FILE;
            this.store.sendMessage(url, type);
        } catch (error) {
            console.error('File upload failed:', error);
        }
    }

    render() {
        const {
            user, conversations, activeConversation, messages,
            onlineUsers, typingUsers, isConnected, error
        } = this.store.state;

        let html;

        if (!user) {
            html = this.renderLogin();
        } else {
            const currentConversation = conversations.find(c => c.id === activeConversation);
            const isOnline = currentConversation?.participants?.some(p => onlineUsers.includes(p.id)) || false;
            const activeTypingUsers = typingUsers.filter(u => u.conversationId === activeConversation);

            html = `
                <div class="chat-app ${isConnected ? 'connected' : 'disconnected'}">
                    ${error ? `<div class="error-banner">${escapeHtml(error)}</div>` : ''}

                    ${new ConversationList({
                        conversations,
                        activeId: activeConversation,
                        onlineUsers
                    }).render()}

                    <div class="chat-main">
                        ${activeConversation ? `
                            ${new ChatHeader({
                                conversation: currentConversation,
                                isOnline,
                                typingUsers: activeTypingUsers
                            }).render()}

                            ${new MessageList({
                                messages,
                                currentUserId: user.id,
                                typingUsers: activeTypingUsers
                            }).render()}

                            ${new MessageInput().render()}
                        ` : `
                            <div class="no-chat-selected">
                                <p>Select a conversation to start chatting</p>
                            </div>
                        `}
                    </div>
                </div>
            `;
        }

        if (this.container) {
            this.container.innerHTML = html;
        }

        return html;
    }

    renderLogin() {
        return `
            <div class="login-page">
                <div class="login-card">
                    <h1>Chat App</h1>
                    <form data-action="login">
                        <input type="email" name="email" placeholder="Email" required />
                        <input type="password" name="password" placeholder="Password" required />
                        <button type="submit">Login</button>
                    </form>
                </div>
            </div>
        `;
    }
}

// ============================================================================
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: ChatApp
});

// Request notification permission
if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
}

app.mount();

export { ChatApp, ChatStore, escapeHtml, escapeAttr, generateId };
