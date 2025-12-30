"# Super Mario Clone for Roku

A high-performance side-scrolling platformer for Roku OS, built using the roScreen 2D API and BrightScript.

## Project Status

✅ **Playable Demo** - Menu, audio, pause/options, game over, coins/goombas (see [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md))

## Architecture

This project uses:
- **roScreen 2D API** for low-latency rendering (60 FPS target)
- **Custom BrightScript game engine** with delta time and object pooling
- **AABB collision detection** with tile-based physics
- **Manual menu system** rendered via roScreen (no SceneGraph)

See [PLAN.md](PLAN.md) for the complete technical blueprint.

## Development Setup

### Prerequisites

1. **Roku Device** in developer mode
   - Go to Settings > System > Advanced system settings > Developer settings
   - Enable "Developer mode" and set a password

2. **VS Code** with BrightScript extension installed
   - Extension: `rokucommunity.brightscript`

3. **Telnet client** for real-time debugging

### Configuration

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update `.env` with your Roku device IP and password:
   ```
   ROKU_DEV_TARGET=192.168.1.XXX
   DEVPASSWORD=your_password
   ```

3. Find your Roku IP address:
   - Go to Settings > System > About on your Roku device

### Debugging

#### VS Code Debugger
- Press F5 to launch and debug on your Roku device
- Set breakpoints in BrightScript code
- Inspect variables in real-time via port 8085

#### Telnet Console (Real-time Logging)
Connect to your Roku for live log output:
```bash
telnet <ROKU_IP> 8085
```

You'll see:
- Print statements from your code
- Runtime errors
- Texture memory warnings
- System messages

Press Ctrl+] then type `quit` to exit telnet.

#### BrightScript Profiler (quick checklist)
Performance profiling is enabled via `bsprof_enable=1` in the manifest.

1) Play a session on device (Express + Ultra if possible) until gameplay.
2) Exit the app to flush the `.bsprof` file.
3) Browse to `http://<ROKU_IP>/` and download the latest `.bsprof`.
4) Review top CPU functions; look for spikes in rendering, JSON parse, or object creation.
5) Re-run after fixes; target 60 FPS (16.6ms budget).

## Project Structure

```
roku-super-mario/
├── source/              # BrightScript source files
│   ├── Main.brs         # Entry point, game modes (menu/pause/options/gameover/countdown)
│   ├── RenderSystem.brs # Tile rendering + camera
│   ├── PhysicsSystem.brs# AABB + movement
│   ├── InputSystem.brs  # Remote input state
│   ├── EntityManager.brs# Player, coins, goombas, collisions
│   ├── AudioManager.brs # SFX/music + volume persistence
│   └── MenuSystem.brs   # Main menu rendering/logic
├── images/             # Graphics assets
│   ├── sprites/        # Character and entity sprites
│   ├── tiles/          # Tileset graphics
│   └── splash-fhd.png  # Splash screen (1920×1080)
├── levels/             # JSON level data
│   └── level-1-1.json
├── audio/              # Sound and music
│   ├── sfx/            # Sound effects (WAV)
│   └── music/          # Background music (WAV loop)
├── manifest            # Roku app configuration
├── PLAN.md            # Technical blueprint
└── IMPLEMENTATION_PLAN.md  # Step-by-step implementation guide
```

## Building and Running

### Deploy to Roku
```bash
# Package will be automatically deployed when using F5 in VS Code
# Or manually zip and upload via http://<ROKU_IP>/
```

### Manual Packaging
```bash
# Create a zip of all files
zip -r roku-super-mario.zip manifest source/ images/ audio/ levels/
# Upload via Roku developer web interface
```

## Technical Constraints

From the technical blueprint, key constraints respected:
- **game=1** in manifest for low-latency audio
- **Object pooling** to prevent garbage collection
- **Viewport culling** to reduce draw calls
- **Sub-pixel positioning** (Float logic, Int rendering)
- **Delta time** for frame-rate independence
- **Texture memory management** (no virtual paging)

## Performance Targets

- **60 FPS** on Roku Ultra (16.6ms frame budget)
- **50+ FPS** on Roku Express
- **Texture memory** under 80% capacity
- **Input latency** under 50ms

## Contributing

This is a learning project following the implementation plan. See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the current development roadmap.

## License

Educational project - see LICENSE file for details." 
