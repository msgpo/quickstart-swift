//
//  ViewController.swift
//  HelloSnips
//
//  Copyright © 2018 Snips. All rights reserved.
//

import UIKit
import SnipsPlatform
import AVFoundation

class ViewController: UIViewController {
    
    fileprivate let snips: SnipsPlatform
    fileprivate let audioEngine: AVAudioEngine
    fileprivate lazy var logView = UITextView()

    init() {
        let url = Bundle.main.url(forResource: "assistant", withExtension: nil)!
        snips = try! SnipsPlatform(assistantURL: url)
        audioEngine = try! ViewController.createAudioEngine(with: snips)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Say the wake word"
        
        logView.font = UIFont.systemFont(ofSize: 16)
        logView.frame = view.frame
        logView.isUserInteractionEnabled = false
        view.addSubview(logView)
        
        setupHandlers()
        
        do {
            try snips.start()
            try audioEngine.start()
        } catch let e as SnipsPlatformError {
            print("Snips error: \(e)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
    
    fileprivate class func createAudioEngine(with snips: SnipsPlatform) throws -> AVAudioEngine {
        let audioEngine = AVAudioEngine()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetoothA2DP, .allowBluetooth])
        try audioSession.setPreferredSampleRate(16_000)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)
        let input = audioEngine.inputNode
        let downMixer = AVAudioMixerNode()
        audioEngine.attach(downMixer)
        audioEngine.connect(input, to: downMixer, format: nil)
        downMixer.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, time) in
            do {
                try snips.appendBuffer(buffer)
            } catch {}
        }
        audioEngine.prepare()
        return audioEngine
    }
    
    fileprivate func setupHandlers() {
        snips.onIntentDetected = { [weak self] intent in
            DispatchQueue.main.sync {
                self?.title = "Intent detected"
                self?.logView.text = String(format:
                    "Query: %@\n" +
                    "Intent: %@\n" +
                    "Probability: %.3f\n" +
                    "Slots:\n\t%@",
                    intent.input,
                    intent.intent.intentName,
                    intent.intent.confidenceScore,
                    intent.slots.map { "\($0.slotName): \($0.value)" }.joined(separator: "\n\t")
                )
            }
        }
        
        snips.onHotwordDetected = { [weak self] in
            DispatchQueue.main.sync {
                self?.title = "🔔"
            }
        }
        
        snips.onListeningStateChanged = { [weak self] listening in
            DispatchQueue.main.sync {
                self?.title = listening ? "Listening..." : "Say the wake word"
            }
        }
        
        snips.snipsWatchHandler = { message in
            DispatchQueue.main.sync {
                NSLog("Snips log: \(message)")
            }
        }
    }
}
