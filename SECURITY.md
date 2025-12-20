# Security Policy

## Supported Versions

The following versions of Zylix are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: |

As the project matures, we will maintain a clearer versioning policy with LTS (Long Term Support) releases.

## Reporting a Vulnerability

We take the security of Zylix seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@zylix.dev**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

### What to Include

Please include the following information in your report:

- Type of vulnerability (e.g., buffer overflow, memory corruption, XSS, etc.)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact assessment and potential attack scenarios

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours.

2. **Initial Assessment**: We will provide an initial assessment of the report within 7 days, including:
   - Whether we can reproduce the issue
   - The severity assessment
   - Our planned timeline for a fix

3. **Resolution**: We will work on a fix and keep you informed of our progress. The timeline depends on the severity:
   - **Critical**: Fix within 7 days
   - **High**: Fix within 30 days
   - **Medium**: Fix within 60 days
   - **Low**: Fix in next scheduled release

4. **Disclosure**: We will coordinate with you on the public disclosure of the vulnerability. We aim to disclose vulnerabilities within 90 days of the initial report.

5. **Credit**: We will credit you in the security advisory (unless you prefer to remain anonymous).

## Security Considerations for Zylix

### Memory Safety

Zylix is built with Zig, which provides:
- No hidden memory allocations
- Compile-time safety checks
- No undefined behavior by default
- Explicit error handling

However, as a systems programming framework, certain considerations apply:

### Platform Bindings

When using platform-specific bindings (C ABI, JNI, Swift interop):
- Validate all data crossing language boundaries
- Be cautious with pointer arithmetic and raw memory access
- Follow platform-specific security guidelines

### Web/WASM Considerations

For WASM builds:
- The WASM sandbox provides memory isolation
- DOM interactions go through validated JavaScript bindings
- User input should always be sanitized

### Native Platform Considerations

For native builds (iOS, Android, macOS, Linux, Windows):
- Follow platform security best practices
- Use secure storage APIs for sensitive data
- Implement proper permission handling

## Security Best Practices

When developing with Zylix, we recommend:

1. **Keep Dependencies Updated**: Regularly update to the latest stable version of Zylix.

2. **Input Validation**: Always validate user input before processing.

3. **Memory Management**: Use Zylix's built-in memory management patterns.

4. **Error Handling**: Handle all errors explicitly; never ignore error returns.

5. **Platform APIs**: Use platform-provided security APIs for:
   - Secure storage (Keychain, KeyStore, etc.)
   - Network security (TLS/SSL)
   - Authentication and authorization

## Security Updates

Security updates will be announced through:

- GitHub Security Advisories
- Release notes
- The official Zylix website (https://zylix.dev)

## Acknowledgments

We appreciate the security research community's efforts in helping us maintain a secure framework. Contributors who report valid security issues will be acknowledged in our Security Hall of Fame (with their permission).

---

Thank you for helping keep Zylix and its users safe!
