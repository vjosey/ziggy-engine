# 🎮 **ZiggyEngine**

**A modern, lightweight, editor-first + code-first hybrid game engine written in Zig.**  
Fast. Minimal. Hackable. Cross-platform. Built for 2D, 3D, tools, and creativity.



## ✨ **What is ZiggyEngine?**

ZiggyEngine is a proof-of-concept, open-source game engine written in **Zig**, with a design philosophy built on three pillars:

### ✔ **1. Editor-first workflow**

Comes with **Ziggy Studio**, a lightweight IDE-like editor with scene hierarchy, entity tools, live preview, and asset inspection.

### ✔ **2. Code-first architecture**

A clean, modular core (Ziggy Core) you can use directly in code _without_ the editor.  
Minimal abstractions. Full control. Works perfectly with Zig build systems.

### ✔ **3. Hybrid Component System (ZCS)**

A simple, data-oriented ECS-light system combined with a hierarchical scene graph.  
You get:

- Fast iteration
    
- Zero-runtime reflection
    
- Clean APIs
    
- Stability across Zig upgrades
    

---

## 🚀 **Current Status (Early Development)**

ZiggyEngine is in **very early prototyping**.  
Here is what currently exists:

-  **Ziggy Core runtime**
    
-  **ZCS (Ziggy Component System)**
    
-  Entities + hierarchy (parent/child/sibling)
    
-  Transform component + world transform system
    
-  Compiles cleanly on Zig 0.14+
    
-  `hello_core` example
    

Work in progress:

-  Ziggy Studio window
    
-  Rendering backend (OpenGL/Vulkan/Metal backend)
    
-  2D/3D renderer
    
-  Input system
    
-  Particle system
    
-  Physics (Jolt for 3D, Chipmunk2D for 2D)
    
-  Sound (miniaudio)
    
-  Rive integration (UI/animation)
    
-  Hot reload pipeline
    

---

## 🧱 **Project Structure**

`ziggy-engine/   core/     ziggy_core.zig        <- public API module     runtime.zig           <- engine runtime     zcs/       components.zig      <- Transform and future components       scene.zig           <- scene graph + entity management       systems/         transforms.zig    <- world transform propagation   studio/     main.zig              <- Ziggy Studio entry point (WIP)   examples/     hello_core/       main.zig            <- simple runtime example   build.zig`

---

## 🛠 **Building ZiggyEngine**

Requires **Zig 0.14+**.

### Build everything:

`zig build`

### Run the example:

`zig build run-example`

### Run Ziggy Studio:

`zig build run-studio`

---

## 🌟 **Long-Term Vision**

### 🎨 Rendering

- 2D + 3D hybrid renderer
    
- Render graph system
    
- Modern backend: OpenGL → Vulkan → Metal
    

### ✏️ Tools

- Ziggy Studio with:
    
    - Scene editor
        
    - Component inspector
        
    - Asset browser
        
    - Gizmos
        
    - Script hot reload
        
    - Debug overlays
        

### 🔊 Audio

- miniaudio integration
    
- Streaming, spatial audio, mixer & effects
    

### 🧩 Physics

- 3D: Jolt
    
- 2D: Chipmunk2D
    
- Unified collision API
    

### 🧬 UI

- Vanilla engine UI
    
- Optional **Rive** integration for:
    
    - vector UI
        
    - UI animations
        
    - skeletal animation
        

### ☄️ VFX

- GPU particle systems
    
- CPU fallback particle system
    
- Burst, looping, ribbon trails
    

---

# 🤝 **Contributing**

ZiggyEngine is at the perfect stage for contributors who enjoy **deep engine design**, **clean code**, and **Zig exploration**.

### When should you start accepting contributors?

**Right now — with limitations.**

The best time to open contributions is when:

### ✔ The core builds and runs (check)

### ✔ The codebase is organized (check)

### ✔ You have a clear public API layer (ziggy_core.zig — check)

### ✔ You have a roadmap (this README — check)

This is _exactly_ when you want early contributors who enjoy:

- Building rendering pipelines
    
- Engine architecture
    
- Zig build system work
    
- UI systems
    
- Physics integration
    
- Editor tools
    
- Debug tooling
    

People who join now become “founding” contributors.

### How to invite contributors now:

Add this section to README:

---

## 🧩 How to Contribute

ZiggyEngine is early and evolving quickly. Contributions are welcome in:

- Engine architecture
    
- Rendering (OpenGL/Vulkan/Metal)
    
- Editor (Ziggy Studio UI)
    
- ECS / scene extensions
    
- Physics integrations
    
- Audio APIs
    
- Asset pipelines
    
- Documentation & examples
    

### Steps

1. Fork the repository
    
2. Make a feature branch
    
3. Run `zig build` to ensure everything compiles
    
4. Send a pull request
    
5. Join discussions in Issues
    

---

## 🧭 **Roadmap (v0.1 → v1.0)**

### v0.1 (Proof of Concept)

- Core runtime
    
- ZCS system
    
- Transform system
    
- Ziggy Studio window
    
- 2D triangles/quads rendering
    
- Input system
    

### v0.2

- Basic editor hierarchy
    
- Move/rotate gizmos
    
- Materials + textures
    
- 2D batch renderer
    

### v0.3

- Cameras
    
- Lighting
    
- Mesh loading
    

### v0.4

- Chipmunk2D integration
    
- Audio initialization
    

### v0.5

- Jolt 3D physics
    
- Particle system
    
- Editor viewport playback
    

### v0.6–1.0

- Rive integration
    
- Render graph
    
- Hot reload
    
- Advanced tools
    
- Export pipeline
    
- Template projects
    

---

# 🌌 Why ZiggyEngine?

Because building a modern game engine in Zig isn’t just doable — it’s **fun**, educational, and the community is hungry for it.

ZiggyEngine is:

- small enough to understand
    
- powerful enough to grow
    
- flexible enough for contributors
    
- simple enough for beginners
    
- fast enough for real games
    

---

# 📬 Contact / Community

Coming soon:

- Discord
    
- GitHub Discussions
    
- Issue tracker
    

---

## 📜 License

MIT 