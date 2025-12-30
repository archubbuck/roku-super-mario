' *****************************************************
' Menu System - roScreen-based main menu
' Manual rendering and navigation
' *****************************************************

Function CreateMenuSystem() as Object
    menu = {
        items: ["Start Game", "Select Level", "Options", "Quit"]
        levelItemIndex: 1
        selected: 0
        font: invalid
        titleFont: invalid
        bgColor: &h0A1E3BFF  ' Dark blue backdrop
        highlightColor: &h2E74FFFF
        textColor: &hFFFFFFFF
        subtitleColor: &hB0FFFFFF

        Init: Menu_Init
        HandleEvent: Menu_HandleEvent
        Render: Menu_Render
        UpdateLevelLabel: Menu_UpdateLevelLabel
    }
    return menu
End Function

Sub Menu_Init()
    m.font = CreateObject("roFont", "font:MediumBoldSystemFont", 48, false)
    m.titleFont = CreateObject("roFont", "font:MediumBoldSystemFont", 72, false)
End Sub

Sub Menu_HandleEvent(event as Object, gameState as Object)
    if type(event) <> "roUniversalControlEvent" then return
    if event.GetIndex() <> 1 then return  ' Only on press

    key = event.GetInt()
    count = m.items.Count()

    if key = gameState.inputState.KEY_UP then
        m.selected = (m.selected - 1 + count) MOD count
    else if key = gameState.inputState.KEY_DOWN then
        m.selected = (m.selected + 1) MOD count
    else if key = gameState.inputState.KEY_OK then
        Menu_ActivateSelection(gameState)
    else if key = gameState.inputState.KEY_BACK then
        gameState.running = false
    end if
End Sub

Sub Menu_ActivateSelection(gameState as Object)
    choice = m.items[m.selected]
    if choice = "Start Game" then
        gameState.requestReset = true
        gameState.mode = "game"
        if gameState.inputState <> invalid then gameState.inputState.Reset()
    else if Left(choice, 12) = "Select Level" then
        if gameState.levelList <> invalid then
            gameState.levelIndex = (gameState.levelIndex + 1) MOD gameState.levelList.Count()
            m.UpdateLevelLabel(gameState)
            print "Selected level: " + gameState.levelList[gameState.levelIndex].name
        end if
    else if choice = "Options" then
        gameState.optionsReturnMode = "menu"
        gameState.mode = "options"
        gameState.optionsMenu.selected = 0
    else if choice = "Quit" then
        gameState.running = false
    else
        ' Options placeholder
        print "Options menu not implemented yet"
    end if
End Sub

Sub Menu_Render(screen as Object, renderer as Object)
    screen.Clear(m.bgColor)

    ' Title
    title = "Super Mario Clone"
    titleW = m.titleFont.GetOneLineWidth(title)
    titleX = (renderer.SCREEN_WIDTH - titleW) / 2
    screen.DrawText(title, titleX, 200, m.textColor, m.titleFont)

    subtitle = "Press OK to select"
    subW = m.font.GetOneLineWidth(subtitle)
    subX = (renderer.SCREEN_WIDTH - subW) / 2
    screen.DrawText(subtitle, subX, 280, m.subtitleColor, m.font)

    ' Menu items
    startY = 380
    spacing = 90
    for i = 0 to m.items.Count() - 1
        label = m.items[i]
        labelW = m.font.GetOneLineWidth(label)
        labelX = (renderer.SCREEN_WIDTH - labelW) / 2
        labelY = startY + (i * spacing)

        if i = m.selected then
            highlightW = labelW + 120
            highlightH = 70
            highlightX = (renderer.SCREEN_WIDTH - highlightW) / 2
            highlightY = labelY - 20
            screen.DrawRect(highlightX, highlightY, highlightW, highlightH, m.highlightColor)
        end if

        screen.DrawText(label, labelX, labelY, m.textColor, m.font)
    end for
End Sub


Sub Menu_UpdateLevelLabel(gameState as Object)
    if gameState = invalid OR gameState.levelList = invalid then return
    if m.levelItemIndex < 0 OR m.levelItemIndex >= m.items.Count() then return
    levelName = gameState.levelList[gameState.levelIndex].name
    m.items[m.levelItemIndex] = "Select Level: " + levelName
End Sub
