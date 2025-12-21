// Chat - Advanced Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - WebSocket real-time messaging
// - User presence
// - File attachments
// - Push notifications
// - Typing indicators

import { ZylixApp, Component, State, Router, Http, WebSocket, Storage } from 'zylix';

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
    }

    connect(token) {
        return new Promise((resolve, reject) => {
            this.ws = new window.WebSocket(`${this.url}?token=${token}`);

            this.ws.onopen = () => {
                console.log('[Chat] Connected');
                this.reconnectAttempts = 0;
                this.flushQueue();
                resolve();
            };

            this.ws.onclose = () => {
                console.log('[Chat] Disconnected');
                this.scheduleReconnect();
            };

            this.ws.onerror = (error) => {
                console.error('[Chat] Error:', error);
                reject(error);
            };

            this.ws.onmessage = (event) => {
                const message = JSON.parse(event.data);
                this.handleMessage(message);
            };
        });
    }

    disconnect() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }

    scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) return;

        this.reconnectAttempts++;
        const delay = Math.min(30000, Math.pow(2, this.reconnectAttempts) * 1000);

        setTimeout(() => {
            if (this.ws?.readyState !== window.WebSocket.OPEN) {
                const token = Storage.get('chat-token');
                if (token) this.connect(token);
            }
        }, delay);
    }

    send(type, payload) {
        const message = { type, payload, timestamp: Date.now() };

        if (this.ws?.readyState === window.WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        } else {
            this.messageQueue.push(message);
        }
    }

    flushQueue() {
        while (this.messageQueue.length > 0) {
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
            isLoading: false
        });

        this.ws = new ChatWebSocket('wss://chat.example.com/ws');
        this.setupWebSocket();
    }

    setupWebSocket() {
        this.ws.on('message', (msg) => this.handleNewMessage(msg));
        this.ws.on('typing', (data) => this.handleTyping(data));
        this.ws.on('presence', (data) => this.handlePresence(data));
        this.ws.on('read', (data) => this.handleReadReceipt(data));
    }

    async login(email, password) {
        this.setState({ isLoading: true });
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
            this.setState({ isLoading: false });
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
            isConnected: false
        });
    }

    async loadConversations() {
        const conversations = await Http.get('/api/conversations');
        this.setState({ conversations });
    }

    async selectConversation(conversationId) {
        this.setState({ isLoading: true });
        const messages = await Http.get(`/api/conversations/${conversationId}/messages`);

        this.setState({
            activeConversation: conversationId,
            messages,
            isLoading: false
        });

        // Mark as read
        this.ws.send('read', { conversationId });
    }

    sendMessage(content, type = MessageType.TEXT) {
        const { activeConversation, user } = this.state;
        if (!activeConversation || !content.trim()) return;

        const message = {
            id: Date.now(),
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
            conversationId: activeConversation,
            content,
            type
        });
    }

    async uploadFile(file) {
        const formData = new FormData();
        formData.append('file', file);

        const response = await Http.post('/api/upload', formData);
        return response.url;
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
            this.setState({
                messages: [...messages, message]
            });
        }

        // Update conversation preview
        const updatedConversations = conversations.map(conv =>
            conv.id === message.conversationId
                ? { ...conv, lastMessage: message, unreadCount: conv.unreadCount + 1 }
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
            if (!typingUsers.some(u => u.id === userId)) {
                this.setState({
                    typingUsers: [...typingUsers, { id: userId, conversationId }]
                });
            }
        } else {
            this.setState({
                typingUsers: typingUsers.filter(u => u.id !== userId)
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

    showNotification(message) {
        if (!('Notification' in window)) return;
        if (Notification.permission !== 'granted') return;
        if (document.hasFocus()) return;

        new Notification('New Message', {
            body: message.content,
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
        const { conversations, activeId, onlineUsers, onSelect } = this.props;

        return `
            <div class="conversation-list">
                <div class="list-header">
                    <h2>Messages</h2>
                    <button class="btn-new-chat" onclick="startNewChat()">+</button>
                </div>
                <div class="list-search">
                    <input type="search" placeholder="Search conversations..." />
                </div>
                <div class="list-items">
                    ${conversations.map(conv => {
                        const isOnline = conv.participants.some(p => onlineUsers.includes(p.id));
                        const isActive = conv.id === activeId;

                        return `
                            <div class="conversation-item ${isActive ? 'active' : ''}"
                                 onclick="selectConversation('${conv.id}')">
                                <div class="avatar ${isOnline ? 'online' : ''}">
                                    <img src="${conv.avatar}" alt="${conv.name}" />
                                </div>
                                <div class="conv-info">
                                    <div class="conv-name">${conv.name}</div>
                                    <div class="conv-preview">${conv.lastMessage?.content || ''}</div>
                                </div>
                                <div class="conv-meta">
                                    <div class="conv-time">${formatTime(conv.lastMessage?.timestamp)}</div>
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

        return `
            <div class="message ${isOwn ? 'own' : 'other'}">
                ${!isOwn && showAvatar ? `
                    <div class="message-avatar">
                        <img src="${message.sender?.avatar}" alt="" />
                    </div>
                ` : ''}
                <div class="message-content">
                    ${message.type === MessageType.IMAGE
                        ? `<img src="${message.content}" class="message-image" />`
                        : message.type === MessageType.FILE
                            ? `<a href="${message.content}" class="message-file">📎 ${message.fileName}</a>`
                            : `<p>${message.content}</p>`
                    }
                    <div class="message-meta">
                        <span class="message-time">${formatTime(message.timestamp)}</span>
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
                ${messages.map((message, index) => {
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
    constructor(props) {
        super(props);
        this.state = {
            text: '',
            isTyping: false
        };
        this.typingTimeout = null;
    }

    handleInput(e) {
        const text = e.target.value;
        this.setState({ text });

        // Typing indicator
        if (!this.state.isTyping) {
            this.props.onTyping(true);
            this.setState({ isTyping: true });
        }

        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
            this.props.onTyping(false);
            this.setState({ isTyping: false });
        }, 2000);
    }

    handleSubmit(e) {
        e.preventDefault();
        if (!this.state.text.trim()) return;

        this.props.onSend(this.state.text);
        this.setState({ text: '', isTyping: false });
        this.props.onTyping(false);
    }

    async handleFileUpload(e) {
        const file = e.target.files[0];
        if (!file) return;

        const url = await this.props.onUpload(file);
        const type = file.type.startsWith('image/') ? MessageType.IMAGE : MessageType.FILE;
        this.props.onSend(url, type);
    }

    render() {
        return `
            <form class="message-input" onsubmit="handleMessageSubmit(event)">
                <label class="attach-btn">
                    📎
                    <input type="file" hidden onchange="handleFileUpload(event)" />
                </label>
                <input
                    type="text"
                    class="input-field"
                    placeholder="Type a message..."
                    value="${this.state.text}"
                    oninput="handleMessageInput(event)"
                />
                <button type="button" class="emoji-btn" onclick="showEmojiPicker()">😊</button>
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
                        <img src="${conversation.avatar}" alt="" />
                    </div>
                    <div class="header-text">
                        <div class="header-name">${conversation.name}</div>
                        <div class="header-status">
                            ${typingUsers.length > 0
                                ? 'typing...'
                                : isOnline ? 'Online' : 'Offline'
                            }
                        </div>
                    </div>
                </div>
                <div class="header-actions">
                    <button class="btn-call">📞</button>
                    <button class="btn-video">📹</button>
                    <button class="btn-info">ℹ️</button>
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
    }

    render() {
        const {
            user, conversations, activeConversation, messages,
            onlineUsers, typingUsers, isConnected
        } = this.store.state;

        if (!user) {
            return this.renderLogin();
        }

        const currentConversation = conversations.find(c => c.id === activeConversation);
        const isOnline = currentConversation?.participants.some(p => onlineUsers.includes(p.id));
        const activeTypingUsers = typingUsers.filter(u => u.conversationId === activeConversation);

        return `
            <div class="chat-app ${isConnected ? 'connected' : 'disconnected'}">
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

                        ${new MessageInput({
                            onSend: (content, type) => this.store.sendMessage(content, type),
                            onTyping: (isTyping) => this.store.sendTypingIndicator(isTyping),
                            onUpload: (file) => this.store.uploadFile(file)
                        }).render()}
                    ` : `
                        <div class="no-chat-selected">
                            <p>Select a conversation to start chatting</p>
                        </div>
                    `}
                </div>
            </div>
        `;
    }

    renderLogin() {
        return `
            <div class="login-page">
                <div class="login-card">
                    <h1>Chat App</h1>
                    <form onsubmit="handleLogin(event)">
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
// Utilities
// ============================================================================

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
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: ChatApp
});

// Request notification permission
if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
}

app.mount();

export { ChatApp, ChatStore };
