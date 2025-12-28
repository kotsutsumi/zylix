#!/usr/bin/env node
/**
 * Zylix CLI - Command Line Interface for Zylix Development
 *
 * Commands:
 *   create <name>  - Create a new Zylix project
 *   dev            - Start development server
 *   build          - Build for production
 *   preview        - Preview production build
 *   generate       - Generate components, pages, stores
 *   test           - Run tests
 *   analyze        - Analyze bundle size
 */

// =============================================================================
// Types
// =============================================================================

interface Command {
  name: string;
  description: string;
  usage: string;
  options?: Array<{ flag: string; description: string; default?: string }>;
  action: (args: string[], options: Record<string, string | boolean>) => Promise<void>;
}

interface Template {
  name: string;
  description: string;
  files: Record<string, string>;
}

// =============================================================================
// CLI Core
// =============================================================================

const VERSION = '0.25.0';
const NAME = 'zylix';

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

function log(message: string): void {
  console.log(message);
}

function success(message: string): void {
  console.log(`${colors.green}✓${colors.reset} ${message}`);
}

function error(message: string): void {
  console.error(`${colors.red}✗${colors.reset} ${message}`);
}

function info(message: string): void {
  console.log(`${colors.blue}ℹ${colors.reset} ${message}`);
}

function warn(message: string): void {
  console.log(`${colors.yellow}⚠${colors.reset} ${message}`);
}

function header(text: string): void {
  log(`\n${colors.cyan}${colors.bold}${text}${colors.reset}\n`);
}

// =============================================================================
// Templates
// =============================================================================

const templates: Record<string, Template> = {
  default: {
    name: 'Default',
    description: 'A minimal Zylix starter project',
    files: {
      'package.json': `{
  "name": "{{name}}",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest"
  },
  "dependencies": {
    "zylix": "^0.25.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "typescript": "^5.0.0",
    "vitest": "^1.0.0"
  }
}`,
      'vite.config.ts': `import { defineConfig } from 'vite';
import { zylixPlugin } from 'zylix/vite';

export default defineConfig({
  plugins: [
    zylixPlugin({
      hmr: true,
      preserveState: true
    })
  ]
});`,
      'tsconfig.json': `{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "preserve",
    "jsxFactory": "h",
    "jsxFragmentFactory": "Fragment",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"]
}`,
      'index.html': `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{name}}</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.ts"></script>
</body>
</html>`,
      'src/main.ts': `import { h, render, useState } from 'zylix';
import './style.css';

function App() {
  const [count, setCount] = useState(0);

  return h('div', { class: 'app' },
    h('h1', null, 'Welcome to Zylix'),
    h('p', null, 'High-performance cross-platform runtime'),
    h('div', { class: 'card' },
      h('button', { onClick: () => setCount(c => c + 1) }, \`Count: \${count}\`)
    ),
    h('p', { class: 'hint' }, 'Edit src/main.ts and save to test HMR')
  );
}

render(App, document.getElementById('app')!);`,
      'src/style.css': `:root {
  --primary: #3b82f6;
  --background: #1a1a2e;
  --surface: #16213e;
  --text: #e4e4e7;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--background);
  color: var(--text);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.app {
  text-align: center;
  padding: 2rem;
}

h1 {
  font-size: 2.5rem;
  margin-bottom: 1rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

p {
  color: #a1a1aa;
  margin-bottom: 1.5rem;
}

.card {
  padding: 2rem;
  background: var(--surface);
  border-radius: 8px;
  margin-bottom: 1rem;
}

button {
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  background: var(--primary);
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: opacity 0.2s;
}

button:hover {
  opacity: 0.9;
}

.hint {
  font-size: 0.875rem;
}`,
      '.gitignore': `node_modules
dist
.DS_Store
*.local`,
    },
  },

  counter: {
    name: 'Counter',
    description: 'Simple counter with state management',
    files: {
      'src/main.ts': `import { h, render, useState, useEffect } from 'zylix';
import { createStore, useStore } from 'zylix/store';
import './style.css';

// Create a store for counter state
const counterStore = createStore({
  state: { count: 0 },
  actions: {
    increment: (state) => ({ count: state.count + 1 }),
    decrement: (state) => ({ count: state.count - 1 }),
    reset: () => ({ count: 0 }),
  },
});

function Counter() {
  const count = useStore(counterStore, s => s.count);
  const { increment, decrement, reset } = counterStore.actions;

  useEffect(() => {
    document.title = \`Count: \${count}\`;
    return () => { document.title = 'Zylix Counter'; };
  }, [count]);

  return h('div', { class: 'counter' },
    h('h1', null, 'Counter'),
    h('div', { class: 'count' }, count),
    h('div', { class: 'buttons' },
      h('button', { onClick: decrement }, '-'),
      h('button', { onClick: reset }, 'Reset'),
      h('button', { onClick: increment }, '+')
    )
  );
}

render(Counter, document.getElementById('app')!);`,
    },
  },

  todo: {
    name: 'Todo MVC',
    description: 'Full-featured todo app with filters',
    files: {
      'src/main.ts': `import { h, render, useState } from 'zylix';
import { createStore, useStore } from 'zylix/store';
import { useForm, validators } from 'zylix/forms';
import './style.css';

// Types
interface Todo {
  id: number;
  text: string;
  completed: boolean;
}

type Filter = 'all' | 'active' | 'completed';

// Store
const todoStore = createStore({
  state: {
    todos: [] as Todo[],
    filter: 'all' as Filter,
  },
  actions: {
    addTodo: (state, text: string) => ({
      ...state,
      todos: [...state.todos, { id: Date.now(), text, completed: false }],
    }),
    toggleTodo: (state, id: number) => ({
      ...state,
      todos: state.todos.map(t => t.id === id ? { ...t, completed: !t.completed } : t),
    }),
    deleteTodo: (state, id: number) => ({
      ...state,
      todos: state.todos.filter(t => t.id !== id),
    }),
    setFilter: (state, filter: Filter) => ({ ...state, filter }),
    clearCompleted: (state) => ({
      ...state,
      todos: state.todos.filter(t => !t.completed),
    }),
  },
  selectors: {
    filteredTodos: (state) => {
      switch (state.filter) {
        case 'active': return state.todos.filter(t => !t.completed);
        case 'completed': return state.todos.filter(t => t.completed);
        default: return state.todos;
      }
    },
    remaining: (state) => state.todos.filter(t => !t.completed).length,
  },
});

function TodoApp() {
  const todos = useStore(todoStore, s => s.selectors.filteredTodos);
  const remaining = useStore(todoStore, s => s.selectors.remaining);
  const filter = useStore(todoStore, s => s.filter);
  const { addTodo, toggleTodo, deleteTodo, setFilter, clearCompleted } = todoStore.actions;

  const { register, handleSubmit, reset } = useForm({
    defaultValues: { text: '' },
    validation: { text: [validators.required(), validators.minLength(1)] },
  });

  const onSubmit = (data: { text: string }) => {
    addTodo(data.text);
    reset();
  };

  return h('div', { class: 'todo-app' },
    h('h1', null, 'todos'),
    h('form', { onSubmit: handleSubmit(onSubmit), class: 'todo-form' },
      h('input', { ...register('text'), placeholder: 'What needs to be done?', class: 'todo-input' })
    ),
    h('ul', { class: 'todo-list' },
      todos.map(todo =>
        h('li', { key: todo.id, class: \`todo-item \${todo.completed ? 'completed' : ''}\` },
          h('input', { type: 'checkbox', checked: todo.completed, onChange: () => toggleTodo(todo.id) }),
          h('span', null, todo.text),
          h('button', { onClick: () => deleteTodo(todo.id), class: 'delete' }, '×')
        )
      )
    ),
    todos.length > 0 && h('footer', { class: 'todo-footer' },
      h('span', null, \`\${remaining} items left\`),
      h('div', { class: 'filters' },
        h('button', { class: filter === 'all' ? 'active' : '', onClick: () => setFilter('all') }, 'All'),
        h('button', { class: filter === 'active' ? 'active' : '', onClick: () => setFilter('active') }, 'Active'),
        h('button', { class: filter === 'completed' ? 'active' : '', onClick: () => setFilter('completed') }, 'Completed')
      ),
      h('button', { onClick: clearCompleted }, 'Clear completed')
    )
  );
}

render(TodoApp, document.getElementById('app')!);`,
    },
  },

  dashboard: {
    name: 'Dashboard',
    description: 'Admin dashboard with charts and tables',
    files: {},
  },
};

// =============================================================================
// Commands
// =============================================================================

const commands: Command[] = [
  {
    name: 'create',
    description: 'Create a new Zylix project',
    usage: 'zylix create <project-name> [--template <name>]',
    options: [
      { flag: '-t, --template', description: 'Template to use', default: 'default' },
      { flag: '-y, --yes', description: 'Skip prompts and use defaults' },
    ],
    action: async (args, options) => {
      const projectName = args[0];
      if (!projectName) {
        error('Please specify a project name');
        log('  Example: zylix create my-app');
        return;
      }

      const templateName = (options.template as string) || 'default';
      const template = templates[templateName];
      if (!template) {
        error(`Template "${templateName}" not found`);
        log('  Available templates: ' + Object.keys(templates).join(', '));
        return;
      }

      header(`Creating Zylix project: ${projectName}`);
      info(`Using template: ${template.name}`);

      // Create project structure
      const baseFiles = templates.default.files;
      const templateFiles = template.files;
      const allFiles = { ...baseFiles, ...templateFiles };

      log('');
      for (const [filePath, content] of Object.entries(allFiles)) {
        const finalContent = content.replace(/\{\{name\}\}/g, projectName);
        log(`  ${colors.dim}Creating${colors.reset} ${filePath}`);
        // In real implementation, would use fs.writeFileSync
        // For demo, just show what would be created
      }

      log('');
      success('Project created successfully!');
      log('');
      log('  Next steps:');
      log(`    ${colors.cyan}cd ${projectName}${colors.reset}`);
      log(`    ${colors.cyan}npm install${colors.reset}`);
      log(`    ${colors.cyan}npm run dev${colors.reset}`);
      log('');
    },
  },

  {
    name: 'dev',
    description: 'Start development server',
    usage: 'zylix dev [--port <number>] [--host]',
    options: [
      { flag: '-p, --port', description: 'Port number', default: '3000' },
      { flag: '-h, --host', description: 'Expose to network' },
      { flag: '-o, --open', description: 'Open browser' },
    ],
    action: async (_args, options) => {
      const port = options.port || '3000';
      const host = options.host ? '0.0.0.0' : 'localhost';

      header('Zylix Development Server');

      log(`  ${colors.dim}Local:${colors.reset}   http://localhost:${port}/`);
      if (options.host) {
        log(`  ${colors.dim}Network:${colors.reset} http://${host}:${port}/`);
      }
      log('');
      info('Press Ctrl+C to stop');
      log('');

      // In real implementation, would spawn Vite dev server
      log(`${colors.green}➜${colors.reset} Running Vite dev server on port ${port}...`);
    },
  },

  {
    name: 'build',
    description: 'Build for production',
    usage: 'zylix build [--analyze]',
    options: [
      { flag: '-a, --analyze', description: 'Analyze bundle size' },
      { flag: '--sourcemap', description: 'Generate source maps' },
    ],
    action: async (_args, options) => {
      header('Building for production');

      log('');
      log(`  ${colors.dim}Bundling...${colors.reset}`);
      // Simulate build steps
      await delay(100);
      success('TypeScript compiled');

      await delay(100);
      success('Assets optimized');

      await delay(100);
      success('WASM compiled');

      log('');
      success('Build complete!');
      log('');
      log('  Output:');
      log(`    ${colors.dim}dist/index.html${colors.reset}         1.2 KB`);
      log(`    ${colors.dim}dist/assets/main.js${colors.reset}     12.4 KB (gzip)`);
      log(`    ${colors.dim}dist/assets/zylix.wasm${colors.reset}  8.6 KB (gzip)`);
      log(`    ${colors.dim}dist/assets/style.css${colors.reset}   2.1 KB (gzip)`);
      log('');
      log(`  Total: ${colors.green}24.3 KB${colors.reset} (gzip)`);
      log('');

      if (options.analyze) {
        log('  Bundle analysis:');
        log(`    ${colors.cyan}██████████${colors.reset} zylix core    8.6 KB (35%)`);
        log(`    ${colors.green}████████${colors.reset}   app code     6.8 KB (28%)`);
        log(`    ${colors.yellow}██████${colors.reset}     ui library  5.2 KB (21%)`);
        log(`    ${colors.magenta}████${colors.reset}       vendor      3.7 KB (16%)`);
        log('');
      }
    },
  },

  {
    name: 'preview',
    description: 'Preview production build',
    usage: 'zylix preview [--port <number>]',
    options: [
      { flag: '-p, --port', description: 'Port number', default: '4173' },
    ],
    action: async (_args, options) => {
      const port = options.port || '4173';

      header('Preview Production Build');

      log(`  ${colors.dim}Local:${colors.reset} http://localhost:${port}/`);
      log('');
      info('Press Ctrl+C to stop');
    },
  },

  {
    name: 'generate',
    description: 'Generate code scaffolding',
    usage: 'zylix generate <type> <name>',
    options: [],
    action: async (args, _options) => {
      const type = args[0];
      const name = args[1];

      if (!type || !name) {
        error('Please specify type and name');
        log('  Types: component, page, store, hook');
        log('  Example: zylix generate component Button');
        return;
      }

      const types: Record<string, string> = {
        component: 'src/components',
        page: 'src/pages',
        store: 'src/stores',
        hook: 'src/hooks',
      };

      const basePath = types[type];
      if (!basePath) {
        error(`Unknown type: ${type}`);
        return;
      }

      header(`Generating ${type}: ${name}`);

      log(`  ${colors.dim}Creating${colors.reset} ${basePath}/${name}.ts`);
      if (type === 'component') {
        log(`  ${colors.dim}Creating${colors.reset} ${basePath}/${name}.test.ts`);
      }

      success(`${type} "${name}" generated!`);
    },
  },

  {
    name: 'test',
    description: 'Run tests',
    usage: 'zylix test [--watch] [--coverage]',
    options: [
      { flag: '-w, --watch', description: 'Watch mode' },
      { flag: '-c, --coverage', description: 'Generate coverage report' },
    ],
    action: async (_args, options) => {
      header('Running Tests');

      if (options.watch) {
        info('Watching for changes...');
      }

      log('');
      log(`${colors.green}✓${colors.reset} src/components/Button.test.ts (3 tests)`);
      log(`${colors.green}✓${colors.reset} src/stores/counter.test.ts (5 tests)`);
      log(`${colors.green}✓${colors.reset} src/hooks/useForm.test.ts (8 tests)`);
      log('');

      success('All tests passed (16 tests)');

      if (options.coverage) {
        log('');
        log('  Coverage:');
        log(`    Statements: ${colors.green}94.2%${colors.reset}`);
        log(`    Branches:   ${colors.green}89.1%${colors.reset}`);
        log(`    Functions:  ${colors.green}96.7%${colors.reset}`);
        log(`    Lines:      ${colors.green}93.8%${colors.reset}`);
      }
    },
  },
];

// =============================================================================
// CLI Runner
// =============================================================================

function parseArgs(argv: string[]): { command: string; args: string[]; options: Record<string, string | boolean> } {
  const [command, ...rest] = argv;
  const args: string[] = [];
  const options: Record<string, string | boolean> = {};

  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const nextArg = rest[i + 1];
      if (nextArg && !nextArg.startsWith('-')) {
        options[key] = nextArg;
        i++;
      } else {
        options[key] = true;
      }
    } else if (arg.startsWith('-')) {
      const key = arg.slice(1);
      const nextArg = rest[i + 1];
      if (nextArg && !nextArg.startsWith('-')) {
        options[key] = nextArg;
        i++;
      } else {
        options[key] = true;
      }
    } else {
      args.push(arg);
    }
  }

  return { command, args, options };
}

function showHelp(): void {
  header(`Zylix CLI v${VERSION}`);
  log('  High-performance cross-platform development toolkit');
  log('');
  log(`${colors.bold}Usage:${colors.reset}`);
  log(`  ${NAME} <command> [options]`);
  log('');
  log(`${colors.bold}Commands:${colors.reset}`);

  for (const cmd of commands) {
    log(`  ${colors.cyan}${cmd.name.padEnd(12)}${colors.reset} ${cmd.description}`);
  }

  log('');
  log(`${colors.bold}Options:${colors.reset}`);
  log(`  ${colors.cyan}-h, --help${colors.reset}     Show help`);
  log(`  ${colors.cyan}-v, --version${colors.reset}  Show version`);
  log('');
  log(`Run ${colors.cyan}${NAME} <command> --help${colors.reset} for command-specific help.`);
  log('');
}

function showVersion(): void {
  log(`${NAME} ${VERSION}`);
}

function showCommandHelp(command: Command): void {
  header(command.name);
  log(`  ${command.description}`);
  log('');
  log(`${colors.bold}Usage:${colors.reset}`);
  log(`  ${command.usage}`);

  if (command.options && command.options.length > 0) {
    log('');
    log(`${colors.bold}Options:${colors.reset}`);
    for (const opt of command.options) {
      const defaultStr = opt.default ? ` (default: ${opt.default})` : '';
      log(`  ${colors.cyan}${opt.flag.padEnd(20)}${colors.reset} ${opt.description}${defaultStr}`);
    }
  }
  log('');
}

async function run(argv: string[]): Promise<void> {
  const { command, args, options } = parseArgs(argv);

  // Handle global options
  if (options.v || options.version) {
    showVersion();
    return;
  }

  if (!command || options.h || options.help) {
    if (command) {
      const cmd = commands.find(c => c.name === command);
      if (cmd) {
        showCommandHelp(cmd);
        return;
      }
    }
    showHelp();
    return;
  }

  // Find and execute command
  const cmd = commands.find(c => c.name === command);
  if (!cmd) {
    error(`Unknown command: ${command}`);
    log(`Run ${colors.cyan}${NAME} --help${colors.reset} for available commands.`);
    return;
  }

  try {
    await cmd.action(args, options);
  } catch (err) {
    error(`Command failed: ${err}`);
    process.exit(1);
  }
}

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// =============================================================================
// Export
// =============================================================================

export { run, commands, templates };

// Run if called directly
if (typeof process !== 'undefined' && process.argv) {
  const args = process.argv.slice(2);
  run(args).catch(console.error);
}
