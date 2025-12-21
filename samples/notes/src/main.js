// Notes - Advanced Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - Rich text editing
// - Folder organization
// - Full-text search
// - Cloud sync
// - Offline support

import { ZylixApp, Component, State, Router, Http, Storage, Sync } from 'zylix';

// ============================================================================
// Types
// ============================================================================

const NoteFormat = {
    PLAIN: 'plain',
    MARKDOWN: 'markdown',
    RICH: 'rich'
};

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
        return `note_${crypto.randomUUID()}`;
    }
    // Fallback for older browsers
    return `note_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

function debounce(fn, ms) {
    let timeout;
    return (...args) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn(...args), ms);
    };
}

// ============================================================================
// Rich Text Editor
// ============================================================================

class RichTextEditor {
    constructor(element) {
        this.element = element;
        this.element.contentEditable = true;
        this.element.classList.add('rich-editor');
        this.setupToolbar();
    }

    setupToolbar() {
        this.toolbar = document.createElement('div');
        this.toolbar.className = 'editor-toolbar';
        this.toolbar.innerHTML = `
            <button data-command="bold" title="Bold (Ctrl+B)"><b>B</b></button>
            <button data-command="italic" title="Italic (Ctrl+I)"><i>I</i></button>
            <button data-command="underline" title="Underline (Ctrl+U)"><u>U</u></button>
            <button data-command="strikeThrough" title="Strikethrough"><s>S</s></button>
            <span class="separator"></span>
            <button data-command="insertUnorderedList" title="Bullet List">•</button>
            <button data-command="insertOrderedList" title="Numbered List">1.</button>
            <button data-command="indent" title="Indent">→</button>
            <button data-command="outdent" title="Outdent">←</button>
            <span class="separator"></span>
            <button data-command="formatBlock" data-value="h1" title="Heading 1">H1</button>
            <button data-command="formatBlock" data-value="h2" title="Heading 2">H2</button>
            <button data-command="formatBlock" data-value="h3" title="Heading 3">H3</button>
            <button data-command="formatBlock" data-value="p" title="Paragraph">¶</button>
            <span class="separator"></span>
            <button data-command="createLink" title="Insert Link">🔗</button>
            <button data-command="insertImage" title="Insert Image">🖼️</button>
            <button data-command="insertHorizontalRule" title="Horizontal Rule">—</button>
            <span class="separator"></span>
            <button data-command="undo" title="Undo (Ctrl+Z)">↩️</button>
            <button data-command="redo" title="Redo (Ctrl+Y)">↪️</button>
        `;

        this.element.parentNode.insertBefore(this.toolbar, this.element);

        this.toolbar.querySelectorAll('button').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const command = btn.dataset.command;
                const value = btn.dataset.value;

                if (command === 'createLink') {
                    const url = prompt('Enter URL:');
                    if (url) document.execCommand(command, false, url);
                } else if (command === 'insertImage') {
                    const url = prompt('Enter image URL:');
                    if (url) document.execCommand(command, false, url);
                } else {
                    document.execCommand(command, false, value || null);
                }

                this.element.focus();
            });
        });
    }

    getContent() {
        return this.element.innerHTML;
    }

    setContent(html) {
        this.element.innerHTML = html;
    }

    getPlainText() {
        return this.element.textContent;
    }
}

// ============================================================================
// Search Engine
// ============================================================================

class SearchEngine {
    constructor() {
        this.index = new Map();
    }

    indexNote(note) {
        const terms = this.tokenize(note.title + ' ' + note.content);
        terms.forEach(term => {
            if (!this.index.has(term)) {
                this.index.set(term, new Set());
            }
            this.index.get(term).add(note.id);
        });
    }

    removeNote(noteId) {
        this.index.forEach((noteIds, term) => {
            noteIds.delete(noteId);
            if (noteIds.size === 0) {
                this.index.delete(term);
            }
        });
    }

    search(query) {
        const terms = this.tokenize(query);
        if (terms.length === 0) return [];

        const results = new Map();

        terms.forEach(term => {
            const matchingNotes = this.findMatches(term);
            matchingNotes.forEach(noteId => {
                results.set(noteId, (results.get(noteId) || 0) + 1);
            });
        });

        return Array.from(results.entries())
            .sort((a, b) => b[1] - a[1])
            .map(([noteId]) => noteId);
    }

    findMatches(term) {
        const matches = new Set();

        this.index.forEach((noteIds, indexedTerm) => {
            if (indexedTerm.includes(term)) {
                noteIds.forEach(id => matches.add(id));
            }
        });

        return matches;
    }

    tokenize(text) {
        return text
            .toLowerCase()
            .replace(/<[^>]+>/g, ' ')
            .split(/\W+/)
            .filter(term => term.length > 2);
    }
}

// ============================================================================
// State Management
// ============================================================================

class NotesStore extends State {
    constructor() {
        super({
            notes: [],
            folders: [],
            activeNote: null,
            activeFolder: null,
            searchQuery: '',
            searchResults: [],
            syncStatus: 'idle',
            isOffline: !navigator.onLine,
            pendingSync: []
        });

        this.searchEngine = new SearchEngine();
        this.autoSave = debounce((note) => this.saveNote(note), 1000);

        this.loadFromStorage();
        this.setupSync();
        this.setupOfflineDetection();
    }

    loadFromStorage() {
        const notes = Storage.get('notes-data') || [];
        const folders = Storage.get('notes-folders') || [
            { id: 'default', name: 'All Notes', icon: '📝' },
            { id: 'favorites', name: 'Favorites', icon: '⭐' },
            { id: 'archive', name: 'Archive', icon: '📦' },
            { id: 'trash', name: 'Trash', icon: '🗑️' }
        ];

        notes.forEach(note => this.searchEngine.indexNote(note));

        this.setState({ notes, folders });
    }

    saveToStorage() {
        Storage.set('notes-data', this.state.notes);
        Storage.set('notes-folders', this.state.folders);
    }

    setupSync() {
        // Periodic sync
        setInterval(() => this.syncNotes(), 60000);

        // Sync on visibility change
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) {
                this.syncNotes();
            }
        });
    }

    setupOfflineDetection() {
        window.addEventListener('online', () => {
            this.setState({ isOffline: false });
            this.syncPendingChanges();
        });

        window.addEventListener('offline', () => {
            this.setState({ isOffline: true });
        });
    }

    // Notes CRUD
    createNote(folderId = 'default') {
        const note = {
            id: generateId(),
            title: 'Untitled Note',
            content: '',
            format: NoteFormat.RICH,
            folderId,
            tags: [],
            isFavorite: false,
            isArchived: false,
            isTrashed: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            syncedAt: null
        };

        this.setState({
            notes: [note, ...this.state.notes],
            activeNote: note.id
        });

        this.searchEngine.indexNote(note);
        this.saveToStorage();
        this.queueSync(note);

        return note;
    }

    saveNote(note) {
        const updatedNote = {
            ...note,
            updatedAt: new Date().toISOString()
        };

        this.setState({
            notes: this.state.notes.map(n =>
                n.id === note.id ? updatedNote : n
            )
        });

        this.searchEngine.removeNote(note.id);
        this.searchEngine.indexNote(updatedNote);
        this.saveToStorage();
        this.queueSync(updatedNote);
    }

    deleteNote(noteId) {
        // Move to trash first
        const note = this.state.notes.find(n => n.id === noteId);
        if (!note) return;

        if (note.isTrashed) {
            // Permanent delete
            this.setState({
                notes: this.state.notes.filter(n => n.id !== noteId),
                activeNote: this.state.activeNote === noteId ? null : this.state.activeNote
            });
            this.searchEngine.removeNote(noteId);
        } else {
            // Move to trash
            this.saveNote({ ...note, isTrashed: true });
        }

        this.saveToStorage();
    }

    restoreNote(noteId) {
        const note = this.state.notes.find(n => n.id === noteId);
        if (note) {
            this.saveNote({ ...note, isTrashed: false });
        }
    }

    toggleFavorite(noteId) {
        const note = this.state.notes.find(n => n.id === noteId);
        if (note) {
            this.saveNote({ ...note, isFavorite: !note.isFavorite });
        }
    }

    archiveNote(noteId) {
        const note = this.state.notes.find(n => n.id === noteId);
        if (note) {
            this.saveNote({ ...note, isArchived: !note.isArchived });
        }
    }

    // Folders
    createFolder(name, icon = '📁') {
        const folder = {
            id: generateId(),
            name,
            icon,
            createdAt: new Date().toISOString()
        };

        this.setState({
            folders: [...this.state.folders, folder]
        });

        this.saveToStorage();
        return folder;
    }

    renameFolder(folderId, name) {
        this.setState({
            folders: this.state.folders.map(f =>
                f.id === folderId ? { ...f, name } : f
            )
        });
        this.saveToStorage();
    }

    deleteFolder(folderId) {
        // Move notes to default folder
        this.setState({
            notes: this.state.notes.map(n =>
                n.folderId === folderId ? { ...n, folderId: 'default' } : n
            ),
            folders: this.state.folders.filter(f => f.id !== folderId)
        });
        this.saveToStorage();
    }

    // Search
    search(query) {
        if (!query.trim()) {
            this.setState({ searchQuery: '', searchResults: [] });
            return;
        }

        const resultIds = this.searchEngine.search(query);
        this.setState({
            searchQuery: query,
            searchResults: resultIds
        });
    }

    // Navigation
    selectNote(noteId) {
        this.setState({ activeNote: noteId });
    }

    selectFolder(folderId) {
        this.setState({
            activeFolder: folderId,
            activeNote: null
        });
    }

    // Sync
    queueSync(note) {
        if (this.state.isOffline) {
            this.setState({
                pendingSync: [...this.state.pendingSync, note.id]
            });
        } else {
            this.syncNote(note);
        }
    }

    async syncNote(note) {
        this.setState({ syncStatus: 'syncing' });

        try {
            await Http.put(`/api/notes/${note.id}`, note);
            this.setState({
                syncStatus: 'synced',
                notes: this.state.notes.map(n =>
                    n.id === note.id
                        ? { ...n, syncedAt: new Date().toISOString() }
                        : n
                )
            });
        } catch (error) {
            console.error('Sync failed:', error);
            this.setState({ syncStatus: 'error' });
            this.queueSync(note);
        }
    }

    async syncNotes() {
        if (this.state.isOffline) return;

        this.setState({ syncStatus: 'syncing' });

        try {
            const remoteNotes = await Http.get('/api/notes');

            // Merge logic
            const mergedNotes = this.mergeNotes(this.state.notes, remoteNotes);

            this.setState({
                notes: mergedNotes,
                syncStatus: 'synced'
            });

            this.saveToStorage();
        } catch (error) {
            console.error('Sync failed:', error);
            this.setState({ syncStatus: 'error' });
        }
    }

    async syncPendingChanges() {
        const { pendingSync, notes } = this.state;

        for (const noteId of pendingSync) {
            const note = notes.find(n => n.id === noteId);
            if (note) {
                await this.syncNote(note);
            }
        }

        this.setState({ pendingSync: [] });
    }

    mergeNotes(local, remote) {
        const merged = new Map();

        // Add all local notes
        local.forEach(note => merged.set(note.id, note));

        // Merge with remote (remote wins if newer)
        remote.forEach(remoteNote => {
            const localNote = merged.get(remoteNote.id);
            if (!localNote || new Date(remoteNote.updatedAt) > new Date(localNote.updatedAt)) {
                merged.set(remoteNote.id, remoteNote);
            }
        });

        return Array.from(merged.values());
    }

    // Getters
    getFilteredNotes() {
        const { notes, activeFolder, searchQuery, searchResults } = this.state;

        let filtered = notes.filter(n => !n.isTrashed);

        if (searchQuery) {
            filtered = filtered.filter(n => searchResults.includes(n.id));
        } else if (activeFolder === 'favorites') {
            filtered = filtered.filter(n => n.isFavorite);
        } else if (activeFolder === 'archive') {
            filtered = filtered.filter(n => n.isArchived);
        } else if (activeFolder === 'trash') {
            filtered = notes.filter(n => n.isTrashed);
        } else if (activeFolder && activeFolder !== 'default') {
            filtered = filtered.filter(n => n.folderId === activeFolder);
        }

        return filtered.sort((a, b) =>
            new Date(b.updatedAt) - new Date(a.updatedAt)
        );
    }

    getActiveNote() {
        return this.state.notes.find(n => n.id === this.state.activeNote);
    }
}

// ============================================================================
// Components
// ============================================================================

class Sidebar extends Component {
    render() {
        const { folders, activeFolder, notes, onSelect, onCreate } = this.props;

        const getCounts = () => {
            const counts = { default: 0, favorites: 0, archive: 0, trash: 0 };

            notes.forEach(note => {
                if (note.isTrashed) counts.trash++;
                else if (note.isArchived) counts.archive++;
                else if (note.isFavorite) counts.favorites++;
                counts.default++;
            });

            return counts;
        };

        const counts = getCounts();

        return `
            <aside class="sidebar">
                <div class="sidebar-header">
                    <h1>Notes</h1>
                    <button class="btn-new-note" data-action="create-note">+</button>
                </div>

                <div class="sidebar-search">
                    <input type="search" placeholder="Search notes..."
                           data-action="search" />
                </div>

                <nav class="folder-list">
                    ${folders.map(folder => `
                        <div class="folder-item ${activeFolder === folder.id ? 'active' : ''}"
                             data-action="select-folder" data-folder-id="${escapeAttr(folder.id)}">
                            <span class="folder-icon">${escapeHtml(folder.icon)}</span>
                            <span class="folder-name">${escapeHtml(folder.name)}</span>
                            <span class="folder-count">${counts[folder.id] || 0}</span>
                        </div>
                    `).join('')}
                </nav>

                <button class="btn-new-folder" data-action="create-folder">
                    + New Folder
                </button>
            </aside>
        `;
    }
}

class NoteList extends Component {
    render() {
        const { notes, activeNote, onSelect } = this.props;

        if (notes.length === 0) {
            return `
                <div class="note-list-empty">
                    <p>No notes yet</p>
                    <button data-action="create-note">Create your first note</button>
                </div>
            `;
        }

        return `
            <div class="note-list">
                ${notes.map(note => `
                    <div class="note-item ${activeNote === note.id ? 'active' : ''}"
                         data-action="select-note" data-note-id="${escapeAttr(note.id)}">
                        <div class="note-title">
                            ${note.isFavorite ? '⭐ ' : ''}${escapeHtml(note.title)}
                        </div>
                        <div class="note-preview">
                            ${escapeHtml(this.getPreview(note.content))}
                        </div>
                        <div class="note-meta">
                            <span class="note-date">${escapeHtml(formatDate(note.updatedAt))}</span>
                            ${note.tags.map(tag => `<span class="note-tag">#${escapeHtml(tag)}</span>`).join('')}
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    getPreview(content) {
        const text = content.replace(/<[^>]+>/g, '');
        return text.substring(0, 100) + (text.length > 100 ? '...' : '');
    }
}

class NoteEditor extends Component {
    render() {
        const { note, onSave, onDelete, syncStatus } = this.props;

        if (!note) {
            return `
                <div class="editor-empty">
                    <p>Select a note or create a new one</p>
                </div>
            `;
        }

        const escapedId = escapeAttr(note.id);

        return `
            <div class="note-editor">
                <div class="editor-header">
                    <input type="text" class="note-title-input"
                           value="${escapeAttr(note.title)}"
                           data-action="title-change"
                           placeholder="Note title" />
                    <div class="editor-actions">
                        <button data-action="toggle-favorite" data-note-id="${escapedId}"
                                class="${note.isFavorite ? 'active' : ''}">
                            ${note.isFavorite ? '⭐' : '☆'}
                        </button>
                        <button data-action="archive-note" data-note-id="${escapedId}">📦</button>
                        <button data-action="delete-note" data-note-id="${escapedId}">🗑️</button>
                    </div>
                </div>

                <div class="editor-tags">
                    ${note.tags.map(tag => `
                        <span class="tag">
                            #${escapeHtml(tag)}
                            <button data-action="remove-tag" data-note-id="${escapedId}" data-tag="${escapeAttr(tag)}">×</button>
                        </span>
                    `).join('')}
                    <input type="text" class="tag-input"
                           placeholder="Add tag..."
                           data-action="add-tag" data-note-id="${escapedId}" />
                </div>

                <div id="rich-editor" class="editor-content">${note.content}</div>

                <div class="editor-footer">
                    <span class="word-count">${this.getWordCount(note.content)} words</span>
                    <span class="sync-status ${escapeAttr(syncStatus)}">${this.getSyncText(syncStatus)}</span>
                    <span class="last-edited">Edited ${escapeHtml(formatDate(note.updatedAt))}</span>
                </div>
            </div>
        `;
    }

    getWordCount(content) {
        const text = content.replace(/<[^>]+>/g, '');
        return text.split(/\s+/).filter(w => w.length > 0).length;
    }

    getSyncText(status) {
        switch (status) {
            case 'syncing': return '⏳ Syncing...';
            case 'synced': return '✓ Saved';
            case 'error': return '⚠️ Sync failed';
            default: return '';
        }
    }
}

// ============================================================================
// App
// ============================================================================

class NotesApp extends Component {
    constructor() {
        super();
        this.store = new NotesStore();
        this.store.subscribe(() => this.render());
        this.boundHandleClick = this.handleClick.bind(this);
        this.boundHandleInput = this.handleInput.bind(this);
        this.boundHandleKeydown = this.handleKeydown.bind(this);
    }

    mount(container) {
        this.container = container;
        this.render();
        this.attachEventListeners();
    }

    attachEventListeners() {
        if (!this.container) return;

        this.container.addEventListener('click', this.boundHandleClick);
        this.container.addEventListener('input', this.boundHandleInput);
        this.container.addEventListener('keydown', this.boundHandleKeydown);
    }

    handleClick(event) {
        const target = event.target.closest('[data-action]');
        if (!target) return;

        const action = target.dataset.action;
        const noteId = target.dataset.noteId;
        const folderId = target.dataset.folderId;

        switch (action) {
            case 'create-note':
                this.store.createNote(this.store.state.activeFolder);
                break;
            case 'create-folder':
                const folderName = prompt('Enter folder name:');
                if (folderName) {
                    this.store.createFolder(folderName);
                }
                break;
            case 'select-folder':
                this.store.selectFolder(folderId);
                break;
            case 'select-note':
                this.store.selectNote(noteId);
                break;
            case 'toggle-favorite':
                this.store.toggleFavorite(noteId);
                break;
            case 'archive-note':
                this.store.archiveNote(noteId);
                break;
            case 'delete-note':
                this.store.deleteNote(noteId);
                break;
            case 'remove-tag':
                const tagToRemove = target.dataset.tag;
                const noteForTag = this.store.state.notes.find(n => n.id === noteId);
                if (noteForTag) {
                    this.store.saveNote({
                        ...noteForTag,
                        tags: noteForTag.tags.filter(t => t !== tagToRemove)
                    });
                }
                break;
        }
    }

    handleInput(event) {
        const target = event.target;
        const action = target.dataset.action;

        if (action === 'search') {
            this.store.search(target.value);
        } else if (action === 'title-change') {
            const note = this.store.getActiveNote();
            if (note) {
                this.store.autoSave({
                    ...note,
                    title: target.value
                });
            }
        }
    }

    handleKeydown(event) {
        const target = event.target;
        if (target.dataset.action === 'add-tag' && event.key === 'Enter') {
            event.preventDefault();
            const tag = target.value.trim();
            const noteId = target.dataset.noteId;
            if (tag && noteId) {
                const note = this.store.state.notes.find(n => n.id === noteId);
                if (note && !note.tags.includes(tag)) {
                    this.store.saveNote({
                        ...note,
                        tags: [...note.tags, tag]
                    });
                }
                target.value = '';
            }
        }
    }

    componentDidMount() {
        // Initialize rich text editor
        const editorEl = document.getElementById('rich-editor');
        if (editorEl && !this.editor) {
            this.editor = new RichTextEditor(editorEl);
            editorEl.addEventListener('input', () => {
                const note = this.store.getActiveNote();
                if (note) {
                    this.store.autoSave({
                        ...note,
                        content: this.editor.getContent()
                    });
                }
            });
        }
    }

    render() {
        const { folders, activeFolder, syncStatus, isOffline } = this.store.state;
        const notes = this.store.getFilteredNotes();
        const activeNote = this.store.getActiveNote();

        return `
            <div class="notes-app ${isOffline ? 'offline' : ''}">
                ${isOffline ? '<div class="offline-banner">You are offline. Changes will sync when connected.</div>' : ''}

                ${new Sidebar({
                    folders,
                    activeFolder,
                    notes: this.store.state.notes
                }).render()}

                <div class="notes-main">
                    ${new NoteList({
                        notes,
                        activeNote: this.store.state.activeNote
                    }).render()}
                </div>

                <div class="notes-editor">
                    ${new NoteEditor({
                        note: activeNote,
                        syncStatus
                    }).render()}
                </div>
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
    const diff = now - date;

    if (diff < 60000) return 'just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} min ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} hours ago`;
    if (diff < 604800000) return `${Math.floor(diff / 86400000)} days ago`;

    return date.toLocaleDateString();
}

// ============================================================================
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: NotesApp
});

app.mount();

export { NotesApp, NotesStore, escapeHtml, escapeAttr, generateId };
