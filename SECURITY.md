# ZiggyEngine Security Policy

ZiggyEngine is an open-source project still in early development.  
We take security seriously, especially as the engine grows and more developers rely on it.

This document outlines how we handle security updates, vulnerability disclosures, and responsible reporting.

---

## 🔐 Supported Versions

ZiggyEngine is currently in pre-1.0 development.  
Security updates are provided only for the active development branch.

| Version        | Supported          |
|----------------|--------------------|
| main (latest)  | :white_check_mark: |
| dev            | :white_check_mark: |
| < 0.1.0        | :x:                |

Once the engine reaches 1.0, a proper LTS policy will be added.

---

## 🛡 Reporting a Vulnerability

If you discover a security vulnerability, please **do not open a GitHub Issue**.  
Security concerns should be reported privately so we can address them responsibly.

### 📬 How to Report

Please send an email to:

**security@<your-domain-or-github-username>.com**  
(or whatever email you want to use)

Include:

- A detailed description of the vulnerability  
- Steps to reproduce  
- Potential impact  
- Any suggested fixes (optional)

If you prefer encrypted communication, mention it and we can provide a PGP key.

---

## ⏳ Response Expectations

When you report a vulnerability:

- You will receive an acknowledgment within **72 hours**
- A maintainer will investigate the issue within **7 days**
- Fixes will be prioritized based on severity
- You will be notified when:
  - The issue is validated  
  - A fix is underway  
  - The fix has shipped  

---

## 🔏 Responsible Disclosure

We ask that you:

- Give us reasonable time to fix the issue before making it public  
- Do not exploit vulnerabilities  
- Do not share vulnerabilities with others before disclosure to the ZiggyEngine maintainers  

Maintainers will publicly credit individuals who responsibly disclose security issues (optional—tell us if you'd like recognition).

---

## 🧱 Scope of This Policy

This security policy applies to:

- ZiggyEngine Core  
- ZiggyEngine Studio  
- Official examples  
- Build scripts and runtime code

It **does not** apply to:

- Third-party dependencies (miniaudio, GLFW, Chipmunk2D, Jolt, etc.)  
- User-created game code  
- Unofficial forks or plugins  

Third-party issues should be reported to those upstream projects.

---

## 🙏 Thank You

Thank you for helping keep ZiggyEngine safe for all developers.  
Security is a community effort, and we appreciate every responsible disclosure.

