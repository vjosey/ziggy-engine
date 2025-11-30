# Contributing to ZiggyEngine

First off, thank you for taking the time to contribute!\
ZiggyEngine is a young project, and your help will directly shape its
future.

This document explains how to set up your environment, how to submit
changes, and the standards for contributing to the engine and editor.

------------------------------------------------------------------------

# 🧰 Getting Started

## Requirements

-   **Zig 0.14+** (latest stable recommended)
-   Git
-   A terminal or shell you're comfortable with

Optional (for graphics work): - GLFW development libraries - OpenGL /
GPU drivers up to date

------------------------------------------------------------------------

# 📦 Building the Project

Clone the repository:

``` bash
git clone https://github.com/<yourname>/ziggy-engine.git
cd ziggy-engine
```

Build everything:

``` bash
zig build
```

Run the example:

``` bash
zig build run-example
```

Run Ziggy Studio:

``` bash
zig build run-studio
```

If something breaks, feel free to open an Issue.

------------------------------------------------------------------------

# 🌱 Branch Structure

ZiggyEngine uses a simple and safe branching model:

-   `main` → **stable**, release-ready code\
-   `dev` → active development branch\
-   `feature/*` → contributor branches for PRs

Do **not** submit PRs directly to `main`.

------------------------------------------------------------------------

# 🛠 Creating a Contribution

## 1. Fork the repo

Click "Fork" at the top right on GitHub.

## 2. Create a feature branch

``` bash
git checkout -b feature/my-feature-name
```

## 3. Make changes

-   Keep commits clean and atomic\
-   Add comments where necessary\
-   Ensure the code builds with `zig build` before submitting

## 4. Run tests/examples

If applicable:

``` bash
zig build run-example
zig build run-studio
```

## 5. Submit a Pull Request (PR)

Target the `dev` branch.

In your PR description: - Explain what you changed\
- Reference any related issues\
- Add screenshots or logs if helpful

A maintainer will review it and provide feedback before merging.

------------------------------------------------------------------------

# 🧹 Code Style Guidelines

ZiggyEngine uses standard Zig conventions:

-   Tabs for indentation\
-   LowerCamelCase for function names\
-   PascalCase for types\
-   snake_case for file names\
-   Avoid unnecessary `comptime` complexity\
-   Keep functions small and focused\
-   Prefer clean, explicit code over cleverness

------------------------------------------------------------------------

# 🧪 Testing

ZiggyEngine currently relies on: - Examples - Visual engine behavior -
Future: formal test suite using `zig test`

When adding features: - If possible, include a minimal test or example
scene

------------------------------------------------------------------------

# 🛰 Future Areas for Contribution

-   Rendering backend (OpenGL → Vulkan)
-   Scene graph tools
-   Editor UI panels
-   Physics integration (Chipmunk2D, Jolt)
-   Audio (miniaudio)
-   Particle system (CPU/GPU)
-   Rive integration
-   Documentation & tutorials

------------------------------------------------------------------------

# ❤️ Thank You

ZiggyEngine is a community-driven project.\
Your participation --- whether code, issues, feedback, or testing ---
makes this engine grow.

If you have any questions, open a Discussion or Issue.

Welcome to the ZiggyEngine community!
