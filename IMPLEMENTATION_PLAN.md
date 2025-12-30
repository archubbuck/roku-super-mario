# Super Mario Clone for Roku - Implementation Plan

## Project Overview

Build a high-performance side-scrolling platformer on Roku using the roScreen 2D API exclusively, implementing a custom game engine in BrightScript with 60 FPS gameplay, tile-based collision detection, placeholder programmer art, and comprehensive debugging setup for iterative development.

## Architecture Decisions

Based on the technical blueprint in [PLAN.md](PLAN.md), the following architectural decisions have been made:

1. **Menu System**: Build entire menu system in roScreen using bitmap buttons and manual rendering for consistency
2. **Level Format**: Start with simple 2D integer arrays in JSON for rapid prototyping
3. **Asset Strategy**: Create placeholder programmer art for initial development and focus on engine mechanics first
4. **Development Tooling**: Configure VS Code BrightScript extension with launch.json for breakpoint debugging

## Implementation Steps

### Step 1: Configure Development Tooling and Workspace
**Goal**: Set up comprehensive debugging and development environment

**Tasks**:
- Install BrightScript Language extension in VS Code
- Create `.vscode/launch.json` with debug configuration for port 8085 breakpoint debugging
- Set up Telnet console access for real-time logging
- Create `.gitignore` excluding `*.pkg`, `out/`, and `.bsprof` files

**Technical Details**:
- Debug protocol port: 8085
- Telnet connection for log streaming
- BrightScript profiler enabled via manifest

**Deliverables**:
- `.vscode/launch.json`
- `.gitignore`

---

### Step 2: Initialize Project Structure with Manifest
**Goal**: Create proper Roku application structure with optimized manifest configuration

**Tasks**:
- Create `manifest` file with critical gaming attributes
- Establish directory structure for source, assets, levels, and audio
- Configure resolution targeting and splash screens

**Technical Details**:
- `game=1` - Critical for low-latency audio (reduces 200-500ms input lag)
- `ui_resolutions=fhd` - Target 1920×1080 logical coordinate system
- `bsprof_enable=1` - Enable performance profiling
- Directory structure:
  - `source/` - All BrightScript (.brs) files
  - `images/sprites/` - Character and entity sprites
  - `images/tiles/` - Tileset graphics
  - `levels/` - JSON level data files
  - `audio/sfx/` - Sound effect WAV files
  - `audio/music/` - Background music files

**Deliverables**:
- `manifest`
- Directory structure

---

### Step 3: Create Placeholder Programmer Art Assets
**Goal**: Generate minimal viable graphics for engine testing without investing in polished art

**Tasks**:
- Create simple geometric placeholder sprites (colored rectangles)
- Generate basic tileset with distinct colors for different tile types
- Create required splash screen

**Asset Specifications**:
- **Mario sprites**: 32×32px colored rectangles
  - Idle: Blue rectangle
  - Run frames: Blue with white stripe
  - Jump: Blue rotated appearance
- **Enemy sprites**: 32×32px
  - Goomba: Brown rectangle
  - Koopa: Green rectangle
- **Item sprites**: 16×16px
  - Coin: Yellow circle
  - Power-up: Red rectangle
- **Tileset**: 32×32px tiles
  - Ground (ID=1): Brown solid color
  - Brick (ID=2): Orange solid color
  - Question Block (ID=3): Yellow solid color with "?" text
- **Splash screen**: 1920×1080px solid color with title text

**Deliverables**:
- `images/sprites/mario-placeholder.png`
- `images/sprites/enemies-placeholder.png`
- `images/sprites/items-placeholder.png`
- `images/tiles/tileset-placeholder-fhd.png`
- `images/splash-fhd.png`

---

### Step 4: Implement Core Game Loop with roScreen
**Goal**: Build the fundamental game loop architecture with delta time and V-sync

**Tasks**:
- Create `Main()` entry point function
- Initialize roScreen with double buffering
- Set up roMessagePort for input handling
- Implement delta time calculation with roTimespan
- Create V-sync loop with SwapBuffers()
- Add frame time capping (50ms max) to prevent physics tunneling

**Code Structure**:
```brightscript
Sub Main()
    ' Initialize roScreen with double buffering
    screen = CreateObject("roScreen", true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    
    ' Timing setup
    clock = CreateObject("roTimespan")
    lastTime = clock.TotalMilliseconds()
    
    ' Main game loop
    while true
        ' Calculate delta time (capped at 50ms)
        currentTime = clock.TotalMilliseconds()
        deltaTime = (currentTime - lastTime) / 1000.0
        if deltaTime > 0.05 then deltaTime = 0.05
        lastTime = currentTime
        
        ' Input polling
        msg = port.GetMessage()
        if type(msg) = "roUniversalControlEvent" then
            HandleInput(msg)
        end if
        
        ' Update game state
        UpdateGame(deltaTime)
        
        ' Render
        screen.Clear(&h000000FF)
        RenderGame(screen)
        screen.SwapBuffers()
    end while
End Sub
```

**Performance Targets**:
- 60 FPS (16.6ms frame budget)
- Delta time capped at 50ms to prevent tunneling
- Non-blocking input polling

**Deliverables**:
- `source/Main.brs`

---

### Step 5: Build roScreen-based Menu System
**Goal**: Create fully functional menu system using manual bitmap rendering

**Tasks**:
- Design menu state machine (Main Menu, Options, Gameplay)
- Render bitmap-based buttons using DrawObject()
- Implement manual cursor navigation with directional keys
- Handle button state tracking (normal, highlighted, selected)
- Create transition logic to gameplay state

**Menu Structure**:
```
Main Menu
├── Start Game
├── Options
└── Quit
```

**Input Mapping**:
- Up/Down (2/3): Navigate menu items
- OK/Select (6): Activate highlighted item
- Back (0): Return to previous menu

**Technical Implementation**:
- Store button positions as Associative Arrays
- Track current selection index
- Render highlighted button with different color/border
- Use direct roScreen DrawObject() calls (no SceneGraph)

**Deliverables**:
- `source/MenuSystem.brs`

---

### Step 6: Develop Rendering System with Viewport Culling
**Goal**: Build efficient tile map and sprite rendering with viewport optimization

**Tasks**:
- Implement viewport culling for tile map
- Set up roCompositor for sprite management
- Create roRegion system for animation frames
- Add parallax background scrolling
- Implement camera system with smooth scrolling

**Viewport Culling Algorithm**:
```brightscript
' Calculate visible tile range
startCol = Int(cameraX / TILE_WIDTH)
endCol = Int((cameraX + SCREEN_WIDTH) / TILE_WIDTH) + 1
startRow = Int(cameraY / TILE_HEIGHT)
endRow = Int((cameraY + SCREEN_HEIGHT) / TILE_HEIGHT) + 1

' Only render visible tiles
for row = startRow to endRow
    for col = startCol to endCol
        tileId = levelMap[row][col]
        if tileId > 0 then
            DrawTile(screen, tileId, col, row, cameraX, cameraY)
        end if
    end for
end for
```

**Rendering Layers**:
1. Background (parallax, scrolls at 0.5x speed)
2. Tile map (foreground, scrolls at 1.0x speed)
3. Sprites (entities via roCompositor)
4. HUD (fixed position, no scrolling)

**Deliverables**:
- `source/RenderSystem.brs`

---

### Step 7: Build AABB Physics and Collision Detection
**Goal**: Implement robust collision detection and physics simulation

**Tasks**:
- Create AABB collision checking function
- Implement tile-based grid collision resolution
- Add gravity and velocity systems
- Handle sub-pixel movement (Float logic, Int rendering)
- Implement separate X/Y axis collision resolution

**AABB Collision Function**:
```brightscript
Function CheckAABB(rectA, rectB) as Boolean
    return (rectA.x < rectB.x + rectB.w) AND _
           (rectA.x + rectA.w > rectB.x) AND _
           (rectA.y < rectB.y + rectB.h) AND _
           (rectA.y + rectA.h > rectB.y)
End Function
```

**Tile Collision Algorithm**:
1. Apply X velocity to player position
2. Check grid collision on X axis
3. Resolve X collision (snap to tile edge, zero X velocity)
4. Apply Y velocity to player position
5. Check grid collision on Y axis
6. Resolve Y collision (snap to tile edge, zero Y velocity, set grounded flag)

**Physics Constants**:
- Gravity: 1200 pixels/second²
- Max fall speed: 600 pixels/second
- Jump velocity: -400 pixels/second
- Walk speed: 180 pixels/second
- Run speed: 300 pixels/second

**Deliverables**:
- `source/PhysicsSystem.brs`

---

### Step 8: Create Entity System with Object Pooling
**Goal**: Build efficient entity management system preventing garbage collection

**Tasks**:
- Design entity constructor functions returning Associative Arrays
- Implement entity pools (pre-allocated arrays)
- Create Update() and Draw() methods for entities
- Build animation state machines
- Implement entity activation/deactivation system

**Entity Constructor Pattern**:
```brightscript
Function CreateMario(x as Float, y as Float) as Object
    this = {
        type: "Player"
        x: x
        y: y
        vx: 0.0
        vy: 0.0
        width: 32
        height: 32
        isGrounded: false
        isActive: true
        animFrame: 0
        animTime: 0.0
        facing: 1  ' 1 = right, -1 = left
        
        ' Methods
        Update: Entity_PlayerUpdate
        Draw: Entity_PlayerDraw
    }
    return this
End Function
```

**Object Pooling Strategy**:
- Allocate entity pools at startup (no CreateObject during gameplay)
- Goomba pool: 20 objects
- Koopa pool: 10 objects
- Coin pool: 50 objects
- Power-up pool: 5 objects

**Entity Types**:
- Player (Mario)
- Enemies (Goomba, Koopa)
- Items (Coin, Mushroom, Fire Flower)
- Projectiles (Fireball)

**Deliverables**:
- `source/EntityManager.brs`

---

### Step 9: Implement Input Handling with State Tracking
**Goal**: Build low-latency input system with button state persistence

**Tasks**:
- Process roUniversalControlEvent messages
- Track button press/release states
- Map Roku remote keys to game actions
- Enable variable jump height mechanics
- Persist input state across frames

**Roku Remote Key Mapping**:
```
Key Code Mapping:
- Left:  4 (press), 104 (release)
- Right: 5 (press), 105 (release)
- Up:    2 (press), 102 (release)
- Down:  3 (press), 103 (release)
- OK:    6 (press), 106 (release)
- Back:  0 (press), 100 (release)
- Star:  10 (press), 110 (release)
```

**Input State Structure**:
```brightscript
inputState = {
    left: false
    right: false
    jump: false
    down: false
    run: false
}
```

**Variable Jump Mechanics**:
- Detect jump button press → apply jump velocity
- While jump button held AND player moving upward → maintain upward momentum
- When jump button released → reduce upward velocity for shorter jump

**Deliverables**:
- `source/InputSystem.brs`

---

### Step 10: Design Simple JSON Level Format and Loader
**Goal**: Create level data format and loading system with memory management

**Tasks**:
- Design JSON level structure with 2D integer arrays
- Implement ParseJSON() level loading
- Create tile ID to sprite mapping
- Build dynamic asset loading/unloading based on viewport
- Handle texture memory constraints

**Level JSON Format**:
```json
{
  "name": "World 1-1",
  "width": 200,
  "height": 15,
  "tileSize": 32,
  "tiles": [
    [0, 0, 0, 0, 0, 0, ...],
    [0, 0, 0, 0, 0, 0, ...],
    ...
    [1, 1, 1, 1, 1, 1, ...]
  ],
  "entities": [
    {"type": "goomba", "x": 320, "y": 352},
    {"type": "coin", "x": 400, "y": 200}
  ]
}
```

**Tile ID Mapping**:
- 0: Air (no collision, no render)
- 1: Ground block (solid, brown)
- 2: Brick (solid, breakable, orange)
- 3: Question block (solid, interactive, yellow)
- 4: Pipe top (solid, green)
- 5: Pipe body (solid, green)

**Memory Management Strategy**:
- Load only currently visible level section
- Unload tiles outside viewport buffer zone (2 screens left/right)
- Track texture memory usage via roDeviceInfo
- Emergency unload if approaching memory limit

**Deliverables**:
- `source/LevelManager.brs`
- `levels/level-1-1.json` (test level)

---

### Step 11: Build Audio System with Low-Latency SFX
**Goal**: Implement responsive audio system leveraging game=1 manifest setting

**Tasks**:
- Set up roAudioResource for sound effects
- Configure roAudioPlayer for background music
- Implement sound priority system
- Handle concurrent audio stream limits
- Pre-load all SFX at startup

**Audio Components**:

**Sound Effects (roAudioResource)**:
- Jump: Short beep sound (50ms)
- Coin: Bright chime (100ms)
- Stomp: Thud sound (80ms)
- Die: Descending tone (500ms)
- Power-up: Ascending melody (1000ms)

**Background Music (roAudioPlayer)**:
- Overworld theme (looping)
- Underground theme (looping)
- Castle theme (looping)

**Audio Manager Structure**:
```brightscript
audioManager = {
    sfxPool: {}  ' Pre-loaded roAudioResource objects
    musicPlayer: invalid
    currentMusic: ""
    
    PlaySFX: AudioManager_PlaySFX
    PlayMusic: AudioManager_PlayMusic
    StopMusic: AudioManager_StopMusic
}
```

**Concurrent Audio Limits**:
- Max 4 simultaneous audio streams on Roku
- Priority: SFX > Music > Ambient
- If limit reached, cancel lowest priority sound

**Technical Requirements**:
- All SFX must be mono, WAV or IMA-ADPCM format
- Keep SFX files under 100KB each
- Music can be stereo MP3/AAC, streaming from pkg:/

**Deliverables**:
- `source/AudioManager.brs`
- `audio/sfx/` (placeholder audio files)

---

### Step 12: Profile and Optimize Performance
**Goal**: Ensure 60 FPS performance across all Roku device tiers

**Tasks**:
- Enable BrightScript profiler and generate .bsprof files
- Analyze CPU time per function
- Verify object pooling eliminates mid-game allocations
- Test delta time frame-rate independence
- Optimize rendering bottlenecks
- Monitor texture memory usage

**Profiling Workflow**:
1. Add `bsprof_enable=1` to manifest (already done in Step 2)
2. Run game on Roku device
3. Play through test level
4. Close application
5. Download .bsprof file via Roku web interface (http://roku-ip/)
6. Analyze results for bottlenecks

**Common Bottlenecks to Avoid**:
- `DrawScaledObject()` - Scaling is expensive, use pre-scaled assets
- `ParseJSON()` - Parse once at level load, not every frame
- String concatenation - Use string builder pattern or pre-format
- Object creation - Use object pools exclusively

**Performance Metrics**:
- Target: 60 FPS (16.6ms/frame)
- Acceptable: 50 FPS (20ms/frame) on Roku Express
- Texture Memory: Stay under 80% capacity

**Testing Checklist**:
- [ ] Game runs at 60 FPS on Roku Ultra
- [ ] Game runs at 50+ FPS on Roku Express
- [ ] No garbage collection spikes during gameplay
- [ ] Delta time prevents speed variations across devices
- [ ] Texture memory stays below 80% usage
- [ ] Input latency under 50ms (game=1 working)
- [ ] No visible tearing (V-sync working)
- [ ] Collision detection prevents wall clipping
- [ ] Physics feels consistent (Mario "feel")

**Deliverables**:
- Performance analysis report
- Optimized codebase
- .bsprof files for reference

---

## Development Milestones

### Milestone 1: Development Environment (Steps 1-3)
- Tooling configured
- Project structure created
- Placeholder assets ready

### Milestone 2: Core Engine (Steps 4-7)
- Game loop functional
- Menu system working
- Rendering pipeline operational
- Physics system implemented

### Milestone 3: Game Logic (Steps 8-11)
- Entities functional
- Input responsive
- Levels loading
- Audio playing

### Milestone 4: Polish & Performance (Step 12)
- Profiling complete
- Performance optimized
- 60 FPS achieved

---

## Critical Technical Constraints

From [PLAN.md](PLAN.md), these constraints must be respected throughout implementation:

1. **Texture Memory Limits**: Roku OS kills app immediately if texture memory exceeded (EXIT_CHANNEL_MEM_LIMIT_FG)
2. **Single-Threaded Execution**: All game logic runs on main thread; avoid garbage collection during gameplay
3. **roScreen Only**: SceneGraph and roScreen are "immiscible" - cannot be mixed
4. **game=1 Required**: Manifest attribute critical for low-latency audio (prevents 200-500ms lag)
5. **V-Sync Mandatory**: SwapBuffers() must be called to synchronize with 60Hz display
6. **Delta Time Essential**: Frame-rate independence required for Roku Express (20 FPS) vs Ultra (60 FPS)
7. **Object Pooling Mandatory**: Pre-allocate all entities at startup to prevent GC pauses
8. **Viewport Culling Required**: Cannot render entire level - only visible portion
9. **Sub-Pixel Movement**: Float positions for physics, Int conversion only at render time
10. **Separate Axis Collision**: Resolve X and Y collisions independently to prevent corner snagging

---

## Next Actions

Begin with **Step 1**: Configure development tooling and workspace setup.