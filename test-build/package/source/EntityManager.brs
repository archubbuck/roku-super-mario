' *****************************************************
' Entity Manager - Create and manage game entities
' Uses object pooling to prevent garbage collection
' *****************************************************

' *****************************************************
' Create Mario Entity (Player)
' *****************************************************
Function CreateMario(startX as Float, startY as Float) as Object
    mario = {
        ' Type identification
        type: "Player"
        isActive: true
        
        ' Position and physics (Float for sub-pixel precision)
        x: startX
        y: startY
        vx: 0.0  ' X velocity (pixels/second)
        vy: 0.0  ' Y velocity (pixels/second)
        
        ' Bounding box
        width: 32
        height: 32
        
        ' Physics state
        isGrounded: false
        facing: 1  ' 1 = right, -1 = left
        jumpHeldLastFrame: false
        lives: 3
        invincibleTimer: 0.0
        powerState: "small"
        fireCooldown: 0.0
        starSparkleTimer: 0.0
        
        ' Animation state
        animState: "idle"  ' idle, walk, run, jump, fall
        animFrame: 0
        animTime: 0.0
        animSpeed: 0.1  ' Time per frame in seconds
        
        ' Sprite data (will be loaded)
        spriteIdle: invalid
        spriteRun: invalid
        spriteJump: invalid
        
        ' Methods
        Update: Entity_MarioUpdate
        Draw: Entity_MarioDraw
        LoadSprites: Entity_MarioLoadSprites
    }
    
    return mario
End Function


' *****************************************************
' Load Mario Sprites
' *****************************************************
Sub Entity_MarioLoadSprites()
    ' Load placeholder sprites
    m.spriteIdle = CreateObject("roBitmap", "pkg:/images/sprites/mario-idle.png")
    m.spriteRun = CreateObject("roBitmap", "pkg:/images/sprites/mario-run.png")
    m.spriteJump = CreateObject("roBitmap", "pkg:/images/sprites/mario-jump.png")
End Sub


' *****************************************************
' Update Mario
' *****************************************************
Sub Entity_MarioUpdate(inputState as Object, levelData as Object, audioManager as Object, deltaTime as Float)
    ' Update physics (defined in PhysicsSystem.brs)
    UpdateEntityPhysics(m, inputState, levelData, deltaTime, audioManager)
    
    ' Determine animation state based on movement
    if NOT m.isGrounded then
        if m.vy < 0 then
            m.animState = "jump"
        else
            m.animState = "fall"
        end if
    else if Abs(m.vx) > 10 then
        if Abs(m.vx) > 200 then
            m.animState = "run"
        else
            m.animState = "walk"
        end if
    else
        m.animState = "idle"
    end if
    
    ' Update animation frame
    m.animTime = m.animTime + deltaTime
    if m.animTime >= m.animSpeed then
        m.animTime = 0.0
        m.animFrame = m.animFrame + 1
        if m.animFrame >= 3 then m.animFrame = 0  ' 3 frames in run animation
    end if
End Sub


' *****************************************************
' Draw Mario
' Uses Int() conversion for pixel-perfect rendering
' Float positions maintained for sub-pixel physics
' *****************************************************
Sub Entity_MarioDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    
    ' Convert Float position to Int for rendering
    drawX = Int(m.x - cameraX)
    drawY = Int(m.y - cameraY)
    
    ' Select sprite based on animation state
    sprite = invalid
    if m.animState = "jump" OR m.animState = "fall" then
        sprite = m.spriteJump
    else if m.animState = "walk" OR m.animState = "run" then
        sprite = m.spriteRun
        ' TODO: Use roRegion to select frame from sprite sheet
    else
        sprite = m.spriteIdle
    end if
    
    ' Draw sprite
    if sprite <> invalid then
        ' TODO: Handle flipping sprite based on m.facing direction
        screen.DrawObject(drawX, drawY, sprite)
    else
        ' Fallback: draw colored rectangle if sprites not loaded
        DrawDebugRect(screen, drawX, drawY, m.width, m.height, &h0000FFFF)
    end if

    ' Star invincibility overlay
    if m.invincibleTimer > 0 then
        overlayColor = &hFFD70088
        if (Int(m.invincibleTimer * 10) MOD 2) = 0 then overlayColor = &hFFFFFF88
        screen.DrawRect(drawX, drawY, m.width, m.height, overlayColor)
    end if
End Sub


' *****************************************************
' Helper: Draw Debug Rectangle
' Used for entities without sprites loaded
' *****************************************************
Sub DrawDebugRect(screen as Object, x as Integer, y as Integer, w as Integer, h as Integer, color as Integer)
    debugBitmap = CreateObject("roBitmap", {width: w, height: h, AlphaEnable: true})
    debugBitmap.Clear(color)
    screen.DrawObject(x, y, debugBitmap)
End Sub


' *****************************************************
' Create Coin Entity
' *****************************************************
Function CreateCoin(x as Float, y as Float, sprite as Object) as Object
    coin = {
        type: "Coin"
        isActive: true
        x: x
        y: y
        width: 16
        height: 16
        sprite: sprite

        Draw: Entity_CoinDraw
    }
    return coin
End Function

Sub Entity_CoinDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    drawX = Int(m.x - cameraX)
    drawY = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(drawX, drawY, m.sprite)
    else
        DrawDebugRect(screen, drawX, drawY, m.width, m.height, &hFFFF00FF)
    end if
End Sub


' *****************************************************
' Player damage and respawn
' *****************************************************
Function DamagePlayer(audioManager as Object) as Boolean
    if m.player = invalid then return false
    if m.player.invincibleTimer > 0 then return false

    m.player.lives = m.player.lives - 1
    m.player.invincibleTimer = 1.5

    ' Respawn at spawn point
    m.player.x = m.spawnX
    m.player.y = m.spawnY
    m.player.vx = 0
    m.player.vy = 0
    m.player.isGrounded = false

    if audioManager <> invalid then audioManager.PlaySFX("die")

    return m.player.lives <= 0
End Function


' *****************************************************
' Create Powerup (Mushroom)
' *****************************************************
Function CreatePowerup(x as Float, y as Float, powerType as String, sprite as Object) as Object
    color = &hFF0000FF ' default red for mushroom
    pt = LCase(powerType)
    if pt = "fireflower" OR pt = "flower" OR pt = "fire" then
        color = &hFF8000FF ' orange
    else if pt = "star" then
        color = &hFFD700FF ' gold
    end if

    p = {
        type: "Powerup"
        powerType: pt
        isActive: true
        x: x
        y: y
        vx: 40.0
        vy: 0.0
        width: 16
        height: 16
        sprite: sprite
        color: color
        collected: false

        Update: Entity_PowerupUpdate
        Draw: Entity_PowerupDraw
    }
    return p
End Function

Sub Entity_PowerupUpdate(levelData as Object, deltaTime as Float)
    if NOT m.isActive then return
    constants = GetPhysicsConstants()

    ' Simple walk to the right
    m.x = m.x + (m.vx * deltaTime)
    m.vy = m.vy + (constants.GRAVITY * deltaTime)
    if m.vy > constants.MAX_FALL_SPEED then m.vy = constants.MAX_FALL_SPEED

    m.y = m.y + (m.vy * deltaTime)
    CheckTileCollisionY(m, levelData, constants)
    CheckTileCollisionX(m, levelData, constants)
End Sub

Sub Entity_PowerupDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    drawX = Int(m.x - cameraX)
    drawY = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(drawX, drawY, m.sprite)
    else
        DrawDebugRect(screen, drawX, drawY, m.width, m.height, m.color)
    end if
End Sub


' *****************************************************
' Create Goomba Entity
' *****************************************************
Function CreateGoomba(x as Float, y as Float, sprite as Object) as Object
    goomba = {
        type: "Goomba"
        isActive: true
        x: x
        y: y
        vx: -80.0
        vy: 0.0
        width: 32
        height: 32
        facing: -1
        isGrounded: false
        sprite: sprite
        respawnY: y

        Update: Entity_GoombaUpdate
        Draw: Entity_GoombaDraw
    }
    return goomba
End Function


' *****************************************************
' Create Koopa Entity
' *****************************************************
Function CreateKoopa(x as Float, y as Float, sprite as Object) as Object
    koopa = {
        type: "Koopa"
        isActive: true
        x: x
        y: y
        vx: -60.0
        vy: 0.0
        width: 32
        height: 32
        facing: -1
        isGrounded: false
        sprite: sprite
        respawnY: y

        Update: Entity_KoopaUpdate
        Draw: Entity_KoopaDraw
    }
    return koopa
End Function


' *****************************************************
' Create Hazard Entity (static damage)
' *****************************************************
Function CreateHazard(x as Float, y as Float, sprite as Object) as Object
    hz = {
        type: "Hazard"
        isActive: true
        x: x
        y: y
        width: 32
        height: 16
        sprite: sprite
        Draw: Entity_HazardDraw
    }
    return hz
End Function

Sub Entity_HazardDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    dx = Int(m.x - cameraX)
    dy = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(dx, dy, m.sprite)
    else
        screen.DrawRect(dx, dy, m.width, m.height, &hFF4444FF)
    end if
End Sub


' *****************************************************
' Create Goal Entity
' *****************************************************
Function CreateGoal(x as Float, y as Float, sprite as Object) as Object
    gl = {
        type: "Goal"
        isActive: true
        x: x
        y: y
        width: 20
        height: 80
        sprite: sprite
        Draw: Entity_GoalDraw
    }
    return gl
End Function

Sub Entity_GoalDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    dx = Int(m.x - cameraX)
    dy = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(dx, dy, m.sprite)
    else
        screen.DrawRect(dx, dy, m.width, m.height, &hFFFFFFFF)
    end if
End Sub

Sub Entity_GoombaUpdate(levelData as Object, deltaTime as Float)
    if NOT m.isActive then return
    constants = GetPhysicsConstants()

    ' Simple patrol: keep moving in facing direction
    speed = 80.0
    if m.facing >= 0 then
        m.vx = speed
        m.facing = 1
    else
        m.vx = -speed
        m.facing = -1
    end if

    ' Gravity
    ApplyGravity(m, deltaTime, constants)

    ' Move X and flip on collision
    m.x = m.x + (m.vx * deltaTime)
    if CheckTileCollisionX(m, levelData, constants) then
        m.facing = -m.facing
    end if

    ' Move Y and resolve ground
    m.y = m.y + (m.vy * deltaTime)
    CheckTileCollisionY(m, levelData, constants)

    ' If fell off map, respawn at original Y just off-screen
    if m.y > (levelData.height * constants.TILE_SIZE) then
        m.x = m.x - 64  ' shift back a bit
        m.y = m.respawnY
        m.vy = 0
        m.isGrounded = false
    end if
End Sub

Sub Entity_KoopaUpdate(levelData as Object, deltaTime as Float)
    if NOT m.isActive then return
    constants = GetPhysicsConstants()

    speed = 60.0
    if m.facing >= 0 then
        m.vx = speed
        m.facing = 1
    else
        m.vx = -speed
        m.facing = -1
    end if

    ApplyGravity(m, deltaTime, constants)

    m.x = m.x + (m.vx * deltaTime)
    if CheckTileCollisionX(m, levelData, constants) then
        m.facing = -m.facing
    end if

    m.y = m.y + (m.vy * deltaTime)
    CheckTileCollisionY(m, levelData, constants)

    if m.y > (levelData.height * constants.TILE_SIZE) then
        m.x = m.x - 64
        m.y = m.respawnY
        m.vy = 0
        m.isGrounded = false
    end if
End Sub

Sub Entity_GoombaDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    drawX = Int(m.x - cameraX)
    drawY = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(drawX, drawY, m.sprite)
    else
        DrawDebugRect(screen, drawX, drawY, m.width, m.height, &h8B4513FF)
    end if
End Sub

Sub Entity_KoopaDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    drawX = Int(m.x - cameraX)
    drawY = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(drawX, drawY, m.sprite)
    else
        DrawDebugRect(screen, drawX, drawY, m.width, m.height, &h006400FF)
    end if
End Sub


' *****************************************************
' Create Entity Manager
' Manages all game entities and object pools
' *****************************************************
Function CreateEntityManager() as Object
    manager = {
        ' Player
        player: invalid
        spawnX: 0.0
        spawnY: 0.0
        gameOver: false
        levelComplete: false
        
        ' Entity pools (pre-allocated for performance)
        goombas: []
        koopas: []
        coins: []
        powerups: []
        hazards: []
        goals: []
        projectiles: []
        projectileMax: 16
        spriteFireball: invalid
        coinCount: 0
        score: 0
        spriteCoin: invalid
        spriteGoomba: invalid
        spriteKoopa: invalid
        spritePowerup: invalid
        spriteHazard: invalid
        spriteGoal: invalid
        particles: []
        particleMax: 64
        
        ' Methods
        Init: EntityManager_Init
        Update: EntityManager_Update
        Draw: EntityManager_Draw
        LoadEntities: EntityManager_LoadEntities
        SpawnParticleBurst: EntityManager_SpawnParticleBurst
    }
    
    return manager
End Function


' *****************************************************
' Create Fireball Projectile
' *****************************************************
Function CreateFireball(x as Float, y as Float, dir as Integer, sprite as Object) as Object
    fb = {
        type: "Fireball"
        isActive: true
        x: x
        y: y
        vx: 360.0 * dir
        vy: -120.0
        width: 12
        height: 12
        isGrounded: false
        gravity: 900.0
        lifetime: 2.5
        sprite: sprite

        Update: invalid
        Draw: Entity_FireballDraw
    }
    return fb
End Function

Sub Entity_FireballDraw(screen as Object, cameraX as Float, cameraY as Float)
    if NOT m.isActive then return
    dx = Int(m.x - cameraX)
    dy = Int(m.y - cameraY)
    if m.sprite <> invalid then
        screen.DrawObject(dx, dy, m.sprite)
    else
        screen.DrawRect(dx, dy, m.width, m.height, &hFF8000FF)
    end if
End Sub


' *****************************************************
' Initialize Entity Manager
' *****************************************************
Sub EntityManager_Init(startX as Float, startY as Float, levelData as Object)
    m.spawnX = startX
    m.spawnY = startY
    m.gameOver = false
    m.levelComplete = false

    ' Load shared sprites once
    m.spriteCoin = CreateObject("roBitmap", "pkg:/images/sprites/coin.png")
    m.spriteGoomba = CreateObject("roBitmap", "pkg:/images/sprites/goomba.png")
    m.spriteKoopa = CreateObject("roBitmap", "pkg:/images/sprites/koopa.png")
    m.spritePowerup = CreateObject("roBitmap", "pkg:/images/sprites/powerup.png")
    m.spriteHazard = CreateObject("roBitmap", {width: 32, height: 16, AlphaEnable: true})
    if m.spriteHazard <> invalid then m.spriteHazard.Clear(&hFF4444FF)
    m.spriteGoal = CreateObject("roBitmap", {width: 20, height: 80, AlphaEnable: true})
    if m.spriteGoal <> invalid then m.spriteGoal.Clear(&hFFFFFFFF)
    m.spriteFireball = CreateObject("roBitmap", {width: 12, height: 12, AlphaEnable: true})
    if m.spriteFireball <> invalid then m.spriteFireball.Clear(&hFF8000FF)

    ' Prepare particle pool
    m.particles = []
    for i = 0 to m.particleMax - 1
        m.particles.Push({isActive: false, x: 0.0, y: 0.0, vx: 0.0, vy: 0.0, lifetime: 0.0, size: 6, color: &hFFFFFFFF})
    end for

    ' Prepare projectile pool
    m.projectiles = []
    for i = 0 to m.projectileMax - 1
        m.projectiles.Push(CreateFireball(0, 0, 0, m.spriteFireball))
        m.projectiles[i].isActive = false
    end for

    ' Create player (Mario)
    m.player = CreateMario(startX, startY)
    m.player.LoadSprites()
    
    ' Populate entities from level data
    m.LoadEntities(levelData)
    
    print "Entity Manager initialized"
    print "Player spawned at (" + str(startX) + ", " + str(startY) + ")"
End Sub


' *****************************************************
' Load entities defined in level JSON
' *****************************************************
Sub EntityManager_LoadEntities(levelData as Object)
    m.coins = []
    m.goombas = []
    m.koopas = []
    m.powerups = []
    m.hazards = []
    m.goals = []
    m.coinCount = 0
    m.score = 0
    m.levelComplete = false
    m.player.powerState = "small"
    m.player.fireCooldown = 0.0
    m.player.starSparkleTimer = 0.0

    if levelData = invalid OR levelData.entities = invalid then return

    for each ent in levelData.entities
        if ent = invalid then continue for
        etype = LCase(ent.type)
        if etype = "coin" then
            coin = CreateCoin(ent.x, ent.y, m.spriteCoin)
            m.coins.Push(coin)
        else if etype = "goomba" then
            goomba = CreateGoomba(ent.x, ent.y, m.spriteGoomba)
            m.goombas.Push(goomba)
        else if etype = "koopa" then
            koopa = CreateKoopa(ent.x, ent.y, m.spriteKoopa)
            m.koopas.Push(koopa)
        else if etype = "mushroom" OR etype = "powerup" then
            p = CreatePowerup(ent.x, ent.y, "mushroom", m.spritePowerup)
            m.powerups.Push(p)
        else if etype = "fireflower" OR etype = "flower" OR etype = "fire" then
            p = CreatePowerup(ent.x, ent.y, "fireflower", m.spritePowerup)
            m.powerups.Push(p)
        else if etype = "star" then
            p = CreatePowerup(ent.x, ent.y, "star", m.spritePowerup)
            m.powerups.Push(p)
        else if etype = "hazard" then
            hz = CreateHazard(ent.x, ent.y, m.spriteHazard)
            m.hazards.Push(hz)
        else if etype = "goal" then
            gl = CreateGoal(ent.x, ent.y, m.spriteGoal)
            m.goals.Push(gl)
        end if
    end for

    ' Fireball collisions with enemies
    for each fb in m.projectiles
        if fb.isActive then
            fbRect = {x: fb.x, y: fb.y, w: fb.width, h: fb.height}

            for each g in m.goombas
                if g.isActive then
                    gRect = {x: g.x, y: g.y, w: g.width, h: g.height}
                    if CheckAABB(fbRect, gRect) then
                        g.isActive = false
                        fb.isActive = false
                        m.score = m.score + 150
                        SpawnParticleBurst(g.x + g.width / 2, g.y + g.height / 2, 8, &hFF8000FF)
                        exit for
                    end if
                end if
            end for

            if fb.isActive then
                for each k in m.koopas
                    if k.isActive then
                        kRect = {x: k.x, y: k.y, w: k.width, h: k.height}
                        if CheckAABB(fbRect, kRect) then
                            k.isActive = false
                            fb.isActive = false
                            m.score = m.score + 200
                            SpawnParticleBurst(k.x + k.width / 2, k.y + k.height / 2, 10, &hFF8000FF)
                            exit for
                        end if
                    end if
                end for
            end if
        end if
    end for

    print "Entities loaded: coins=" + str(m.coins.Count()) + " goombas=" + str(m.goombas.Count()) + " koopas=" + str(m.koopas.Count()) + " powerups=" + str(m.powerups.Count())
End Sub


' *****************************************************
' Update All Entities
' *****************************************************
Sub EntityManager_Update(inputState as Object, levelData as Object, audioManager as Object, deltaTime as Float)
    constants = GetPhysicsConstants()

    ' Update player
    if m.player <> invalid AND m.player.isActive then
        m.player.Update(inputState, levelData, audioManager, deltaTime)

        ' Fireball shooting when in fire state and run button held
        if m.player.powerState = "fire" then
            m.player.fireCooldown = m.player.fireCooldown - deltaTime
            if m.player.fireCooldown < 0 then m.player.fireCooldown = 0
            if inputState <> invalid AND inputState.run AND m.player.fireCooldown <= 0 then
                FireFireball(m.player, m)
                m.player.fireCooldown = 0.35
                if audioManager <> invalid then audioManager.PlaySFX("fireball")
            end if
        end if

        ' Star sparkle particles while invincible
        if m.player.invincibleTimer > 0 then
            m.player.starSparkleTimer = m.player.starSparkleTimer - deltaTime
            if m.player.starSparkleTimer <= 0 then
                SpawnParticleBurst(m.player.x + m.player.width / 2, m.player.y + (m.player.height / 2), 3, &hFFD700FF)
                m.player.starSparkleTimer = 0.15
            end if
        end if

        ' Pitfall: treat falling off the map as a death/respawn event
        pitY = (levelData.height * constants.TILE_SIZE) + 64
        if m.player.y > pitY then
            if DamagePlayer(audioManager) then
                m.gameOver = true
            end if
        end if
    end if

    ' Tick invincibility timer
    if m.player <> invalid AND m.player.invincibleTimer > 0 then
        m.player.invincibleTimer = m.player.invincibleTimer - deltaTime
        if m.player.invincibleTimer < 0 then m.player.invincibleTimer = 0
    end if

    ' Update goombas
    for each g in m.goombas
        if g.isActive then g.Update(levelData, deltaTime)
    end for

    ' Update koopas
    for each k in m.koopas
        if k.isActive then k.Update(levelData, deltaTime)
    end for

    ' Update powerups
    for each p in m.powerups
        if p.isActive then p.Update(levelData, deltaTime)
    end for
    
    ' Handle player interactions
    if m.player <> invalid AND m.player.isActive then
        pRect = {x: m.player.x, y: m.player.y, w: m.player.width, h: m.player.height}

        ' Coins
        for each c in m.coins
            if c.isActive then
                cRect = {x: c.x, y: c.y, w: c.width, h: c.height}
                if CheckAABB(pRect, cRect) then
                    c.isActive = false
                    m.coinCount = m.coinCount + 1
                    m.score = m.score + 100
                    if audioManager <> invalid then audioManager.PlaySFX("coin")
                    SpawnParticleBurst(c.x + c.width / 2, c.y + c.height / 2, 8, &hFFD700FF)
                end if
            end if
        end for

        ' Goombas (stomp to defeat)
        for each g in m.goombas
            if g.isActive then
                gRect = {x: g.x, y: g.y, w: g.width, h: g.height}
                if CheckAABB(pRect, gRect) then
                    if m.player.invincibleTimer > 0 then
                        g.isActive = false
                        m.score = m.score + 200
                        SpawnParticleBurst(g.x + g.width / 2, g.y + g.height / 2, 10, &hBBBBBBFF)
                    else if m.player.vy > 0 AND m.player.y < g.y then
                        g.isActive = false
                        m.player.vy = -250
                        m.score = m.score + 200
                        if audioManager <> invalid then audioManager.PlaySFX("stomp")
                        SpawnParticleBurst(g.x + g.width / 2, g.y + g.height / 2, 10, &hBBBBBBFF)
                    else
                        if DamagePlayer(audioManager) then
                            m.gameOver = true
                        end if
                    end if
                end if
            end if
        end for

        ' Koopas (stomp to defeat)
        for each k in m.koopas
            if k.isActive then
                kRect = {x: k.x, y: k.y, w: k.width, h: k.height}
                if CheckAABB(pRect, kRect) then
                    if m.player.invincibleTimer > 0 then
                        k.isActive = false
                        m.score = m.score + 300
                        SpawnParticleBurst(k.x + k.width / 2, k.y + k.height / 2, 12, &hBBBBBBFF)
                    else if m.player.vy > 0 AND m.player.y < k.y then
                        k.isActive = false
                        m.player.vy = -250
                        m.score = m.score + 300
                        if audioManager <> invalid then audioManager.PlaySFX("stomp")
                        SpawnParticleBurst(k.x + k.width / 2, k.y + k.height / 2, 12, &hBBBBBBFF)
                    else
                        if DamagePlayer(audioManager) then
                            m.gameOver = true
                        end if
                    end if
                end if
            end if
        end for

        ' Powerups (mushroom, fireflower, star)
        for each p in m.powerups
            if p.isActive then
                powerRect = {x: p.x, y: p.y, w: p.width, h: p.height}
                if CheckAABB(pRect, powerRect) then
                    p.isActive = false
                    if p.powerType = "fireflower" then
                        m.player.powerState = "fire"
                        m.score = m.score + 1000
                        m.player.fireCooldown = 0.0
                        if audioManager <> invalid then audioManager.PlaySFX("powerup")
                    else if p.powerType = "star" then
                        m.player.invincibleTimer = 6.0
                        m.player.starSparkleTimer = 0.0
                        m.score = m.score + 1000
                        if audioManager <> invalid then audioManager.PlaySFX("star")
                    else
                        m.player.powerState = "super"
                        m.player.lives = m.player.lives + 1
                        m.score = m.score + 500
                        if audioManager <> invalid then audioManager.PlaySFX("powerup")
                    end if
                    SpawnParticleBurst(p.x + p.width / 2, p.y, 10, &hFFD700FF)
                end if
            end if
        end for

        ' Hazards (spikes)
        for each hz in m.hazards
            if hz.isActive then
                hRect = {x: hz.x, y: hz.y, w: hz.width, h: hz.height}
                if CheckAABB(pRect, hRect) then
                    if DamagePlayer(audioManager) then
                        m.gameOver = true
                    end if
                end if
            end if
        end for

        ' Goal (level completion)
        for each gl in m.goals
            if gl.isActive then
                gRect = {x: gl.x, y: gl.y, w: gl.width, h: gl.height}
                if CheckAABB(pRect, gRect) then
                    m.levelComplete = true
                end if
            end if
        end for
    end if

    ' Update particles
    for each prt in m.particles
        if prt.isActive then
            prt.lifetime = prt.lifetime - deltaTime
            if prt.lifetime <= 0 then
                prt.isActive = false
            else
                prt.vy = prt.vy + 400 * deltaTime
                prt.x = prt.x + (prt.vx * deltaTime)
                prt.y = prt.y + (prt.vy * deltaTime)
            end if
        end if
    end for
    
    ' Update projectiles (fireballs)
    for each fb in m.projectiles
        if fb.isActive then
            fb.lifetime = fb.lifetime - deltaTime
            if fb.lifetime <= 0 then
                fb.isActive = false
            else
                fb.vy = fb.vy + fb.gravity * deltaTime
                fb.x = fb.x + (fb.vx * deltaTime)
                fb.y = fb.y + (fb.vy * deltaTime)

                ' Bounce on ground / kill on wall
                if CheckTileCollisionX(fb, levelData, GetPhysicsConstants()) then
                    fb.isActive = false
                end if
                if CheckTileCollisionY(fb, levelData, GetPhysicsConstants()) then
                    fb.vy = -Abs(fb.vy) * 0.7
                end if
            end if
        end if
    end for
    
    ' TODO: Update projectiles
End Sub


' *****************************************************
' Draw All Entities
' *****************************************************
Sub EntityManager_Draw(screen as Object, cameraX as Float, cameraY as Float)
    ' Draw coins first (background layer)
    for each c in m.coins
        if c.isActive then c.Draw(screen, cameraX, cameraY)
    end for

    ' Draw powerups
    for each p in m.powerups
        if p.isActive then p.Draw(screen, cameraX, cameraY)
    end for

    ' Draw hazards
    for each hz in m.hazards
        if hz.isActive then hz.Draw(screen, cameraX, cameraY)
    end for

    ' Draw goombas
    for each g in m.goombas
        if g.isActive then g.Draw(screen, cameraX, cameraY)
    end for

    ' Draw koopas
    for each k in m.koopas
        if k.isActive then k.Draw(screen, cameraX, cameraY)
    end for

    ' Draw goals
    for each gl in m.goals
        if gl.isActive then gl.Draw(screen, cameraX, cameraY)
    end for

    ' Draw particles
    for each prt in m.particles
        if prt.isActive then
            px = Int(prt.x - cameraX)
            py = Int(prt.y - cameraY)
            screen.DrawRect(px, py, prt.size, prt.size, prt.color)
        end if
    end for

    ' Draw projectiles
    for each fb in m.projectiles
        if fb.isActive then
            fb.Draw(screen, cameraX, cameraY)
        end if
    end for

    ' Draw player on top
    if m.player <> invalid AND m.player.isActive then
        m.player.Draw(screen, cameraX, cameraY)
    end if
    
    ' TODO: Draw projectiles
End Sub


' *****************************************************
' Spawn particle burst helper
' *****************************************************
Sub EntityManager_SpawnParticleBurst(x as Float, y as Float, count as Integer, color as Integer)
    if count < 1 then return
    for i = 0 to count - 1
        slot = invalid
        for each p in m.particles
            if NOT p.isActive then
                slot = p
                exit for
            end if
        end for

        if slot = invalid then exit for

        slot.isActive = true
        slot.x = x
        slot.y = y
        slot.size = 4 + (i mod 3)
        slot.color = color
        slot.lifetime = 0.4 + (Rnd(1) * 0.2)
        ' random spread
        spread = 120.0
        slot.vx = (Rnd(1) * spread) - (spread / 2)
        slot.vy = -120 - (Rnd(1) * 80)
    end for
End Sub


' *****************************************************
' Fire a fireball from player if pool slot available
' *****************************************************
Sub FireFireball(player as Object, manager as Object)
    dir = 1
    if player.facing < 0 then dir = -1

    slot = invalid
    for each fb in manager.projectiles
        if NOT fb.isActive then
            slot = fb
            exit for
        end if
    end for

    if slot = invalid then return

    slot.isActive = true
    slot.x = player.x + (player.width / 2) + (dir * 16)
    slot.y = player.y + (player.height / 2) - 6
    slot.vx = 360.0 * dir
    slot.vy = -120.0
    slot.lifetime = 2.5
End Sub
