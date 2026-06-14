import Foundation
import CoreGraphics
import AppKit

class FrameAnimator: ObservableObject {
    @Published var currentFrame: CGImage?
    
    private var cache: ThemeCache
    private var timer: Timer?
    
    private var currentAnimation: PetAnimation = .idle
    private var frameIndex: Int = 0
    private var isLooping: Bool = true
    
    private var lastVariant: PetAnimation?
    private var isPlayingVariant: Bool = false
    private var lastVariantTime: Date = Date.distantPast
    
    var fps: Int = 10 {
        didSet {
            restartTimer()
        }
    }
    
    var energySavingMode: Bool = false {
        didSet {
            restartTimer()
        }
    }
    
    var enableIdleVariants: Bool = true
    
    var isPaused: Bool = false {
        didSet {
            updateTimerState()
        }
    }
    
    private var isAppHidden = false
    private var isSystemSleeping = false
    private var isScreenSleeping = false
    
    init(themeName: String = "CuteCat") {
        self.cache = ThemeCache.load(themeName: themeName)
        updateFrame()
        setupNotificationObservers()
        restartTimer()
    }
    
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        let wnc = NSWorkspace.shared.notificationCenter
        
        nc.addObserver(self, selector: #selector(appDidHide), name: NSApplication.didHideNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidUnhide), name: NSApplication.didUnhideNotification, object: nil)
        
        wnc.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }
    
    @objc private func appDidHide() {
        isAppHidden = true
        updateTimerState()
    }
    
    @objc private func appDidUnhide() {
        isAppHidden = false
        updateTimerState()
    }
    
    @objc private func systemWillSleep() {
        isSystemSleeping = true
        updateTimerState()
    }
    
    @objc private func systemDidWake() {
        isSystemSleeping = false
        updateTimerState()
    }
    
    @objc private func screensDidSleep() {
        isScreenSleeping = true
        updateTimerState()
    }
    
    @objc private func screensDidWake() {
        isScreenSleeping = false
        updateTimerState()
    }
    
    private func updateTimerState() {
        let shouldPause = isPaused || isAppHidden || isSystemSleeping || isScreenSleeping
        if shouldPause {
            stopTimer()
        } else {
            restartTimer()
        }
    }
    
    func updateTheme(themeName: String) {
        self.cache = ThemeCache.load(themeName: themeName)
        frameIndex = 0
        updateFrame()
    }
    
    func updateState(
        displayState: DesktopPetDisplayState,
        interactionState: PetInteractionState,
        isVisuallyDegraded: Bool
    ) {
        let nextAnim: PetAnimation
        let loop: Bool
        
        let effectiveDisplayState: DesktopPetDisplayState
        if displayState == .issues && isVisuallyDegraded {
            effectiveDisplayState = .idle
        } else {
            effectiveDisplayState = displayState
        }
        
        if effectiveDisplayState == .eating {
            nextAnim = .eating
            loop = true
            isPlayingVariant = false
        } else if effectiveDisplayState == .done {
            nextAnim = .done
            loop = false
            isPlayingVariant = false
        } else if effectiveDisplayState == .issues {
            nextAnim = .issues
            loop = true
            isPlayingVariant = false
        } else {
            // Idle business state
            if interactionState == .hover {
                nextAnim = .petting
                loop = true
                isPlayingVariant = false
            } else if interactionState == .dragHover {
                nextAnim = .dragHover
                loop = true
                isPlayingVariant = false
            } else {
                if isPlayingVariant {
                    return
                }
                nextAnim = .idle
                loop = true
                checkAndTriggerIdleVariant()
            }
        }
        
        if nextAnim != currentAnimation {
            currentAnimation = nextAnim
            isLooping = loop
            frameIndex = 0
            updateFrame()
            restartTimer()
        }
    }
    
    private func checkAndTriggerIdleVariant() {
        guard enableIdleVariants && !isPlayingVariant else { return }
        
        let now = Date()
        let cooldown: TimeInterval = Double.random(in: 20...40)
        guard now.timeIntervalSince(lastVariantTime) > cooldown else { return }
        
        let variants: [PetAnimation] = [.stretch, .yawn]
        let available = variants.filter { $0 != lastVariant }
        guard let chosen = available.randomElement() else { return }
        
        lastVariant = chosen
        lastVariantTime = now
        isPlayingVariant = true
        currentAnimation = chosen
        isLooping = false
        frameIndex = 0
        updateFrame()
        restartTimer()
    }
    
    private func restartTimer() {
        stopTimer()
        let shouldPause = isPaused || isAppHidden || isSystemSleeping || isScreenSleeping
        guard !shouldPause else { return }
        
        let targetFps = energySavingMode ? max(1, fps / 2) : fps
        let interval = 1.0 / Double(targetFps)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard let framesForAnim = cache.frames[currentAnimation], !framesForAnim.isEmpty else { return }
        
        frameIndex += 1
        if frameIndex >= framesForAnim.count {
            if isLooping {
                frameIndex = 0
            } else {
                frameIndex = framesForAnim.count - 1
                if isPlayingVariant {
                    isPlayingVariant = false
                    currentAnimation = .idle
                    isLooping = true
                    frameIndex = 0
                    restartTimer()
                }
            }
        }
        updateFrame()
    }
    
    private func updateFrame() {
        if let framesForAnim = cache.frames[currentAnimation], !framesForAnim.isEmpty {
            let idx = min(max(0, frameIndex), framesForAnim.count - 1)
            currentFrame = framesForAnim[idx]
        } else {
            currentFrame = cache.frames[.idle]?.first
        }
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
