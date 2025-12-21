# Zylix Sample Applications

This directory contains 5 comprehensive sample applications demonstrating real-world Zylix usage across different complexity levels.

## Sample Apps Overview

| App | Level | Key Features |
|-----|-------|--------------|
| **Todo Pro** | Beginner | State management, forms, local storage, dark/light theme |
| **E-Commerce** | Intermediate | Routing, HTTP requests, authentication, shopping cart |
| **Dashboard** | Intermediate | Real-time data, charts, tables, export functionality |
| **Chat** | Advanced | WebSocket, real-time messaging, push notifications |
| **Notes** | Advanced | Rich text editing, folder organization, full-text search, cloud sync |

## Getting Started

Each sample app can be run independently. Navigate to the sample directory and:

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

## Todo Pro (Beginner)

A feature-rich todo application demonstrating core Zylix concepts:

- **State Management**: Reactive state with local storage persistence
- **Form Handling**: Input validation and form submission
- **Categories & Tags**: Organize todos with categories and searchable tags
- **Due Dates**: Set due dates with browser notification reminders
- **Theme Toggle**: Dark and light theme support

```javascript
import { ZylixApp, State, Storage } from 'zylix';

const store = new State({
    todos: Storage.get('todos') || [],
    filter: 'all',
    theme: 'light'
});
```

## E-Commerce (Intermediate)

A complete shopping experience showcasing routing and HTTP integration:

- **Product Catalog**: Browse and search products with filtering
- **Shopping Cart**: Add, remove, and update cart items
- **User Authentication**: Login, register, and session management
- **Order Management**: View order history and track status
- **Responsive Design**: Mobile-first responsive layouts

```javascript
import { Router, Http } from 'zylix';

Router.on('/products/:id', async (params) => {
    const product = await Http.get(`/api/products/${params.id}`);
    render(ProductPage, { product });
});
```

## Dashboard (Intermediate)

A data visualization dashboard with real-time updates:

- **Metric Cards**: Key performance indicators with trend indicators
- **Line Charts**: Time-series data visualization with SVG
- **Bar Charts**: Category comparison charts
- **Data Tables**: Sortable, filterable, paginated tables
- **Export**: CSV export functionality
- **Auto-Refresh**: Periodic data refresh with configurable interval

```javascript
import { State } from 'zylix';

const store = new State({
    metrics: {},
    chartData: []
});

// Auto-refresh every 30 seconds
setInterval(() => store.refreshData(), 30000);
```

## Chat (Advanced)

A real-time messaging application with WebSocket communication:

- **Real-time Messaging**: Instant message delivery via WebSocket
- **User Presence**: Online/offline status indicators
- **Typing Indicators**: "User is typing..." notifications
- **File Attachments**: Image and file sharing
- **Push Notifications**: Browser notifications for new messages
- **Message Status**: Sent, delivered, and read receipts

```javascript
import { WebSocket } from 'zylix';

const ws = new WebSocket('wss://chat.example.com');
ws.on('message', (msg) => handleNewMessage(msg));
ws.send('message', { content: 'Hello!' });
```

## Notes (Advanced)

A feature-rich note-taking application with offline support:

- **Rich Text Editor**: Full formatting with toolbar
- **Folder Organization**: Organize notes into folders
- **Tags**: Tag notes for easy categorization
- **Full-text Search**: Fast search across all notes
- **Cloud Sync**: Automatic sync with conflict resolution
- **Offline Support**: Work offline with pending sync queue

```javascript
import { State, Sync, Storage } from 'zylix';

const store = new State({
    notes: Storage.get('notes') || [],
    syncStatus: 'idle'
});

// Auto-save with debounce
const autoSave = debounce((note) => {
    store.saveNote(note);
    Sync.queue(note);
}, 1000);
```

## Architecture Patterns

### State Management
All apps use the reactive `State` class:
- Immutable state updates
- Subscription-based reactivity
- Local storage integration

### Routing
E-Commerce app demonstrates SPA routing:
- Path parameters (`:id`)
- Route guards
- Navigation history

### API Integration
E-Commerce and Dashboard apps show HTTP patterns:
- RESTful API calls
- Error handling
- Loading states

### Real-time Communication
Chat app demonstrates WebSocket patterns:
- Connection management
- Reconnection with backoff
- Message queuing

### Offline Support
Notes app shows offline-first patterns:
- Service worker integration
- Pending sync queue
- Conflict resolution

## Cross-Platform

These samples are designed to work across all Zylix platforms:
- **Web**: HTML/CSS/JavaScript
- **iOS**: SwiftUI with native components
- **Android**: Jetpack Compose with native components
- **macOS**: AppKit with native components
- **Windows**: WinUI 3 with native components
- **Linux**: GTK4 with native components

## Performance

All samples are optimized for:
- Bundle size < 50KB (gzipped)
- Time to Interactive < 2s on 3G
- 60fps animations
- Lazy loading where applicable

## License

MIT - Part of the Zylix framework
