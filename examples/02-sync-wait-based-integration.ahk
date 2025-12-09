AppBannerAd := new AdsJumbo

...

loop 1    {
    if (!AppBannerAd.runExe({el1:[hwndGui1,"AppName","WinTitle","323x190","300x600",(setDpiScale?"":"-DpiScaleMode ") "+AutoScroll"]}))
        break
    if (!AppBannerAd.waitFormShown(10))
        break
    AppBannerAd.setMemoryThresholdRestartCallback(func("appBannerAd_MemoryThreshold"))
    varSetCapacity(RECT, 16, 0)
    dllCall("User32.dll\GetWindowRect", "Ptr",hwndGui1BannerPic, "Ptr",&RECT)
    dllCall("User32.dll\ScreenToClient", "Ptr",hwndGui1, "Ptr",&RECT)
    x1:=numGet(&RECT, 0,"Int"), y1:=numGet(&RECT, 4,"Int"), x2:=numGet(&RECT, 8,"Int"), y2:=numGet(&RECT, 12,"Int")
    if (!AppBannerAd.connectToAhkGui({el1:{x:x1, y:y1}}))
        break
    WS_EX_DLGMODALFRAME:=0x00000001, WS_EX_LEFTSCROLLBAR:=0x00004000
    if (!AppBannerAd.setExStyle({el1:{exStyle:"+" WS_EX_LEFTSCROLLBAR " -" WS_EX_DLGMODALFRAME, alpha:0}}))
        break
    AppBannerAd.adjustDpiScale()
    AppBannerAd.show()
    AppBannerAd.delayedAnimate()
}

...

appBannerAd_MemoryThreshold(sender)    {
    global
    sender.initializeOnMemoryThreshold()
    if (!sender.runExe({el1:[hwndGui1,"AppName","WinTitle","323x190","300x600","+AutoScroll"]}))
        break
    if (!sender.waitFormShown(10))
        break
    sender.setMemoryThresholdRestartCallback(func(A_ThisFunc))
    varSetCapacity(RECT, 16, 0)
    dllCall("User32.dll\GetWindowRect", "Ptr",hwndGui1BannerPic, "Ptr",&RECT)
    dllCall("User32.dll\ScreenToClient", "Ptr",hwndGui1, "Ptr",&RECT)
    x1:=numGet(&RECT, 0,"Int"), y1:=numGet(&RECT, 4,"Int"), x2:=numGet(&RECT, 8,"Int"), y2:=numGet(&RECT, 12,"Int")
    if (!sender.connectToAhkGui({el1:{x:x1, y:y1}}))
        break
    WS_EX_DLGMODALFRAME:=0x00000001, WS_EX_LEFTSCROLLBAR:=0x00004000
    if (!sender.setExStyle({el1:{exStyle:"+" WS_EX_LEFTSCROLLBAR " -" WS_EX_DLGMODALFRAME, alpha:0}}))
        break
    sender.adjustDpiScale()
    sender.show()
    sender.delayedAnimate()
}