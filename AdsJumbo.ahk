#Requires AutoHotkey v1.1.36+
#Include %A_ScriptDir%
#Include .\lib\getFullPathName.ahk
#Include .\lib\OSVersion.ahk
#Include .\lib\ShellHidden.ahk
;==============================================================
; AdsJumbo — Banner advertisement host/embedding helper for AutoHotkey GUIs
;
; GitHub: https://github.com/SevenKeyboard/ads-jumbo
; Author: SevenKeyboard Ltd. (2025)
; License: MIT License
;
; Required files (relative to A_ScriptDir):
;   resource\AdsJumboWinForm.dll
;   resource\BannerAdHost.AdsJumbo.exe
;   resource\BannerAdHost.AdsJumbo.exe.config
;
; Documentation / References:
;   How-to: App compatibility
;     https://ss64.com/nt/syntax-compatibility.html
;   Change "Override high DPI scaling behavior" in C#
;     https://stackoverflow.com/questions/45759789/change-override-high-dpi-scaling-behavior-in-c-sharp
;   How to use WS_EX_LAYERED on child controls
;     https://stackoverflow.com/questions/42569348/how-to-use-ws-ex-layered-on-child-controls
;==============================================================
class VersionManager_AdsJumbo
{
    static _ := VersionManager_AdsJumbo._init()
    _init()    {
        global
        ADSJUMBO_VERSION := "1.0.3"
        if (!this._verCheck(GETFULLPATHNAME_VERSION, "1.0.0"))
            throw exception("getFullPathName version 1.x is required (minimum 1.0.0).")
        if (!this._verCheck(OSVERSION_VERSION, "2.0.0"))
            throw exception("OSVersion version 2.x is required (minimum 2.0.0).")
        if (!this._verCheck(SHELLHIDDEN_VERSION, "1.0.0"))
            throw exception("ShellHidden version 1.x is required (minimum 1.0.0).")
        return true
    }
    _verCheck(byRef actual, required)    {
        if !isSet(actual)
            return false
        actualMajor     := strSplit(actual, ".",, 2)[1]
        requiredMajor   := strSplit(required, ".",, 2)[1]
        if (actualMajor !== requiredMajor)
            return false
        return verCompare(actual, ">=" required)
    }
}
class AdsJumbo
{
    __new()    {
        this._subdir:=A_ScriptDir "\resource"
        this._exeFileName:="BannerAdHost.AdsJumbo.exe"
        this._obmTimerWaitForm1:=objBindMethod(this,"_timerWaitForm1")
        this._obmTimerWaitForm2:=objBindMethod(this,"_timerWaitForm2")
        this._obmTimerDelayedAnimate:=objBindMethod(this,"_timerDelayedAnimate")
        this._obmTimerAnimate:=objBindMethod(this,"_timerAnimate")
        this._obmTimerMemoryUsage:=objBindMethod(this,"_timerMemoryUsage")
        this._obmTimerInvokeCallbackWith0:=objBindMethod(this,"_invokeCallback",0)
        this._isFormShownWaiting:=false
        this._waitFormInfos:=""
    }
    __delete()    {

    }
    ;----------------------------------------------------------------------------
    _initProps(id:="")    {
        if (id=="")    {
            this.els:={}
            return
        }
        this.els[id]:={mainGuiHwnd:0, hWnd:0, pid:0, text:this._exeFileName, dpiScaleMode:true}
    }
    _setProps(id, props)    {
        if (!this.els.hasKey(id))
            return
        for k,v in props    {
            if (this.els[id].hasKey(k))
                this.els[id][k]:=v
        }
    }
    _closeAll(force:=false)    {
        static GWL_STYLE:=-16
            ,SC_CLOSE:=0xF060
            ,SW_HIDE:=0
            ,WM_SYSCOMMAND:=0x0112
            ,WS_CHILD:=0x40000000
            ,WS_POPUP:=0x80000000
        detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"On")
        switch
        {
            default:
                for id,props in this.els
                    winClose % "ahk_pid " props.pid
            case (force):
                for id,props in this.els    {
                    b:=false
                    if (props.hWnd && dllCall("User32.dll\IsChild", "Ptr",props.mainGuiHwnd, "Ptr",props.hWnd))    {
                        dllCall("User32.dll\ShowWindow", "Ptr",props.hWnd, "Int",SW_HIDE)
                        if (dllCall("User32.dll\SetParent", "Ptr",props.hWnd, "Ptr",0, "Ptr"))    {
                            style:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",props.hWnd, "Int",GWL_STYLE, (A_PtrSize==8?"Ptr":"Int"))
                            style:=(style|WS_POPUP)&~WS_CHILD
                            if (dllCall("User32.dll\SetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",props.hWnd, "Int",GWL_STYLE, "Int",style, (A_PtrSize==8?"Ptr":"Int")))    {
                                dllCall("User32.dll\PostMessage", "Ptr",props.hWnd, "UInt",WM_SYSCOMMAND, "UPtr",SC_CLOSE, "Ptr",0)
                                process waitClose, % props.pid, 0.5
                                b:=!ErrorLevel
                            }
                        }
                    }
                    if (!b)
                        process Close, % props.pid
                }
        }
        detectHiddenWindows % prevDHW
    }
    _deleteAllTimers()    {
        local
        for _,v in ["_obmTimerWaitForm1","_obmTimerWaitForm2","_obmTimerDelayedAnimate","_obmTimerAnimate","_obmTimerMemoryUsage"]    {
            %v%:=this[v]
            setTimer % %v%, % "Delete"
        }
    }
    ;----------------------------------------------------------------------------
    _onMainGuiExit()    {
        this._deleteAllTimers()
        switch (this.IsFormShownWaiting)
        {
            case true:      this._closeAll(), this._initProps(), this._invokeCallback(2)
            default:        this._initProps()
        }
    }
    close()    {
        this._deleteAllTimers()
        switch (this.IsFormShownWaiting)
        {
            case true:      this._closeAll(), this._initProps(), this._invokeCallback(3)
            default:        this._closeAll(true), this._initProps()
        }
    }
    initializeOnMemoryThreshold()    {
        this._deleteAllTimers()
        switch (this.IsFormShownWaiting)
        {
            case true:      this._closeAll(), this._initProps(), this._invokeCallback(4)
            default:        this._closeAll(true), this._initProps()
        }
    }
    ;----------------------------------------------------------------------------
    runExe(param)    {
        if (!AdsJumbo_Static.Enabled)
            return false
        ;  1. Check if the arguments of the element are valid.
        this._initProps()
        this._deleteAllTimers()
        for id,args in param    {
            if (!isObject(args))
                return false
            if (args.length()<5)
                return false
        }
        ;  2. Verify that the hWnd of the main GUI for each respective element is identical and valid.
        b:=0
        for id,args in param    {
            c:=format("{:d}",args.hasKey(1)?args[1]:0)
            if (!b)    {
                if !(b:=c)
                    break
            }  else  {
                if (b==c)
                    continue
                b:=0
                break
            }
        }
        if (!b || !dllCall("User32.dll\IsWindow", "Ptr",b))
            return false
        ;  3. Execute the element's arguments as a command line to run the executable file.
        this.deleteAppCompatibility()
        critical % format("{2}",prevIC:=A_IsCritical,"On")
        b:=true, pids:={}
        for id,args in param    {
            this._initProps(id)
            mainGuiHwnd:=format("{:d}",args.hasKey(1)?args[1]:0)
            if (args[3]!=="")
                text:=args[3]
            command:="""" this._ExeFileFullPath """"
            for _,arg in args
                command.=" """ arg """"
            run % command, % this._subdir, % "UseErrorLevel", pid
            if !(b:=!ErrorLevel)    {
                this._initProps()
                break
            }
            if (!pid)
                break

            dpiScaleMode:=true
            if (regExMatch(args[6],"iDO)(?<=^|\h)(\+|-)?DpiScaleMode(?=$|\h)",m))
                dpiScaleMode:=!(m[1]=="-")
            this._setProps(id, {mainGuiHwnd:mainGuiHwnd, pid:pid:=format("{:d}",pid), text:text, dpiScaleMode:dpiScaleMode})
            pids[pid]:=""
        }
        critical % prevIC
        switch (b)
        {
            case true:          AdsJumbo_Static.registerMainGui(mainGuiHwnd,this)
            case false:
                detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"On")
                for pid in pids    {
                    winWait % "ahk_pid " pid,, 1
                    if (!ErrorLevel)
                        winClose % "ahk_pid " pid
                }
                detectHiddenWindows % prevDHW
        }
        return b
    }
    setAppCompatibility(regData:="")    {
        static regKeyName:="HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        fileAttribute:=fileExist(this._FilePath)
        if (fileAttribute && !inStr(fileAttribute,"D"))
            regWrite REG_SZ, % regKeyName, % this._ExeFileFullPath, % regData
    }
    deleteAppCompatibility()    {
        static regKeyName:="HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        regRead _, % regKeyName, % this._ExeFileFullPath
        if (!ErrorLevel)
            regDelete % regKeyName, % this._ExeFileFullPath
    }
    ;----------------------------------------------------------------------------
    waitFormShown(timeout:=0)    {
        static GWL_EXSTYLE:=-20, WS_EX_LAYERED:=0x00080000
        if (!this.els.count())
            return false
        endTick:=(timeout?this._TickCount+floor(timeout*1000):0)
        waitFormInfos:={}
        for id,props in this.els
            waitFormInfos[id]:={title:(props.text " ahk_pid " props.pid), hWnd:false}
        detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"On")
        b1:=false
        while (!endTick || this._TickCount<endTick)    {
            for id,info in waitFormInfos    {
                if (!info.hWnd)    {
                    if (hWnd:=winExist(info.title))
                        waitFormInfos[id].hWnd:=hWnd
                }
            }
            for _,info in waitFormInfos    {
                if (!info.hWnd)
                    continue 2
            }
            b1:=true
            break
        }
        detectHiddenWindows % prevDHW
        b2:=false
        if (b1)    {
            while (!endTick || this._TickCount<endTick)    {
                for _,info in waitFormInfos    {
                    exStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",info.hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int"))
                    if (exStyle&WS_EX_LAYERED)
                        continue 2
                }
                for id,info in waitFormInfos
                    this._setProps(id, {hWnd:info.hWnd})
                b2:=true
                break
            }
        }
        switch (b2)
        {
            case false:         this._closeAll(), this._initProps()
        }
        return b:=(b1 && b2)
    }
    ;----------------------------------------------------------------------------
    IsFormShownWaiting    {
        get  {
            return (!!this._isFormShownWaiting)
        }
        set  {
            this._isFormShownWaiting:=value
        }
    }
    setFormShownHook(callbackFunc, timeout:=0)    {
        this._isFormShownWaiting:=false
        if (!isFunc(callbackFunc))
            return
        if (!this.els.count())
            return
        this._waitFormInfos:={}
        this._waitFormInfos.callbackFunc:=callbackFunc
        this._waitFormInfos.endTick:=(timeout?this._TickCount+floor(timeout*1000):0)
        this._waitFormInfos.els:={}
        for id,props in this.els
            this._waitFormInfos.els[id]:={title:(props.text " ahk_pid " props.pid), hWnd:false}
        this._isFormShownWaiting:=true
        obm1:=this._obmTimerWaitForm1
        setTimer % obm1, 200
        obm2:=this._obmTimerWaitForm2
        setTimer % obm2, % "Delete"
    }
    _timerWaitForm1()    { ;  Wait until the Form exists.
        endTick:=this._waitFormInfos.endTick
        if (endTick && endTick<this._TickCount)    {
            obm1:=this._obmTimerWaitForm1
            setTimer % obm1, % "Delete"
            this._isFormShownWaiting:=false
            this._closeAll(), this._initProps(), this._invokeCallback(1)
            return
        }
        detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"On")
        loop % format("{2}",b:=false,1)    {
            for id,info in this._waitFormInfos.els    {
                if (!info.hWnd)    {
                    if (hWnd:=winExist(info.title))
                        this._waitFormInfos.els[id].hWnd:=hWnd
                }
            }
            for _,info in this._waitFormInfos.els    {
                if (!info.hWnd)
                    break 2
            }
        }  until (b:=true)
        detectHiddenWindows % prevDHW
        if (b)    {
            obm1:=this._obmTimerWaitForm1
            setTimer % obm1, % "Delete"
            obm2:=this._obmTimerWaitForm2
            setTimer % obm2, % 200
        }
    }
    _timerWaitForm2()    { ;  Wait until the Hide() of the Form is completed.
        static GWL_EXSTYLE:=-20, WS_EX_LAYERED:=0x00080000
        endTick:=this._waitFormInfos.endTick
        if (endTick && endTick<this._TickCount)    {
            obm2:=this._obmTimerWaitForm2
            setTimer % obm2, % "Delete"
            this._isFormShownWaiting:=false
            this._closeAll(), this._initProps(), this._invokeCallback(1)
            return
        }
        for _,info in this._waitFormInfos.els    {
            exStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",info.hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int"))
            if (exStyle&WS_EX_LAYERED) ;  To prevent flickering in Form1_Shown, temporarily set 'this.Opacity' to 0, and attempt 'this.Hide()' and 'this.AllowTransparency = false'. Wait until the WS_EX_LAYERED of the window is released.
                return
        }
        for id,info in this._waitFormInfos.els
            this._setProps(id, {hWnd:info.hWnd})
        obm2:=this._obmTimerWaitForm2
        setTimer % obm2, % "Delete"
        this._isFormShownWaiting:=false
        obm3:=this._obmTimerInvokeCallbackWith0 ;  , this._invokeCallback(0)
        setTimer % obm3, -1000
    }
    _invokeCallback(e)    {
        if (this._waitFormInfos=="")
            return
        this._waitFormInfos.callbackFunc.call(this,e)
        this._waitFormInfos:=""
    }
    ;----------------------------------------------------------------------------
    connectToAhkGui(param:="", useClipChildren:=false, useClipSiblings:=false)    {
        static GWL_STYLE:=-16
            ,WS_CHILD:=0x40000000
            ,WS_CLIPCHILDREN:=0x02000000
            ,WS_CLIPSIBLINGS:=0x04000000
            ,WS_POPUP:=0x80000000
            ,HWND_TOP:=0
            ,SWP_NOACTIVATE:=0x0010
            ,SWP_NOSIZE:=0x0001
            ,SWP_NOZORDER:=0x0004
        if (param=="")
            param:={}
        if (!this.els.count())
            return false
        for id,props in this.els    {
            if (A_Index==1 && !dllCall("User32.dll\IsWindow", "Ptr",mainGuiHwnd:=props.mainGuiHwnd))
                return false
            if (!dllCall("User32.dll\IsWindow", "Ptr",props.hWnd))
                return false
        }
        loop % format("{2}",b1:=false,1)    {
            if (useClipChildren)    {
                parentStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",mainGuiHwnd, "Int",GWL_STYLE, (A_PtrSize==8?"Ptr":"Int"))
                parentStyle|=WS_CLIPCHILDREN
                if (!dllCall("User32.dll\SetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",mainGuiHwnd, "Int",GWL_STYLE, "Int",parentStyle, (A_PtrSize==8?"Ptr":"Int")))
                    break
            }
            for id,props in this.els    {
                childStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",props.hWnd, "Int",GWL_STYLE, (A_PtrSize==8?"Ptr":"Int"))
                childStyle|=WS_CHILD|(useClipSiblings?WS_CLIPSIBLINGS:0)
                childStyle&=~WS_POPUP
                if (!dllCall("User32.dll\SetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",props.hWnd, "Int",GWL_STYLE, "Int",childStyle, (A_PtrSize==8?"Ptr":"Int")))
                    break
                if (!dllCall("User32.dll\SetParent", "Ptr",props.hWnd, "Ptr",props.mainGuiHwnd, "Ptr"))
                    break
            }            
        }  until (b1:=true)
        b2:=true
        if (b1)    {
            for id,pos in param    {
                if (!this.els.hasKey(id))
                    continue
                if (!dllCall("User32.dll\SetWindowPos", "Ptr",this.els[id].hWnd, "Ptr",HWND_TOP, "Int",pos.x, "Int",pos.y, "Int",0, "Int",0, "UInt",SWP_NOACTIVATE|SWP_NOSIZE|SWP_NOZORDER))    {
                    b2:=false
                    break
                }
            }  
        }
        switch b:=(b1 && b2)
        {
            case true:
                for id,pos in param    {
                    if (!this.els.hasKey(id))
                        continue
                    dllCall("User32.dll\SetWindowPos", "Ptr",this.els[id].hWnd, "Ptr",HWND_TOP, "Int",pos.x, "Int",pos.y, "Int",0, "Int",0, "UInt",SWP_NOACTIVATE|SWP_NOSIZE|SWP_NOZORDER)
                }
        }
        return b
    }
    setExStyle(param)    {
        static GWL_EXSTYLE:=-20
            ,WS_EX_LAYERED:=0x00080000
            ,LWA_ALPHA:=0x00000002
        if (!this.els.count())
            return false
        for id,opt in param    {
            if (!this.els.hasKey(id))
                continue
            hWnd:=this.els[id].hWnd
            childExStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int"))
            if !(childExStyle&WS_EX_LAYERED)    {
                if (!dllCall("User32.dll\SetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, "Int",childExStyle|WS_EX_LAYERED, (A_PtrSize==8?"Ptr":"Int")))
                    return false
            }
            if (opt.hasKey("exStyle"))    {
                spo:=1
                while (regExMatch(opt.exStyle,"iDO)(?<=^|\h)(\+|-)?(0x[[:xdigit:]]+|\d+)(?=$|\h)",m,spo))    {
                    spo:=m.pos(0)+m.len(0)
                    childExStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int"))
                    exStyle:=format("{:d}",m[2])
                    switch (sign:=m[1]=="-"?"-":"+")
                    {
                        case "+":       childExStyle|=exStyle
                        case "-":       childExStyle&=~exStyle
                    }
                    if (!dllCall("User32.dll\SetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, "Int",childExStyle, (A_PtrSize==8?"Ptr":"Int")))
                        return false
                }
            }
            alpha:=(opt.hasKey("alpha")?opt.alpha:255)
            if (!dllCall("User32.dll\SetLayeredWindowAttributes", "Ptr",hWnd, "UInt",0, "UChar",alpha, "UInt",LWA_ALPHA))
                return false
        }
        return true
    }
    adjustDpiScale()    {
        if !(wheelcount:=(dllCall("User32.dll\GetDpiForSystem", "UInt")-96)//24*25//5)
            return
        setControlDelay % format("{2}",prevCD:=A_ControlDelay,100)
        for id,props in this.els    {
            if (!props.dpiScaleMode)
                continue
            controlGet hCtnl, Hwnd,, % "Internet Explorer_Server1", % "ahk_id " props.hWnd
            controlSend,, % "{LCtrl Down}", % "ahk_id " hCtnl
            controlClick,, % "ahk_id " hCtnl,, % (0<wheelcount?"WU":"WD"), % abs(wheelcount), % "NA"
            controlSend,, % "{LCtrl Up}", % "ahk_id " hCtnl
        }
        setControlDelay % prevCD        
    }
    show(cmdShow:=1)    {
        static SW_HIDE:=0
            ,SW_SHOWNORMAL:= SW_NORMAL:=1
            ,SW_SHOWMINIMIZED:=2
            ,SW_SHOWMAXIMIZED:= SW_MAXIMIZE:=3
            ,SW_SHOWNOACTIVATE:=4
            ,SW_SHOW:=5
            ,SW_MINIMIZE:=6
            ,SW_SHOWMINNOACTIVE:=7
            ,SW_SHOWNA:=8
            ,SW_RESTORE:=9
            ,SW_SHOWDEFAULT:=10
            ,SW_FORCEMINIMIZE:=11
        for id,props in this.els    {
            if (hWnd:=props.hWnd)
                dllCall("User32.dll\ShowWindow", "Ptr",hWnd, "Int",cmdShow)
        }
    }
    delayedAnimate(delay:=2000, N:=255, time:=400)    {
        this._delayedAnimateInfos:={N:N, time:time}
        obm:=this._obmTimerDelayedAnimate
        setTimer % obm, % -abs(delay)
    }
    _timerDelayedAnimate()    {
        if (!this.els.count())
            return false
        for _,props in this.els    {
            mainGuiHwnd:=props.mainGuiHwnd
            break
        }
        if (dllCall("User32.dll\IsWindow", "Ptr",mainGuiHwnd))
            this.animate(this._delayedAnimateInfos.N, this._delayedAnimateInfos.time)
    }
    animate(N:=255, time:=400)    {
        static SW_HIDE:=0
            ,SW_SHOWNORMAL:=1
            ,LWA_ALPHA:=0x00000002
        N:=max(0,min(255,N))
        this._animateCurrFrame:=0
        this._animateMaxFrame:=time//(frameSpace:=25)
        this._animateInfos:={}
        for id,props in this.els    {
            if !(hWnd:=props.hWnd)
                continue
            switch (this.isLayered(id))
            {
                case true:          this._animateInfos[id]:={startAlpha:this.getAlpha(id,255), lastAlpha:"", endAlpha:N}
            }
        }
        obm:=this._obmTimerAnimate
        setTimer % obm, % frameSpace
    }
    _timerAnimate()    {
        ++this._animateCurrFrame
        for id,info in this._animateInfos    {
            currAlpha:=floor(info.startAlpha+(info.endAlpha-info.startAlpha)*this._animateCurrFrame//this._animateMaxFrame)
            if (info.lastAlpha!==currAlpha)    {
                this._animateInfos[id].lastAlpha:=currAlpha
                this.setAlpha({(id):currAlpha})
            }
        }
        if (this._animateMaxFrame<=this._animateCurrFrame)    {
            obm:=this._obmTimerAnimate
            setTimer % obm, % "Delete"
        }
    }
    ;----------------------------------------------------------------------------
    setAlpha(paramOrAlpha)    {
        static LWA_ALPHA:=0x00000002
        switch isObject(paramOrAlpha)
        {
            case true:
                for id,alpha in paramOrAlpha    {
                    if (!this.els.hasKey(id))
                        continue
                    if !(hWnd:=this.els[id].hWnd)
                        continue
                    dllCall("User32.dll\SetLayeredWindowAttributes", "Ptr",hWnd, "UInt",0, "UChar",alpha, "UInt",LWA_ALPHA)
                }
            default:
                for _,props in this.els    {
                    if (hWnd:=props.hWnd)
                        dllCall("User32.dll\SetLayeredWindowAttributes", "Ptr",hWnd, "UInt",0, "UChar",paramOrAlpha, "UInt",LWA_ALPHA)
                }
        }
    }
    getAlpha(id:="", default:=255)    {
        static GWL_EXSTYLE:=-20
            ,WS_EX_LAYERED:=0x00080000
            ,LWA_ALPHA:=0x00000002
        switch (id!=="")
        {
            case true:
                if (this.els.hasKey(id))
                && (hWnd:=this.els[id].hWnd)
                && (exStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int")))
                && (exStyle&WS_EX_LAYERED)
                && (dllCall("User32.dll\GetLayeredWindowAttributes", "Ptr",hWnd, "Ptr",0, "UChar*",alpha, "UInt*",flags))
                && (flags==LWA_ALPHA)
                    return alpha
                else
                    return (default!==""?default:"")
            default:
                ret:={}
                for id in this.els
                    ret[id]:=this.getAlpha(id,default)
                return ret
        }
    }
    isLayered(id:="")    {
        static GWL_EXSTYLE:=-20
            ,WS_EX_LAYERED:=0x00080000
        switch (id!=="")
        {
            case true:
                return !!((this.els.hasKey(id))
                    && (hWnd:=this.els[id].hWnd)
                    && (exStyle:=dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_EXSTYLE, (A_PtrSize==8?"Ptr":"Int")))
                    && (exStyle&WS_EX_LAYERED))
            default:
                ret:={}
                for id in this.els
                    ret[id]:=this.isLayered(id)
                return ret
        }
    }
    ;----------------------------------------------------------------------------
    setMemoryThresholdRestartCallback(callbackFunc, maxMemoryMB:=400)    {
        if (!isFunc(callbackFunc))
            return
        this._restartcallbackFunc:=callbackFunc
        this._maxMemoryMB:=maxMemoryMB
        obm:=this._obmTimerMemoryUsage
        setTimer % obm, 10000
    }
    _timerMemoryUsage()    {
        totalMemoryMB:=0
        for id,props in this.els    {
            bytes:=this._getProcessWorkingSetSize(props.pid)
            mb:=(kb:=bytes/1024)/1024
            totalMemoryMB+=mb
        }
        ;  tooltip % floor(totalMemoryMB) "`n" this._maxMemoryMB
        if (this._maxMemoryMB<totalMemoryMB)    {
            obm:=this._obmTimerMemoryUsage
            setTimer % obm, % "Delete"
            callbackFunc:=this._restartcallbackFunc
            callbackFunc.call(this)
        }            
    }
    _getProcessWorkingSetSize(pid) {
        static PROCESS_QUERY_INFORMATION:=0x0400
            ,PROCESS_VM_READ:=0x0010
        varSetCapacity(pmcex,size:=440,0)
        workingSetSize:=0
        if (hProcess:=dllCall("Kernel32.dll\OpenProcess", "UInt",PROCESS_QUERY_INFORMATION|PROCESS_VM_READ, "Int",false, "Ptr",pid, "Ptr"))    {
            if (dllCall("Psapi.dll\GetProcessMemoryInfo", "Ptr",hProcess, "Ptr",&pmcex, "UInt",size))
                workingSetSize:=numGet(pmcex,(A_PtrSize==8?4*2+8:4*3),"UPtr")
            dllCall("Kernel32.dll\CloseHandle", "Ptr",hProcess)
        }
        return workingSetSize
    }
    ;----------------------------------------------------------------------------
    _ExeFilePath    {
        get  {
            return this._subdir "\" this._exeFileName
        }
    }
    _ExeFileFullPath    {
        get  {
            static _:=""
            return (_==""?_:=getFullPathName(this._ExeFilePath):_)
        }
    }
    _TickCount    {
        get  {
            return (A_Is64bitOS?this._TickCount64:this._TickCount32)
        }
    }
    _TickCount32    {
        get  {
            return dllCall("Kernel32.dll\GetTickCount", "UInt") ;  0x0 to 0xFFFFFFFF
        }
    }
    _TickCount64    {
        get  {
            return dllCall("Kernel32.dll\GetTickCount64", "Int64") & 0x7FFFFFFFFFFFFFFF ;  0x0 to 0x7FFFFFFFFFFFFFFF
        }
    }
}
;================================================================================
class AdsJumbo_Static
{
    init()    {
        this._subdir:=A_ScriptDir "\resource"
        this._exeFileName:="BannerAdHost.AdsJumbo.exe"
        this._hHook:=0
        this._mainGuis:={}
        ;  this._exeInstall()
        this._setObjDestroyEventHook()
    }
    registerMainGui(hWnd, classObj)    {
        this._mainGuis[format("{:d}",hWnd)]:=classObj
    }
    unregisterMainGui(hWnd)    {
        if (this._mainGuis.hasKey(hWnd:=format("{:d}",hWnd)))
            this._mainGuis.delete(hwnd)
    }
    handleObjDestroyEventHook(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)    {
        if (A_PtrSize!==8)
            hwnd:=hwnd<<32>>32
        if (!this._mainGuis.hasKey(hwnd))
            return
        classObj:=this._mainGuis[hwnd]
        classObj._onMainGuiExit()
        this._mainGuis.delete(hwnd)
    }
    fileExist()    {
        bRet := false
        loop  1    {
            fileAttribute:=fileExist(this._subdir "\AdsJumboWinForm.dll")
            if (!fileAttribute || inStr(fileAttribute,"D"))
                break
            fileAttribute:=fileExist(this._subdir "\" this._exeFileName ".config")
            if (!fileAttribute || inStr(fileAttribute,"D"))
                break
            fileAttribute:=fileExist(filePath := this._subdir "\" this._exeFileName)
            if (!fileAttribute || inStr(fileAttribute,"D"))
                break
            if !(isShellCreated := ShellHidden.IsCreated)
                ShellHidden.create()
            command := "
            (Join LTrim RTrim0
                powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command 
                (Get-AuthenticodeSignature -FilePath """ filePath """).SignerCertificate.Thumbprint
            )"
            thumbprint := regExReplace(ShellHidden.ComObj.Exec(command).StdOut.ReadAll(), "\W")
            bRet := (format("{:L}",thumbprint) == "6bef1ed9d0d1238efb825330179f483dc40c90f8")
            if (!isShellCreated)
                ShellHidden.destroy()
        }
        return bRet
    }
    Enabled    {
        get  {
            static DPI_AWARENESS_CONTEXT_SYSTEM_AWARE:=-2
            if (!OSVersion.IsWindows8OrGreater())
                return false
            dpiAwarenessContext:=0
            dpiContextA:=dllCall("user32.dll\GetThreadDpiAwarenessContext", "UInt")
            loop 5    {
                if dllCall("user32.dll\AreDpiAwarenessContextsEqual", "UInt",dpiContextA, "Int",dpiContextB:=-1*A_Index)    {
                    dpiAwarenessContext:=dpiContextB
                    break
                }
            }
            return (dpiAwarenessContext==DPI_AWARENESS_CONTEXT_SYSTEM_AWARE)
        }
    }
    ;----------------------------------------------------------------------------
    /*
    _exeInstall()    { ;  Recommend excluding file installation and handling it separately via NSIS or other installers.
        if !(fileExist(this._subdir)~="D")    {
            fileCreateDir % this._subdir
            if (ErrorLevel)
                return            
        }
        _subdir:=this._subdir
        _exeFileName:=this._exeFileName
        FileInstall, ..., %_subdir%\AdsJumboWinForm.dll, 1
        FileInstall, ..., %_subdir%\%_exeFileName%, 1
        FileInstall, ..., %_subdir%\%_exeFileName%.config, 1
    }
    */
    _setObjDestroyEventHook()    {
        static EVENT_OBJECT_DESTROY:=0x8001
            ,WINEVENT_OUTOFCONTEXT:=0x0000
        this._hHook:=dllCall("User32.dll\SetWinEventHook"
            ,"UInt",eventMin:=EVENT_OBJECT_DESTROY
            ,"UInt",eventMax:=EVENT_OBJECT_DESTROY
            ,"Ptr",hmodWinEventProc:=0
            ,"Ptr",pfnWinEventProc:=registerCallback("adsJumbo_WinEventProc_E33B642F","F")
            ,"UInt",idProcess:=dllCall("Kernel32.dll\GetCurrentProcessId","UInt")
            ,"UInt",idThread:=0
            ,"UInt",dwflags:=WINEVENT_OUTOFCONTEXT
            ,"Ptr")
        onExit(objBindMethod(this,"_onApplicationExit"))
    }
    _onApplicationExit(exitReason, exitCode)    {
        if (this._hHook)
            dllCall("UnhookWinEvent", "Ptr",this._hHook)
    }
}
adsJumbo_WinEventProc_E33B642F(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)    {
    AdsJumbo_Static.handleObjDestroyEventHook(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)
}