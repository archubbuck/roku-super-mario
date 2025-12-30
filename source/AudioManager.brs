' *****************************************************
' Audio Manager - Low Latency SFX & Music
' Uses roAudioResource for short sounds and roAudioPlayer for music
' *****************************************************

' *****************************************************
' Factory: Create Audio Manager
' *****************************************************
Function CreateAudioManager() as Object
    mgr = {
        sfx: {}
        musicPlayer: invalid
        musicPort: invalid
        currentMusic: ""
        defaultSfxVolume: 80  ' 0-100
        defaultMusicVolume: 70
        registry: invalid

        Init: AudioManager_Init
        PlaySFX: AudioManager_PlaySFX
        PlayMusic: AudioManager_PlayMusic
        StopMusic: AudioManager_StopMusic
        SetMusicVolume: AudioManager_SetMusicVolume
        SetSFXVolume: AudioManager_SetSFXVolume
        SaveVolumes: AudioManager_SaveVolumes
        LoadVolumes: AudioManager_LoadVolumes
    }

    return mgr
End Function


' *****************************************************
' Initialize and load audio assets
' *****************************************************
Sub AudioManager_Init()
    m.registry = CreateObject("roRegistrySection", "settings")
    m.LoadVolumes()

    ' Preload short SFX as roAudioResource for low latency
    sfxPaths = {
        jump: "pkg:/audio/sfx/jump.wav"
        coin: "pkg:/audio/sfx/coin.wav"
        stomp: "pkg:/audio/sfx/stomp.wav"
        die: "pkg:/audio/sfx/die.wav"
        powerup: "pkg:/audio/sfx/powerup.wav"
        fireball: "pkg:/audio/sfx/powerup.wav"
        star: "pkg:/audio/sfx/powerup.wav"
        goal: "pkg:/audio/sfx/powerup.wav"
    }

    for each key in sfxPaths
        path = sfxPaths[key]
        res = CreateObject("roAudioResource", path)
        if res <> invalid then
            res.SetVolume(m.defaultSfxVolume)
            res.SetMaxSimulStreams(3)
        else
            print "WARN: Failed to load SFX: " + path
        end if
        m.sfx[key] = res
    end for

    ' Music player setup
    m.musicPort = CreateObject("roMessagePort")
    m.musicPlayer = CreateObject("roAudioPlayer")
    m.musicPlayer.SetMessagePort(m.musicPort)
    m.musicPlayer.SetLoop(true)
    m.musicPlayer.SetVolume(m.defaultMusicVolume)
End Sub


' *****************************************************
' Play a short sound effect by name
' *****************************************************
Sub AudioManager_PlaySFX(name as String, volume = invalid)
    if NOT m.sfx.DoesExist(name) then return

    res = m.sfx[name]
    if res = invalid then return

    playVolume = m.defaultSfxVolume
    if volume <> invalid then playVolume = volume

    res.Trigger(playVolume)
End Sub


' *****************************************************
' Play looping background music
' *****************************************************
Sub AudioManager_PlayMusic(trackName as String)
    if trackName = "" then return
    if m.musicPlayer = invalid then return

    ' Avoid restarting the same track
    if m.currentMusic = trackName then return

    ' Recreate player to clear any previous content safely
    m.musicPlayer.Stop()
    m.musicPlayer = CreateObject("roAudioPlayer")
    m.musicPlayer.SetMessagePort(m.musicPort)
    m.musicPlayer.SetLoop(true)
    m.musicPlayer.SetVolume(m.defaultMusicVolume)

    url = "pkg:/audio/music/" + trackName + ".wav"
    content = { url: url }

    m.musicPlayer.AddContent(content)
    m.musicPlayer.Play()
    m.currentMusic = trackName
End Sub


' *****************************************************
' Stop current music
' *****************************************************
Sub AudioManager_StopMusic()
    if m.musicPlayer <> invalid then
        m.musicPlayer.Stop()
    end if
    m.currentMusic = ""
End Sub


' *****************************************************
' Adjust music volume (0-100)
' *****************************************************
Sub AudioManager_SetMusicVolume(volume as Integer)
    if m.musicPlayer = invalid then return
    m.musicPlayer.SetVolume(volume)
    m.defaultMusicVolume = volume
    m.SaveVolumes()
End Sub


' *****************************************************
' Adjust SFX volume (0-100)
' *****************************************************
Sub AudioManager_SetSFXVolume(volume as Integer)
    m.defaultSfxVolume = volume
    for each key in m.sfx
        res = m.sfx[key]
        if res <> invalid then res.SetVolume(volume)
    end for
    m.SaveVolumes()
End Sub


' *****************************************************
' Persist volume settings
' *****************************************************
Sub AudioManager_SaveVolumes()
    if m.registry = invalid then return
    m.registry.Write("musicVolume", str(m.defaultMusicVolume))
    m.registry.Write("sfxVolume", str(m.defaultSfxVolume))
    m.registry.Flush()
End Sub


' *****************************************************
' Load volume settings from registry if present
' *****************************************************
Sub AudioManager_LoadVolumes()
    if m.registry = invalid then return
    musicStr = m.registry.Read("musicVolume")
    sfxStr = m.registry.Read("sfxVolume")
    if musicStr <> invalid then
        mv = val(musicStr)
        if mv >= 0 AND mv <= 100 then m.defaultMusicVolume = mv
    end if
    if sfxStr <> invalid then
        sv = val(sfxStr)
        if sv >= 0 AND sv <= 100 then m.defaultSfxVolume = sv
    end if
End Sub
