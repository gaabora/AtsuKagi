class WinDrag extends AKPlugin {
  _overlayGui := ""
  _snapPreviewGui := ""
  _infoTipGui := ""
  _infoTipTextCtrl := ""
  _lastInfoTipText := ""
  _infoTipVisible := false
  _snappedWindows := Map()
  windowState := {}

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "WinDrag",
        "title", "WinDrag",
        "description", "Enhanced window moving/resizing with drag from any place on window instead of titlebar/borders",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure drag-anywhere movement, resizing, snapping, and preview behavior",
        "icon", "icons10-resize-four-directions"
      ),
      "config", [
        Map(
          "key", "QuickPositionHotkey",
          "label", "Quick position hotkey",
          "description", "Hold to snap the window into quick-position regions",
          "type", "hotkey",
          "default", "LCtrl",
          "section", "Movement",
        ),
        Map(
          "key", "EnableSnapping",
          "label", "Enable snapping",
          "description", "Snap dragged or resized windows to monitor edges",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnappingDistance",
          "label", "Magnetic snap distance (px)",
          "description", "Pixel distance threshold for magnetic edge snapping during drag",
          "type", "integer", "control", "range", "default", 10, "validation", Map("min", 10, "max", 100, "step", 2),
          "section", "Snapping",
        ),
        Map(
          "key", "CompensateInvisibleBorders",
          "label", "Compensate invisible DWM borders",
          "description", "Use visible window bounds so edge snapping lands flush on screen edges",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapOnRelease",
          "label", "Edge snap on release",
          "description", "Show edge snap targets while dragging and apply them when mouse is released",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapEdgeThreshold", ; TODO: ADVANCED: review consistency of setting keys (everywhere, not only this) and rename better way
          "label", "Edge snap threshold (px)",
          "description", "How close cursor must be to a screen edge to trigger edge snap preview",
          "type", "integer", "control", "range", "default", 50, "validation", Map("min", 10, "max", 100, "step", 2),
          "section", "Snapping",
        ),
        Map(
          "key", "SnapHalfScreen",
          "label", "Snap to left/right half",
          "description", "Enable half-screen edge snap targets",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapMaximizeOnTop",
          "label", "Maximize on top edge snap",
          "description", "Enable maximize target at the top screen edge",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapMinimizeOnBottom",
          "label", "Minimize on bottom edge snap",
          "description", "Enable minimize target at the bottom screen edge",
          "type", "boolean",
          "default", false,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapLeftRightTiles",
          "label", "Enable left/right tile snap",
          "description", "Reserved for expanded edge tile layouts",
          "type", "boolean",
          "default", false,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapQuarterCorners",
          "label", "Snap quarter corners",
          "description", "Enable quarter-screen snap targets in all four corners",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapToWindows",
          "label", "Snap to other windows",
          "description", "Magnetically snap to edges of other visible windows during move and resize",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
        ),
        Map(
          "key", "SnapToWindowsDistance",
          "label", "Window snap distance (px)",
          "description", "Pixel threshold for snapping to other window edges. Larger values = stronger pull",
          "type", "integer", "control", "range", "default", 20, "validation", Map("min", 10, "max", 100, "step", 2),
          "section", "Snapping",
        ),
        Map(
          "key", "ResizeAxisThreshold",
          "label", "Resize axis resistance (px)",
          "description", "Secondary axis is suppressed during resize until mouse moves this many pixels. Doubled when the edge is docked to a screen or window edge",
          "type", "integer", "control", "range", "default", 50, "validation", Map("min", 10, "max", 500, "step", 10),
          "section", "Behavior",
        ),
        Map(
          "key", "StickyResizeModifier",
          "label", "Sticky resize modifier",
          "description", "Hold this key during resize to also resize neighboring windows that share an edge",
          "type", "hotkey",
          "default", "LShift",
          "section", "Behavior",
        ),
        Map(
          "key", "ShowWindowContentOnMove",
          "label", "Show window content while moving",
          "description", "When disabled, show only a frame preview instead of moving the live window",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
        ),
        Map(
          "key", "ShowWindowContentOnResize",
          "label", "Show window content while resizing",
          "description", "When disabled, show only a frame preview instead of resizing the live window",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
        ),
        Map(
          "key", "ShowWindowContentOnQuickPosition",
          "label", "Show window content on quick position",
          "description", "When disabled, show only a frame preview when using quick position snap",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
        ),
        Map(
          "key", "BringToFront",
          "label", "Bring window to front",
          "description", "Activate the target window when move or resize mode begins",
          "type", "boolean",
          "default", false,
          "section", "Behavior",
        ),
        Map(
          "key", "ShowGeometryTooltip",
          "label", "Show geometry tooltip",
          "description", "Display a tooltip with window position and size during move and resize",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
        ),
        Map(
          "key", "OverlayColor",
          "label", "Overlay color",
          "description", "Hex color for the drag frame overlay",
          "type", "color", "control", "color", "default", "2080DD",
          "section", "Visuals",
        ),
        Map(
          "key", "OverlayOpacity",
          "label", "Overlay opacity",
          "description", "Transparency level for the drag frame overlay",
          "type", "integer", "control", "range", "default", 80, "validation", Map("min", 10, "max", 250, "step", 10),
          "section", "Visuals",
        ),
        Map(
          "key", "UseSetWindowPos",
          "label", "Use SetWindowPos for dragging",
          "description", "Use the native SetWindowPos API during live move and resize updates",
          "type", "boolean",
          "default", true,
          "section", "Performance",
        ),
      ],
      "actions", [
        Map(
          "action", "EnterWindowMovingMode",
          "label", "Move window",
          "description", "Move a window by dragging from anywhere on it",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "CompensateInvisibleBorders", "SnapOnRelease", "SnapEdgeThreshold", "SnapHalfScreen", "SnapQuarterCorners", "SnapToWindows", "SnapToWindowsDistance", "SnapMaximizeOnTop", "SnapMinimizeOnBottom", "SnapLeftRightTiles", "ShowWindowContentOnMove", "ShowWindowContentOnQuickPosition", "UseSetWindowPos", "BringToFront", "OverlayColor", "OverlayOpacity"]
        ),
        Map(
          "action", "EnterWindowResizingMode",
          "label", "Resize window",
          "description", "Resize a window by dragging from anywhere on it",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "CompensateInvisibleBorders", "SnapOnRelease", "SnapEdgeThreshold", "SnapHalfScreen", "SnapQuarterCorners", "SnapToWindows", "SnapToWindowsDistance", "ResizeAxisThreshold", "StickyResizeModifier", "SnapMaximizeOnTop", "SnapMinimizeOnBottom", "SnapLeftRightTiles", "ShowWindowContentOnResize", "ShowWindowContentOnQuickPosition", "UseSetWindowPos", "BringToFront", "OverlayColor", "OverlayOpacity"]
        ),
        Map(
          "action", "EnterWindowQuickPositioningMode",
          "label", "Quick position window",
          "description", "Instantly snap the window under the cursor to a grid zone based on cursor position",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["CompensateInvisibleBorders"]
        )
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  EnterWindowQuickPositioningMode() {
    ctx := {}
    if (!this._initDragSession(&ctx, A_ThisFunc))
      return

    if (!this.Config.ShowWindowContentOnQuickPosition)
      this._createOverlay()

    xWinDst := ctx.xWinSrc
    yWinDst := ctx.yWinSrc
    wWinDst := ctx.wWinSrc
    hWinDst := ctx.hWinSrc
    insets := { left: ctx.leftInset, top: ctx.topInset, right: ctx.rightInset, bottom: ctx.bottomInset }

    Loop {
      pollStatus := this._pollDragInput(ctx)
      if (pollStatus = "released")
        break
      if (pollStatus = "cancelled") {
        this.restoreOriginalWindowState(ctx.hwnd)
        break
      }

      this.quickPositionWindowOnEdge(ctx.hwnd, &xWinDst, &yWinDst, &wWinDst, &hWinDst)
      this._renderDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, true, "ShowWindowContentOnQuickPosition")
      this._updateInfoTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst / 2, yWinDst + hWinDst / 2)
    }

    this._finalizeDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, true, "ShowWindowContentOnQuickPosition", ctx.EscButtonState != "U")

    this._destroyInfoTip()
    this.disableEscapeHook()
    return
  }
  
  EnterWindowMovingMode() { ;;;
    this._destroySnapPreview()
    
    ctx := {}
    if (!this._initDragSession(&ctx, A_ThisFunc))
      return

    if (!this.Config.ShowWindowContentOnMove)
      this._createOverlay()

    ; Handle snapped window (drag-to-unstick)
    if (this._snappedWindows.Has(ctx.hwnd)) {
      snapState := this._snappedWindows[ctx.hwnd]
      this._snappedWindows.Delete(ctx.hwnd)
      this._setCornerRounding(ctx.hwnd, WindowFlags.DWMWCP_DEFAULT)
      ; Preserve cursor's relative position within the window
      WinGetPos(&snapX, &snapY, &snapW, &snapH, "ahk_id " ctx.hwnd)
      ratioX := (snapW > 0) ? (ctx.xMouSrc - snapX) / snapW : 0.5
      ratioY := (snapH > 0) ? (ctx.yMouSrc - snapY) / snapH : 0.5
      newX := Round(ctx.xMouSrc - snapState["w"] * ratioX)
      newY := Round(ctx.yMouSrc - snapState["h"] * ratioY)
      this._applyWindowRect(
        ctx.hwnd,
        newX,
        newY,
        snapState["w"],
        snapState["h"]
      )
      ; Re-grab source coords and state after unstick so drag offsets and cancel work correctly
      this.saveOriginalWindowState(ctx.hwnd)
      WinGetPos(&xSrc, &ySrc, &wSrc, &hSrc, "ahk_id " ctx.hwnd)
      ctx.xWinSrc := xSrc
      ctx.yWinSrc := ySrc
      ctx.wWinSrc := wSrc
      ctx.hWinSrc := hSrc
    }

    xWinDst := ctx.xWinSrc
    yWinDst := ctx.yWinSrc
    wWinDst := ctx.wWinSrc
    hWinDst := ctx.hWinSrc
    pendingSnapZone := ""
    snappingDistance := Number(this.Config.SnappingDistance)
    windowSnappingDistance := Number(this.Config.SnapToWindowsDistance)
    neighborEdges := this.Config.SnapToWindows ? this._getNeighborEdges(ctx.hwnd) : Map("x", [], "y", [])
    insets := { left: ctx.leftInset, top: ctx.topInset, right: ctx.rightInset, bottom: ctx.bottomInset }
    wasQuickPositioning := false

    Loop {
      pollStatus := this._pollDragInput(ctx)
      if (pollStatus = "released")
        break
      if (pollStatus = "cancelled") {
        this.restoreOriginalWindowState(ctx.hwnd)
        break
      }

      ctx.isQuickPositioning := false
      pendingSnapZone := ""
      if (ctx.quickPositionHotkey_wasUp && IsHotkeyStatePressed(ctx.quickPositionHotkey)) {
        ctx.isQuickPositioning := true
        wasQuickPositioning := true
        this.quickPositionWindowOnEdge(ctx.hwnd, &xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else {
        ; Rebase after QP release so the window continues from its QP position
        if (wasQuickPositioning) {
          wasQuickPositioning := false
          ctx.xWinSrc := xWinDst
          ctx.yWinSrc := yWinDst
          ctx.wWinSrc := wWinDst
          ctx.hWinSrc := hWinDst
          ctx.xMouSrc := ctx.xMouLst
          ctx.yMouSrc := ctx.yMouLst
          ctx.xMouDif := 0
          ctx.yMouDif := 0
          ; No longer snapped — restore rounding and clear snap tracking
          this._snappedWindows.Delete(ctx.hwnd)
          this._setCornerRounding(ctx.hwnd, WindowFlags.DWMWCP_DEFAULT)
        }
        xWinDst := ctx.xWinSrc + ctx.xMouDif
        yWinDst := ctx.yWinSrc + ctx.yMouDif

        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
        screenRect := { left: CurScrLeft, right: CurScrRight, top: CurScrTop, bottom: CurScrBottom }

        if (this.Config.EnableSnapping) {
          this._snapToScreenEdges(&xWinDst, &yWinDst, &wWinDst, &hWinDst, insets, snappingDistance, screenRect, "move")
        }

        if (this.Config.SnapToWindows) {
          this._snapToNeighborEdges(&xWinDst, &yWinDst, &wWinDst, &hWinDst, insets, windowSnappingDistance, neighborEdges, "move")
        }
      }

      this._handleSnapPreview(ctx.xMouLst, ctx.yMouLst, ctx.isQuickPositioning, &pendingSnapZone)

      this._renderDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, ctx.isQuickPositioning, "ShowWindowContentOnMove")
      this._updateInfoTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst/2, yWinDst + hWinDst/2)
    }

    this._hideSnapPreview()
    this._destroySnapPreview()

    this._finalizeDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, ctx.isQuickPositioning, "ShowWindowContentOnMove", ctx.EscButtonState != "U")

    if (ctx.EscButtonState = "U" && IsObject(pendingSnapZone)) {
      this._applySnapZone(ctx.hwnd, pendingSnapZone, insets)
    }

    this._destroyInfoTip()
    this.disableEscapeHook()
    return
  }

  EnterWindowResizingMode() { ;;;
    RestoreOnResize := 1
    Use9WindowAreasToResize := 0

    ctx := {}
    if (!this._initDragSession(&ctx, A_ThisFunc))
      return

    ; ; Check window has sizing border 
    ; style := WinGetStyle("ahk_id " ctx.hwnd)
    ; if (!(style & WindowFlags.WS_SIZEBOX)) { //FIXME: for this block make it still possible to resize the window, but just add some threshold before resize try to start
    ;   this._destroyInfoTip()
    ;   this.disableEscapeHook()
    ;   return
    ; }

    if (!this.Config.ShowWindowContentOnResize)
      this._createOverlay()

    ; Resize-specific setup
    if (RestoreOnResize) {
      IsMaximized := WinGetMinMax("ahk_id " ctx.hwnd)
      if (IsMaximized) {
        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
        WinRestore("ahk_id " ctx.hwnd)
        this.saveOriginalWindowState(ctx.hwnd)
        this.windowState.max := 1
        WinMove(CurScrLeft, CurScrTop, CurScrRight - CurScrLeft, CurScrBottom - CurScrTop, "ahk_id " ctx.hwnd)
      }
    }

    xWinDst := ctx.xWinSrc
    yWinDst := ctx.yWinSrc
    wWinDst := ctx.wWinSrc
    hWinDst := ctx.hWinSrc
    insets := { left: ctx.leftInset, top: ctx.topInset, right: ctx.rightInset, bottom: ctx.bottomInset }

    ; Calculate resize multipliers
    mul := this._calcResizeMultipliers(ctx.xMouSrc, ctx.yMouSrc, ctx.xWinSrc, ctx.yWinSrc, ctx.wWinSrc, ctx.hWinSrc, Use9WindowAreasToResize)
    xMul := mul["xMul"]
    yMul := mul["yMul"]

    snappingDistance := Number(this.Config.SnappingDistance)
    windowSnappingDistance := Number(this.Config.SnapToWindowsDistance)
    resizeAxisThreshold := Number(this.Config.ResizeAxisThreshold)
    neighborEdges := this.Config.SnapToWindows ? this._getNeighborEdges(ctx.hwnd) : Map("x", [], "y", [])

    ; Query minimum tracking size so we can clamp and prevent sliding at min size
    minSize := this._getMinTrackSize(ctx.hwnd)

    ; Detect docked edges
    GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
    screenRect := { left: CurScrLeft, right: CurScrRight, top: CurScrTop, bottom: CurScrBottom, x: CurScrLeft, y: CurScrTop, w: CurScrRight - CurScrLeft, h: CurScrBottom - CurScrTop }
    winRect := { x: ctx.xWinSrc, y: ctx.yWinSrc, w: ctx.wWinSrc, h: ctx.hWinSrc }
    dockState := this._detectDockedEdges(winRect, insets, screenRect, neighborEdges, 3)
    wasQuickPositioning := false

    ; Sticky resize setup
    stickyKey := this.Config.StickyResizeModifier
    stickyNeighbors := this._getStickyNeighbors(ctx.hwnd, insets, xMul, yMul)
    stickyOrigX := ctx.xWinSrc
    stickyOrigW := ctx.wWinSrc
    stickyOrigY := ctx.yWinSrc
    stickyOrigH := ctx.hWinSrc

    Loop {
      pollStatus := this._pollDragInput(ctx)
      if (pollStatus = "released")
        break
      if (pollStatus = "cancelled") {
        this.restoreOriginalWindowState(ctx.hwnd)
        this._restoreStickyNeighbors(stickyNeighbors)
        break
      }

      ctx.isQuickPositioning := false

      ; Apply axis resistance
      xMouDif := ctx.xMouDif
      yMouDif := ctx.yMouDif
      this._applyAxisResistance(&xMouDif, &yMouDif, resizeAxisThreshold, xMul, yMul, dockState)

      if (ctx.quickPositionHotkey_wasUp && IsHotkeyStatePressed(ctx.quickPositionHotkey)) {
        ctx.isQuickPositioning := true
        wasQuickPositioning := true
        this.quickPositionWindowOnEdge(ctx.hwnd, &xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else {
        ; Rebase after QP release so the window continues from its QP geometry
        if (wasQuickPositioning) {
          wasQuickPositioning := false
          ctx.xWinSrc := xWinDst
          ctx.yWinSrc := yWinDst
          ctx.wWinSrc := wWinDst
          ctx.hWinSrc := hWinDst
          ctx.xMouSrc := ctx.xMouLst
          ctx.yMouSrc := ctx.yMouLst
          xMouDif := 0
          yMouDif := 0
          ; No longer snapped — restore rounding and clear snap tracking
          this._snappedWindows.Delete(ctx.hwnd)
          this._setCornerRounding(ctx.hwnd, WindowFlags.DWMWCP_DEFAULT)
          ; Re-query min size and dock state for the new geometry
          minSize := this._getMinTrackSize(ctx.hwnd)
          winRect := { x: ctx.xWinSrc, y: ctx.yWinSrc, w: ctx.wWinSrc, h: ctx.hWinSrc }
          dockState := this._detectDockedEdges(winRect, insets, screenRect, neighborEdges, 3)
          ; Re-detect sticky neighbors from new geometry
          stickyNeighbors := this._getStickyNeighbors(ctx.hwnd, insets, xMul, yMul)
          stickyOrigX := ctx.xWinSrc
          stickyOrigW := ctx.wWinSrc
          stickyOrigY := ctx.yWinSrc
          stickyOrigH := ctx.hWinSrc
        }

        if (this.Config.EnableSnapping) {
          xWinDst := ctx.xWinSrc + (xMul = 1 ? 1 : 0) * xMouDif
          yWinDst := ctx.yWinSrc + (yMul = 1 ? 1 : 0) * yMouDif
          wWinDst := ctx.wWinSrc - xMul * xMouDif
          hWinDst := ctx.hWinSrc - yMul * yMouDif

          GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
          screenRect := { left: CurScrLeft, right: CurScrRight, top: CurScrTop, bottom: CurScrBottom }

          this._snapToScreenEdges(&xWinDst, &yWinDst, &wWinDst, &hWinDst, insets, snappingDistance, screenRect, "resize", xMul, yMul)

          if (this.Config.SnapToWindows) {
            this._snapToNeighborEdges(&xWinDst, &yWinDst, &wWinDst, &hWinDst, insets, windowSnappingDistance, neighborEdges, "resize", xMul, yMul)
          }
        } else {
          xWinDst := ctx.xWinSrc + (xMul = 1 ? 1 : 0) * xMouDif
          yWinDst := ctx.yWinSrc + (yMul = 1 ? 1 : 0) * yMouDif
          wWinDst := ctx.wWinSrc - xMul * xMouDif
          hWinDst := ctx.hWinSrc - yMul * yMouDif
        }
      }

      ; Apply oversize resistance
      if (!ctx.isQuickPositioning) {
        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
        screenRect := { left: CurScrLeft, right: CurScrRight, top: CurScrTop, bottom: CurScrBottom }
        this._applyOversizeResistance(&xWinDst, &yWinDst, &wWinDst, &hWinDst, insets, screenRect, xMul, yMul)
      }

      ; Clamp to minimum window size, pinning the fixed edge
      if (!ctx.isQuickPositioning)
        this._clampToMinSize(&xWinDst, &yWinDst, &wWinDst, &hWinDst, ctx.xWinSrc, ctx.yWinSrc, ctx.wWinSrc, ctx.hWinSrc, xMul, yMul, minSize)

      this._renderDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, ctx.isQuickPositioning, "ShowWindowContentOnResize")
      this._updateInfoTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst / 2, yWinDst + hWinDst / 2)

      ; Sticky resize: co-resize neighboring windows sharing an edge
      if (!ctx.isQuickPositioning && stickyKey && GetKeyState(stickyKey, "P") && stickyNeighbors.Length > 0) {
        dLeft := xWinDst - stickyOrigX
        dRight := (xWinDst + wWinDst) - (stickyOrigX + stickyOrigW)
        dTop := yWinDst - stickyOrigY
        dBottom := (yWinDst + hWinDst) - (stickyOrigY + stickyOrigH)
        this._applyStickyResize(stickyNeighbors, dLeft, dRight, dTop, dBottom)
      }
    }

    this._finalizeDragFeedback(ctx.hwnd, xWinDst, yWinDst, wWinDst, hWinDst, insets, ctx.isQuickPositioning, "ShowWindowContentOnResize", ctx.EscButtonState != "U")

    this._destroyInfoTip()
    this.disableEscapeHook()
    return
  }

  _initDragSession(&ctx, callerName) {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    this.initEscapeHook()
    this.disableEscapeHook()

    MouseGetPos(&xMouSrc, &yMouSrc, &hwnd)
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    MouseButton := hotkeyInfo.key

    if (!hwnd || this._isSystemWindow(hwnd))
      return false

    if (this.IsWindowBlocklisted(hwnd, callerName)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return false
    }

    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()

    if (this.Config.BringToFront)
      WinActivate("ahk_id " hwnd)

    IsMaximized := WinGetMinMax("ahk_id " hwnd)
    if (IsMaximized) {
      WinRestore("ahk_id " hwnd)
      this.saveOriginalWindowState(hwnd)
      this.windowState.max := 1
    }

    this._createInfoTip()

    QuickPositionHotkey := ResolveHotkeyStateKeyName(this.Config.QuickPositionHotkey, "LWin")
    QuickPositionHotkey_wasUp := !IsHotkeyStatePressed(QuickPositionHotkey)

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)

    leftInset := 0
    topInset := 0
    rightInset := 0
    bottomInset := 0
    this._getInvisibleBorderOffsets(hwnd, &leftInset, &topInset, &rightInset, &bottomInset)

    ctx := {
      hwnd: hwnd,
      mouseButton: MouseButton,
      xMouSrc: xMouSrc,
      yMouSrc: yMouSrc,
      xWinSrc: xWinSrc,
      yWinSrc: yWinSrc,
      wWinSrc: wWinSrc,
      hWinSrc: hWinSrc,
      leftInset: leftInset,
      topInset: topInset,
      rightInset: rightInset,
      bottomInset: bottomInset,
      quickPositionHotkey: QuickPositionHotkey,
      quickPositionHotkey_wasUp: QuickPositionHotkey_wasUp,
      EscButtonState: "U",
      isQuickPositioning: false
    }
    return true
  }

  _pollDragInput(ctx) {
    mouseButtonState := GetKeyState(ctx.mouseButton, "P") ? "D" : "U"
    if (mouseButtonState = "U")
      return "released"

    escButtonState := GetKeyState("Escape", "P") ? "D" : "U"
    if (escButtonState = "D") {
      ctx.EscButtonState := escButtonState
      return "cancelled"
    }

    if (!ctx.quickPositionHotkey_wasUp)
      ctx.quickPositionHotkey_wasUp := !IsHotkeyStatePressed(ctx.quickPositionHotkey)

    MouseGetPos(&xMouLst, &yMouLst)
    ctx.xMouLst := xMouLst
    ctx.yMouLst := yMouLst
    ctx.xMouDif := xMouLst - ctx.xMouSrc
    ctx.yMouDif := yMouLst - ctx.yMouSrc

    return "continue"
  }

  saveOriginalWindowState(hwnd) {
    max := WinGetMinMax("ahk_id " hwnd)
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    this.windowState := { max: max, x: x, y: y, w: w, h: h }
    OutputDebug("SAVE state: max: " max ", x: " x ", y: " y ", w: " w ", h: " h "`n")
  }
  
  restoreOriginalWindowState(hwnd) {
    max := this.windowState.max
    x := this.windowState.x
    y := this.windowState.y
    w := this.windowState.w
    h := this.windowState.h
    
    OutputDebug("LOAD state: max: " max ", x: " x ", y: " y ", w: " w ", h: " h "`n")
    IsMaximized := WinGetMinMax("ahk_id " hwnd)
    if (IsMaximized && ! this.windowState.max) {
      WinRestore("ahk_id " hwnd)
      WinMove(x, y, w, h, "ahk_id " hwnd)
    } else if (! IsMaximized && this.windowState.max) {
      WinMove(x, y, w, h, "ahk_id " hwnd)
      WinMaximize("ahk_id " hwnd)
    } else {
      WinMove(x, y, w, h, "ahk_id " hwnd)
    }
  }

  _applyWindowRect(hwnd, x, y, w, h) {
    if (this.Config.UseSetWindowPos) {
      try {
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", Round(x), "Int", Round(y), "Int", Round(w), "Int", Round(h), "UInt", WindowFlags.SWP_NOZORDER | WindowFlags.SWP_NOACTIVATE)
        return
      }
    }

    WinMove(x, y, w, h, "ahk_id " hwnd)
  }

  _applyVisibleWindowRect(hwnd, x, y, w, h, leftInset, topInset, rightInset, bottomInset) {
    this._applyWindowRect(
      hwnd,
      x - leftInset,
      y - topInset,
      w + leftInset + rightInset,
      h + topInset + bottomInset
    )
  }

  _getVisibleRect(x, y, w, h, leftInset, topInset, rightInset, bottomInset) {
    return {
      left: x + leftInset,
      top: y + topInset,
      right: x + w - rightInset,
      bottom: y + h - bottomInset
    }
  }

  _detectDockedEdges(winRect, insets, screenRect, neighborEdges, tolerance) {
    visLeft := winRect.x + insets.left
    visTop := winRect.y + insets.top
    visRight := winRect.x + winRect.w - insets.right
    visBottom := winRect.y + winRect.h - insets.bottom

    docked := { left: false, right: false, top: false, bottom: false }

    if (Abs(visLeft - screenRect.left) <= tolerance)
      docked.left := true
    if (Abs(visRight - screenRect.right) <= tolerance)
      docked.right := true
    if (Abs(visTop - screenRect.top) <= tolerance)
      docked.top := true
    if (Abs(visBottom - screenRect.bottom) <= tolerance)
      docked.bottom := true

    for edge in neighborEdges["x"] {
      if (Abs(visLeft - edge) <= tolerance)
        docked.left := true
      if (Abs(visRight - edge) <= tolerance)
        docked.right := true
    }
    for edge in neighborEdges["y"] {
      if (Abs(visTop - edge) <= tolerance)
        docked.top := true
      if (Abs(visBottom - edge) <= tolerance)
        docked.bottom := true
    }

    return docked
  }

  _calcResizeMultipliers(mouseX, mouseY, winX, winY, winW, winH, use9Areas) {
    if (use9Areas) {
      xMul := 0
      yMul := 0
      if (mouseX < winX + winW / 3)
        xMul := 1
      if (mouseX > winX + winW * 2/3)
        xMul := -1
      if (mouseY < winY + winH / 3)
        yMul := 1
      if (mouseY > winY + winH * 2/3)
        yMul := -1
    } else {
      xMul := (mouseX < winX + winW / 2) ? 1 : -1
      yMul := (mouseY < winY + winH / 2) ? 1 : -1
    }
    return Map("xMul", xMul, "yMul", yMul)
  }

  _applyAxisResistance(&xMouDif, &yMouDif, threshold, xMul, yMul, dockState) {
    if (threshold <= 0)
      return

    absX := Abs(xMouDif)
    absY := Abs(yMouDif)
    xEdgeDocked := (xMul > 0 && dockState.left) || (xMul < 0 && dockState.right)
    yEdgeDocked := (yMul > 0 && dockState.top) || (yMul < 0 && dockState.bottom)

    if (absX >= absY) {
      yThresh := yEdgeDocked ? threshold * 2 : threshold
      if (absY < yThresh)
        yMouDif := 0
    } else {
      xThresh := xEdgeDocked ? threshold * 2 : threshold
      if (absX < xThresh)
        xMouDif := 0
    }
  }

  _applyOversizeResistance(&x, &y, &w, &h, insets, screenRect, xMul, yMul) {
    scrW := screenRect.right - screenRect.left
    scrH := screenRect.bottom - screenRect.top
    oversizeThreshX := Round(scrW * 0.3)
    oversizeThreshY := Round(scrH * 0.3)

    visLeft := x + insets.left
    if (visLeft < screenRect.left && xMul > 0) {
      absorbed := Min(screenRect.left - visLeft, oversizeThreshX)
      x += absorbed
      w -= absorbed
    }

    visRight := x + w - insets.right
    if (visRight > screenRect.right && xMul < 0) {
      absorbed := Min(visRight - screenRect.right, oversizeThreshX)
      w -= absorbed
    }

    visTop := y + insets.top
    if (visTop < screenRect.top && yMul > 0) {
      absorbed := Min(screenRect.top - visTop, oversizeThreshY)
      y += absorbed
      h -= absorbed
    }

    visBottom := y + h - insets.bottom
    if (visBottom > screenRect.bottom && yMul < 0) {
      absorbed := Min(visBottom - screenRect.bottom, oversizeThreshY)
      h -= absorbed
    }
  }

  _getMinTrackSize(hwnd) {
    ; Query the window's minimum tracking size via WM_GETMINMAXINFO
    mmi := Buffer(40, 0)
    try SendMessage(WindowFlags.WM_GETMINMAXINFO, 0, mmi.Ptr, "ahk_id " hwnd)
    minW := NumGet(mmi, 24, "Int") ; ptMinTrackSize.x
    minH := NumGet(mmi, 28, "Int") ; ptMinTrackSize.y
    ; Fall back to system defaults if the window returned zeros
    if (minW <= 0)
      minW := DllCall("GetSystemMetrics", "Int", WindowFlags.SM_CXMINTRACK)
    if (minH <= 0)
      minH := DllCall("GetSystemMetrics", "Int", WindowFlags.SM_CYMINTRACK)
    return { w: minW, h: minH }
  }

  _clampToMinSize(&x, &y, &w, &h, xSrc, ySrc, wSrc, hSrc, xMul, yMul, minSize) {
    if (w < minSize.w) {
      w := minSize.w
      ; Pin the fixed edge: when dragging from left (xMul=1), right edge is fixed
      if (xMul > 0)
        x := xSrc + wSrc - minSize.w
    }
    if (h < minSize.h) {
      h := minSize.h
      ; Pin the fixed edge: when dragging from top (yMul=1), bottom edge is fixed
      if (yMul > 0)
        y := ySrc + hSrc - minSize.h
    }
  }

  _getInvisibleBorderOffsets(hwnd, &leftInset, &topInset, &rightInset, &bottomInset) {
    leftInset := 0
    topInset := 0
    rightInset := 0
    bottomInset := 0

    if (!this.Config.CompensateInvisibleBorders)
      return false

    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
    rect := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect.Ptr, "UInt", rect.Size) != 0)
      return false

    visX := NumGet(rect, 0, "Int")
    visY := NumGet(rect, 4, "Int")
    visR := NumGet(rect, 8, "Int")
    visB := NumGet(rect, 12, "Int")

    leftInset := Max(0, visX - winX)
    topInset := Max(0, visY - winY)
    rightInset := Max(0, (winX + winW) - visR)
    bottomInset := Max(0, (winY + winH) - visB)
    return true
  }

  _isSystemWindow(hwnd) {
    if (!hwnd)
      return true

    if (!DllCall("IsWindowVisible", "Ptr", hwnd))
      return true

    isWindowInvisible := 0
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_CLOAKED, "UInt*", &isWindowInvisible, "UInt", Win32Sizes.DWORD) = 0) {
      if (isWindowInvisible)
        return true
    }

    exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & WindowFlags.WS_EX_TOOLWINDOW)
      return true
    if (exStyle & WindowFlags.WS_EX_LAYERED)
      return true

    className := ""
    try className := WinGetClass("ahk_id " hwnd)
    if (className = "Shell_TrayWnd" || className = "Shell_SecondaryTrayWnd" || className = "Windows.UI.Core.CoreWindow" || className = "Button" || className = "SysPager" || className = "WorkerW" || className = "Progman")
      return true

    processName := ""
    try processName := WinGetProcessName("ahk_id " hwnd)
    if (processName = "StartMenuExperienceHost.exe" || processName = "SearchHost.exe")
      return true

    return false
  }

  formatWindowGeometryInfo(x, y, w, h) {
    return "x: " . Round(x) . ", y: " . Round(y) . "`n(" . Round(w) . " x " . Round(h) . ")"
  }

  quickPositionWindowOnEdge(hwnd, &xWin, &yWin, &wWin, &hWin) {
    ; 16-zone grid: mouse position maps to a grid cell (0..15 on each axis).
    ; Cells fold symmetrically around the center, giving 8 size tiers per axis.
    ; The sizeSteps array maps folded index (1..8) to the fraction of screen filled.
    static sizeSteps := [1/4, 1/3, 0.382, 1/2, 0.618, 2/3, 3/4, 1]

    CurScrLeft := 0
    CurScrRight := A_ScreenWidth
    CurScrTop := 0
    CurScrBottom := A_ScreenHeight
    GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
    scrWidth  := CurScrRight - CurScrLeft
    scrHeight := CurScrBottom - CurScrTop
    MouseGetPos(&mouseX, &mouseY)

    localX := mouseX - CurScrLeft
    localY := mouseY - CurScrTop

    cellX := Floor((16 * localX) / scrWidth)  ; 0..15
    cellY := Floor((16 * localY) / scrHeight) ; 0..15

    ; Fold to symmetric index (1..8): cells 0..7 → 1..8, cells 8..15 → 8..1
    foldX := (cellX < 8) ? cellX + 1 : 16 - cellX
    foldY := (cellY < 8) ? cellY + 1 : 16 - cellY

    ; Center zone detection (mouse near screen center)
    dxCenter := Abs(localX - scrWidth / 2)
    dyCenter := Abs(localY - scrHeight / 2)
    cellW := scrWidth / 16
    cellH := scrHeight / 16

    if (dxCenter < cellW * 0.33 && dyCenter < cellH * 0.33) {
      ; Inner center — 33% of screen
      xWin := CurScrLeft + 0.33 * scrWidth
      yWin := CurScrTop + 0.33 * scrHeight
      wWin := scrWidth * 0.33
      hWin := scrHeight * 0.33
    } else if (dxCenter < cellW * 0.66 && dyCenter < cellH * 0.66) {
      ; Middle center — 50% of screen
      xWin := CurScrLeft + 0.25 * scrWidth
      yWin := CurScrTop + 0.25 * scrHeight
      wWin := scrWidth * 0.5
      hWin := scrHeight * 0.5
    } else if (dxCenter < cellW && dyCenter < cellH) {
      ; Outer center — golden ratio inset
      inset := 0.382 * 0.382
      xWin := CurScrLeft + inset * scrWidth
      yWin := CurScrTop + inset * scrHeight
      wWin := scrWidth * (1 - 2 * inset)
      hWin := scrHeight * (1 - 2 * inset)
    } else {
      ; Edge/corner tile — look up size from sizeSteps
      wWin := scrWidth * sizeSteps[foldX]
      hWin := scrHeight * sizeSteps[foldY]

      xWin := (cellX < 8) ? CurScrLeft : CurScrLeft + scrWidth - wWin
      yWin := (cellY < 8) ? CurScrTop : CurScrTop + scrHeight - hWin
    }

    ; Track pre-snap state and set square corners
    if (!this._snappedWindows.Has(hwnd)) {
      WinGetPos(&preX, &preY, &preW, &preH, "ahk_id " hwnd)
      this._snappedWindows[hwnd] := Map("x", preX, "y", preY, "w", preW, "h", preH)
    }
    this._setCornerRounding(hwnd, WindowFlags.DWMWCP_DONOTROUND)
  }

  _setCornerRounding(hwnd, mode) {
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_WINDOW_CORNER_PREFERENCE, "Int*", mode, "UInt", Win32Sizes.DWORD)
  }

  _createOverlay() {
    this._destroyOverlay()
    this._overlayGui := this._createOverlayGui()
  }

  _showOverlay(x, y, w, h) {
    if (!IsObject(this._overlayGui))
      this._createOverlay()
    this._overlayGui.Show("x" Round(x) " y" Round(y) " w" Round(w) " h" Round(h) " NoActivate")
  }

  _destroyOverlay() {
    if (IsObject(this._overlayGui)) {
      try this._overlayGui.Destroy()
      this._overlayGui := ""
    }
  }

  _createOverlayGui() {
    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    overlayGui.BackColor := this.Config.OverlayColor
    overlayGui.Show("Hide NoActivate") ; Show hidden first to establish the window
    WinSetTransparent(Number(this.Config.OverlayOpacity), "ahk_id " overlayGui.Hwnd)
    this._setCornerRounding(overlayGui.Hwnd, WindowFlags.DWMWCP_ROUND)
    return overlayGui
  }

  _createSnapPreview() {
    this._destroySnapPreview()
    this._snapPreviewGui := this._createOverlayGui()
  }

  _showSnapPreview(x, y, w, h) {
    if (!IsObject(this._snapPreviewGui))
      this._createSnapPreview()
    this._snapPreviewGui.Show("x" Round(x) " y" Round(y) " w" Round(w) " h" Round(h) " NoActivate")
  }

  _hideSnapPreview() {
    if (IsObject(this._snapPreviewGui)) {
      try this._snapPreviewGui.Show("Hide")
    }
  }

  _destroySnapPreview() {
    if (IsObject(this._snapPreviewGui)) {
      try this._snapPreviewGui.Destroy()
      this._snapPreviewGui := ""
    }
  }

  _snapToScreenEdges(&x, &y, &w, &h, insets, snapDist, screenRect, mode, xMul := 0, yMul := 0) {
    vis := this._getVisibleRect(x, y, w, h, insets.left, insets.top, insets.right, insets.bottom)

    if (mode = "move") {
      if (vis.left < screenRect.left + snapDist) && (vis.left > screenRect.left - snapDist)
        x := screenRect.left - insets.left

      if (vis.top < screenRect.top + snapDist) && (vis.top > screenRect.top - snapDist)
        y := screenRect.top - insets.top

      if (vis.right > screenRect.right - snapDist) && (vis.right < screenRect.right + snapDist)
        x := screenRect.right - (w - insets.right)

      if (vis.bottom > screenRect.bottom - snapDist) && (vis.bottom < screenRect.bottom + snapDist)
        y := screenRect.bottom - (h - insets.bottom)
    } else if (mode = "resize") {
      if (vis.left < screenRect.left + snapDist) && (vis.left > screenRect.left - snapDist) && (xMul > 0) {
        oldX := x
        x := screenRect.left - insets.left
        w := w + (oldX - x)
      }
      if (vis.top < screenRect.top + snapDist) && (vis.top > screenRect.top - snapDist) && (yMul > 0) {
        oldY := y
        y := screenRect.top - insets.top
        h := h + (oldY - y)
      }
      if (vis.right > screenRect.right - snapDist) && (vis.right < screenRect.right + snapDist) && (xMul < 0) {
        w := screenRect.right - x + insets.right
      }
      if (vis.bottom > screenRect.bottom - snapDist) && (vis.bottom < screenRect.bottom + snapDist) && (yMul < 0) {
        h := screenRect.bottom - y + insets.bottom
      }
    }
  }

  _snapToNeighborEdges(&x, &y, &w, &h, insets, snapDist, neighborEdges, mode, xMul := 0, yMul := 0) {
    vis := this._getVisibleRect(x, y, w, h, insets.left, insets.top, insets.right, insets.bottom)

    for edge in neighborEdges["x"] {
      if (mode = "move") {
        if (Abs(vis.left - edge) <= snapDist) {
          x := edge - insets.left
          break
        }
        if (Abs(vis.right - edge) <= snapDist) {
          x := edge - (w - insets.right)
          break
        }
      } else if (mode = "resize") {
        if (xMul > 0 && Abs(vis.left - edge) <= snapDist) {
          oldX := x
          x := edge - insets.left
          w := w + (oldX - x)
          break
        }
        if (xMul < 0 && Abs(vis.right - edge) <= snapDist) {
          w := edge - x + insets.right
          break
        }
      }
    }

    for edge in neighborEdges["y"] {
      if (mode = "move") {
        if (Abs(vis.top - edge) <= snapDist) {
          y := edge - insets.top
          break
        }
        if (Abs(vis.bottom - edge) <= snapDist) {
          y := edge - (h - insets.bottom)
          break
        }
      } else if (mode = "resize") {
        if (yMul > 0 && Abs(vis.top - edge) <= snapDist) {
          oldY := y
          y := edge - insets.top
          h := h + (oldY - y)
          break
        }
        if (yMul < 0 && Abs(vis.bottom - edge) <= snapDist) {
          h := edge - y + insets.bottom
          break
        }
      }
    }
  }

  _getNeighborEdges(excludeHwnd) {
    xEdges := []
    yEdges := []

    windows := WinGetList()
    for hwnd in windows {
      if (hwnd = excludeHwnd)
        continue
      try {
        if (WinGetMinMax("ahk_id " hwnd) = -1)
          continue
      } catch
        continue
      if (this._isSystemWindow(hwnd))
        continue

      rect := Buffer(16, 0)
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect.Ptr, "UInt", rect.Size) = 0) {
        xEdges.Push(NumGet(rect, 0, "Int"))
        xEdges.Push(NumGet(rect, 8, "Int"))
        yEdges.Push(NumGet(rect, 4, "Int"))
        yEdges.Push(NumGet(rect, 12, "Int"))
      }
    }

    return Map("x", xEdges, "y", yEdges)
  }

  _getStickyNeighbors(hwnd, insets, xMul, yMul) {
    ; Find windows whose edges touch the edges being resized.
    ; "follows" flags: neighbor's opposite edge touches my edge (e.g. neighbor is to my right).
    ; "aligns" flags: perpendicular neighbor's same-side edge is co-linear with mine
    ;   (e.g. neighbor below me has its left edge aligned with my left edge).
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    vis := this._getVisibleRect(wx, wy, ww, wh, insets.left, insets.top, insets.right, insets.bottom)
    tolerance := 5
    neighbors := []

    for otherHwnd in WinGetList() {
      if (otherHwnd = hwnd)
        continue
      try {
        if (WinGetMinMax("ahk_id " otherHwnd) != 0)
          continue
      } catch
        continue
      if (this._isSystemWindow(otherHwnd))
        continue

      nli := 0, nti := 0, nri := 0, nbi := 0
      this._getInvisibleBorderOffsets(otherHwnd, &nli, &nti, &nri, &nbi)
      WinGetPos(&nx, &ny, &nw, &nh, "ahk_id " otherHwnd)
      nVis := this._getVisibleRect(nx, ny, nw, nh, nli, nti, nri, nbi)

      ; Windows must overlap on the perpendicular axis to share an edge
      vOverlap := (nVis.top < vis.bottom - tolerance) && (nVis.bottom > vis.top + tolerance)
      hOverlap := (nVis.left < vis.right - tolerance) && (nVis.right > vis.left + tolerance)

      ; Adjacency detection (ungated by xMul/yMul)
      isRight := vOverlap && Abs(nVis.left - vis.right) <= tolerance
      isLeft  := vOverlap && Abs(nVis.right - vis.left) <= tolerance
      isBelow := hOverlap && Abs(nVis.top - vis.bottom) <= tolerance
      isAbove := hOverlap && Abs(nVis.bottom - vis.top) <= tolerance

      fRight := false, fLeft := false, fBottom := false, fTop := false
      aLeft := false, aRight := false, aTop := false, aBottom := false

      ; Direct edge followers: neighbor's opposite edge touches my moving edge
      if (xMul < 0 && isRight)
        fRight := true
      if (xMul > 0 && isLeft)
        fLeft := true
      if (yMul < 0 && isBelow)
        fBottom := true
      if (yMul > 0 && isAbove)
        fTop := true

      ; Aligned edges: perpendicular neighbor's same-side edge matches mine
      if ((isBelow || isAbove) && xMul > 0 && Abs(nVis.left - vis.left) <= tolerance)
        aLeft := true
      if ((isBelow || isAbove) && xMul < 0 && Abs(nVis.right - vis.right) <= tolerance)
        aRight := true
      if ((isLeft || isRight) && yMul > 0 && Abs(nVis.top - vis.top) <= tolerance)
        aTop := true
      if ((isLeft || isRight) && yMul < 0 && Abs(nVis.bottom - vis.bottom) <= tolerance)
        aBottom := true

      if (fRight || fLeft || fBottom || fTop || aLeft || aRight || aTop || aBottom)
        neighbors.Push({ hwnd: otherHwnd, origX: nx, origY: ny, origW: nw, origH: nh,
          followsRight: fRight, followsLeft: fLeft, followsBottom: fBottom, followsTop: fTop,
          alignsLeft: aLeft, alignsRight: aRight, alignsTop: aTop, alignsBottom: aBottom })
    }
    return neighbors
  }

  _applyStickyResize(neighbors, dLeft, dRight, dTop, dBottom) {
    for n in neighbors {
      nx := n.origX + (n.followsRight ? dRight : 0) + (n.alignsLeft ? dLeft : 0)
      nw := n.origW - (n.followsRight ? dRight : 0) + (n.followsLeft ? dLeft : 0) - (n.alignsLeft ? dLeft : 0) + (n.alignsRight ? dRight : 0)
      ny := n.origY + (n.followsBottom ? dBottom : 0) + (n.alignsTop ? dTop : 0)
      nh := n.origH - (n.followsBottom ? dBottom : 0) + (n.followsTop ? dTop : 0) - (n.alignsTop ? dTop : 0) + (n.alignsBottom ? dBottom : 0)
      this._applyWindowRect(n.hwnd, nx, ny, nw, nh)
    }
  }

  _restoreStickyNeighbors(neighbors) {
    for n in neighbors
      this._applyWindowRect(n.hwnd, n.origX, n.origY, n.origW, n.origH)
  }

  _renderDragFeedback(hwnd, x, y, w, h, insets, isQuickPositioning, showContentKey) {
    showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config[showContentKey]
    if (showContent) {
      if (isQuickPositioning)
        this._applyVisibleWindowRect(hwnd, x, y, w, h, insets.left, insets.top, insets.right, insets.bottom)
      else
        this._applyWindowRect(hwnd, x, y, w, h)
    } else {
      this._showOverlay(x, y, w, h)
    }
  }

  _finalizeDragFeedback(hwnd, x, y, w, h, insets, isQuickPositioning, showContentKey, cancelled) {
    showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config[showContentKey]
    if (!showContent) {
      this._destroyOverlay()
      if (!cancelled) {
        if (isQuickPositioning)
          this._applyVisibleWindowRect(hwnd, x, y, w, h, insets.left, insets.top, insets.right, insets.bottom)
        else
          this._applyWindowRect(hwnd, x, y, w, h)
      }
    }
  }

  _handleSnapPreview(mouseX, mouseY, isQuickPositioning, &pendingSnapZone) {
    if (!isQuickPositioning && this.Config.SnapOnRelease) {
      zone := ""
      if (this._detectSnapZone(mouseX, mouseY, &zone)) {
        pendingSnapZone := zone
        this._showSnapPreview(zone["x"], zone["y"], zone["w"], zone["h"])
      } else {
        this._hideSnapPreview()
      }
    } else {
      this._hideSnapPreview()
    }
  }

  _applySnapZone(hwnd, zone, insets) {
    action := zone["action"]
    if (action = "minimize") {
      WinMinimize("ahk_id " hwnd)
    } else {
      WinGetPos(&preSnapX, &preSnapY, &preSnapW, &preSnapH, "ahk_id " hwnd)
      this._snappedWindows[hwnd] := Map("x", preSnapX, "y", preSnapY, "w", preSnapW, "h", preSnapH)
      this._applyVisibleWindowRect(
        hwnd,
        zone["x"],
        zone["y"],
        zone["w"],
        zone["h"],
        insets.left,
        insets.top,
        insets.right,
        insets.bottom
      )
      this._setCornerRounding(hwnd, WindowFlags.DWMWCP_DONOTROUND)
    }
  }

  _detectSnapZone(mouseX, mouseY, &zone) {
    zone := ""

    threshold := Max(1, Round(Number(this.Config.SnapEdgeThreshold)))

    ; Use MonitorGet (full bounds) to find which monitor the cursor is on,
    ; so snap zones still work when cursor enters the taskbar area.
    ; Then use MonitorGetWorkArea on that monitor for zone geometry.
    CurScrLeft := 0
    CurScrRight := A_ScreenWidth
    CurScrTop := 0
    CurScrBottom := A_ScreenHeight
    monitorFound := false
    MonitorCount := MonitorGetCount()
    Loop MonitorCount {
      MonitorGet(A_Index, &mLeft, &mTop, &mRight, &mBottom)
      if (mouseX >= mLeft && mouseX < mRight && mouseY >= mTop && mouseY < mBottom) {
        MonitorGetWorkArea(A_Index, &CurScrLeft, &CurScrTop, &CurScrRight, &CurScrBottom)
        monitorFound := true
        break
      }
    }
    if (!monitorFound)
      return false

    scrWidth := CurScrRight - CurScrLeft
    scrHeight := CurScrBottom - CurScrTop
    if (scrWidth <= 0 || scrHeight <= 0)
      return false

    leftHit := mouseX <= (CurScrLeft + threshold)
    rightHit := mouseX >= (CurScrRight - threshold)
    topHit := mouseY <= (CurScrTop + threshold)
    bottomHit := mouseY >= (CurScrBottom - threshold)

    ; Corners have priority over edges.
    if (this.Config.SnapQuarterCorners) {
      halfW := Round(scrWidth / 2)
      halfH := Round(scrHeight / 2)
      if (leftHit && topHit) {
        zone := Map("x", CurScrLeft, "y", CurScrTop, "w", halfW, "h", halfH, "action", "tile")
        return true
      }
      if (rightHit && topHit) {
        zone := Map("x", CurScrLeft + scrWidth - halfW, "y", CurScrTop, "w", halfW, "h", halfH, "action", "tile")
        return true
      }
      if (leftHit && bottomHit) {
        zone := Map("x", CurScrLeft, "y", CurScrTop + scrHeight - halfH, "w", halfW, "h", halfH, "action", "tile")
        return true
      }
      if (rightHit && bottomHit) {
        zone := Map("x", CurScrLeft + scrWidth - halfW, "y", CurScrTop + scrHeight - halfH, "w", halfW, "h", halfH, "action", "tile")
        return true
      }
    }

    if (this.Config.SnapMaximizeOnTop && topHit) {
      zone := Map("x", CurScrLeft, "y", CurScrTop, "w", scrWidth, "h", scrHeight, "action", "maximize")
      return true
    }

    if (this.Config.SnapMinimizeOnBottom && bottomHit) {
      previewHeight := Max(60, Round(scrHeight * 0.18))
      zone := Map("x", CurScrLeft, "y", CurScrBottom - previewHeight, "w", scrWidth, "h", previewHeight, "action", "minimize")
      return true
    }

    if (this.Config.SnapHalfScreen) {
      halfW := Round(scrWidth / 2)
      if (leftHit) {
        zone := Map("x", CurScrLeft, "y", CurScrTop, "w", halfW, "h", scrHeight, "action", "tile")
        return true
      }
      if (rightHit) {
        zone := Map("x", CurScrLeft + scrWidth - halfW, "y", CurScrTop, "w", halfW, "h", scrHeight, "action", "tile")
        return true
      }
    }

    return false
  }

  _createInfoTip() {
    if (!this.Config.ShowGeometryTooltip)
      return
    this._destroyInfoTip()
    this._infoTipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    this._infoTipGui.BackColor := "1A1A2E"
    this._infoTipGui.MarginX := 12
    this._infoTipGui.MarginY := 8
    this._infoTipGui.SetFont("s10 cE0E0E0", "Segoe UI")
    this._infoTipTextCtrl := this._infoTipGui.Add("Text", "vInfoText w160 R2 Center", "`n")
    this._infoTipGui.Show("AutoSize Hide NoActivate")
    WinSetTransparent(220, "ahk_id " this._infoTipGui.Hwnd)
    this._setCornerRounding(this._infoTipGui.Hwnd, WindowFlags.DWMWCP_ROUND)
    this._lastInfoTipText := ""
    this._infoTipVisible := false
  }

  _updateInfoTip(text, centerX, centerY) {
    if (!IsObject(this._infoTipGui) || !IsObject(this._infoTipTextCtrl))
      this._createInfoTip()

    infoTipGui := this._infoTipGui
    infoTipTextCtrl := this._infoTipTextCtrl
    if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd) {
      this._createInfoTip()
      infoTipGui := this._infoTipGui
      infoTipTextCtrl := this._infoTipTextCtrl
    }

    if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
      return

    if (this._lastInfoTipText != text) {
      try infoTipTextCtrl.Text := text
      catch {
        this._createInfoTip()
        infoTipGui := this._infoTipGui
        infoTipTextCtrl := this._infoTipTextCtrl
        if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl))
          return
        infoTipTextCtrl.Text := text
      }
      this._lastInfoTipText := text
    }
    try infoTipGui.GetPos(,, &tipW, &tipH)
    catch {
      this._createInfoTip()
      infoTipGui := this._infoTipGui
      infoTipTextCtrl := this._infoTipTextCtrl
      if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
        return
      tipW := 180
      tipH := 50
    }
    if (!tipW)
      tipW := 180
    if (!tipH)
      tipH := 50
    newX := Round(centerX - tipW / 2)
    newY := Round(centerY - tipH / 2)
    if (!this._infoTipVisible) {
      try infoTipGui.Show("x" newX " y" newY " NoActivate")
      catch {
        this._createInfoTip()
        infoTipGui := this._infoTipGui
        infoTipTextCtrl := this._infoTipTextCtrl
        if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
          return
        infoTipTextCtrl.Text := text
        infoTipGui.Show("x" newX " y" newY " NoActivate")
      }
      this._infoTipVisible := true
    } else {
      try DllCall("SetWindowPos", "Ptr", infoTipGui.Hwnd, "Ptr", 0
          , "Int", newX, "Int", newY, "Int", 0, "Int", 0
          , "UInt", WindowFlags.SWP_NOSIZE | WindowFlags.SWP_NOZORDER | WindowFlags.SWP_NOACTIVATE)
      catch {
        this._infoTipVisible := false
      }
    }
  }

  _destroyInfoTip() {
    if (IsObject(this._infoTipGui)) {
      try this._infoTipGui.Destroy()
    }
    this._infoTipGui := ""
    this._infoTipTextCtrl := ""
    this._lastInfoTipText := ""
    this._infoTipVisible := false
  }

  initEscapeHook() {
    doNothingFn := this.doNothing
    Hotkey("!Escape", doNothingFn)
    Hotkey("Escape", doNothingFn)
  }

  enableEscapeHook() {
    Hotkey("!Escape", "On")
    Hotkey("Escape", "On")
  }
  disableEscapeHook() {
    Hotkey("!Escape", "Off")
    Hotkey("Escape", "Off")
  }

  doNothing(*) {
    return
  }
}
