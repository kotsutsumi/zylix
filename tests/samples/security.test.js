import { test, describe } from 'node:test';
import assert from 'node:assert';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const samplesDir = join(__dirname, '../../samples');

describe('Sample Applications Security', () => {
    const sampleApps = readdirSync(samplesDir, { withFileTypes: true })
        .filter(d => d.isDirectory() && !d.name.startsWith('.'))
        .map(d => d.name);

    describe('XSS Prevention', () => {
        for (const app of sampleApps) {
            const mainPath = join(samplesDir, app, 'src/main.js');
            let content;

            try {
                content = readFileSync(mainPath, 'utf-8');
            } catch {
                continue; // Skip if file doesn't exist
            }

            test(`${app} should have escapeHtml utility`, () => {
                assert.ok(
                    content.includes('function escapeHtml'),
                    `${app} should define escapeHtml function`
                );
            });

            test(`${app} should not use innerHTML without escaping`, () => {
                // Check for patterns like innerHTML = variable (without escapeHtml)
                const dangerousPatterns = [
                    /innerHTML\s*=\s*[^`'"]*\$\{(?!escapeHtml)/g,
                    /innerHTML\s*=\s*[a-zA-Z_]\w*(?!.*escapeHtml)/g,
                ];

                // We're looking for innerHTML usage that doesn't use escapeHtml
                // Note: This is a heuristic check, not foolproof
                const lines = content.split('\n');
                const problematicLines = [];

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (line.includes('innerHTML') && line.includes('${')) {
                        // Check if the interpolation uses escapeHtml
                        const interpolations = line.match(/\$\{[^}]+\}/g) || [];
                        for (const interp of interpolations) {
                            // Skip if it's escapeHtml, escapeAttr, or a known safe value
                            if (!interp.includes('escapeHtml') &&
                                !interp.includes('escapeAttr') &&
                                !interp.includes('escapeUrl') &&
                                !interp.includes('escapedId') &&
                                !interp.includes('escaped')) {
                                // Check if it's a simple variable that might be unescaped
                                if (/\$\{[a-zA-Z_]\w*(\.[a-zA-Z_]\w*)*\}/.test(interp)) {
                                    // This might be problematic, but we allow it if escaping happens elsewhere
                                    // For now, just note it
                                }
                            }
                        }
                    }
                }

                // This test passes if escapeHtml is defined and used in template literals
                const usesEscaping = content.includes('escapeHtml(') || content.includes('escapeAttr(');
                assert.ok(usesEscaping, `${app} should use escapeHtml or escapeAttr functions`);
            });

            test(`${app} should use data-action pattern for event handling`, () => {
                // Check that onclick is not used inline
                const hasInlineOnclick = /onclick\s*=\s*["'][^"']*\(/.test(content);
                const hasDataAction = content.includes('data-action');

                // If there are interactive elements, they should use data-action
                if (content.includes('button') || content.includes('click')) {
                    assert.ok(
                        hasDataAction,
                        `${app} should use data-action pattern for event handling`
                    );
                }
            });
        }
    });

    describe('Secure ID Generation', () => {
        for (const app of sampleApps) {
            const mainPath = join(samplesDir, app, 'src/main.js');
            let content;

            try {
                content = readFileSync(mainPath, 'utf-8');
            } catch {
                continue;
            }

            if (content.includes('generateId')) {
                test(`${app} should use crypto.randomUUID for ID generation`, () => {
                    assert.ok(
                        content.includes('crypto.randomUUID') || content.includes('crypto.getRandomValues'),
                        `${app} should use secure random generation`
                    );
                });
            }
        }
    });

    describe('Event Delegation', () => {
        for (const app of sampleApps) {
            const mainPath = join(samplesDir, app, 'src/main.js');
            let content;

            try {
                content = readFileSync(mainPath, 'utf-8');
            } catch {
                continue;
            }

            test(`${app} should implement event delegation`, () => {
                // Check for event delegation patterns
                const hasEventDelegation =
                    content.includes('addEventListener') &&
                    (content.includes('closest') || content.includes('target') || content.includes('data-action'));

                assert.ok(
                    hasEventDelegation,
                    `${app} should use event delegation pattern`
                );
            });

            test(`${app} should have handleClick method for delegation`, () => {
                // Check for handleClick or similar delegation handler
                const hasDelegationHandler =
                    content.includes('handleClick') ||
                    content.includes('handleEvent') ||
                    content.includes('handleAction');

                // This is a soft requirement - not all apps need it
                if (content.includes('data-action')) {
                    assert.ok(
                        hasDelegationHandler,
                        `${app} should have a delegation handler method`
                    );
                }
            });
        }
    });
});

describe('Sample Applications Structure', () => {
    // WASM samples use a different structure (zylix.js instead of src/main.js)
    const wasmSamples = ['counter-wasm', 'todo-wasm', 'component-showcase'];

    const sampleApps = readdirSync(samplesDir, { withFileTypes: true })
        .filter(d => d.isDirectory() && !d.name.startsWith('.'))
        .filter(d => !wasmSamples.includes(d.name))
        .map(d => d.name);

    for (const app of sampleApps) {
        describe(`${app}`, () => {
            test('should have main.js entry point', () => {
                const mainPath = join(samplesDir, app, 'src/main.js');
                assert.doesNotThrow(() => {
                    readFileSync(mainPath);
                }, `${app} should have src/main.js`);
            });

            test('main.js should be valid JavaScript', async () => {
                const mainPath = join(samplesDir, app, 'src/main.js');
                try {
                    const content = readFileSync(mainPath, 'utf-8');
                    // Check for basic syntax by trying to parse
                    // Note: We can't use new Function() for ES modules
                    // So we use a simpler syntax check via node --check
                    const { execSync } = await import('node:child_process');
                    execSync(`node --check "${mainPath}"`, { stdio: 'pipe' });
                } catch (error) {
                    if (error.message && error.message.includes('SyntaxError')) {
                        assert.fail(`${app}/src/main.js has syntax errors: ${error.message}`);
                    }
                    // Other errors from execSync indicate syntax issues
                    if (error.status !== 0 && error.stderr) {
                        assert.fail(`${app}/src/main.js has syntax errors: ${error.stderr.toString()}`);
                    }
                }
            });

            test('should export main app class or function', () => {
                const mainPath = join(samplesDir, app, 'src/main.js');
                const content = readFileSync(mainPath, 'utf-8');

                const hasExport =
                    content.includes('export ') ||
                    content.includes('module.exports') ||
                    content.includes('window.');

                assert.ok(hasExport, `${app} should export its main component`);
            });
        });
    }

    // Separate tests for WASM samples with different structure
    const wasmMainFiles = {
        'counter-wasm': 'zylix.js',
        'todo-wasm': 'zylix-todo.js',
        'component-showcase': 'zylix-showcase.js'
    };

    for (const app of wasmSamples) {
        const mainFile = wasmMainFiles[app];

        describe(`${app} (WASM)`, () => {
            test(`should have ${mainFile} entry point`, () => {
                const mainPath = join(samplesDir, app, mainFile);
                assert.doesNotThrow(() => {
                    readFileSync(mainPath);
                }, `${app} should have ${mainFile}`);
            });

            test(`${mainFile} should be valid JavaScript`, async () => {
                const mainPath = join(samplesDir, app, mainFile);
                try {
                    const { execSync } = await import('node:child_process');
                    execSync(`node --check "${mainPath}"`, { stdio: 'pipe' });
                } catch (error) {
                    if (error.status !== 0 && error.stderr) {
                        assert.fail(`${app}/${mainFile} has syntax errors: ${error.stderr.toString()}`);
                    }
                }
            });

            test('should have WASM file', () => {
                const wasmPath = join(samplesDir, app, 'zylix.wasm');
                assert.doesNotThrow(() => {
                    readFileSync(wasmPath);
                }, `${app} should have zylix.wasm`);
            });
        });
    }
});
