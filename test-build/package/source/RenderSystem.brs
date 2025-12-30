' *****************************************************
' Rendering System - Tile Map and Sprite Rendering
' Implements viewport culling for performance
' *****************************************************

' *****************************************************
' Create Rendering System
' *****************************************************
Function CreateRenderSystem() as Object
    renderer = {
        ' Screen dimensions (FHD)
        SCREEN_WIDTH: 1920
        SCREEN_HEIGHT: 1080
        
        ' Tile properties
        TILE_SIZE: 32
        
        ' Camera position
        cameraX: 0.0
        cameraY: 0.0
        
        ' Tileset bitmap
        tileset: invalid
        
        ' Background color
        bgColor: &h5C94FCFF  ' Sky blue
        
        ' Methods
        Init: RenderSystem_Init
        UpdateCamera: RenderSystem_UpdateCamera
        RenderTileMap: RenderSystem_RenderTileMap
        Clear: RenderSystem_Clear
    }
    
    return renderer
End Function


' *****************************************************
' Initialize Rendering System
' *****************************************************
Sub RenderSystem_Init()
    ' Load tileset
    m.tileset = CreateObject("roBitmap", "pkg:/images/tiles/tileset-fhd.png")
    print "Rendering system initialized"
    print "Tileset loaded: " + str(m.tileset <> invalid)
End Sub


' *****************************************************
' Update Camera Position
' Follow the player with screen bounds
' *****************************************************
Sub RenderSystem_UpdateCamera(playerX as Float, playerY as Float, levelWidth as Integer)
    ' Center camera on player horizontally
    m.cameraX = playerX - (m.SCREEN_WIDTH / 2)
    
    ' Clamp camera to level bounds
    if m.cameraX < 0 then m.cameraX = 0
    
    maxCameraX = (levelWidth * m.TILE_SIZE) - m.SCREEN_WIDTH
    if m.cameraX > maxCameraX then m.cameraX = maxCameraX
    
    ' Keep camera Y fixed for now (no vertical scrolling)
    m.cameraY = 0
End Sub


' *****************************************************
' Clear Screen
' *****************************************************
Sub RenderSystem_Clear(screen as Object)
    screen.Clear(m.bgColor)
End Sub


' *****************************************************
' Render Tile Map with Viewport Culling
' Only draws visible tiles based on camera position
' *****************************************************
Sub RenderSystem_RenderTileMap(screen as Object, levelData as Object)
    if m.tileset = invalid then return
    
    ' Calculate visible tile range (with 1-tile buffer)
    startCol = Int(m.cameraX / m.TILE_SIZE) - 1
    endCol = Int((m.cameraX + m.SCREEN_WIDTH) / m.TILE_SIZE) + 1
    startRow = Int(m.cameraY / m.TILE_SIZE) - 1
    endRow = Int((m.cameraY + m.SCREEN_HEIGHT) / m.TILE_SIZE) + 1
    
    ' Clamp to level bounds
    if startCol < 0 then startCol = 0
    if startRow < 0 then startRow = 0
    if endCol >= levelData.width then endCol = levelData.width - 1
    if endRow >= levelData.height then endRow = levelData.height - 1
    
    ' Create regions for each tile in the tileset
    ' Tileset layout: [Ground(0-31), Brick(32-63), Question(64-95)]
    groundRegion = CreateObject("roRegion", m.tileset, 0, 0, 32, 32)
    brickRegion = CreateObject("roRegion", m.tileset, 32, 0, 32, 32)
    questionRegion = CreateObject("roRegion", m.tileset, 64, 0, 32, 32)
    
    ' Render only visible tiles
    for row = startRow to endRow
        for col = startCol to endCol
            tileId = levelData.tiles[row][col]
            
            if tileId > 0 then
                ' Calculate screen position
                screenX = Int((col * m.TILE_SIZE) - m.cameraX)
                screenY = Int((row * m.TILE_SIZE) - m.cameraY)
                
                ' Select tile region based on ID
                tileRegion = invalid
                if tileId = 1 then
                    tileRegion = groundRegion
                else if tileId = 2 then
                    tileRegion = brickRegion
                else if tileId = 3 then
                    tileRegion = questionRegion
                end if
                
                ' Draw tile
                if tileRegion <> invalid then
                    screen.DrawObject(screenX, screenY, tileRegion)
                end if
            end if
        end for
    end for
End Sub
