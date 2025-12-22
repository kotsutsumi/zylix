# Release Guide for v0.8.0

## Pre-release Checklist

- [x] CHANGELOG.md updated
- [x] Version consistency verified (0.8.0)
- [x] TypeScript bindings prepared (@zylix/test)
- [x] Python bindings prepared (zylix-test)
- [x] LICENSE files added to bindings

## Release Steps

### 1. Create Git Tag

```bash
git add .
git commit -m "chore: prepare v0.8.0 release"
git tag -a v0.8.0 -m "Release v0.8.0

- watchOS support (Digital Crown, Side Button, Companion Device)
- Language bindings (TypeScript @zylix/test, Python zylix-test)
- CI/CD with GitHub Actions
- E2E test framework
- Platform-specific sample demos
- API documentation"
git push origin main --tags
```

### 2. Publish TypeScript Package to npm

```bash
cd bindings/typescript

# Install dependencies
npm install

# Build
npm run build

# Verify package contents
npm pack --dry-run

# Publish (requires npm login)
npm publish --access public
```

### 3. Publish Python Package to PyPI

```bash
cd bindings/python

# Install build tools
pip install build twine

# Build
python -m build

# Verify package
twine check dist/*

# Upload to PyPI (requires credentials)
twine upload dist/*
```

### 4. Create GitHub Release

1. Go to https://github.com/kotsutsumi/zylix/releases
2. Click "Draft a new release"
3. Select tag `v0.8.0`
4. Title: `v0.8.0`
5. Copy release notes from CHANGELOG.md
6. Publish release

## Post-release

- [ ] Verify npm package: https://www.npmjs.com/package/@zylix/test
- [ ] Verify PyPI package: https://pypi.org/project/zylix-test/
- [ ] Update documentation site
- [ ] Announce release

## Version Matrix

| Package | Version | Registry |
|---------|---------|----------|
| @zylix/test | 0.8.0 | npm |
| zylix-test | 0.8.0 | PyPI |
| zylix (core) | 0.8.0 | GitHub |
