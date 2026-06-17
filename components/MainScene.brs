sub init()
    print "[OnlyAds] MainScene init"

    m.video = m.top.FindNode("adVideo")
    m.status = m.top.FindNode("statusLabel")
    m.aboutHint = m.top.FindNode("aboutHintLabel")
    m.loader = CreateObject("roSGNode", "AdLoader")

    m.adUrls = []
    m.adDetails = []
    m.adIndex = -1
    m.pausedByUser = false
    m.resumeAfterDialog = false
    m.currentAdTimer = invalid
    m.dialogMode = ""

    m.video.ObserveField("state", "onVideoStateChanged")
    m.loader.ObserveField("adDetails", "onAdDetailsLoaded")
    m.loader.ObserveField("adUrls", "onAdsLoaded")
    m.loader.ObserveField("status", "onAdLoadStatus")
    m.loader.ObserveField("error", "onAdLoadError")

    keepSceneFocus()
    m.top.SetFocus(true)
    loadAds()
end sub

sub loadAds()
    config = GetAdConfig()
    m.status.text = "Loading ads - press Up for About"
    m.loader.vastTags = config.vastTags
    m.loader.requestTimeoutSeconds = config.requestTimeoutSeconds
    m.loader.maxAdsPerRefresh = config.maxAdsPerRefresh
    if config.DoesExist("debugEnabled") then m.loader.debugEnabled = config.debugEnabled
    debugLog("Loading ads")
    m.loader.control = "RUN"
end sub

sub onAdDetailsLoaded()
    m.adDetails = m.loader.adDetails
end sub

sub onAdsLoaded()
    m.adUrls = m.loader.adUrls
    if m.adUrls = invalid or m.adUrls.Count() = 0 then
        m.status.text = "No playable ad media found"
        return
    end if

    m.status.text = ""
    m.adIndex = -1
    debugLog("Loaded " + m.adUrls.Count().ToStr() + " playable ad URL(s)")
    printAdCatalog()
    playNextAd()
end sub

sub onAdLoadStatus()
    if m.loader.status <> invalid and m.loader.status <> "" then
        m.status.text = m.loader.status
        debugLog(m.loader.status)
    end if
end sub

sub onAdLoadError()
    if m.loader.error <> invalid and m.loader.error <> "" then
        m.status.text = m.loader.error
        debugLog("ERROR: " + m.loader.error)
    end if
end sub

sub playNextAd()
    if m.adUrls = invalid then
        loadAds()
        return
    end if

    if m.adUrls.Count() = 0 then
        loadAds()
        return
    end if

    m.adIndex = m.adIndex + 1
    if m.adIndex >= m.adUrls.Count() then
        loadAds()
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    ad = getCurrentAdDetail()
    if ad <> invalid and ad.DoesExist("url") then
        content.url = ad.url
        if ad.DoesExist("streamFormat") then
            content.streamformat = ad.streamFormat
        else
            content.streamformat = inferStreamFormat(content.url)
        end if
    else
        content.url = m.adUrls[m.adIndex]
        content.streamformat = inferStreamFormat(content.url)
    end if
    content.title = "Advertisement"

    printAdBeforePlay(ad, m.adIndex, m.adUrls.Count())
    debugLog("Playing ad " + (m.adIndex + 1).ToStr() + "/" + m.adUrls.Count().ToStr() + " format=" + content.streamformat + " url=" + content.url)
    m.video.content = content
    m.currentAdTimer = CreateObject("roTimespan")
    m.currentAdTimer.Mark()
    m.video.control = "play"
    keepSceneFocus()
end sub

sub onVideoStateChanged()
    state = m.video.state
    debugLog("Video state: " + state)
    if state = "finished" then
        logCurrentAdElapsed("finished")
        playNextAd()
    else if state = "error" then
        logCurrentAdElapsed("error")
        m.status.text = "Skipping ad that failed to play"
        playNextAd()
    else if state = "playing" then
        m.status.text = ""
        keepSceneFocus()
    end if
end sub

sub keepSceneFocus()
    if m.video <> invalid then
        if m.video.HasField("enableUI") then m.video.enableUI = false
        m.video.SetFocus(false)
    end if
    m.top.SetFocus(true)
end sub

sub logCurrentAdElapsed(reason as string)
    if m.currentAdTimer = invalid then
        debugLog("Ad " + reason + " before timer started")
        return
    end if

    elapsedMs = m.currentAdTimer.TotalMilliseconds()
    elapsedSeconds = elapsedMs / 1000.0
    debugLog("Ad " + reason + " after " + elapsedSeconds.ToStr() + " seconds")
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    debugLog("Key pressed: " + key)

    if key = "options" or key = "option" or key = "*" then
        showAboutDialog()
        return true
    end if

    if key = "OK" or key = "up" then
        showAboutDialog()
        return true
    end if

    if key = "play" then
        if m.video.state = "playing" then
            m.pausedByUser = true
            m.video.control = "pause"
        else
            m.pausedByUser = false
            m.video.control = "resume"
        end if
        return true
    else if key = "right" then
        logCurrentAdElapsed("skipped")
        playNextAd()
        return true
    else if key = "back" then
        m.video.control = "stop"
        return false
    end if

    return false
end function

sub showAboutDialog()
    closeDialog()

    if m.video <> invalid and m.video.state = "playing" then
        m.resumeAfterDialog = true
        m.video.control = "pause"
    else
        m.resumeAfterDialog = false
    end if

    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Only Ads"
    dialog.message = "Status: Paused" + Chr(10) + "Developed by: gressware.ai" + Chr(10) + "Version 1.1"
    dialog.buttons = ["OK"]
    dialog.ObserveField("buttonSelected", "onDialogButtonSelected")

    m.dialogMode = "about"
    m.top.dialog = dialog
    debugLog("Showing about dialog")
end sub

sub onDialogButtonSelected()
    dialog = m.top.dialog
    if dialog = invalid then return

    selected = dialog.buttonSelected
    debugLog("Dialog selected mode=" + m.dialogMode + " button=" + selected.ToStr())

    closeDialog()
end sub

sub closeDialog()
    if m.top.dialog <> invalid then
        m.top.dialog.close = true
    end if
    m.dialogMode = ""

    if m.resumeAfterDialog then
        m.resumeAfterDialog = false
        m.video.control = "resume"
        keepSceneFocus()
    end if
end sub

function inferStreamFormat(url as string) as string
    lowerUrl = LCase(url)
    if Instr(1, lowerUrl, ".m3u8") > 0 then return "hls"
    if Instr(1, lowerUrl, ".mpd") > 0 then return "dash"
    return "mp4"
end function

function getCurrentAdDetail() as dynamic
    if m.adDetails = invalid then return invalid
    if m.adIndex < 0 then return invalid
    if m.adIndex >= m.adDetails.Count() then return invalid
    return m.adDetails[m.adIndex]
end function

sub printAdCatalog()
    if m.adDetails = invalid or m.adDetails.Count() = 0 then return

    debugLog("Ad catalog:")
    for i = 0 to m.adDetails.Count() - 1
        debugLog("  " + formatAdDetail(m.adDetails[i]))
    end for
end sub

sub printAdBeforePlay(ad as dynamic, index as integer, total as integer)
    debugLog("Ad detail before play " + (index + 1).ToStr() + "/" + total.ToStr() + ":")
    if ad = invalid then
        debugLog("  url=" + m.adUrls[index])
        debugLog("  streamFormat=" + inferStreamFormat(m.adUrls[index]))
        return
    end if

    debugLog("  " + formatAdDetail(ad))
end sub

function formatAdDetail(ad as object) as string
    if ad = invalid then return "<invalid ad>"

    detail = "index=" + safeString(ad.index)
    detail = detail + " streamFormat=" + safeString(ad.streamFormat)
    detail = detail + " mediaType=" + safeString(ad.mediaType)
    detail = detail + " delivery=" + safeString(ad.delivery)
    detail = detail + " size=" + safeString(ad.width) + "x" + safeString(ad.height)
    detail = detail + " bitrate=" + safeString(ad.bitrate)
    detail = detail + " minBitrate=" + safeString(ad.minBitrate)
    detail = detail + " maxBitrate=" + safeString(ad.maxBitrate)
    detail = detail + " codec=" + safeString(ad.codec)
    detail = detail + " scalable=" + safeString(ad.scalable)
    detail = detail + " maintainAspectRatio=" + safeString(ad.maintainAspectRatio)
    detail = detail + " sourceDepth=" + safeString(ad.sourceDepth)
    detail = detail + " url=" + safeString(ad.url)
    return detail
end function

function safeString(value as dynamic) as string
    if value = invalid then return ""
    if type(value) = "roInt" or type(value) = "Integer" then return value.ToStr()
    if type(value) = "roFloat" or type(value) = "Float" or type(value) = "Double" then return value.ToStr()
    if type(value) = "roBoolean" or type(value) = "Boolean" then
        if value then return "true"
        return "false"
    end if
    return value.ToStr()
end function

sub debugLog(message as string)
    print "[OnlyAds] "; message
end sub
