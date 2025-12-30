' *****************************************************
' Physics System - AABB Collision Detection & Physics
' Implements gravity, velocity, and tile-based collision
' *****************************************************

' Physics constants (tuned to match Super Mario feel)
Function GetPhysicsConstants() as Object
    return {
        ' Gravity and movement
        GRAVITY: 1200.0              ' pixels/second² (downward acceleration)
        MAX_FALL_SPEED: 600.0        ' pixels/second (terminal velocity)
        JUMP_VELOCITY: -400.0        ' pixels/second (negative = upward)
        JUMP_HOLD_BOOST: 0.85        ' Multiplier while holding jump button
        
        ' Horizontal movement
        WALK_SPEED: 180.0            ' pixels/second
        RUN_SPEED: 300.0             ' pixels/second
        GROUND_ACCELERATION: 800.0   ' pixels/second²
        GROUND_FRICTION: 600.0       ' pixels/second²
        AIR_ACCELERATION: 400.0      ' pixels/second² (less control in air)
        
        ' Tile properties
        TILE_SIZE: 32                ' 32x32 pixels per tile
    }
End Function


' *****************************************************
' Apply Gravity to Entity
' *****************************************************
Sub ApplyGravity(entity as Object, deltaTime as Float, constants as Object)
    if NOT entity.isGrounded then
        ' Apply gravity acceleration
        entity.vy = entity.vy + (constants.GRAVITY * deltaTime)
        
        ' Cap at terminal velocity
        if entity.vy > constants.MAX_FALL_SPEED then
            entity.vy = constants.MAX_FALL_SPEED
        end if
    end if
End Sub


' *****************************************************
' Check AABB Collision
' Returns true if two axis-aligned bounding boxes overlap
' *****************************************************
Function CheckAABB(rectA as Object, rectB as Object) as Boolean
    ' Check if rectangles overlap on both axes
    overlapX = (rectA.x < rectB.x + rectB.w) AND (rectA.x + rectA.w > rectB.x)
    overlapY = (rectA.y < rectB.y + rectB.h) AND (rectA.y + rectA.h > rectB.y)
    return overlapX AND overlapY
End Function


' *****************************************************
' Get Tile at Grid Position
' Returns tile ID (0 = air, >0 = solid)
' *****************************************************
Function GetTileAt(levelData as Object, gridX as Integer, gridY as Integer) as Integer
    ' Bounds check
    if gridX < 0 OR gridY < 0 OR gridY >= levelData.height OR gridX >= levelData.width then
        return 1  ' Treat out-of-bounds as solid
    end if
    
    ' Get tile from 2D array
    return levelData.tiles[gridY][gridX]
End Function


' *****************************************************
' Check Tile Collision on X Axis
' Returns true if collision detected and resolved
' *****************************************************
Function CheckTileCollisionX(entity as Object, levelData as Object, constants as Object) as Boolean
    tileSize = constants.TILE_SIZE
    collided = false
    
    ' Calculate grid coordinates of entity's bounding box
    ' Check multiple points along the edge moving toward
    
    if entity.vx > 0 then
        ' Moving right - check right edge
        rightEdge = entity.x + entity.width
        topY = Int(entity.y / tileSize)
        bottomY = Int((entity.y + entity.height - 1) / tileSize)
        checkX = Int(rightEdge / tileSize)
        
        for gridY = topY to bottomY
            tileId = GetTileAt(levelData, checkX, gridY)
            if tileId > 0 then
                ' Solid tile - snap to left edge of tile
                entity.x = (checkX * tileSize) - entity.width
                entity.vx = 0
                collided = true
                exit for
            end if
        end for
        
    else if entity.vx < 0 then
        ' Moving left - check left edge
        leftEdge = entity.x
        topY = Int(entity.y / tileSize)
        bottomY = Int((entity.y + entity.height - 1) / tileSize)
        checkX = Int(leftEdge / tileSize)
        
        for gridY = topY to bottomY
            tileId = GetTileAt(levelData, checkX, gridY)
            if tileId > 0 then
                ' Solid tile - snap to right edge of tile
                entity.x = (checkX + 1) * tileSize
                entity.vx = 0
                collided = true
                exit for
            end if
        end for
    end if
    
    return collided
End Function


' *****************************************************
' Check Tile Collision on Y Axis
' Returns true if collision detected and resolved
' *****************************************************
Function CheckTileCollisionY(entity as Object, levelData as Object, constants as Object) as Boolean
    tileSize = constants.TILE_SIZE
    collided = false
    entity.isGrounded = false  ' Reset grounded state
    
    if entity.vy > 0 then
        ' Moving down - check bottom edge
        bottomEdge = entity.y + entity.height
        leftX = Int(entity.x / tileSize)
        rightX = Int((entity.x + entity.width - 1) / tileSize)
        checkY = Int(bottomEdge / tileSize)
        
        for gridX = leftX to rightX
            tileId = GetTileAt(levelData, gridX, checkY)
            if tileId > 0 then
                ' Solid tile - snap to top of tile
                entity.y = (checkY * tileSize) - entity.height
                entity.vy = 0
                entity.isGrounded = true
                collided = true
                exit for
            end if
        end for
        
    else if entity.vy < 0 then
        ' Moving up - check top edge
        topEdge = entity.y
        leftX = Int(entity.x / tileSize)
        rightX = Int((entity.x + entity.width - 1) / tileSize)
        checkY = Int(topEdge / tileSize)
        
        for gridX = leftX to rightX
            tileId = GetTileAt(levelData, gridX, checkY)
            if tileId > 0 then
                ' Solid tile - snap to bottom of tile
                entity.y = (checkY + 1) * tileSize
                entity.vy = 0
                collided = true
                exit for
            end if
        end for
    end if
    
    return collided
End Function


' *****************************************************
' Apply Horizontal Movement with Friction
' *****************************************************
Sub ApplyHorizontalMovement(entity as Object, inputState as Object, deltaTime as Float, constants as Object)
    targetSpeed = 0.0
    acceleration = constants.GROUND_ACCELERATION
    
    if NOT entity.isGrounded then
        acceleration = constants.AIR_ACCELERATION  ' Less control in air
    end if
    
    ' Determine target speed based on input
    if inputState.IsMovingRight() then
        if inputState.IsRunning() then
            targetSpeed = constants.RUN_SPEED
        else
            targetSpeed = constants.WALK_SPEED
        end if
        entity.facing = 1  ' Face right
        
    else if inputState.IsMovingLeft() then
        if inputState.IsRunning() then
            targetSpeed = -constants.RUN_SPEED
        else
            targetSpeed = -constants.WALK_SPEED
        end if
        entity.facing = -1  ' Face left
    end if
    
    ' Accelerate toward target speed
    if entity.vx < targetSpeed then
        entity.vx = entity.vx + (acceleration * deltaTime)
        if entity.vx > targetSpeed then entity.vx = targetSpeed
    else if entity.vx > targetSpeed then
        entity.vx = entity.vx - (acceleration * deltaTime)
        if entity.vx < targetSpeed then entity.vx = targetSpeed
    end if
    
    ' Apply friction when not actively moving
    if targetSpeed = 0 AND entity.isGrounded then
        if entity.vx > 0 then
            entity.vx = entity.vx - (constants.GROUND_FRICTION * deltaTime)
            if entity.vx < 0 then entity.vx = 0
        else if entity.vx < 0 then
            entity.vx = entity.vx + (constants.GROUND_FRICTION * deltaTime)
            if entity.vx > 0 then entity.vx = 0
        end if
    end if
End Sub


' *****************************************************
' Apply Jump
' Called when jump button is pressed and entity is grounded
' *****************************************************
Sub ApplyJump(entity as Object, constants as Object)
    if entity.isGrounded then
        entity.vy = constants.JUMP_VELOCITY
        entity.isGrounded = false
    end if
End Sub


' *****************************************************
' Handle Variable Jump Height
' Reduce upward velocity when jump button released
' *****************************************************
Sub HandleVariableJump(entity as Object, inputState as Object, constants as Object)
    ' If moving upward and jump button released, cut velocity
    if entity.vy < 0 AND NOT inputState.IsJumping() then
        entity.vy = entity.vy * constants.JUMP_HOLD_BOOST
    end if
End Sub


' *****************************************************
' Update Entity Physics
' Main physics update function
' *****************************************************
Sub UpdateEntityPhysics(entity as Object, inputState as Object, levelData as Object, deltaTime as Float, audioManager = invalid)
    constants = GetPhysicsConstants()
    
    ' Trigger jump when button is newly pressed while grounded
    jumpWasHeld = false
    if inputState <> invalid then jumpWasHeld = inputState.IsJumping()

    if jumpWasHeld AND entity.isGrounded AND NOT entity.jumpHeldLastFrame then
        ApplyJump(entity, constants)
        if audioManager <> invalid then audioManager.PlaySFX("jump")
    end if

    entity.jumpHeldLastFrame = jumpWasHeld

    ' Apply horizontal input
    ApplyHorizontalMovement(entity, inputState, deltaTime, constants)
    
    ' Apply gravity
    ApplyGravity(entity, deltaTime, constants)
    
    ' Handle variable jump height
    HandleVariableJump(entity, inputState, constants)
    
    ' ===== X-AXIS MOVEMENT AND COLLISION =====
    ' Apply X velocity (sub-pixel precision with Float)
    entity.x = entity.x + (entity.vx * deltaTime)
    
    ' Check X collision against tiles
    CheckTileCollisionX(entity, levelData, constants)
    
    ' ===== Y-AXIS MOVEMENT AND COLLISION =====
    ' Apply Y velocity
    entity.y = entity.y + (entity.vy * deltaTime)
    
    ' Check Y collision against tiles
    CheckTileCollisionY(entity, levelData, constants)
End Sub
