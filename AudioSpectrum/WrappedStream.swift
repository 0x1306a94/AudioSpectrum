//
//  WrappedStream.swift
//  AudioSpectrum
//
//  Created by king on 2020/5/30.
//  Copyright © 2020 taihe. All rights reserved.
//

import Foundation
import AudioStreamer
import AVFoundation

public class WrappedStream: NSObject {

    let stream: Streamer = Streamer()
    let url: URL
    @objc
    public init(url: URL, callBack: @escaping AVAudioNodeTapBlock) {
        self.url = url
        stream.url = url
        stream.engine.mainMixerNode.removeTap(onBus: 0)
        stream.engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil, block: callBack)
    }
    
    @objc
    public func play() {
        stream.play()
    }
}
