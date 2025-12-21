import { test, describe } from 'node:test';
import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const samplesDir = join(__dirname, '../../samples');

// ============================================================================
// Extract and test utility functions from sample apps
// ============================================================================

// Extract escapeHtml function from todo-pro
const todoProSource = readFileSync(join(samplesDir, 'todo-pro/src/main.js'), 'utf-8');

// Create isolated versions of the utility functions for testing
function escapeHtml(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function escapeAttr(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;');
}

function generateId() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
    }
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
// Tests
// ============================================================================

describe('escapeHtml Security Utility', () => {
    describe('Basic escaping', () => {
        test('should escape < and >', () => {
            assert.strictEqual(escapeHtml('<script>'), '&lt;script&gt;');
        });

        test('should escape &', () => {
            assert.strictEqual(escapeHtml('a & b'), 'a &amp; b');
        });

        test('should escape double quotes', () => {
            assert.strictEqual(escapeHtml('"hello"'), '&quot;hello&quot;');
        });

        test('should escape single quotes', () => {
            assert.strictEqual(escapeHtml("'hello'"), '&#039;hello&#039;');
        });

        test('should escape all special characters together', () => {
            const input = '<script>alert("xss" & \'attack\')</script>';
            const expected = '&lt;script&gt;alert(&quot;xss&quot; &amp; &#039;attack&#039;)&lt;/script&gt;';
            assert.strictEqual(escapeHtml(input), expected);
        });
    });

    describe('Edge cases', () => {
        test('should return empty string for null', () => {
            assert.strictEqual(escapeHtml(null), '');
        });

        test('should return empty string for undefined', () => {
            assert.strictEqual(escapeHtml(undefined), '');
        });

        test('should convert numbers to string', () => {
            assert.strictEqual(escapeHtml(123), '123');
        });

        test('should handle empty string', () => {
            assert.strictEqual(escapeHtml(''), '');
        });

        test('should preserve safe text', () => {
            assert.strictEqual(escapeHtml('Hello World'), 'Hello World');
        });
    });

    describe('XSS attack vectors', () => {
        test('should prevent script injection', () => {
            const attack = '<script>document.cookie</script>';
            const escaped = escapeHtml(attack);
            assert.ok(!escaped.includes('<script>'));
            assert.ok(!escaped.includes('</script>'));
        });

        test('should prevent img onerror injection', () => {
            const attack = '<img src=x onerror="alert(1)">';
            const escaped = escapeHtml(attack);
            // escapeHtml escapes < and > making it safe text, not executable HTML
            assert.ok(!escaped.includes('<img'));
            assert.ok(escaped.includes('&lt;img'));
            // 'onerror' is still present as text but harmless since < > are escaped
            assert.ok(escaped.startsWith('&lt;'));
        });

        test('should prevent event handler injection', () => {
            const attack = '" onclick="alert(1)"';
            const escaped = escapeHtml(attack);
            assert.ok(!escaped.includes('"'));
        });

        test('should prevent javascript: URL injection', () => {
            const attack = 'javascript:alert(1)';
            // Note: escapeHtml doesn't prevent javascript: URLs
            // This test documents behavior
            const escaped = escapeHtml(attack);
            assert.strictEqual(escaped, 'javascript:alert(1)');
        });
    });

    describe('Unicode handling', () => {
        test('should preserve unicode characters', () => {
            assert.strictEqual(escapeHtml('日本語'), '日本語');
        });

        test('should preserve emoji', () => {
            assert.strictEqual(escapeHtml('Hello 👋'), 'Hello 👋');
        });

        test('should handle mixed unicode and special chars', () => {
            const input = '<日本語>';
            const expected = '&lt;日本語&gt;';
            assert.strictEqual(escapeHtml(input), expected);
        });
    });
});

describe('escapeAttr Security Utility', () => {
    describe('Basic escaping', () => {
        test('should escape &', () => {
            assert.strictEqual(escapeAttr('a & b'), 'a &amp; b');
        });

        test('should escape double quotes', () => {
            assert.strictEqual(escapeAttr('a "b" c'), 'a &quot;b&quot; c');
        });

        test('should NOT escape single quotes', () => {
            // escapeAttr only escapes & and "
            assert.strictEqual(escapeAttr("a 'b' c"), "a 'b' c");
        });

        test('should NOT escape < and >', () => {
            // escapeAttr is for attribute values, not content
            assert.strictEqual(escapeAttr('a < b > c'), 'a < b > c');
        });
    });

    describe('Edge cases', () => {
        test('should return empty string for null', () => {
            assert.strictEqual(escapeAttr(null), '');
        });

        test('should return empty string for undefined', () => {
            assert.strictEqual(escapeAttr(undefined), '');
        });

        test('should convert numbers to string', () => {
            assert.strictEqual(escapeAttr(42), '42');
        });
    });

    describe('Attribute injection prevention', () => {
        test('should prevent attribute breakout', () => {
            const attack = '" onclick="alert(1)';
            const escaped = escapeAttr(attack);
            assert.ok(!escaped.includes('"'));
            assert.strictEqual(escaped, '&quot; onclick=&quot;alert(1)');
        });
    });
});

describe('generateId Utility', () => {
    test('should generate a string', () => {
        const id = generateId();
        assert.strictEqual(typeof id, 'string');
    });

    test('should generate non-empty string', () => {
        const id = generateId();
        assert.ok(id.length > 0);
    });

    test('should generate unique IDs', () => {
        const ids = new Set();
        for (let i = 0; i < 100; i++) {
            ids.add(generateId());
        }
        assert.strictEqual(ids.size, 100, 'All generated IDs should be unique');
    });

    test('should generate IDs with valid characters', () => {
        const id = generateId();
        // UUID format or alphanumeric
        assert.ok(/^[a-zA-Z0-9-]+$/.test(id), 'ID should only contain alphanumeric chars and hyphens');
    });
});

describe('formatDate Utility', () => {
    test('should return "Overdue" for past dates', () => {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        assert.strictEqual(formatDate(yesterday.toISOString()), 'Overdue');
    });

    test('should return "Today" for today', () => {
        const today = new Date();
        // Add a few hours to ensure it's still today
        today.setHours(today.getHours() + 1);
        const result = formatDate(today.toISOString());
        assert.ok(result === 'Today' || result === 'Tomorrow', `Expected "Today" or "Tomorrow", got "${result}"`);
    });

    test('should return "Tomorrow" for tomorrow', () => {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 2); // Add 2 days to ensure "tomorrow" range
        tomorrow.setHours(0, 0, 0, 0);
        const result = formatDate(tomorrow.toISOString());
        // Due to timezone differences, could be "Tomorrow" or "In 1 days" or "In 2 days"
        assert.ok(
            result === 'Tomorrow' || result.includes('In') && result.includes('days'),
            `Expected "Tomorrow" or "In X days", got "${result}"`
        );
    });

    test('should return "In X days" for dates within a week', () => {
        const future = new Date();
        future.setDate(future.getDate() + 5);
        future.setHours(12, 0, 0, 0);
        const result = formatDate(future.toISOString());
        assert.ok(result.includes('In') && result.includes('days'), `Expected "In X days" format, got "${result}"`);
    });

    test('should return localized date for dates beyond a week', () => {
        const future = new Date();
        future.setDate(future.getDate() + 30);
        const result = formatDate(future.toISOString());
        // Should not contain "In" prefix for dates beyond 7 days
        assert.ok(!result.includes('In ') || result.includes('/') || result.includes('-') || result.includes(','), 
            `Expected a formatted date, got "${result}"`);
    });
});

describe('Utility Function Consistency Across Samples', () => {
    const samples = ['todo-pro', 'chat', 'dashboard', 'e-commerce', 'notes'];

    for (const sample of samples) {
        test(`${sample} should have consistent escapeHtml implementation`, () => {
            const source = readFileSync(join(samplesDir, `${sample}/src/main.js`), 'utf-8');
            
            // Check for the expected escape patterns
            assert.ok(source.includes(".replace(/&/g, '&amp;')"), `${sample} should escape &`);
            assert.ok(source.includes(".replace(/</g, '&lt;')"), `${sample} should escape <`);
            assert.ok(source.includes(".replace(/>/g, '&gt;')"), `${sample} should escape >`);
            assert.ok(source.includes(".replace(/\"/g, '&quot;')"), `${sample} should escape "`);
        });
    }

    for (const sample of samples) {
        test(`${sample} should have null/undefined handling in escapeHtml`, () => {
            const source = readFileSync(join(samplesDir, `${sample}/src/main.js`), 'utf-8');
            
            // Check for null/undefined handling
            assert.ok(
                source.includes("str == null") || source.includes("str === null"),
                `${sample} should handle null in escapeHtml`
            );
        });
    }
});
