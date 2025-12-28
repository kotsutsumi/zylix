/**
 * Zylix Testing Library
 *
 * A lightweight testing library for Zylix components inspired by
 * @testing-library/react. Provides utilities for rendering components,
 * querying the DOM, firing events, and making assertions.
 */

// =============================================================================
// Types
// =============================================================================

export interface RenderOptions {
  container?: HTMLElement;
  baseElement?: HTMLElement;
  wrapper?: (props: { children: unknown }) => unknown;
}

export interface RenderResult {
  container: HTMLElement;
  baseElement: HTMLElement;
  debug: (element?: HTMLElement) => void;
  rerender: (element: unknown) => void;
  unmount: () => void;
  asFragment: () => DocumentFragment;
}

export interface QueryOptions {
  exact?: boolean;
  normalizer?: (text: string) => string;
  selector?: string;
}

export interface WaitForOptions {
  timeout?: number;
  interval?: number;
  onTimeout?: (error: Error) => Error;
}

export interface FireEventOptions {
  bubbles?: boolean;
  cancelable?: boolean;
  composed?: boolean;
}

// =============================================================================
// DOM Utilities
// =============================================================================

let container: HTMLElement | null = null;

function getDocument(): Document {
  if (typeof document === 'undefined') {
    throw new Error('Testing library requires a DOM environment');
  }
  return document;
}

function createContainer(): HTMLElement {
  const doc = getDocument();
  const div = doc.createElement('div');
  div.setAttribute('data-testid', 'zylix-testing-root');
  doc.body.appendChild(div);
  return div;
}

function cleanupContainer(el: HTMLElement): void {
  if (el.parentNode) {
    el.parentNode.removeChild(el);
  }
}

// =============================================================================
// Render Function
// =============================================================================

// Simple VDOM to DOM renderer (simplified for testing)
function createElement(vnode: unknown): Node {
  if (vnode == null || vnode === false) {
    return document.createTextNode('');
  }

  if (typeof vnode === 'string' || typeof vnode === 'number') {
    return document.createTextNode(String(vnode));
  }

  if (Array.isArray(vnode)) {
    const fragment = document.createDocumentFragment();
    vnode.forEach(v => fragment.appendChild(createElement(v)));
    return fragment;
  }

  const node = vnode as { type: unknown; props: Record<string, unknown>; children: unknown[] };

  if (typeof node.type === 'function') {
    const result = (node.type as Function)(node.props || {});
    return createElement(result);
  }

  const element = document.createElement(node.type as string);

  const props = node.props || {};
  for (const [key, value] of Object.entries(props)) {
    if (key === 'children') continue;
    if (key.startsWith('on') && typeof value === 'function') {
      element.addEventListener(key.slice(2).toLowerCase(), value as EventListener);
    } else if (key === 'style' && typeof value === 'object') {
      Object.assign(element.style, value);
    } else if (key === 'className') {
      element.className = value as string;
    } else if (key === 'ref' && typeof value === 'object') {
      (value as { current: HTMLElement }).current = element;
    } else if (key === 'dangerouslySetInnerHTML') {
      element.innerHTML = (value as { __html: string }).__html;
    } else if (typeof value === 'boolean') {
      if (value) {
        element.setAttribute(key, '');
      }
    } else if (value != null) {
      element.setAttribute(key, String(value));
    }
  }

  const children = node.children || [];
  children.forEach((child: unknown) => {
    if (child != null) {
      element.appendChild(createElement(child));
    }
  });

  return element;
}

/**
 * Render a Zylix component for testing
 */
export function render(element: unknown, options: RenderOptions = {}): RenderResult {
  const {
    container: customContainer,
    baseElement = getDocument().body,
  } = options;

  // Create or use container
  container = customContainer || createContainer();

  // Render element
  const domElement = createElement(element);
  container.innerHTML = '';
  container.appendChild(domElement);

  return {
    container,
    baseElement,

    debug(el?: HTMLElement) {
      console.log(prettyDOM(el || container!));
    },

    rerender(newElement: unknown) {
      const newDom = createElement(newElement);
      container!.innerHTML = '';
      container!.appendChild(newDom);
    },

    unmount() {
      container!.innerHTML = '';
    },

    asFragment() {
      const fragment = document.createDocumentFragment();
      Array.from(container!.childNodes).forEach(node => {
        fragment.appendChild(node.cloneNode(true));
      });
      return fragment;
    }
  };
}

/**
 * Cleanup rendered components
 */
export function cleanup(): void {
  if (container) {
    cleanupContainer(container);
    container = null;
  }
}

// =============================================================================
// Screen Queries
// =============================================================================

type QueryMethod = (text: string | RegExp, options?: QueryOptions) => HTMLElement | null;
type QueryAllMethod = (text: string | RegExp, options?: QueryOptions) => HTMLElement[];
type GetMethod = (text: string | RegExp, options?: QueryOptions) => HTMLElement;
type GetAllMethod = (text: string | RegExp, options?: QueryOptions) => HTMLElement[];
type FindMethod = (text: string | RegExp, options?: QueryOptions & WaitForOptions) => Promise<HTMLElement>;
type FindAllMethod = (text: string | RegExp, options?: QueryOptions & WaitForOptions) => Promise<HTMLElement[]>;

function matches(element: HTMLElement, text: string | RegExp, options: QueryOptions = {}): boolean {
  const { exact = true, normalizer = (t: string) => t.trim() } = options;

  const elementText = normalizer(element.textContent || '');

  if (text instanceof RegExp) {
    return text.test(elementText);
  }

  const searchText = normalizer(text);
  return exact ? elementText === searchText : elementText.includes(searchText);
}

function queryAllByText(text: string | RegExp, options: QueryOptions = {}): HTMLElement[] {
  if (!container) return [];
  const elements = Array.from(container.querySelectorAll('*')) as HTMLElement[];
  return elements.filter(el => matches(el, text, options));
}

function queryByText(text: string | RegExp, options?: QueryOptions): HTMLElement | null {
  const results = queryAllByText(text, options);
  return results[0] || null;
}

function getByText(text: string | RegExp, options?: QueryOptions): HTMLElement {
  const element = queryByText(text, options);
  if (!element) {
    throw new Error(`Unable to find element with text: ${text}`);
  }
  return element;
}

function getAllByText(text: string | RegExp, options?: QueryOptions): HTMLElement[] {
  const elements = queryAllByText(text, options);
  if (elements.length === 0) {
    throw new Error(`Unable to find any elements with text: ${text}`);
  }
  return elements;
}

function queryAllByRole(role: string, options: QueryOptions & { name?: string | RegExp } = {}): HTMLElement[] {
  if (!container) return [];
  const { name, ...queryOptions } = options;

  let selector = `[role="${role}"]`;

  // Add implicit roles
  const implicitRoles: Record<string, string[]> = {
    button: ['button', 'input[type="button"]', 'input[type="submit"]', 'input[type="reset"]'],
    textbox: ['input:not([type])', 'input[type="text"]', 'input[type="email"]', 'input[type="password"]', 'input[type="search"]', 'input[type="tel"]', 'input[type="url"]', 'textarea'],
    checkbox: ['input[type="checkbox"]'],
    radio: ['input[type="radio"]'],
    link: ['a[href]'],
    heading: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'],
    list: ['ul', 'ol'],
    listitem: ['li'],
    img: ['img[alt]'],
    navigation: ['nav'],
    main: ['main'],
    banner: ['header'],
    contentinfo: ['footer'],
    region: ['section[aria-label]', 'section[aria-labelledby]'],
    form: ['form'],
    search: ['[role="search"]'],
    alert: ['[role="alert"]'],
    dialog: ['dialog', '[role="dialog"]'],
    tab: ['[role="tab"]'],
    tablist: ['[role="tablist"]'],
    tabpanel: ['[role="tabpanel"]'],
    menu: ['[role="menu"]'],
    menuitem: ['[role="menuitem"]'],
    progressbar: ['progress', '[role="progressbar"]'],
    slider: ['input[type="range"]', '[role="slider"]'],
    spinbutton: ['input[type="number"]', '[role="spinbutton"]'],
    switch: ['[role="switch"]'],
    table: ['table'],
    row: ['tr'],
    cell: ['td'],
    columnheader: ['th'],
    rowgroup: ['tbody', 'thead', 'tfoot'],
    grid: ['[role="grid"]'],
    gridcell: ['[role="gridcell"]'],
    tree: ['[role="tree"]'],
    treeitem: ['[role="treeitem"]'],
    separator: ['hr', '[role="separator"]'],
    complementary: ['aside'],
    article: ['article'],
    figure: ['figure'],
  };

  const implicit = implicitRoles[role];
  if (implicit) {
    selector = [selector, ...implicit].join(', ');
  }

  const elements = Array.from(container.querySelectorAll(selector)) as HTMLElement[];

  if (name !== undefined) {
    return elements.filter(el => {
      const accessibleName =
        el.getAttribute('aria-label') ||
        el.getAttribute('title') ||
        el.textContent ||
        (el as HTMLInputElement).value ||
        '';
      return matches({ textContent: accessibleName } as HTMLElement, name, queryOptions);
    });
  }

  return elements;
}

function queryByRole(role: string, options?: QueryOptions & { name?: string | RegExp }): HTMLElement | null {
  const results = queryAllByRole(role, options);
  return results[0] || null;
}

function getByRole(role: string, options?: QueryOptions & { name?: string | RegExp }): HTMLElement {
  const element = queryByRole(role, options);
  if (!element) {
    throw new Error(`Unable to find element with role: ${role}${options?.name ? ` and name: ${options.name}` : ''}`);
  }
  return element;
}

function getAllByRole(role: string, options?: QueryOptions & { name?: string | RegExp }): HTMLElement[] {
  const elements = queryAllByRole(role, options);
  if (elements.length === 0) {
    throw new Error(`Unable to find any elements with role: ${role}`);
  }
  return elements;
}

function queryAllByTestId(testId: string): HTMLElement[] {
  if (!container) return [];
  return Array.from(container.querySelectorAll(`[data-testid="${testId}"]`)) as HTMLElement[];
}

function queryByTestId(testId: string): HTMLElement | null {
  const results = queryAllByTestId(testId);
  return results[0] || null;
}

function getByTestId(testId: string): HTMLElement {
  const element = queryByTestId(testId);
  if (!element) {
    throw new Error(`Unable to find element with data-testid: ${testId}`);
  }
  return element;
}

function getAllByTestId(testId: string): HTMLElement[] {
  const elements = queryAllByTestId(testId);
  if (elements.length === 0) {
    throw new Error(`Unable to find any elements with data-testid: ${testId}`);
  }
  return elements;
}

function queryAllByPlaceholder(text: string | RegExp, options: QueryOptions = {}): HTMLElement[] {
  if (!container) return [];
  const elements = Array.from(container.querySelectorAll('[placeholder]')) as HTMLElement[];
  return elements.filter(el => {
    const placeholder = el.getAttribute('placeholder') || '';
    return matches({ textContent: placeholder } as HTMLElement, text, options);
  });
}

function queryByPlaceholder(text: string | RegExp, options?: QueryOptions): HTMLElement | null {
  const results = queryAllByPlaceholder(text, options);
  return results[0] || null;
}

function getByPlaceholder(text: string | RegExp, options?: QueryOptions): HTMLElement {
  const element = queryByPlaceholder(text, options);
  if (!element) {
    throw new Error(`Unable to find element with placeholder: ${text}`);
  }
  return element;
}

function getAllByPlaceholder(text: string | RegExp, options?: QueryOptions): HTMLElement[] {
  const elements = queryAllByPlaceholder(text, options);
  if (elements.length === 0) {
    throw new Error(`Unable to find any elements with placeholder: ${text}`);
  }
  return elements;
}

function queryAllByLabelText(text: string | RegExp, options: QueryOptions = {}): HTMLElement[] {
  if (!container) return [];
  const labels = Array.from(container.querySelectorAll('label')) as HTMLLabelElement[];
  const elements: HTMLElement[] = [];

  for (const label of labels) {
    if (matches(label, text, options)) {
      const forId = label.getAttribute('for');
      if (forId) {
        const input = container.querySelector(`#${forId}`);
        if (input) elements.push(input as HTMLElement);
      }
      const inputs = label.querySelectorAll('input, select, textarea');
      inputs.forEach(input => elements.push(input as HTMLElement));
    }
  }

  // Also check aria-label
  const ariaElements = Array.from(container.querySelectorAll('[aria-label]')) as HTMLElement[];
  for (const el of ariaElements) {
    const ariaLabel = el.getAttribute('aria-label') || '';
    if (matches({ textContent: ariaLabel } as HTMLElement, text, options)) {
      elements.push(el);
    }
  }

  return elements;
}

function queryByLabelText(text: string | RegExp, options?: QueryOptions): HTMLElement | null {
  const results = queryAllByLabelText(text, options);
  return results[0] || null;
}

function getByLabelText(text: string | RegExp, options?: QueryOptions): HTMLElement {
  const element = queryByLabelText(text, options);
  if (!element) {
    throw new Error(`Unable to find element with label: ${text}`);
  }
  return element;
}

function getAllByLabelText(text: string | RegExp, options?: QueryOptions): HTMLElement[] {
  const elements = queryAllByLabelText(text, options);
  if (elements.length === 0) {
    throw new Error(`Unable to find any elements with label: ${text}`);
  }
  return elements;
}

// Create find* methods (async versions)
async function findByText(text: string | RegExp, options?: QueryOptions & WaitForOptions): Promise<HTMLElement> {
  return waitFor(() => getByText(text, options), options);
}

async function findAllByText(text: string | RegExp, options?: QueryOptions & WaitForOptions): Promise<HTMLElement[]> {
  return waitFor(() => getAllByText(text, options), options);
}

async function findByRole(role: string, options?: QueryOptions & { name?: string | RegExp } & WaitForOptions): Promise<HTMLElement> {
  return waitFor(() => getByRole(role, options), options);
}

async function findAllByRole(role: string, options?: QueryOptions & { name?: string | RegExp } & WaitForOptions): Promise<HTMLElement[]> {
  return waitFor(() => getAllByRole(role, options), options);
}

async function findByTestId(testId: string, options?: WaitForOptions): Promise<HTMLElement> {
  return waitFor(() => getByTestId(testId), options);
}

async function findAllByTestId(testId: string, options?: WaitForOptions): Promise<HTMLElement[]> {
  return waitFor(() => getAllByTestId(testId), options);
}

/**
 * Screen object with all query methods
 */
export const screen = {
  // Text queries
  queryByText,
  queryAllByText,
  getByText,
  getAllByText,
  findByText,
  findAllByText,

  // Role queries
  queryByRole,
  queryAllByRole,
  getByRole,
  getAllByRole,
  findByRole,
  findAllByRole,

  // TestId queries
  queryByTestId,
  queryAllByTestId,
  getByTestId,
  getAllByTestId,
  findByTestId,
  findAllByTestId,

  // Placeholder queries
  queryByPlaceholder,
  queryAllByPlaceholder,
  getByPlaceholder,
  getAllByPlaceholder,

  // Label queries
  queryByLabelText,
  queryAllByLabelText,
  getByLabelText,
  getAllByLabelText,

  // Debug
  debug(element?: HTMLElement) {
    console.log(prettyDOM(element || container));
  }
};

// =============================================================================
// Fire Event
// =============================================================================

function createEvent(eventType: string, options: FireEventOptions & Record<string, unknown> = {}): Event {
  const { bubbles = true, cancelable = true, composed = false, ...eventInit } = options;

  // Mouse events
  if (['click', 'dblclick', 'mousedown', 'mouseup', 'mousemove', 'mouseenter', 'mouseleave', 'mouseover', 'mouseout'].includes(eventType)) {
    return new MouseEvent(eventType, {
      bubbles,
      cancelable,
      composed,
      ...eventInit
    } as MouseEventInit);
  }

  // Keyboard events
  if (['keydown', 'keyup', 'keypress'].includes(eventType)) {
    return new KeyboardEvent(eventType, {
      bubbles,
      cancelable,
      composed,
      ...eventInit
    } as KeyboardEventInit);
  }

  // Input events
  if (['input', 'change'].includes(eventType)) {
    return new InputEvent(eventType, {
      bubbles,
      cancelable,
      composed,
      ...eventInit
    } as InputEventInit);
  }

  // Focus events
  if (['focus', 'blur', 'focusin', 'focusout'].includes(eventType)) {
    return new FocusEvent(eventType, {
      bubbles: eventType === 'focusin' || eventType === 'focusout',
      cancelable: false,
      composed,
      ...eventInit
    } as FocusEventInit);
  }

  // Submit event
  if (eventType === 'submit') {
    return new SubmitEvent(eventType, {
      bubbles,
      cancelable,
      composed,
      ...eventInit
    } as SubmitEventInit);
  }

  // Generic event
  return new Event(eventType, { bubbles, cancelable, composed });
}

/**
 * Fire events on elements
 */
export const fireEvent = Object.assign(
  function fireEvent(element: HTMLElement, event: Event): boolean {
    return element.dispatchEvent(event);
  },
  {
    // Mouse events
    click(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('click', options));
    },
    dblClick(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('dblclick', options));
    },
    mouseDown(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mousedown', options));
    },
    mouseUp(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mouseup', options));
    },
    mouseMove(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mousemove', options));
    },
    mouseEnter(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mouseenter', { ...options, bubbles: false }));
    },
    mouseLeave(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mouseleave', { ...options, bubbles: false }));
    },
    mouseOver(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mouseover', options));
    },
    mouseOut(element: HTMLElement, options?: MouseEventInit) {
      return element.dispatchEvent(createEvent('mouseout', options));
    },

    // Keyboard events
    keyDown(element: HTMLElement, options?: KeyboardEventInit) {
      return element.dispatchEvent(createEvent('keydown', options));
    },
    keyUp(element: HTMLElement, options?: KeyboardEventInit) {
      return element.dispatchEvent(createEvent('keyup', options));
    },
    keyPress(element: HTMLElement, options?: KeyboardEventInit) {
      return element.dispatchEvent(createEvent('keypress', options));
    },

    // Form events
    input(element: HTMLElement, options?: InputEventInit) {
      return element.dispatchEvent(createEvent('input', options));
    },
    change(element: HTMLElement, options?: InputEventInit) {
      return element.dispatchEvent(createEvent('change', options));
    },
    submit(element: HTMLElement, options?: SubmitEventInit) {
      return element.dispatchEvent(createEvent('submit', options));
    },

    // Focus events
    focus(element: HTMLElement, options?: FocusEventInit) {
      element.focus();
      return element.dispatchEvent(createEvent('focus', options));
    },
    blur(element: HTMLElement, options?: FocusEventInit) {
      element.blur();
      return element.dispatchEvent(createEvent('blur', options));
    },

    // Scroll events
    scroll(element: HTMLElement, options?: EventInit) {
      return element.dispatchEvent(createEvent('scroll', options));
    }
  }
);

// =============================================================================
// User Event (Higher-level interactions)
// =============================================================================

/**
 * Simulate user interactions
 */
export const userEvent = {
  /**
   * Type text into an input element
   */
  async type(element: HTMLElement, text: string, options?: { delay?: number }) {
    const { delay = 0 } = options || {};

    element.focus();

    for (const char of text) {
      await new Promise(resolve => setTimeout(resolve, delay));

      fireEvent.keyDown(element, { key: char });
      fireEvent.keyPress(element, { key: char });

      if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
        element.value += char;
        fireEvent.input(element);
      }

      fireEvent.keyUp(element, { key: char });
    }
  },

  /**
   * Clear an input element
   */
  clear(element: HTMLElement) {
    if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
      element.value = '';
      fireEvent.input(element);
      fireEvent.change(element);
    }
  },

  /**
   * Click an element
   */
  click(element: HTMLElement) {
    fireEvent.mouseDown(element);
    fireEvent.mouseUp(element);
    fireEvent.click(element);
  },

  /**
   * Double click an element
   */
  dblClick(element: HTMLElement) {
    fireEvent.mouseDown(element);
    fireEvent.mouseUp(element);
    fireEvent.click(element);
    fireEvent.mouseDown(element);
    fireEvent.mouseUp(element);
    fireEvent.click(element);
    fireEvent.dblClick(element);
  },

  /**
   * Select an option in a select element
   */
  selectOptions(element: HTMLElement, values: string | string[]) {
    const select = element as HTMLSelectElement;
    const valueArray = Array.isArray(values) ? values : [values];

    for (const option of select.options) {
      option.selected = valueArray.includes(option.value);
    }

    fireEvent.change(select);
  },

  /**
   * Tab to next element
   */
  tab(options?: { shift?: boolean }) {
    const focusable = document.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const elements = Array.from(focusable) as HTMLElement[];
    const currentIndex = elements.indexOf(document.activeElement as HTMLElement);

    let nextIndex: number;
    if (options?.shift) {
      nextIndex = currentIndex <= 0 ? elements.length - 1 : currentIndex - 1;
    } else {
      nextIndex = currentIndex >= elements.length - 1 ? 0 : currentIndex + 1;
    }

    elements[nextIndex]?.focus();
  }
};

// =============================================================================
// Async Utilities
// =============================================================================

/**
 * Wait for a condition to be true
 */
export async function waitFor<T>(
  callback: () => T,
  options: WaitForOptions = {}
): Promise<T> {
  const { timeout = 1000, interval = 50, onTimeout } = options;

  const startTime = Date.now();
  let lastError: Error | null = null;

  while (Date.now() - startTime < timeout) {
    try {
      const result = callback();
      return result;
    } catch (error) {
      lastError = error as Error;
      await new Promise(resolve => setTimeout(resolve, interval));
    }
  }

  const timeoutError = new Error(
    `Timed out after ${timeout}ms waiting for condition. Last error: ${lastError?.message}`
  );

  if (onTimeout) {
    throw onTimeout(timeoutError);
  }

  throw timeoutError;
}

/**
 * Wait for an element to be removed from the DOM
 */
export async function waitForElementToBeRemoved(
  callback: () => HTMLElement | HTMLElement[] | null,
  options: WaitForOptions = {}
): Promise<void> {
  const { timeout = 1000, interval = 50 } = options;

  const startTime = Date.now();

  // First, ensure element exists
  const initialElement = callback();
  if (!initialElement || (Array.isArray(initialElement) && initialElement.length === 0)) {
    throw new Error('Element was not present in the DOM');
  }

  while (Date.now() - startTime < timeout) {
    const element = callback();
    if (!element || (Array.isArray(element) && element.length === 0)) {
      return;
    }
    await new Promise(resolve => setTimeout(resolve, interval));
  }

  throw new Error(`Timed out after ${timeout}ms waiting for element to be removed`);
}

// =============================================================================
// Assertions
// =============================================================================

/**
 * Custom matchers for testing
 */
export const expect = (actual: unknown) => ({
  toBe(expected: unknown) {
    if (actual !== expected) {
      throw new Error(`Expected ${JSON.stringify(expected)}, but got ${JSON.stringify(actual)}`);
    }
  },

  toEqual(expected: unknown) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`Expected ${JSON.stringify(expected)}, but got ${JSON.stringify(actual)}`);
    }
  },

  toBeTruthy() {
    if (!actual) {
      throw new Error(`Expected value to be truthy, but got ${JSON.stringify(actual)}`);
    }
  },

  toBeFalsy() {
    if (actual) {
      throw new Error(`Expected value to be falsy, but got ${JSON.stringify(actual)}`);
    }
  },

  toBeNull() {
    if (actual !== null) {
      throw new Error(`Expected null, but got ${JSON.stringify(actual)}`);
    }
  },

  toBeUndefined() {
    if (actual !== undefined) {
      throw new Error(`Expected undefined, but got ${JSON.stringify(actual)}`);
    }
  },

  toBeDefined() {
    if (actual === undefined) {
      throw new Error('Expected value to be defined');
    }
  },

  toBeInTheDocument() {
    const element = actual as HTMLElement;
    if (!element || !document.body.contains(element)) {
      throw new Error('Expected element to be in the document');
    }
  },

  toHaveTextContent(text: string | RegExp) {
    const element = actual as HTMLElement;
    const content = element.textContent || '';
    const matches = text instanceof RegExp ? text.test(content) : content.includes(text);
    if (!matches) {
      throw new Error(`Expected element to have text content "${text}", but got "${content}"`);
    }
  },

  toHaveValue(value: string | number) {
    const element = actual as HTMLInputElement;
    if (element.value !== String(value)) {
      throw new Error(`Expected element to have value "${value}", but got "${element.value}"`);
    }
  },

  toBeVisible() {
    const element = actual as HTMLElement;
    const style = window.getComputedStyle(element);
    const isVisible = style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      style.opacity !== '0';
    if (!isVisible) {
      throw new Error('Expected element to be visible');
    }
  },

  toBeDisabled() {
    const element = actual as HTMLButtonElement | HTMLInputElement;
    if (!element.disabled) {
      throw new Error('Expected element to be disabled');
    }
  },

  toBeEnabled() {
    const element = actual as HTMLButtonElement | HTMLInputElement;
    if (element.disabled) {
      throw new Error('Expected element to be enabled');
    }
  },

  toHaveAttribute(name: string, value?: string) {
    const element = actual as HTMLElement;
    const attr = element.getAttribute(name);
    if (attr === null) {
      throw new Error(`Expected element to have attribute "${name}"`);
    }
    if (value !== undefined && attr !== value) {
      throw new Error(`Expected attribute "${name}" to be "${value}", but got "${attr}"`);
    }
  },

  toHaveClass(...classNames: string[]) {
    const element = actual as HTMLElement;
    const missing = classNames.filter(c => !element.classList.contains(c));
    if (missing.length > 0) {
      throw new Error(`Expected element to have classes: ${missing.join(', ')}`);
    }
  },

  toHaveStyle(styles: Record<string, string>) {
    const element = actual as HTMLElement;
    const computedStyle = window.getComputedStyle(element);
    for (const [prop, value] of Object.entries(styles)) {
      const actual = computedStyle.getPropertyValue(prop);
      if (actual !== value) {
        throw new Error(`Expected style "${prop}" to be "${value}", but got "${actual}"`);
      }
    }
  },

  toHaveFocus() {
    if (actual !== document.activeElement) {
      throw new Error('Expected element to have focus');
    }
  },

  toContainElement(element: HTMLElement) {
    const parent = actual as HTMLElement;
    if (!parent.contains(element)) {
      throw new Error('Expected element to contain the target element');
    }
  },

  toHaveLength(length: number) {
    const arr = actual as unknown[];
    if (arr.length !== length) {
      throw new Error(`Expected length ${length}, but got ${arr.length}`);
    }
  },

  toThrow(message?: string | RegExp) {
    let threw = false;
    let error: Error | null = null;
    try {
      (actual as Function)();
    } catch (e) {
      threw = true;
      error = e as Error;
    }
    if (!threw) {
      throw new Error('Expected function to throw');
    }
    if (message) {
      const errorMessage = error?.message || '';
      const matches = message instanceof RegExp ? message.test(errorMessage) : errorMessage.includes(message);
      if (!matches) {
        throw new Error(`Expected error message to match "${message}", but got "${errorMessage}"`);
      }
    }
  },

  not: {
    toBe(expected: unknown) {
      if (actual === expected) {
        throw new Error(`Expected ${JSON.stringify(actual)} not to be ${JSON.stringify(expected)}`);
      }
    },

    toBeInTheDocument() {
      const element = actual as HTMLElement;
      if (element && document.body.contains(element)) {
        throw new Error('Expected element not to be in the document');
      }
    },

    toBeNull() {
      if (actual === null) {
        throw new Error('Expected value not to be null');
      }
    },

    toBeVisible() {
      const element = actual as HTMLElement;
      const style = window.getComputedStyle(element);
      const isVisible = style.display !== 'none' &&
        style.visibility !== 'hidden' &&
        style.opacity !== '0';
      if (isVisible) {
        throw new Error('Expected element not to be visible');
      }
    },

    toHaveClass(...classNames: string[]) {
      const element = actual as HTMLElement;
      const present = classNames.filter(c => element.classList.contains(c));
      if (present.length > 0) {
        throw new Error(`Expected element not to have classes: ${present.join(', ')}`);
      }
    }
  }
});

// =============================================================================
// Pretty DOM
// =============================================================================

function prettyDOM(element: HTMLElement | null, maxLength: number = 7000): string {
  if (!element) return '';

  const output = element.outerHTML;
  if (output.length > maxLength) {
    return output.slice(0, maxLength) + '...';
  }
  return output;
}

// =============================================================================
// Store Mocking
// =============================================================================

export interface MockStoreOptions<T> {
  state: T;
  actions?: Record<string, (state: T, ...args: unknown[]) => T>;
  selectors?: Record<string, (state: T) => unknown>;
}

/**
 * Create a mock store for testing
 */
export function createMockStore<T>(options: MockStoreOptions<T>) {
  let state = { ...options.state };
  const listeners = new Set<(state: T) => void>();
  const actionHistory: Array<{ action: string; args: unknown[]; prevState: T; nextState: T }> = [];

  const store = {
    getState: () => state,

    setState: (newState: Partial<T> | ((s: T) => Partial<T>)) => {
      const prevState = state;
      state = {
        ...state,
        ...(typeof newState === 'function' ? newState(state) : newState)
      };
      listeners.forEach(fn => fn(state));
    },

    subscribe: (fn: (state: T) => void) => {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },

    actions: {} as Record<string, (...args: unknown[]) => void>,

    selectors: {} as Record<string, unknown>,

    // Testing utilities
    getActionHistory: () => [...actionHistory],
    clearActionHistory: () => { actionHistory.length = 0; },
    reset: () => {
      state = { ...options.state };
      actionHistory.length = 0;
      listeners.forEach(fn => fn(state));
    }
  };

  // Create actions
  for (const [name, fn] of Object.entries(options.actions || {})) {
    store.actions[name] = (...args: unknown[]) => {
      const prevState = state;
      state = fn(state, ...args);
      actionHistory.push({ action: name, args, prevState, nextState: state });
      listeners.forEach(listener => listener(state));
    };
  }

  // Create selectors
  for (const [name, fn] of Object.entries(options.selectors || {})) {
    Object.defineProperty(store.selectors, name, {
      get: () => fn(state)
    });
  }

  return store;
}

// =============================================================================
// API Mocking
// =============================================================================

export interface MockResponse {
  status?: number;
  statusText?: string;
  headers?: Record<string, string>;
  body?: unknown;
  delay?: number;
}

export interface MockHandler {
  method: string;
  url: string | RegExp;
  response: MockResponse | ((request: Request) => MockResponse | Promise<MockResponse>);
}

/**
 * Create a mock server for testing API calls
 */
export function createMockServer() {
  const handlers: MockHandler[] = [];
  const originalFetch = globalThis.fetch;

  const mockFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    const method = init?.method || 'GET';

    for (const handler of handlers) {
      const urlMatches = handler.url instanceof RegExp
        ? handler.url.test(url)
        : url.includes(handler.url);

      if (urlMatches && handler.method.toUpperCase() === method.toUpperCase()) {
        const response = typeof handler.response === 'function'
          ? await handler.response(new Request(input, init))
          : handler.response;

        if (response.delay) {
          await new Promise(resolve => setTimeout(resolve, response.delay));
        }

        return new Response(
          response.body ? JSON.stringify(response.body) : null,
          {
            status: response.status || 200,
            statusText: response.statusText || 'OK',
            headers: {
              'Content-Type': 'application/json',
              ...response.headers
            }
          }
        );
      }
    }

    // No handler found, call original fetch or throw
    throw new Error(`No mock handler found for ${method} ${url}`);
  };

  return {
    get(url: string | RegExp, response: MockResponse | MockHandler['response']) {
      handlers.push({ method: 'GET', url, response });
      return this;
    },

    post(url: string | RegExp, response: MockResponse | MockHandler['response']) {
      handlers.push({ method: 'POST', url, response });
      return this;
    },

    put(url: string | RegExp, response: MockResponse | MockHandler['response']) {
      handlers.push({ method: 'PUT', url, response });
      return this;
    },

    patch(url: string | RegExp, response: MockResponse | MockHandler['response']) {
      handlers.push({ method: 'PATCH', url, response });
      return this;
    },

    delete(url: string | RegExp, response: MockResponse | MockHandler['response']) {
      handlers.push({ method: 'DELETE', url, response });
      return this;
    },

    use(handler: MockHandler) {
      handlers.push(handler);
      return this;
    },

    listen() {
      globalThis.fetch = mockFetch as typeof fetch;
    },

    close() {
      globalThis.fetch = originalFetch;
    },

    resetHandlers() {
      handlers.length = 0;
    },

    getHandlers() {
      return [...handlers];
    }
  };
}

// =============================================================================
// Playwright Helpers
// =============================================================================

export interface ZylixPlaywrightHelpers {
  waitForWasmReady: () => Promise<void>;
  getState: (storeName?: string) => Promise<unknown>;
  dispatch: (action: string, payload?: unknown) => Promise<void>;
  getPerformanceMetrics: () => Promise<{
    fps: number;
    renderCount: number;
    avgRenderTime: number;
  }>;
}

/**
 * Create Playwright helpers for Zylix testing
 */
export function createPlaywrightHelpers(page: {
  evaluate: <T>(fn: string | Function, ...args: unknown[]) => Promise<T>;
  waitForFunction: (fn: string | Function, options?: { timeout?: number }) => Promise<unknown>;
}): ZylixPlaywrightHelpers {
  return {
    async waitForWasmReady() {
      await page.waitForFunction(
        () => (window as any).__ZYLIX_WASM_READY__ === true,
        { timeout: 10000 }
      );
    },

    async getState(storeName?: string) {
      return page.evaluate((name) => {
        const win = window as any;
        if (name && win.__ZYLIX_STORES__) {
          return win.__ZYLIX_STORES__[name]?.getState();
        }
        return win.__ZYLIX_STORE__?.getState();
      }, storeName);
    },

    async dispatch(action: string, payload?: unknown) {
      return page.evaluate(
        ({ action, payload }) => {
          const win = window as any;
          const store = win.__ZYLIX_STORE__;
          if (store?.actions?.[action]) {
            store.actions[action](payload);
          }
        },
        { action, payload }
      );
    },

    async getPerformanceMetrics() {
      return page.evaluate(() => {
        const win = window as any;
        const devtools = win.__ZYLIX_DEVTOOLS__;
        if (devtools) {
          return devtools.getPerformanceMetrics();
        }
        return { fps: 0, renderCount: 0, avgRenderTime: 0 };
      });
    }
  };
}

// =============================================================================
// Test Utilities
// =============================================================================

/**
 * Create a test wrapper with common setup/teardown
 */
export function createTestWrapper(setup?: () => void, teardown?: () => void) {
  return {
    beforeEach() {
      setup?.();
    },
    afterEach() {
      cleanup();
      teardown?.();
    }
  };
}

/**
 * Act - wrap updates in act() for consistency
 */
export async function act(callback: () => void | Promise<void>): Promise<void> {
  await callback();
  // Allow microtasks to complete
  await new Promise(resolve => setTimeout(resolve, 0));
}

// =============================================================================
// Default Export
// =============================================================================

export default {
  render,
  cleanup,
  screen,
  fireEvent,
  userEvent,
  waitFor,
  waitForElementToBeRemoved,
  expect,
  createMockStore,
  createMockServer,
  createPlaywrightHelpers,
  createTestWrapper,
  act
};
