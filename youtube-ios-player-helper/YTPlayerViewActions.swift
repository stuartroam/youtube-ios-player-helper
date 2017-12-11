// Swift + WKWebView re-write by Stuart Austin on 11/12/17.
//
// Copyright 2014 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License")
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import WebKit

extension YTPlayerView {

    // MARK: - Player methods

    /**
     * Starts or resumes playback on the loaded video. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#playVideo
     */
    func playVideo() {
        webView?.evaluateJavaScript("player.playVideo();", completionHandler: nil)
    }

    /**
     * Pauses playback on a playing video. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#pauseVideo
     */
    func pauseVideo() {
        self.delegate?.playerViewDidChange(toState: .pausedCode, sender: self)
        webView?.evaluateJavaScript("pauseVideo();", completionHandler: nil)
    }

    /**
     * Stops playback on a playing video. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#stopVideo
     */
    func stopVideo() {
        webView?.evaluateJavaScript("player.stopVideo();", completionHandler: nil)
    }

    /**
     * Seek to a given time on a playing video. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#seekTo
     *
     * @param seekToSeconds The time in seconds to seek to in the loaded video.
     * @param allowSeekAhead Whether to make a new request to the server if the time is
     *                       outside what is currently buffered. Recommended to set to YES.
     */
    func seek(toSeconds: TimeInterval, allowSeekAhead: Bool) {
        let command: String = "player.seekTo(\(toSeconds), \(allowSeekAhead));"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    // MARK: - Playing a video in a playlist

    /**
     * Loads and plays the next video in the playlist. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#nextVideo
     */
    func nextVideo() {
        webView?.evaluateJavaScript("player.nextVideo();", completionHandler: nil)
    }

    /**
     * Loads and plays the previous video in the playlist. Corresponds to this method from
     * the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#previousVideo
     */
    func previousVideo() {
        webView?.evaluateJavaScript("player.previousVideo();", completionHandler: nil)
    }

    /**
     * Loads and plays the video at the given 0-indexed position in the playlist.
     * Corresponds to this method from the JavaScript API:
     *   https://developers.google.com/youtube/iframe_api_reference#playVideoAt
     *
     * @param index The 0-indexed position of the video in the playlist to load and play.
     */
    func playVideo(at index: Int) {
        let command: String = "player.playVideoAt(\(NSNumber(value: index)));"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }
}
