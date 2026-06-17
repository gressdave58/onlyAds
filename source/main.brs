sub Main()
    print "[OnlyAds] Main starting"

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("MainScene")
    if scene = invalid then
        print "[OnlyAds] ERROR: MainScene could not be created"
        return
    end if

    screen.Show()
    print "[OnlyAds] Screen shown"

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then return
    end while
end sub
