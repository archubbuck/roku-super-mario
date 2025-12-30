' *****************************************************
' Input System - Handle Roku Remote Input
' Tracks button states for responsive gameplay
' *****************************************************

' *****************************************************
' Initialize Input System
' Returns an input state object
' *****************************************************
Function InitInputSystem() as Object
    inputState = {
        ' Button states (true = currently pressed)
        left: false
        right: false
        up: false
        down: false
        jump: false      ' OK button (6) or Up (2)
        run: false       ' Star button (10) for run
        pause: false     ' Option (*) button
        back: false      ' Back button
        
        ' Key code constants for reference
        ' Press codes (when button pressed down)
        KEY_LEFT: 4
        KEY_RIGHT: 5
        KEY_UP: 2
        KEY_DOWN: 3
        KEY_OK: 6        ' Center button / Select
        KEY_BACK: 0
        KEY_REWIND: 8    ' << button
        KEY_FASTFORWARD: 9  ' >> button
        KEY_STAR: 10     ' * button (Options)
        KEY_PLAY: 13     ' Play/Pause button
        
        ' Release codes (add 100 to press code)
        KEY_LEFT_RELEASE: 104
        KEY_RIGHT_RELEASE: 105
        KEY_UP_RELEASE: 102
        KEY_DOWN_RELEASE: 103
        KEY_OK_RELEASE: 106
        KEY_BACK_RELEASE: 100
        KEY_STAR_RELEASE: 110
        KEY_PLAY_RELEASE: 113
        
        ' Methods
        HandleEvent: InputSystem_HandleEvent
        Reset: InputSystem_Reset
        IsMovingLeft: InputSystem_IsMovingLeft
        IsMovingRight: InputSystem_IsMovingRight
        IsJumping: InputSystem_IsJumping
        IsRunning: InputSystem_IsRunning
        IsDucking: InputSystem_IsDucking
    }
    
    return inputState
End Function


' *****************************************************
' Handle Input Event
' Process roUniversalControlEvent and update button states
' *****************************************************
Sub InputSystem_HandleEvent(event as Object)
    keyCode = event.GetInt()
    isPressed = (event.GetIndex() = 1)  ' 1 = press, 0 = release
    
    ' Left/Right movement
    if keyCode = m.KEY_LEFT then
        m.left = true
        m.right = false  ' Release opposite direction
    else if keyCode = m.KEY_LEFT_RELEASE then
        m.left = false
    else if keyCode = m.KEY_RIGHT then
        m.right = true
        m.left = false  ' Release opposite direction
    else if keyCode = m.KEY_RIGHT_RELEASE then
        m.right = false
        
    ' Up/Down
    else if keyCode = m.KEY_UP OR keyCode = m.KEY_OK then
        m.jump = true
    else if keyCode = m.KEY_UP_RELEASE OR keyCode = m.KEY_OK_RELEASE then
        m.jump = false
    else if keyCode = m.KEY_DOWN then
        m.down = true
    else if keyCode = m.KEY_DOWN_RELEASE then
        m.down = false
        
    ' Special buttons
    else if keyCode = m.KEY_STAR then
        m.run = true  ' Hold for running
    else if keyCode = m.KEY_STAR_RELEASE then
        m.run = false
    else if keyCode = m.KEY_BACK then
        m.back = true
    else if keyCode = m.KEY_BACK_RELEASE then
        m.back = false
    end if
End Sub


' *****************************************************
' Reset Input State
' Clear all button states
' *****************************************************
Sub InputSystem_Reset()
    m.left = false
    m.right = false
    m.up = false
    m.down = false
    m.jump = false
    m.run = false
    m.pause = false
    m.back = false
End Sub


' *****************************************************
' Helper Methods - Check movement states
' *****************************************************

Function InputSystem_IsMovingLeft() as Boolean
    return m.left AND NOT m.right
End Function

Function InputSystem_IsMovingRight() as Boolean
    return m.right AND NOT m.left
End Function

Function InputSystem_IsJumping() as Boolean
    return m.jump
End Function

Function InputSystem_IsRunning() as Boolean
    return m.run
End Function

Function InputSystem_IsDucking() as Boolean
    return m.down
End Function
