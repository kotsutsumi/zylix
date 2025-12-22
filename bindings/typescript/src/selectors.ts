/**
 * Zylix Test Framework - Selector Builders
 */

import type { Selector } from './types.js';

/**
 * Create a selector by test ID
 */
export function byTestId(id: string): Selector {
    return { testId: id };
}

/**
 * Create a selector by accessibility ID
 */
export function byAccessibilityId(id: string): Selector {
    return { accessibilityId: id };
}

/**
 * Create a selector by exact text
 */
export function byText(text: string): Selector {
    return { text };
}

/**
 * Create a selector by text containing
 */
export function byTextContains(text: string): Selector {
    return { textContains: text };
}

/**
 * Create a selector by XPath
 */
export function byXPath(xpath: string): Selector {
    return { xpath };
}

/**
 * Create a selector by CSS (web only)
 */
export function byCss(selector: string): Selector {
    return { css: selector };
}

/**
 * Create a selector by iOS class chain
 */
export function byClassChain(chain: string): Selector {
    return { classChain: chain };
}

/**
 * Create a selector by iOS predicate string
 */
export function byPredicate(predicate: string): Selector {
    return { predicate };
}

/**
 * Create a selector by Android UIAutomator
 */
export function byUIAutomator(selector: string): Selector {
    return { uiAutomator: selector };
}

/**
 * Create a selector by accessibility role (macOS)
 */
export function byRole(role: string, title?: string): Selector {
    return { role, title };
}

/**
 * Convert selector to WebDriver format
 */
export function toWebDriverSelector(selector: Selector): { using: string; value: string } {
    if (selector.testId) {
        return { using: 'css selector', value: `[data-testid="${selector.testId}"]` };
    }
    if (selector.accessibilityId) {
        return { using: 'accessibility id', value: selector.accessibilityId };
    }
    if (selector.text) {
        return { using: 'link text', value: selector.text };
    }
    if (selector.textContains) {
        return { using: 'partial link text', value: selector.textContains };
    }
    if (selector.xpath) {
        return { using: 'xpath', value: selector.xpath };
    }
    if (selector.css) {
        return { using: 'css selector', value: selector.css };
    }
    if (selector.classChain) {
        return { using: '-ios class chain', value: selector.classChain };
    }
    if (selector.predicate) {
        return { using: '-ios predicate string', value: selector.predicate };
    }
    if (selector.uiAutomator) {
        return { using: '-android uiautomator', value: selector.uiAutomator };
    }
    if (selector.role) {
        let predicate = `role == '${selector.role}'`;
        if (selector.title) {
            predicate += ` AND title == '${selector.title}'`;
        }
        return { using: 'predicate string', value: predicate };
    }

    throw new Error('Invalid selector: no valid strategy found');
}
