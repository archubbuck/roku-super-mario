# **Technical Blueprint for High-Performance Side-Scrolling Platformer Development on Roku OS**

## **1\. Executive Summary**

The development of a high-fidelity side-scrolling platformer, specifically modeling the mechanics of *Super Mario Bros.*, on the Roku operating system represents a distinct engineering challenge that diverges significantly from modern mobile or console development paradigms. While Roku devices are ubiquitous, powering millions of televisions globally, their primary architectural design focuses on video decoding rather than general-purpose computing or real-time rendering. Consequently, the creation of a twitch-response action game requires a disciplined rejection of high-level convenience frameworks in favor of low-level optimization and direct hardware management.

This report serves as an exhaustive architectural specification for building such an application. It analyzes the dichotomy between Roku’s modern SceneGraph framework and the legacy 2D API, providing a definitive recommendation for the latter based on thread synchronization requirements and input latency metrics. It details the construction of a custom game engine in BrightScript, the proprietary scripting language of the platform, covering essential subsystems including the game loop, delta-time calculation, tile-map rendering, AABB (Axis-Aligned Bounding Box) collision detection, and audio latency management.

Through a synthesis of technical documentation, developer community insights, and hardware specifications, this document outlines a roadmap for achieving a consistent 60 frames-per-second (FPS) experience. It addresses specific platform constraints such as texture memory limits, single-threaded execution models, and the "immiscible" nature of Roku’s display contexts. The following analysis provides the theoretical and practical foundation necessary to engineer a commercial-grade platformer on the Roku ecosystem.

## **2\. Platform Architecture and Hardware Constraints**

To engineer effective software, one must first understand the substrate upon which it runs. The Roku platform is not a monolithic hardware standard but a spectrum of devices ranging from high-performance set-top boxes to cost-effective HDMI sticks and integrated Smart TVs. Developing a game that functions across this disparity requires a "lowest common denominator" approach to architecture, particularly regarding memory management and processor throughput.

### **2.1 The Processor and Memory Landscape**

Roku devices predominantly utilize ARM-based System-on-Chip (SoC) architectures. While high-end models like the Roku Ultra feature quad-core ARM Cortex processors capable of substantial logic processing, entry-level devices such as the Roku Express utilize less powerful chipsets with limited cache sizes. For a game loop, this variation dictates that logic must be highly optimized; a physics calculation that consumes 2ms on an Ultra might consume 10ms on an Express, threatening the 16.6ms frame budget required for 60 FPS.1

Memory on Roku devices is strictly compartmentalized. Although a device specifications sheet might list 512MB or 1GB of RAM, the Operating System reserves a significant portion for the kernel, video buffer, and application sandbox. For game developers, the critical resource is **Texture Memory**. This is distinct from the heap memory used for variables and code. Texture memory stores the graphical assets (bitmaps) currently loaded for display. When an application exceeds the available texture memory, the OS kills the process immediately to preserve system stability, typically returning exit code EXIT\_CHANNEL\_MEM\_LIMIT\_FG.3

Implication for Design:  
A Super Mario clone cannot naively load all level assets at once. The engine must employ aggressive resource management strategies. Large background images must be reused or tiled, and sprite sheets should be optimized to minimize whitespace. The system does not support virtual memory paging for graphics; if the texture fits, it renders; if it does not, the app crashes. This binary failure state necessitates a robust asset manager that tracks video memory usage and unloads assets that pass out of the camera's viewport.4

### **2.2 The Operating System and Threading Model**

Roku OS is a customized Linux-based environment, but the developer's interaction with it is mediated entirely through BrightScript. The execution model is primarily single-threaded regarding the main application logic. While the OS handles video decoding and network operations on separate threads, the game loop—physics, input processing, and draw calls—executes sequentially on the main thread.

This single-threaded nature creates a "stop-the-world" risk. If the garbage collector runs, or if a complex loop takes too long, the entire application freezes. In a video app, buffering hides these hiccups. In a platformer, a 100ms freeze results in the player falling into a pit. Therefore, the architectural imperative is to minimize memory churn (creating and destroying objects) to prevent garbage collection spikes during gameplay.6

## **3\. Framework Selection: The "Immiscible" Dichotomy**

Roku provides two distinct APIs for visual rendering: **SceneGraph (RSG)** and the **2D API (roScreen)**. Choosing the correct framework is the most consequential architectural decision in the project lifecycle, as the two are fundamentally incompatible for simultaneous use.

### **3.1 Analysis of SceneGraph (RSG)**

SceneGraph is Roku’s modern, retained-mode UI framework. It utilizes an XML-based tree structure to define visual elements (Nodes) and separates the render thread from the main logic thread. This separation is advantageous for media applications, ensuring that UI animations remain smooth even if the main thread is blocking on a network request.7

However, for a high-precision platformer, SceneGraph introduces unacceptable non-deterministic latency.

* **Thread Synchronization Latency:** To move a sprite in SceneGraph, the main thread must modify a field on a Node. This change is then synchronized to the render thread. This asynchronous hand-off introduces a delay between the input processing (logic thread) and the visual update (render thread). In a game requiring frame-perfect jumps, this "floaty" feel is detrimental.8  
* **Event Overhead:** SceneGraph relies on an observer pattern for events. Triggering game logic through field observers incurs significant overhead compared to direct function calls.  
* **Input Polling:** SceneGraph is designed for navigation events (Up, Down, Select), not the rapid-fire polling required to detect if a "Jump" button is held down for variable jump height.

### **3.2 Analysis of the 2D API (roScreen)**

The roScreen component provides an immediate-mode rendering surface. It gives the developer direct access to the frame buffer (or double buffers) and places the burden of the render loop entirely on the developer.

* **Direct Control:** The developer explicitly calls SwapBuffers(). This function blocks execution until the next vertical blanking interval (V-Sync), allowing the application to synchronize perfectly with the display refresh rate (typically 60Hz).9  
* **Performance:** By bypassing the node tree and XML parsing, roScreen offers the raw throughput necessary to push thousands of pixels per frame. It is the legacy standard for all high-performance gaming on the platform.2  
* **Immiscibility:** The documentation describes these frameworks as "immiscible." A channel cannot overlay a SceneGraph UI on top of an roScreen game. One must be closed for the other to open. This means the entire gameplay session, including the Heads-Up Display (HUD), must be drawn using the 2D API.11

### **3.3 The Verdict**

Research consistently highlights that while SceneGraph is the "new hope" for general apps, roScreen remains the only viable option for "heavy animations where you care dearly about FPS".8 For a *Super Mario* clone, where gameplay feel is paramount, the architecture must be built upon roScreen. The following table summarizes the capability gap relevant to game development.

| Feature | SceneGraph (RSG) | 2D API (roScreen) |
| :---- | :---- | :---- |
| **Rendering Paradigm** | Retained Mode (Scene Tree) | Immediate Mode (Direct Draw) |
| **Threading** | Separate Render Thread | Single Main Thread |
| **Latency** | Asynchronous (Variable) | Synchronous (Deterministic) |
| **Input Handling** | Event Observers | Message Port Polling |
| **Collision Detection** | Not Native | Native (roSprite) / Custom |
| **Best Use Case** | Media UI, Simple Puzzles | Arcade Action, Platformers |

## **4\. The BrightScript Game Engine Architecture**

Building a game on Roku requires constructing a micro-engine from scratch using BrightScript. BrightScript is a powerful, dynamically typed bytecode-interpreted language that utilizes Associative Arrays (AAs) to simulate object-oriented behavior.

### **4.1 The Core Game Loop**

The heart of any game engine is the loop: a continuous cycle of reading input, updating state, and rendering frames. In roScreen development, this loop is driven by the vertical sync of the display.

**Standard Loop Structure:**

1. **Poll Input:** Check for user commands.  
2. **Calculate Time:** Determine how much time has passed since the last frame.  
3. **Update:** Advance the game state (physics, AI) based on elapsed time.  
4. **Render:** Draw the state to the back buffer.  
5. **Swap:** Flip the buffers to display the new frame.

Code snippet

Sub Main()  
    ' Initialization Phase  
    screen \= CreateObject("roScreen", true) ' Enable Double Buffering  
    port \= CreateObject("roMessagePort")  
    screen.SetMessagePort(port)  
      
    ' Timing Setup  
    clock \= CreateObject("roTimespan")  
    lastTime \= clock.TotalMilliseconds()  
      
    ' The Infinite Loop  
    while true  
        ' 1\. Time Calculation  
        currentTime \= clock.TotalMilliseconds()  
        deltaTime \= (currentTime \- lastTime) / 1000.0 ' Seconds  
        lastTime \= currentTime  
          
        ' 2\. Input Polling (Non-blocking)  
        msg \= port.GetMessage()   
        if type(msg) \= "roUniversalControlEvent" then  
            HandleInput(msg)  
        end if  
          
        ' 3\. State Update  
        UpdatePhysics(deltaTime)  
        UpdateEntities(deltaTime)  
        UpdateCamera()  
          
        ' 4\. Render Phase  
        screen.Clear(\&h000000FF) ' Clear background to black  
        RenderTileMap(screen)  
        RenderSprites(screen)  
          
        ' 5\. V-Sync Wait  
        screen.SwapBuffers()  
    end while  
End Sub

Ref: 9

### **4.2 Handling Delta Time and Frame Independence**

Roku devices have varying CPU speeds. A loop that increments a character's position by 1 pixel per frame will result in slow movement on an older device (running at 20 FPS) and fast movement on a new device (60 FPS). To solve this, movement must be defined in *units per second*, not *units per frame*.

Implementation:  
The roTimespan object measures system uptime in milliseconds. By capturing the timestamp at the start of each frame and comparing it to the previous frame, we derive deltaTime.

* **Formula:** NewPosition \= OldPosition \+ (Velocity \* deltaTime)  
* **Constraint:** If the frame rate drops significantly (e.g., below 15 FPS due to garbage collection), deltaTime becomes large, causing physics objects to teleport through walls (tunneling). A robust engine implements a "capped delta time" (e.g., never process more than 50ms at once) or a fixed time step accumulator to maintain physics stability.13

### **4.3 The "Fake OOP" Object Model**

BrightScript does not have classes. Instead, it uses Associative Arrays (AAs) to group data and functions. This resembles the prototype-based inheritance of JavaScript but requires manual setup.

Entity Component Structure:  
To manage complexity, the engine should define "Constructor Functions" that return AAs populated with entity data and methods.

Code snippet

Function CreateMario(x as Float, y as Float) as Object  
    this \= {  
        type: "Player",  
        x: x,  
        y: y,  
        vx: 0.0,  
        vy: 0.0,  
        width: 32,  
        height: 32,  
        isGrounded: false,  
        ' Methods  
        Update: Player\_Update,  
        Draw: Player\_Draw  
    }  
    return this  
End Function

Sub Player\_Update(dt as Float)  
    ' "m" refers to the AA ("this") context  
    m.vy \= m.vy \+ (GRAVITY\_CONSTANT \* dt)  
    m.x \= m.x \+ (m.vx \* dt)  
    '... collision logic...  
End Sub

This pattern allows the main loop to iterate over a list of generic objects and call .Update(dt) on each, maintaining polymorphism.15

## **5\. Input Processing Subsystem**

Input handling in a platformer requires low latency and state tracking. The Roku remote, however, is not a dedicated game controller. It communicates via IR (line-of-sight, lower latency) or Wi-Fi (robust, variable latency).

### **5.1 The Event Model**

The roMessagePort receives roUniversalControlEvent messages. These events distinguish between "Press" and "Release" actions, which is critical for mechanics like variable jump height (holding the button makes Mario jump higher).

Key Code Mapping:  
The engine must map Roku key codes to game actions.

* **Left (4) / Right (5):** Horizontal movement.  
* **Up (2) / A (6):** Jump.  
* **Down (3):** Crouch / Pipe interaction.  
* **Option (\*):** Pause menu.

State Machine:  
Because loop cycles are faster than input polling, the engine must store the state of buttons.

Code snippet

if msg.GetInt() \= 4 then InputState.Left \= true  ' Press  
if msg.GetInt() \= 104 then InputState.Left \= false ' Release

This allows the UpdatePhysics function to check if InputState.Left then ApplyForce() every frame, regardless of whether a new input message arrived that specific millisecond.16

### **5.2 Latency and the Manifest**

A critical, often undocumented requirement for gaming on Roku is the game attribute in the application manifest.

* **Attribute:** game=1  
* **Function:** This flag signals the OS to prioritize the audio subsystem buffer. Without it, sound effects (like a jump sound) can lag by 200-500ms relative to the input, destroying the "tight" feel of the game.  
* **Requirement:** This must be set in the manifest file at the root of the package.17

## **6\. The Graphics Pipeline: Tile Maps and Sprites**

A *Super Mario* level consists of two visual layers: the static environment (Tile Map) and the dynamic entities (Sprites). Rendering these efficiently is the primary bottleneck.

### **6.1 The Tile Map System**

Standard levels are grids of tiles. A level might be 200 tiles wide by 15 high. Drawing 3,000 tiles every frame is impossible on Roku hardware. The engine must implement **Viewport Culling**.

Data Structure:  
Levels are best stored as 2D arrays of integers.

* 0: Empty (Air)  
* 1: Ground Block  
* 2: Brick  
* 3: Question Block

Rendering Logic:  
The engine calculates which tiles are currently visible based on the camera position.

1. **Calculate Column Range:**  
   * StartCol \= Camera.x / TileWidth  
   * EndCol \= (Camera.x \+ ScreenWidth) / TileWidth  
2. Iterate and Draw:  
   Only loop through the 2D array from StartCol to EndCol. This reduces the draw calls from thousands to roughly 200-300 per frame, a number the roScreen can handle easily.6

Optimization Tip:  
For static backgrounds that do not change (e.g., the sky and distant hills), use a single large roBitmap or roRegion that scrolls slower than the foreground to create a Parallax Effect. This adds depth without the cost of drawing individual tiles.19

### **6.2 Sprite Management with roCompositor**

For moving objects, roCompositor is the standard tool. It manages a Z-ordered stack of sprites and handles the complex logic of "dirty rectangles"—redrawing the background behind a sprite when it moves.

* **Sprite Sheets:** Load animations as a single large bitmap (Texture Atlas). Use roRegion to define individual frames.  
* **Animation:** Cycle through roRegion objects on the sprite to animate Mario running or swimming.  
* **Compositor Setup:**  
  Code snippet  
  compositor \= CreateObject("roCompositor")  
  compositor.SetDrawTo(screen)  
  sprite \= compositor.NewSprite(x, y, region)

* **Performance:** roCompositor is optimized for sparse moving objects. Do not use it for the static tile map; use direct DrawObject calls for the grid to avoid overhead.10

### **6.3 Resolution Independence**

Roku devices output at 720p, 1080p (FHD), or 4K. The 2D API coordinate system defaults to the UI resolution set in the manifest (ui\_resolutions=fhd).

* **Recommendation:** Target 1080p (1920x1080) as the logical coordinate system. The Roku OS will automatically scale this down for 720p devices.  
* **Asset Management:** Provide asset sets for HD and FHD. Use the roFileSystem to detect the device resolution and load the appropriate sprite sheet to ensure crisp visuals without wasting memory on unnecessary 4K textures on a 720p display.21

## **7\. Physics and Collision Detection**

Roku lacks a built-in physics engine. We must implement **AABB (Axis-Aligned Bounding Box)** physics.

### **7.1 AABB Theory**

AABB checks if the non-rotated rectangles of two objects overlap.

Code snippet

Function CheckCollision(rectA, rectB) as Boolean  
    return (rectA.x \< rectB.x \+ rectB.w) AND \_  
           (rectA.x \+ rectA.w \> rectB.x) AND \_  
           (rectA.y \< rectB.y \+ rectB.h) AND \_  
           (rectA.y \+ rectA.h \> rectB.y)  
End Function

This simple check is fast enough to run dozens of times per frame.22

### **7.2 Tile-Based Collision Resolution**

Mario interacts with the grid. Instead of checking collision against every tile object, we calculate the grid coordinates of Mario's bounding box.

1. **Predictive Movement:** Move Mario along the X-axis.  
2. **Check Grid:** Calculate GridX \= Mario.x / TileSize. Look up LevelMap\[GridX\].  
3. **Resolve:** If the tile is solid (ID \> 0), snap Mario's position to the edge of the tile and stop velocity.  
4. **Repeat for Y-Axis:** This separation of axes prevents "corner snagging" where the character gets stuck on the corner of a block.23

### **7.3 Sub-Pixel Movement**

Physics calculations (Gravity, Friction) result in floating-point positions (e.g., x \= 100.45). However, roScreen draws at integer pixels.

* **Logic:** Store x and y as Floats in the entity object. Perform all physics math with Floats.  
* **Render:** Only convert to Integer (Int(x)) at the moment of drawing. This preserves the momentum and smooth acceleration curves that define the "Mario feel".24

## **8\. Audio Engineering for Games**

Audio on Roku is often an afterthought in documentation, but it is vital for games.

* **Sound Effects (SFX):** Use roAudioResource. This loads the audio data (WAV or IMA-ADPCM) into system RAM. It allows for low-latency triggering via the .Trigger() method.  
  * *Constraint:* RAM usage. Keep SFX short and mono.  
* **Background Music (BGM):** Use roAudioPlayer. This streams audio from storage (pkg) or network. It uses a buffer, so it has high latency for starting but uses minimal RAM.  
* **Concurrency:** Roku has limits on concurrent audio streams. Prioritize gameplay sounds (Jump, Die) over ambient effects.25

## **9\. Project Configuration and Manifest**

The manifest file is the entry point for the Roku OS configuration.

**Essential Manifest Attributes:**

| Attribute | Value | Description |
| :---- | :---- | :---- |
| title | Super Mario Clone | Display name |
| major\_version | 1 | Version tracking |
| game | 1 | **Critical for low-latency audio** |
| ui\_resolutions | fhd | Sets logical grid to 1920x1080 |
| splash\_screen\_fhd | pkg:/images/splash.png | Required for loading screen |
| bs\_libs\_required | roku\_ads\_lib | (Optional) If monetizing |

Ref: 17

## **10\. Performance Optimization Strategy**

To maintain 60 FPS, the engine must respect the limits of the hardware.

### **10.1 Garbage Collection Management**

BrightScript uses reference counting and a garbage collector (GC). Creating and destroying objects in the loop (e.g., bullet \= {x: 0, y:0}) generates "garbage." When the GC runs, it pauses the script.

* **Solution: Object Pooling.** Create a fixed array of "Bullet" objects at startup. When the player fires, find an inactive bullet in the pool and activate it. When it hits a wall, deactivate it. Never CreateObject during the game loop.6

### **10.2 BrightScript Profiler**

Roku provides a profiling tool that generates .bsprof files. These can be analyzed to see exactly which functions take the most CPU time.

* **Usage:** Add bsprof\_enable=1 to the manifest. Run the game. Close the game. Download the profile via the web interface.  
* **Common Bottlenecks:** DrawScaledObject (scaling is expensive), ParseJSON (parsing large level files), and string manipulation.27

## **11\. Debugging and Tooling**

Developing without tools is efficient.

* **VS Code Extension:** The "BrightScript Language" extension allows setting breakpoints, stepping through code, and inspecting variable states in real-time. It connects via the debug protocol port (8085).28  
* **Telnet Console:** Connecting to port 8085 via Telnet provides a raw log of print statements and runtime errors. This is essential for catching "Texture Memory Full" warnings before the app crashes.

## **12\. Conclusion**

Constructing a *Super Mario* clone on Roku requires a deliberate departure from the platform's standard UI frameworks. By utilizing the roScreen 2D API, implementing a custom delta-time game loop, and rigorously managing texture memory and object lifecycles, developers can achieve the high-performance, low-latency experience required for the platforming genre. The architecture detailed above provides a robust foundation for building not just a clone, but a scalable game engine capable of supporting complex mechanics on the Roku OS.

#### **Works cited**

1. Hardware or firmware differences & certification. \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/hardware-or-firmware-differences--certification-/498657](https://community.roku.com/discussions/developer/hardware-or-firmware-differences--certification-/498657)  
2. roScreen on Roku 3 locked to 20 fps, accessed December 30, 2025, [https://community.roku.com/discussions/developer/roscreen-on-roku-3-locked-to-20-fps/457456](https://community.roku.com/discussions/developer/roscreen-on-roku-3-locked-to-20-fps/457456)  
3. Development environment overview \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/getting-started/architecture/dev-environment.md](https://developer.roku.com/docs/developer-program/getting-started/architecture/dev-environment.md)  
4. Memory management \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md)  
5. System Texture Memory Requirements \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/system-texture-memory-requirements/833170](https://community.roku.com/discussions/developer/system-texture-memory-requirements/833170)  
6. Optimization techniques \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/performance-guide/optimization-techniques.md](https://developer.roku.com/docs/developer-program/performance-guide/optimization-techniques.md)  
7. SceneGraph core concepts \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/core-concepts/core-concepts.md](https://developer.roku.com/docs/developer-program/core-concepts/core-concepts.md)  
8. Confused about Scene Graph vs the older frameworks \- Roku Community, accessed December 30, 2025, [https://community.roku.com/t5/Developers/Confused-about-Scene-Graph-vs-the-older-frameworks/m-p/467005](https://community.roku.com/t5/Developers/Confused-about-Scene-Graph-vs-the-older-frameworks/m-p/467005)  
9. Sprites and Animations Using the 2D API, accessed December 30, 2025, [https://blog.roku.com/developer/2012/09/07/sprites-and-animations-using-the-2d-api](https://blog.roku.com/developer/2012/09/07/sprites-and-animations-using-the-2d-api)  
10. Confused about Scene Graph vs the older frameworks \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/confused-about-scene-graph-vs-the-older-frameworks/467004](https://community.roku.com/discussions/developer/confused-about-scene-graph-vs-the-older-frameworks/467004)  
11. Starting a roScreen from a SceneGraph component \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/starting-a-roscreen-from-a-scenegraph-component/410310](https://community.roku.com/discussions/developer/starting-a-roscreen-from-a-scenegraph-component/410310)  
12. Event loops | Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/core-concepts/event-loops.md](https://developer.roku.com/docs/developer-program/core-concepts/event-loops.md)  
13. Creating a fixed delta time javascript game loop, accessed December 30, 2025, [https://stephendoddtech.com/blog/game-design/fixed-delta-time-javascript-game-loop](https://stephendoddtech.com/blog/game-design/fixed-delta-time-javascript-game-loop)  
14. Why use a variable delta time in a physics game loop rather than a fixed time step? \- Reddit, accessed December 30, 2025, [https://www.reddit.com/r/gamedev/comments/uktah1/why\_use\_a\_variable\_delta\_time\_in\_a\_physics\_game/](https://www.reddit.com/r/gamedev/comments/uktah1/why_use_a_variable_delta_time_in_a_physics_game/)  
15. BrightScript 3.0 Reference \- BrightSign™ Network, accessed December 30, 2025, [http://www.brightsignnetwork.com/download/XD\_Beta/BrightScript\_Reference\_Manual\_3.0\_draft.pdf](http://www.brightsignnetwork.com/download/XD_Beta/BrightScript_Reference_Manual_3.0_draft.pdf)  
16. \[Solved\] Continuous button press \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/solved-continuous-button-press/419342](https://community.roku.com/discussions/developer/solved-continuous-button-press/419342)  
17. Manifest file | Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/getting-started/architecture/channel-manifest.md](https://developer.roku.com/docs/developer-program/getting-started/architecture/channel-manifest.md)  
18. Roku OS developer release notes, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/release-notes/roku-os-release-notes.md](https://developer.roku.com/docs/developer-program/release-notes/roku-os-release-notes.md)  
19. ZeroDayArcade/HTML5\_Platformer: Building a 2D side-scrolling platform game in HTML5 from scratch. \- GitHub, accessed December 30, 2025, [https://github.com/ZeroDayArcade/HTML5\_Platformer](https://github.com/ZeroDayArcade/HTML5_Platformer)  
20. scrolling in roScreen, roBitmap, roRegion, roCompositor \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/scrolling-in-roscreen-robitmap-roregion-rocompositor/418697](https://community.roku.com/discussions/developer/scrolling-in-roscreen-robitmap-roregion-rocompositor/418697)  
21. Specifying display resolution \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/core-concepts/specifying-display-resolution.md](https://developer.roku.com/docs/developer-program/core-concepts/specifying-display-resolution.md)  
22. How can I perform 2D side-scroller collision checks in a tile-based map?, accessed December 30, 2025, [https://gamedev.stackexchange.com/questions/58443/how-can-i-perform-2d-side-scroller-collision-checks-in-a-tile-based-map](https://gamedev.stackexchange.com/questions/58443/how-can-i-perform-2d-side-scroller-collision-checks-in-a-tile-based-map)  
23. Array-based tilemaps and bounding box (aabb?), how to do efficient tile collisions?, accessed December 30, 2025, [https://gamedev.stackexchange.com/questions/145095/array-based-tilemaps-and-bounding-box-aabb-how-to-do-efficient-tile-collisio](https://gamedev.stackexchange.com/questions/145095/array-based-tilemaps-and-bounding-box-aabb-how-to-do-efficient-tile-collisio)  
24. INT Conversion \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/int-conversion/667257](https://community.roku.com/discussions/developer/int-conversion/667257)  
25. roAudioResource volume level discrepency \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/roaudioresource-volume-level-discrepency/234089](https://community.roku.com/discussions/developer/roaudioresource-volume-level-discrepency/234089)  
26. How to query sound effects volume setting? \- Roku Community, accessed December 30, 2025, [https://community.roku.com/discussions/developer/how-to-query-sound-effects-volume-setting/213439](https://community.roku.com/discussions/developer/how-to-query-sound-effects-volume-setting/213439)  
27. BrightScript Profiler \- Roku Developer, accessed December 30, 2025, [https://developer.roku.com/docs/developer-program/dev-tools/brightscript-profiler.md](https://developer.roku.com/docs/developer-program/dev-tools/brightscript-profiler.md)  
28. launch.json \- vscode-brightscript-language \- GitHub, accessed December 30, 2025, [https://github.com/rokucommunity/vscode-brightscript-language/blob/master/.vscode/launch.json](https://github.com/rokucommunity/vscode-brightscript-language/blob/master/.vscode/launch.json)  
29. How can install roku SDK and how can I use VS code extension to build my own roku channel?, accessed December 30, 2025, [https://community.roku.com/discussions/developer/how-can-install-roku-sdk-and-how-can-i-use-vs-code-extension-to-build-my-own-rok/906232](https://community.roku.com/discussions/developer/how-can-install-roku-sdk-and-how-can-i-use-vs-code-extension-to-build-my-own-rok/906232)