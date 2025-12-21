/**
 * Zylix TypeScript Definitions
 */

// Core module
export function init(wasmSource: string | ArrayBuffer, options?: {
    imports?: Record<string, unknown>;
}): Promise<void>;
export function deinit(): void;
export function isInitialized(): boolean;
export function getWasm(): WebAssembly.Instance['exports'] | null;
export function getMemory(): WebAssembly.Memory | null;
export function alloc(size: number): number;
export function freeScratch(): void;
export function readString(ptr: number, len: number): string;
export function writeString(str: string): { ptr: number; len: number };
export function getMemoryUsed(): number;
export function getMemoryPeak(): number;
export function getAbiVersion(): number;

// State module
export namespace state {
    const Events: {
        readonly INCREMENT: number;
        readonly DECREMENT: number;
        readonly RESET: number;
    };

    function dispatch(eventType: number, payload?: ArrayBuffer | Uint8Array | null): number;
    function getCounter(): number;
    function getStateVersion(): number;
    function increment(): number;
    function decrement(): number;
    function reset(): number;

    interface Store<T> {
        get(): T;
        set(value: T): void;
        subscribe(fn: (value: T) => void): () => void;
    }

    function createStore<T>(initialValue: T): Store<T>;
}

// Re-export state items at top level
export const Events: typeof state.Events;
export function dispatch(eventType: number, payload?: ArrayBuffer | Uint8Array | null): number;
export function getCounter(): number;
export function getStateVersion(): number;
export function increment(): number;
export function decrement(): number;
export function reset(): number;
export function createStore<T>(initialValue: T): state.Store<T>;

// Todo module
export namespace todo {
    const Filter: {
        readonly ALL: 0;
        readonly ACTIVE: 1;
        readonly COMPLETED: 2;
    };

    const TodoEvents: {
        readonly ADD: number;
        readonly TOGGLE: number;
        readonly REMOVE: number;
        readonly TOGGLE_ALL: number;
        readonly CLEAR_COMPLETED: number;
        readonly FILTER_ALL: number;
        readonly FILTER_ACTIVE: number;
        readonly FILTER_COMPLETED: number;
    };

    function init(): void;
    function add(text: string): number;
    function remove(id: number): boolean;
    function toggle(id: number): boolean;
    function toggleAll(): void;
    function clearCompleted(): number;
    function setFilter(filter: number): void;
    function getFilter(): number;
    function getCount(): number;
    function getActiveCount(): number;
    function getCompletedCount(): number;
    function getVisibleCount(): number;
    function getItemText(id: number): string | null;
    function getItemCompleted(id: number): boolean;
    function updateText(id: number, text: string): boolean;
    function dispatch(callbackId: number): boolean;
    function render(): void;
    function renderAndCommit(): number;

    interface TodoItem {
        id: number;
        text: string;
        completed: boolean;
    }

    function getVisibleItems(): TodoItem[];
    function getAllItems(): TodoItem[];
}

// VDOM module
export namespace vdom {
    const Tag: {
        readonly DIV: number;
        readonly SPAN: number;
        readonly SECTION: number;
        readonly ARTICLE: number;
        readonly HEADER: number;
        readonly FOOTER: number;
        readonly NAV: number;
        readonly MAIN: number;
        readonly H1: number;
        readonly H2: number;
        readonly H3: number;
        readonly H4: number;
        readonly H5: number;
        readonly H6: number;
        readonly P: number;
        readonly BUTTON: number;
        readonly A: number;
        readonly INPUT: number;
        readonly IMG: number;
        readonly UL: number;
        readonly OL: number;
        readonly LI: number;
        readonly FORM: number;
        readonly LABEL: number;
    };

    const PatchType: {
        readonly NONE: number;
        readonly CREATE: number;
        readonly REMOVE: number;
        readonly REPLACE: number;
        readonly UPDATE_PROPS: number;
        readonly UPDATE_TEXT: number;
        readonly REORDER: number;
        readonly INSERT_CHILD: number;
        readonly REMOVE_CHILD: number;
    };

    function init(): void;
    function reset(): void;
    function createElement(tag: number): number;
    function createText(text: string): number;
    function setClass(nodeId: number, className: string): void;
    function setOnClick(nodeId: number, callbackId: number): void;
    function setText(nodeId: number, text: string): void;
    function setKey(nodeId: number, key: string): void;
    function addChild(parentId: number, childId: number): boolean;
    function setRoot(nodeId: number): void;
    function commit(): number;
    function getPatchCount(): number;

    interface Patch {
        type: number;
        nodeId: number;
        domId: number;
        parentId: number;
        tag: number;
        nodeType: number;
        index: number;
        text?: string;
        className?: string;
        onClick?: number;
        styleId?: number;
    }

    function getPatch(index: number): Patch | null;
    function getPatches(): Patch[];
    function getNodeCount(): number;
    function applyPatches(container: Element, domMap?: Map<number, Element>): Map<number, Element>;
}

// Component module
export namespace component {
    const ComponentType: {
        readonly CONTAINER: number;
        readonly TEXT: number;
        readonly BUTTON: number;
        readonly INPUT: number;
        readonly HEADING: number;
        readonly PARAGRAPH: number;
        readonly LINK: number;
        readonly IMAGE: number;
    };

    const InputType: {
        readonly TEXT: number;
        readonly PASSWORD: number;
        readonly EMAIL: number;
        readonly NUMBER: number;
        readonly CHECKBOX: number;
        readonly RADIO: number;
        readonly SUBMIT: number;
    };

    const EventType: {
        readonly CLICK: number;
        readonly INPUT: number;
        readonly CHANGE: number;
        readonly FOCUS: number;
        readonly BLUR: number;
        readonly SUBMIT: number;
        readonly KEYDOWN: number;
        readonly KEYUP: number;
    };

    const HeadingLevel: {
        readonly H1: number;
        readonly H2: number;
        readonly H3: number;
        readonly H4: number;
        readonly H5: number;
        readonly H6: number;
    };

    function init(): void;
    function reset(): void;
    function createContainer(): number;
    function createText(text: string): number;
    function createButton(label: string): number;
    function createInput(inputType?: number): number;
    function createHeading(level: number, text: string): number;
    function createParagraph(text: string): number;
    function createLink(href: string, label: string): number;
    function createImage(src: string, alt: string): number;
    function addChild(parentId: number, childId: number): boolean;
    function remove(id: number, recursive?: boolean): void;
    function setStyle(id: number, styleId: number): void;
    function setText(id: number, text: string): void;
    function setClass(id: number, className: string): void;
    function setPlaceholder(id: number, placeholder: string): void;
    function setValue(id: number, value: string): void;
    function onClick(id: number, callbackId: number): void;
    function onInput(id: number, callbackId: number): void;
    function onChange(id: number, callbackId: number): void;
    function setDisabled(id: number, disabled: boolean): void;
    function setVisible(id: number, visible: boolean): void;
    function dispatchEvent(id: number, eventType: number): number;
    function getCount(): number;
    function getRoot(): number;
    function render(rootId: number): void;
    function getRenderCommandCount(): number;
}

// Version
export const VERSION: string;

// Quick start helper
export function quickStart(wasmPath: string, options?: {
    initTodo?: boolean;
    initVdom?: boolean;
    initComponent?: boolean;
}): Promise<void>;
