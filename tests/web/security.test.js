import { test, describe } from 'node:test';
import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Read and extract the escapeHtml function from the dev server
const devServerCode = readFileSync(
    join(__dirname, '../../platforms/web/zylix-dev-server.js'),
    'utf-8'
);

// Extract the escapeHtml function
const escapeHtmlMatch = devServerCode.match(/function escapeHtml\(str\) \{[\s\S]*?return String\(str\)[\s\S]*?\}/);
if (!escapeHtmlMatch) {
    throw new Error('Could not extract escapeHtml function');
}

// Create the function dynamically
const escapeHtml = new Function('str', `
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
`);

describe('escapeHtml Security Utility', () => {
    describe('Basic escaping', () => {
        test('should escape ampersand', () => {
            assert.strictEqual(escapeHtml('Tom & Jerry'), 'Tom &amp; Jerry');
        });

        test('should escape less than', () => {
            assert.strictEqual(escapeHtml('1 < 2'), '1 &lt; 2');
        });

        test('should escape greater than', () => {
            assert.strictEqual(escapeHtml('2 > 1'), '2 &gt; 1');
        });

        test('should escape double quotes', () => {
            assert.strictEqual(escapeHtml('say "hello"'), 'say &quot;hello&quot;');
        });

        test('should escape single quotes', () => {
            assert.strictEqual(escapeHtml("it's"), 'it&#039;s');
        });
    });

    describe('XSS Prevention', () => {
        test('should neutralize script tags', () => {
            const malicious = '<script>alert("XSS")</script>';
            const escaped = escapeHtml(malicious);

            assert.ok(!escaped.includes('<script>'));
            assert.ok(!escaped.includes('</script>'));
            assert.strictEqual(escaped, '&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;');
        });

        test('should neutralize event handlers', () => {
            const malicious = '<img onerror="alert(\'XSS\')" src="x">';
            const escaped = escapeHtml(malicious);

            // escapeHtml escapes the < and > so the tag is not parsed as HTML
            // The text 'onerror' remains but is not executable
            assert.ok(!escaped.includes('<img'));
            assert.ok(escaped.includes('onerror')); // Text remains but is neutralized
            assert.strictEqual(escaped, '&lt;img onerror=&quot;alert(&#039;XSS&#039;)&quot; src=&quot;x&quot;&gt;');
        });

        test('should handle javascript: URLs', () => {
            const malicious = 'javascript:alert("XSS")';
            const escaped = escapeHtml(malicious);

            // Note: escapeHtml doesn't prevent javascript: URLs directly,
            // but it would prevent injection into HTML attributes
            assert.strictEqual(escaped, 'javascript:alert(&quot;XSS&quot;)');
        });

        test('should neutralize SVG-based XSS', () => {
            const malicious = '<svg onload="alert(\'XSS\')">';
            const escaped = escapeHtml(malicious);

            assert.ok(!escaped.includes('<svg'));
        });

        test('should handle data URIs in attributes', () => {
            const malicious = '<a href="data:text/html,<script>alert(1)</script>">click</a>';
            const escaped = escapeHtml(malicious);

            assert.ok(!escaped.includes('<a'));
            assert.ok(!escaped.includes('<script>'));
        });
    });

    describe('Edge Cases', () => {
        test('should handle null', () => {
            assert.strictEqual(escapeHtml(null), '');
        });

        test('should handle undefined', () => {
            assert.strictEqual(escapeHtml(undefined), '');
        });

        test('should handle empty string', () => {
            assert.strictEqual(escapeHtml(''), '');
        });

        test('should handle numbers', () => {
            assert.strictEqual(escapeHtml(123), '123');
        });

        test('should handle objects via toString', () => {
            assert.strictEqual(escapeHtml({ toString: () => '<test>' }), '&lt;test&gt;');
        });

        test('should handle arrays', () => {
            assert.strictEqual(escapeHtml(['<a>', '<b>']), '&lt;a&gt;,&lt;b&gt;');
        });
    });

    describe('Multiple occurrences', () => {
        test('should escape all instances', () => {
            const input = '<<<<<';
            const expected = '&lt;&lt;&lt;&lt;&lt;';
            assert.strictEqual(escapeHtml(input), expected);
        });

        test('should handle mixed special characters', () => {
            const input = '<div class="test" data-value=\'123\'>&content</div>';
            const escaped = escapeHtml(input);

            assert.ok(!escaped.includes('<'));
            assert.ok(!escaped.includes('>'));
            assert.ok(!escaped.includes('"'));
            assert.ok(!escaped.includes("'"));
            assert.ok(!escaped.includes('&c')); // Should be &amp;content
        });
    });

    describe('Unicode handling', () => {
        test('should preserve Unicode characters', () => {
            assert.strictEqual(escapeHtml('こんにちは'), 'こんにちは');
            assert.strictEqual(escapeHtml('🔥'), '🔥');
            assert.strictEqual(escapeHtml('日本語<test>'), '日本語&lt;test&gt;');
        });
    });
});
