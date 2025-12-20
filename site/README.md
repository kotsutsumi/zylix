# Zylix Website

Official documentation website for Zylix, built with Hugo and Hextra theme.

## Features

- **Multilingual**: English and Japanese
- **Dark/Light Mode**: Automatic theme switching
- **Search**: Full-text search with FlexSearch
- **Live Demo**: Interactive WASM Todo app

## Development

### Prerequisites

- [Hugo Extended](https://gohugo.io/installation/) v0.139.0+
- [Go](https://golang.org/dl/) 1.21+

### Local Development

```bash
cd site

# Install dependencies
hugo mod tidy

# Start dev server
hugo server -D

# Open http://localhost:1313
```

### Build

```bash
hugo --gc --minify
```

Output will be in `public/` directory.

## Deployment

### Vercel

1. Connect your GitHub repository to Vercel
2. Set the following:
   - **Root Directory**: `site`
   - **Build Command**: `hugo --gc --minify`
   - **Output Directory**: `public`
   - **Install Command**: (see vercel.json)

Or use the Vercel CLI:

```bash
cd site
vercel
```

### Manual

```bash
hugo --gc --minify
# Upload public/ to your hosting provider
```

## Structure

```
site/
├── hugo.yaml           # Hugo configuration
├── go.mod              # Go modules
├── vercel.json         # Vercel deployment config
├── content/
│   ├── en/             # English content
│   │   ├── _index.md   # Homepage
│   │   ├── docs/       # Documentation
│   │   ├── demo/       # Live demo
│   │   └── blog/       # Blog posts
│   └── ja/             # Japanese content
│       ├── _index.md   # ホームページ
│       ├── docs/       # ドキュメント
│       ├── demo/       # ライブデモ
│       └── blog/       # ブログ
└── static/
    └── images/         # Static images
```

## Theme

This site uses [Hextra](https://github.com/imfing/hextra) theme with the following features:

- Responsive design
- Dark/Light mode toggle
- Language switcher
- Full-text search
- Syntax highlighting
- Table of contents
- Edit on GitHub links

## License

MIT License - see [LICENSE](../LICENSE) for details.
