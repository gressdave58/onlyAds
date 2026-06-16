sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.error = ""
    m.top.status = "Loading ads"
    m.stats = {
        xmlNodes: 0,
        mediaNodes: 0,
        playableMedia: 0,
        wrapperNodes: 0
    }
    debugLog("AdLoader started")

    tags = m.top.vastTags
    if tags = invalid then
        m.top.error = "Add at least one VAST tag in source/config.brs"
        m.top.adUrls = []
        return
    end if

    if tags.Count() = 0 then
        m.top.error = "Add at least one VAST tag in source/config.brs"
        debugLog("No VAST tags configured")
        m.top.adUrls = []
        return
    end if

    maxAds = m.top.maxAdsPerRefresh
    if maxAds <= 0 then maxAds = 10

    ads = []
    for each tagUrl in tags
        if ads.Count() >= maxAds then exit for

        m.top.status = "Requesting VAST tag"
        debugLog("Preparing VAST tag: " + tagUrl)
        appendAdsFromVastTag(prepareVastUrl(tagUrl), ads, maxAds, m.top.requestTimeoutSeconds, 0)
    end for

    urls = adDetailsToUrls(ads)

    if ads.Count() = 0 and m.top.error = "" then
        m.top.error = "No playable ad media found in configured VAST tags"
        debugLog("No playable ad media found")
    else
        if ads.Count() > 0 then m.top.error = ""
    end if
    debugLog("AdLoader finished. xmlNodes=" + m.stats.xmlNodes.ToStr() + " mediaNodes=" + m.stats.mediaNodes.ToStr() + " playableMedia=" + m.stats.playableMedia.ToStr() + " wrapperNodes=" + m.stats.wrapperNodes.ToStr() + " ads=" + ads.Count().ToStr())
    m.top.adDetails = ads
    m.top.adUrls = urls
end sub

function adDetailsToUrls(ads as object) as object
    urls = []
    for each ad in ads
        urls.Push(ad.url)
    end for
    return urls
end function

function prepareVastUrl(url as string) as string
    if url = invalid then return ""

    dt = CreateObject("roDateTime")
    correlator = dt.AsSeconds().ToStr()

    prepared = url.Replace("{correlator}", correlator)
    prepared = prepared.Replace("[correlator]", correlator)

    if Right(prepared, 11) = "correlator=" then
        prepared = prepared + correlator
    end if

    debugLog("Prepared VAST URL: " + prepared)
    return prepared
end function

sub appendAdsFromVastTag(tagUrl as string, ads as object, maxAds as integer, timeoutSeconds as integer, depth as integer)
    if ads.Count() >= maxAds or depth > 3 then return

    m.top.status = "Loading VAST depth " + depth.ToStr()
    debugLog("Loading VAST depth=" + depth.ToStr() + " url=" + tagUrl)
    xmlText = httpGet(tagUrl, timeoutSeconds)
    if xmlText = invalid then return
    if xmlText = "" then return

    vast = CreateObject("roXMLElement")
    if not vast.Parse(xmlText) then
        m.top.error = "VAST XML parse failed"
        debugLog("VAST XML parse failed")
        return
    end if

    m.top.status = "Finding ad media"
    debugLog("Parsed VAST root=" + getNodeName(vast) + " responseChars=" + Len(xmlText).ToStr())
    beforeCount = ads.Count()
    appendMediaUrls(vast, ads, maxAds, depth)
    m.top.status = "Media nodes " + m.stats.mediaNodes.ToStr() + ", playable " + m.stats.playableMedia.ToStr()

    if ads.Count() > beforeCount then return

    wrapperUrls = []
    appendWrapperUrls(vast, wrapperUrls)
    debugLog("Found " + wrapperUrls.Count().ToStr() + " wrapper URL(s)")
    for each wrapperUrl in wrapperUrls
        if ads.Count() >= maxAds then exit for
        appendAdsFromVastTag(wrapperUrl, ads, maxAds, timeoutSeconds, depth + 1)
    end for
end sub

function httpGet(url as string, timeoutSeconds as integer) as dynamic
    if url = invalid then return invalid
    if url = "" then return invalid

    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetRequest("GET")
    transfer.AddHeader("User-Agent", "OnlyAdsRoku/1.0")
    transfer.AddHeader("Accept", "application/xml,text/xml,*/*")

    if timeoutSeconds <= 0 then timeoutSeconds = 15

    debugLog("HTTP GET " + url)
    if not transfer.AsyncGetToString() then
        m.top.error = "Could not start VAST request"
        debugLog("AsyncGetToString failed")
        return invalid
    end if

    msg = wait(timeoutSeconds * 1000, port)
    if msg = invalid then
        transfer.AsyncCancel()
        m.top.error = "Timed out loading VAST tag"
        return invalid
    end if

    code = msg.GetResponseCode()
    body = msg.GetString()
    debugLog("HTTP " + code.ToStr() + " responseChars=" + Len(body).ToStr())
    if code >= 200 and code < 300 then return body

    m.top.error = "VAST tag request failed: HTTP " + code.ToStr()
    return invalid
end function

sub appendMediaUrls(node as object, ads as object, maxAds as integer, depth as integer)
    if ads.Count() >= maxAds then return

    m.stats.xmlNodes = m.stats.xmlNodes + 1
    nodeName = getNodeName(node)

    if LCase(nodeName) = "mediafile" then
        m.stats.mediaNodes = m.stats.mediaNodes + 1
        mediaType = ""
        attrs = node.GetAttributes()
        if attrs <> invalid and attrs.DoesExist("type") then mediaType = LCase(attrs.type)

        url = normalizeText(node.GetText())
        if isPlayableMedia(url, mediaType) then
            m.stats.playableMedia = m.stats.playableMedia + 1
            ad = mediaNodeToAdDetail(url, mediaType, attrs, depth, ads.Count() + 1)
            ads.Push(ad)
            debugLog("Playable media found " + formatAdDetail(ad))
        else
            debugLog("Rejected media type=" + mediaType + " url=" + url)
        end if
    end if

    children = node.GetChildElements()
    if children = invalid then return

    for each child in children
        if ads.Count() >= maxAds then exit for
        appendMediaUrls(child, ads, maxAds, depth)
    end for
end sub

function mediaNodeToAdDetail(url as string, mediaType as string, attrs as dynamic, depth as integer, index as integer) as object
    ad = {
        index: index,
        url: url,
        mediaType: mediaType,
        streamFormat: inferStreamFormat(url),
        sourceDepth: depth,
        delivery: "",
        width: "",
        height: "",
        bitrate: "",
        minBitrate: "",
        maxBitrate: "",
        codec: "",
        scalable: "",
        maintainAspectRatio: ""
    }

    if attrs <> invalid then
        if attrs.DoesExist("delivery") then ad.delivery = attrs.delivery
        if attrs.DoesExist("width") then ad.width = attrs.width
        if attrs.DoesExist("height") then ad.height = attrs.height
        if attrs.DoesExist("bitrate") then ad.bitrate = attrs.bitrate
        if attrs.DoesExist("minBitrate") then ad.minBitrate = attrs.minBitrate
        if attrs.DoesExist("maxBitrate") then ad.maxBitrate = attrs.maxBitrate
        if attrs.DoesExist("codec") then ad.codec = attrs.codec
        if attrs.DoesExist("scalable") then ad.scalable = attrs.scalable
        if attrs.DoesExist("maintainAspectRatio") then ad.maintainAspectRatio = attrs.maintainAspectRatio
    end if

    return ad
end function

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

sub appendWrapperUrls(node as object, urls as object)
    if LCase(getNodeName(node)) = "vastadtaguri" then
        wrapperUrl = normalizeText(node.GetText())
        lowerWrapperUrl = LCase(wrapperUrl)
        if Left(lowerWrapperUrl, 7) = "http://" or Left(lowerWrapperUrl, 8) = "https://" then
            m.stats.wrapperNodes = m.stats.wrapperNodes + 1
            urls.Push(wrapperUrl)
            debugLog("Wrapper URL found: " + wrapperUrl)
        end if
    end if

    children = node.GetChildElements()
    if children = invalid then return

    for each child in children
        appendWrapperUrls(child, urls)
    end for
end sub

function normalizeText(value as dynamic) as string
    if value = invalid then return ""
    text = value.Trim()
    text = text.Replace(Chr(10), "")
    text = text.Replace(Chr(13), "")
    text = text.Replace(Chr(9), "")
    return text
end function

function getNodeName(node as object) as string
    if node = invalid then return ""

    name = node.GetName()
    if name = invalid then return ""

    colonPosition = Instr(1, name, ":")
    if colonPosition > 0 then
        return Mid(name, colonPosition + 1)
    end if

    return name
end function

function isPlayableMedia(url as string, mediaType as string) as boolean
    if url = invalid then return false
    if url = "" then return false

    lowerUrl = LCase(url)
    if Left(lowerUrl, 7) <> "http://" and Left(lowerUrl, 8) <> "https://" then return false

    if mediaType = "video/mp4" or mediaType = "application/x-mpegurl" then return true
    if Instr(1, lowerUrl, ".mp4") > 0 then return true
    if Instr(1, lowerUrl, ".m3u8") > 0 then return true

    return false
end function

function inferStreamFormat(url as string) as string
    lowerUrl = LCase(url)
    if Instr(1, lowerUrl, ".m3u8") > 0 then return "hls"
    if Instr(1, lowerUrl, ".mpd") > 0 then return "dash"
    return "mp4"
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
    if m.top.debugEnabled then print "[OnlyAds][AdLoader] "; message
end sub
