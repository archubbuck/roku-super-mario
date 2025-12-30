' *****************************************************
' Super Mario Clone for Roku - Main Entry Point
' Implements core game loop with roScreen 2D API
' Integrates all game systems
' *****************************************************

Sub Main()
    ' =========================================
    ' INITIALIZATION
    ' =========================================
    print "============================================"
    print "SUPER MARIO CLONE FOR ROKU"
    print "Target: 60 FPS (16.6ms frame budget)"
    print "============================================"
    
    ' Initialize the screen with double buffering enabled
    screen = CreateObject("roScreen", true)
    screen.SetAlphaEnable(true)  ' Enable alpha blending for sprites
    
    ' Create message port for input handling
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    
    ' Timing setup for delta time calculation
    clock = CreateObject("roTimespan")
    clock.Mark()  ' Start the timer
    lastTime = 0.0
    
    ' =========================================
    ' LOAD LEVEL LIST AND DEFAULT LEVEL
    ' =========================================
    levelList = [
        { name: "1-1", path: "pkg:/levels/level-1-1.json" },
        { name: "1-2", path: "pkg:/levels/level-1-2.json" },
        { name: "1-3", path: "pkg:/levels/level-1-3.json" }
    ]
    levelIndex = 0
    levelData = LoadLevelData(levelList[levelIndex].path)
    if levelData = invalid then
        print "ERROR: Failed to load level data!"
        return
    end if
    print "Level loaded: " + levelData.name
    print "Dimensions: " + str(levelData.width) + "x" + str(levelData.height)
    
    ' =========================================
    ' INITIALIZE GAME SYSTEMS
    ' =========================================
    print "Initializing game systems..."
    
    ' Input system
    inputState = InitInputSystem()
    print "✓ Input system ready"
    
    ' Rendering system
    renderer = CreateRenderSystem()
    renderer.Init()
    print "✓ Rendering system ready"
    
    ' Entity manager
    entityManager = CreateEntityManager()
    ' Spawn Mario at starting position (tile 5, ground level - 1)
    startX = 5.0 * 32  ' 5 tiles from left
    startY = 12.0 * 32  ' Above ground (ground is row 14)
    entityManager.Init(startX, startY, levelData)
    print "✓ Entity manager ready"

    ' Audio manager (SFX + music)
    audioManager = CreateAudioManager()
    audioManager.Init()
    audioManager.PlayMusic("overworld")
    print "✓ Audio manager ready"

    ' Menu system
    menu = CreateMenuSystem()
    menu.Init()
    print "✓ Menu system ready"
    
    ' =========================================
    ' GAME STATE
    ' =========================================
    gameState = {
        screen: screen
        port: port
        clock: clock
        running: true
        deltaTime: 0.0
        frameCount: 0
        fpsDisplay: 60
        fpsUpdateTimer: 0.0
        mode: "menu"  ' menu or game
        requestReset: false
        spawnX: startX
        spawnY: startY
        countdownTime: 0.0
        
        ' Systems
        inputState: inputState
        renderer: renderer
        entityManager: entityManager
        levelData: levelData
        audioManager: audioManager
        menu: menu
        pauseMenu: { items: ["Resume", "Options", "Quit to Menu"], selected: 0 }
        optionsMenu: { items: ["Music Volume", "SFX Volume", "Back"], selected: 0 }
        optionsReturnMode: "menu"
        gameOverMenu: { items: ["Restart", "Menu"], selected: 0 }
        levelList: levelList
        levelIndex: levelIndex
        levelCompleteTimer: 0.0
        levelCompletePlayed: false
        
        ' Notification system
        notificationText: ""
        notificationTimer: 0.0
        notificationDuration: 2.0  ' Show notification for 2 seconds
    }
    menu.UpdateLevelLabel(gameState)
    menu.UpdateLevelLabel(gameState)
    
    print "============================================"
    print "GAME STARTED"
    print "Controls: Arrow keys = Move, OK/Up = Jump"
    print "          * = Run,  Back = Exit"
    print "============================================"
    
    ' =========================================
    ' MAIN GAME LOOP
    ' =========================================
    while gameState.running
        ' 1. CALCULATE DELTA TIME
        currentTime = clock.TotalMilliseconds() / 1000.0  ' Convert to seconds
        gameState.deltaTime = currentTime - lastTime
        
        ' Cap delta time at 50ms (0.05 seconds) to prevent physics tunneling
        if gameState.deltaTime > 0.05 then
            gameState.deltaTime = 0.05
            ' Only print warning occasionally to avoid spam
            if gameState.frameCount mod 60 = 0 then
                print "WARNING: Frame time capped! Running slow."
            end if
        end if
        
        lastTime = currentTime
        gameState.frameCount = gameState.frameCount + 1
        
        ' 2. HANDLE INPUT (Non-blocking)
        ProcessInput(gameState)

        ' Reset level when requested (e.g., new game from menu)
        if gameState.requestReset then
            ResetLevel(gameState)
            gameState.requestReset = false
        end if

        ' Menu state: render menu and skip gameplay updates
        if gameState.mode = "menu" then
            renderer.Clear(screen)
            gameState.menu.Render(screen, renderer)
            screen.SwapBuffers()
            continue while
        end if

        ' Countdown state: render scene with countdown overlay
        if gameState.mode = "countdown" then
            RenderGame(gameState)
            DrawCountdownOverlay(screen, gameState)
            screen.SwapBuffers()
            gameState.countdownTime = gameState.countdownTime - gameState.deltaTime
            if gameState.countdownTime <= 0 then
                gameState.mode = "game"
            end if
            continue while
        end if

        ' Pause state: render current frame with overlay, skip updates
        if gameState.mode = "pause" then
            RenderGame(gameState)
            DrawPauseOverlay(screen, gameState)
            screen.SwapBuffers()
            continue while
        end if

        ' Options state: render options and skip gameplay updates
        if gameState.mode = "options" then
            renderer.Clear(screen)
            DrawOptionsOverlay(screen, gameState)
            screen.SwapBuffers()
            continue while
        end if

        ' Game over state: show overlay and wait for input
        if gameState.mode = "gameover" then
            RenderGame(gameState)
            DrawGameOverOverlay(screen, gameState)
            screen.SwapBuffers()
            continue while
        end if

        ' Level complete state: show overlay and auto-advance
        if gameState.mode = "levelcomplete" then
            RenderGame(gameState)
            DrawLevelCompleteOverlay(screen, gameState)
            screen.SwapBuffers()
            gameState.levelCompleteTimer = gameState.levelCompleteTimer - gameState.deltaTime
            if gameState.levelCompleteTimer <= 0 then
                AdvanceLevel(gameState)
            end if
            continue while
        end if
        
        ' 3. UPDATE GAME STATE
        UpdateGame(gameState)
        
        ' 4. RENDER FRAME
        RenderGame(gameState)
        
        ' 5. SWAP BUFFERS (V-Sync)
        screen.SwapBuffers()
    end while
    
    ' Cleanup
    print "============================================"
    print "GAME ENDED"
    print "Total frames rendered: " + str(gameState.frameCount)
    totalTime = clock.TotalMilliseconds() / 1000.0
    avgFps = gameState.frameCount / totalTime
    print "Average FPS: " + str(Int(avgFps))
    print "============================================"
End Sub


' *****************************************************
' Handle pause menu input
' *****************************************************
Sub HandlePauseInput(event as Object, gameState as Object)
    if type(event) <> "roUniversalControlEvent" then return
    if event.GetIndex() <> 1 then return  ' press only

    key = event.GetInt()
    itemsCount = gameState.pauseMenu.items.Count()

    if key = gameState.inputState.KEY_UP then
        gameState.pauseMenu.selected = (gameState.pauseMenu.selected - 1 + itemsCount) MOD itemsCount
    else if key = gameState.inputState.KEY_DOWN then
        gameState.pauseMenu.selected = (gameState.pauseMenu.selected + 1) MOD itemsCount
    else if key = gameState.inputState.KEY_OK OR key = gameState.inputState.KEY_BACK then
        choice = gameState.pauseMenu.items[gameState.pauseMenu.selected]
        if choice = "Resume" OR key = gameState.inputState.KEY_BACK then
            gameState.mode = "game"
        else if choice = "Options" then
            gameState.optionsReturnMode = "pause"
            gameState.optionsMenu.selected = 0
            gameState.mode = "options"
        else if choice = "Quit to Menu" then
            gameState.requestReset = true
            gameState.mode = "menu"
        end if
    end if
End Sub


' *****************************************************
' Draw pause overlay on top of current frame
' *****************************************************
Sub DrawPauseOverlay(screen as Object, gameState as Object)
    overlay = CreateObject("roBitmap", {width: 500, height: 300, AlphaEnable: true})
    overlay.Clear(&h000000AA)
    screen.DrawObject((gameState.renderer.SCREEN_WIDTH - 500) / 2, 260, overlay)

    font = CreateObject("roFont", "font:MediumBoldSystemFont", 48, false)
    smallFont = CreateObject("roFont", "font:MediumBoldSystemFont", 32, false)

    title = "Paused"
    tW = font.GetOneLineWidth(title)
    screen.DrawText(title, (gameState.renderer.SCREEN_WIDTH - tW) / 2, 320, &hFFFFFFFF, font)

    startY = 380
    spacing = 70
    for i = 0 to gameState.pauseMenu.items.Count() - 1
        label = gameState.pauseMenu.items[i]
        w = smallFont.GetOneLineWidth(label)
        x = (gameState.renderer.SCREEN_WIDTH - w) / 2
        y = startY + (i * spacing)
        if i = gameState.pauseMenu.selected then
            screen.DrawRect(x - 40, y - 20, w + 80, 60, &h2E74FFFF)
        end if
        screen.DrawText(label, x, y, &hFFFFFFFF, smallFont)
    end for
End Sub


' *****************************************************
' Draw countdown overlay (3-2-1-Go)
' *****************************************************
Sub DrawCountdownOverlay(screen as Object, gameState as Object)
    overlay = CreateObject("roBitmap", {width: 400, height: 240, AlphaEnable: true})
    overlay.Clear(&h00000088)
    screen.DrawObject((gameState.renderer.SCREEN_WIDTH - 400) / 2, 300, overlay)

    font = CreateObject("roFont", "font:MediumBoldSystemFont", 96, false)
    num = Int(gameState.countdownTime) + 1
    if num < 1 then num = 1
    if num > 3 then num = 3
    text = str(num)
    tW = font.GetOneLineWidth(text)
    screen.DrawText(text, (gameState.renderer.SCREEN_WIDTH - tW) / 2, 420, &hFFFFFFFF, font)
End Sub


' *****************************************************
' Handle options input (volume controls)
' *****************************************************
Sub HandleOptionsInput(event as Object, gameState as Object)
    if type(event) <> "roUniversalControlEvent" then return
    if event.GetIndex() <> 1 then return  ' press only

    key = event.GetInt()
    itemsCount = gameState.optionsMenu.items.Count()

    if key = gameState.inputState.KEY_UP then
        gameState.optionsMenu.selected = (gameState.optionsMenu.selected - 1 + itemsCount) MOD itemsCount
    else if key = gameState.inputState.KEY_DOWN then
        gameState.optionsMenu.selected = (gameState.optionsMenu.selected + 1) MOD itemsCount
    else if key = gameState.inputState.KEY_LEFT OR key = gameState.inputState.KEY_RIGHT then
        change = 0
        if key = gameState.inputState.KEY_LEFT then change = -5 else change = 5
        label = gameState.optionsMenu.items[gameState.optionsMenu.selected]
        if label = "Music Volume" then
            vol = gameState.audioManager.defaultMusicVolume + change
            if vol < 0 then vol = 0 else if vol > 100 then vol = 100
            gameState.audioManager.SetMusicVolume(vol)
        else if label = "SFX Volume" then
            vol = gameState.audioManager.defaultSfxVolume + change
            if vol < 0 then vol = 0 else if vol > 100 then vol = 100
            gameState.audioManager.SetSFXVolume(vol)
        end if
    else if key = gameState.inputState.KEY_OK OR key = gameState.inputState.KEY_BACK then
        label = gameState.optionsMenu.items[gameState.optionsMenu.selected]
        if label = "Back" OR key = gameState.inputState.KEY_BACK then
            gameState.mode = gameState.optionsReturnMode
        end if
    end if
End Sub


' *****************************************************
' Draw options overlay
' *****************************************************
Sub DrawOptionsOverlay(screen as Object, gameState as Object)
    overlay = CreateObject("roBitmap", {width: 700, height: 400, AlphaEnable: true})
    overlay.Clear(&h000000AA)
    screen.DrawObject((gameState.renderer.SCREEN_WIDTH - 700) / 2, 220, overlay)

    font = CreateObject("roFont", "font:MediumBoldSystemFont", 48, false)
    smallFont = CreateObject("roFont", "font:MediumBoldSystemFont", 32, false)

    title = "Options"
    tW = font.GetOneLineWidth(title)
    screen.DrawText(title, (gameState.renderer.SCREEN_WIDTH - tW) / 2, 280, &hFFFFFFFF, font)

    startY = 340
    spacing = 80
    for i = 0 to gameState.optionsMenu.items.Count() - 1
        label = gameState.optionsMenu.items[i]
        valueText = ""
        if label = "Music Volume" then
            valueText = str(gameState.audioManager.defaultMusicVolume)
        else if label = "SFX Volume" then
            valueText = str(gameState.audioManager.defaultSfxVolume)
        end if

        fullText = label
        if valueText <> "" then fullText = label + ": " + valueText

        w = smallFont.GetOneLineWidth(fullText)
        x = (gameState.renderer.SCREEN_WIDTH - w) / 2
        y = startY + (i * spacing)
        if i = gameState.optionsMenu.selected then
            screen.DrawRect(x - 40, y - 20, w + 80, 60, &h2E74FFFF)
        end if
        screen.DrawText(fullText, x, y, &hFFFFFFFF, smallFont)
    end for
End Sub


' *****************************************************
' Handle game over input
' *****************************************************
Sub HandleGameOverInput(event as Object, gameState as Object)
    if type(event) <> "roUniversalControlEvent" then return
    if event.GetIndex() <> 1 then return

    key = event.GetInt()
    itemsCount = gameState.gameOverMenu.items.Count()

    if key = gameState.inputState.KEY_UP then
        gameState.gameOverMenu.selected = (gameState.gameOverMenu.selected - 1 + itemsCount) MOD itemsCount
    else if key = gameState.inputState.KEY_DOWN then
        gameState.gameOverMenu.selected = (gameState.gameOverMenu.selected + 1) MOD itemsCount
    else if key = gameState.inputState.KEY_OK OR key = gameState.inputState.KEY_BACK then
        choice = gameState.gameOverMenu.items[gameState.gameOverMenu.selected]
        if choice = "Restart" then
            gameState.requestReset = true
            gameState.mode = "game"
        else
            gameState.requestReset = true
            gameState.mode = "menu"
        end if
    end if
End Sub


' *****************************************************
' Draw game over overlay
' *****************************************************
Sub DrawGameOverOverlay(screen as Object, gameState as Object)
    overlay = CreateObject("roBitmap", {width: 700, height: 380, AlphaEnable: true})
    overlay.Clear(&h000000CC)
    screen.DrawObject((gameState.renderer.SCREEN_WIDTH - 700) / 2, 240, overlay)

    font = CreateObject("roFont", "font:MediumBoldSystemFont", 64, false)
    smallFont = CreateObject("roFont", "font:MediumBoldSystemFont", 32, false)

    title = "Game Over"
    tW = font.GetOneLineWidth(title)
    screen.DrawText(title, (gameState.renderer.SCREEN_WIDTH - tW) / 2, 300, &hFFFFFFFF, font)

    scoreText = "Score: " + PadScore(gameState.entityManager.score)
    sW = smallFont.GetOneLineWidth(scoreText)
    screen.DrawText(scoreText, (gameState.renderer.SCREEN_WIDTH - sW) / 2, 360, &hFFFFFFFF, smallFont)

    coinsText = "Coins: " + str(gameState.entityManager.coinCount)
    cW = smallFont.GetOneLineWidth(coinsText)
    screen.DrawText(coinsText, (gameState.renderer.SCREEN_WIDTH - cW) / 2, 410, &hFFFFFFFF, smallFont)

    startY = 460
    spacing = 70
    for i = 0 to gameState.gameOverMenu.items.Count() - 1
        label = gameState.gameOverMenu.items[i]
        w = smallFont.GetOneLineWidth(label)
        x = (gameState.renderer.SCREEN_WIDTH - w) / 2
        y = startY + (i * spacing)
        if i = gameState.gameOverMenu.selected then
            screen.DrawRect(x - 40, y - 20, w + 80, 60, &h2E74FFFF)
        end if
        screen.DrawText(label, x, y, &hFFFFFFFF, smallFont)
    end for
End Sub


' *****************************************************
' Draw level complete overlay
' *****************************************************
Sub DrawLevelCompleteOverlay(screen as Object, gameState as Object)
    overlay = CreateObject("roBitmap", {width: 720, height: 320, AlphaEnable: true})
    overlay.Clear(&h000000CC)
    screen.DrawObject((gameState.renderer.SCREEN_WIDTH - 720) / 2, 260, overlay)

    titleFont = CreateObject("roFont", "font:MediumBoldSystemFont", 64, false)
    bodyFont = CreateObject("roFont", "font:MediumBoldSystemFont", 32, false)

    title = "Course Clear!"
    tW = titleFont.GetOneLineWidth(title)
    screen.DrawText(title, (gameState.renderer.SCREEN_WIDTH - tW) / 2, 320, &hFFFFFFFF, titleFont)

    levelName = "Level"
    nextName = "Next"
    if gameState.levelList <> invalid then
        levelName = gameState.levelList[gameState.levelIndex].name
        nextIndex = gameState.levelIndex + 1
        if nextIndex >= gameState.levelList.Count() then nextIndex = 0
        nextName = gameState.levelList[nextIndex].name
    end if

    levelText = "Completed: " + levelName
    lW = bodyFont.GetOneLineWidth(levelText)
    screen.DrawText(levelText, (gameState.renderer.SCREEN_WIDTH - lW) / 2, 380, &hFFFFFFFF, bodyFont)

    secs = Int(gameState.levelCompleteTimer) + 1
    if secs < 1 then secs = 1
    nextText = "Next: " + nextName + " in " + str(secs) + "s"
    nW = bodyFont.GetOneLineWidth(nextText)
    screen.DrawText(nextText, (gameState.renderer.SCREEN_WIDTH - nW) / 2, 430, &hFFFFFFFF, bodyFont)

    scoreText = "Score: " + PadScore(gameState.entityManager.score)
    sW = bodyFont.GetOneLineWidth(scoreText)
    screen.DrawText(scoreText, (gameState.renderer.SCREEN_WIDTH - sW) / 2, 480, &hFFFFFFFF, bodyFont)
End Sub


' *****************************************************
' Reset level and reinitialize entities
' *****************************************************
Sub ResetLevel(gameState as Object)
    if gameState.levelList = invalid then return
    if gameState.levelIndex < 0 OR gameState.levelIndex >= gameState.levelList.Count() then gameState.levelIndex = 0

    levelInfo = gameState.levelList[gameState.levelIndex]
    levelData = LoadLevelData(levelInfo.path)
    if levelData = invalid then
        print "ERROR: Failed to load level: " + levelInfo.name
        return
    end if
    gameState.levelData = levelData

    entityManager = CreateEntityManager()
    entityManager.Init(gameState.spawnX, gameState.spawnY, gameState.levelData)
    gameState.entityManager = entityManager
    gameState.renderer.UpdateCamera(gameState.spawnX, gameState.spawnY, gameState.levelData.width)
    gameState.levelCompletePlayed = false
    gameState.countdownTime = 3.0
    gameState.mode = "countdown"
    if gameState.inputState <> invalid then gameState.inputState.Reset()
End Sub


' *****************************************************
' Advance to next level and reset state
' *****************************************************
Sub AdvanceLevel(gameState as Object)
    if gameState.levelList = invalid then return
    gameState.levelIndex = gameState.levelIndex + 1
    if gameState.levelIndex >= gameState.levelList.Count() then
        gameState.levelIndex = 0
        gameState.mode = "menu"
    end if
    if gameState.menu <> invalid then gameState.menu.UpdateLevelLabel(gameState)
    ResetLevel(gameState)
End Sub


' *****************************************************
' Helper: Load level JSON safely
' *****************************************************
Function LoadLevelData(path as String) as Object
    if path = invalid OR path = "" then return invalid
    print "Loading level from " + path
    data = ParseJSON(ReadAsciiFile(path))
    if data = invalid then
        print "ERROR: Failed to parse level: " + path
    end if
    return data
End Function


' *****************************************************
' Process Input
' *****************************************************
Sub ProcessInput(gameState as Object)
    ' Get message without blocking
    msg = gameState.port.GetMessage()
    
    if msg <> invalid AND type(msg) = "roUniversalControlEvent" then
        ' Check for play/pause button press (before other handling)
        keyCode = msg.GetInt()
        isPressed = (msg.GetIndex() = 1)
        if keyCode = gameState.inputState.KEY_PLAY AND isPressed then
            ' Show notification in upper right corner
            gameState.notificationText = "Play/Pause Pressed"
            gameState.notificationTimer = gameState.notificationDuration
        end if
        
        ' Let input system handle the event
        gameState.inputState.HandleEvent(msg)

        if gameState.mode = "menu" then
            gameState.menu.HandleEvent(msg, gameState)
        else if gameState.mode = "pause" then
            HandlePauseInput(msg, gameState)
        else if gameState.mode = "options" then
            HandleOptionsInput(msg, gameState)
        else if gameState.mode = "gameover" then
            HandleGameOverInput(msg, gameState)
        else
            ' Check for exit in gameplay
            if gameState.inputState.back then
                print "Back button pressed - Pausing..."
                gameState.mode = "pause"
            end if
        end if
    end if
End Sub


' *****************************************************
' Update Game Logic
' *****************************************************
Sub UpdateGame(gameState as Object)
    ' Update entities (includes physics)
    gameState.entityManager.Update(gameState.inputState, gameState.levelData, gameState.audioManager, gameState.deltaTime)
    
    ' Update camera to follow player
    if gameState.entityManager.player <> invalid then
        player = gameState.entityManager.player
        gameState.renderer.UpdateCamera(player.x, player.y, gameState.levelData.width)
    end if

    ' Check for game over (no lives left)
    if gameState.entityManager.gameOver then
        print "Game over"
        gameState.mode = "gameover"
    end if

    ' Level complete handling
    if gameState.entityManager.levelComplete then
        gameState.mode = "levelcomplete"
        gameState.levelCompleteTimer = 2.0
        gameState.entityManager.levelComplete = false
        if gameState.levelCompletePlayed = false then
            gameState.audioManager.PlayGoal()
            gameState.levelCompletePlayed = true
        end if
    end if
    
    ' Update FPS display (once per second)
    gameState.fpsUpdateTimer = gameState.fpsUpdateTimer + gameState.deltaTime
    if gameState.fpsUpdateTimer >= 1.0 then
        if gameState.deltaTime > 0 then
            gameState.fpsDisplay = Int(1.0 / gameState.deltaTime)
        end if
        gameState.fpsUpdateTimer = 0.0
    end if
    
    ' Update notification timer
    if gameState.notificationTimer > 0 then
        gameState.notificationTimer = gameState.notificationTimer - gameState.deltaTime
        if gameState.notificationTimer < 0 then
            gameState.notificationTimer = 0
        end if
    end if
End Sub


' *****************************************************
' Render Game Frame
' *****************************************************
Sub RenderGame(gameState as Object)
    screen = gameState.screen
    renderer = gameState.renderer
    
    ' Clear screen to sky blue
    renderer.Clear(screen)
    
    ' Render tile map with viewport culling
    renderer.RenderTileMap(screen, gameState.levelData)
    
    ' Render entities
    gameState.entityManager.Draw(screen, renderer.cameraX, renderer.cameraY)
    
    ' Draw HUD (fixed position, not affected by camera)
    DrawHUD(screen, gameState)
    
    ' Draw notification if active
    DrawNotification(screen, gameState)
End Sub


' *****************************************************
' Draw Notification (Upper Right Corner)
' *****************************************************
Sub DrawNotification(screen as Object, gameState as Object)
    if gameState.notificationTimer <= 0 OR gameState.notificationText = "" then return
    
    ' Create notification box
    font = CreateObject("roFont", "font:MediumBoldSystemFont", 32, false)
    textWidth = font.GetOneLineWidth(gameState.notificationText)
    
    ' Box dimensions with padding
    padding = 20
    boxWidth = textWidth + (padding * 2)
    boxHeight = 60
    
    ' Position in upper right corner
    screenWidth = gameState.renderer.SCREEN_WIDTH
    boxX = screenWidth - boxWidth - 20  ' 20px from right edge
    boxY = 20  ' 20px from top
    
    ' Calculate fade effect for last 0.5 seconds
    alpha = 255
    if gameState.notificationTimer < 0.5 then
        alpha = Int(gameState.notificationTimer * 2.0 * 255)
        if alpha < 0 then alpha = 0
        if alpha > 255 then alpha = 255
    end if
    
    ' Draw semi-transparent background
    bgColor = &h2E74FF00 + alpha  ' Blue background with fade
    screen.DrawRect(boxX, boxY, boxWidth, boxHeight, bgColor)
    
    ' Draw border
    borderColor = &hFFFFFF00 + alpha  ' White border with fade
    screen.DrawRect(boxX, boxY, boxWidth, 3, borderColor)  ' Top
    screen.DrawRect(boxX, boxY + boxHeight - 3, boxWidth, 3, borderColor)  ' Bottom
    screen.DrawRect(boxX, boxY, 3, boxHeight, borderColor)  ' Left
    screen.DrawRect(boxX + boxWidth - 3, boxY, 3, boxHeight, borderColor)  ' Right
    
    ' Draw text
    textColor = &hFFFFFF00 + alpha  ' White text with fade
    textX = boxX + padding
    textY = boxY + 15
    screen.DrawText(gameState.notificationText, textX, textY, textColor, font)
End Sub


' *****************************************************
' Draw HUD (Heads-Up Display)
' *****************************************************
Sub DrawHUD(screen as Object, gameState as Object)
    ' HUD background
    screen.DrawRect(10, 10, 340, 210, &h000000AA)

    ' FPS counter (top-left)
    fpsText = "FPS: " + str(gameState.fpsDisplay)
    screen.DrawText(fpsText, 20, 40, &hFFFFFFFF)

    ' Level
    if gameState.levelList <> invalid then
        lvlName = gameState.levelList[gameState.levelIndex].name
        screen.DrawText("Level: " + lvlName, 20, 60, &hFFFFFFFF)
    end if

    ' Score and coins
    if gameState.entityManager <> invalid then
        scoreText = "Score " + PadScore(gameState.entityManager.score)
        screen.DrawText(scoreText, 20, 95, &hFFFFFFFF)

        if gameState.entityManager.spriteCoin <> invalid then
            screen.DrawObject(20, 120, gameState.entityManager.spriteCoin)
            coinsText = "x " + str(gameState.entityManager.coinCount)
            screen.DrawText(coinsText, 60, 140, &hFFFFFFFF)
        else
            coinsText = "Coins: " + str(gameState.entityManager.coinCount)
            screen.DrawText(coinsText, 20, 125, &hFFFFFFFF)
        end if
    end if

    ' Lives and status
    if gameState.entityManager.player <> invalid then
        if gameState.entityManager.player.spriteIdle <> invalid then
            screen.DrawObject(20, 155, gameState.entityManager.player.spriteIdle)
            livesText = "x " + str(gameState.entityManager.player.lives)
            screen.DrawText(livesText, 60, 175, &hFFFFFFFF)
        else
            livesText = "Lives: " + str(gameState.entityManager.player.lives)
            screen.DrawText(livesText, 20, 155, &hFFFFFFFF)
        end if

        if gameState.entityManager.player.invincibleTimer > 0 then
            screen.DrawText("Invincible", 20, 205, &hFFAA00FF)
        end if
    end if

    ' Player position / grounded debug
    if gameState.entityManager.player <> invalid then
        player = gameState.entityManager.player
        posText = "X:" + str(Int(player.x)) + " Y:" + str(Int(player.y))
        screen.DrawText(posText, 20, 230, &hFFFFFFFF)
    end if
End Sub


' *****************************************************
' Helper: Pad score with leading zeros to 6 digits
' *****************************************************
Function PadScore(score as Integer) as String
    s = Trim(str(score))
    while Len(s) < 6
        s = "0" + s
    end while
    return s
End Function
