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
    // MARK: - Setting the playback rate

    /**
     * Gets the playback rate. The default value is 1.0, which represents a video
     * playing at normal speed. Other values may include 0.25 or 0.5 for slower
     * speeds, and 1.5 or 2.0 for faster speeds. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getPlaybackRate
     *
     * @return An integer value between 0 and 100 representing the current volume.
     */
    func playbackRate(callback: @escaping (YTResult<Float>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getPlaybackRate();") { (result, error) in
            if let result = result as? Float {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Sets the playback rate. The default value is 1.0, which represents a video
     * playing at normal speed. Other values may include 0.25 or 0.5 for slower
     * speeds, and 1.5 or 2.0 for faster speeds. To fetch a list of valid values for
     * this method, call YTPlayerView::getAvailablePlaybackRates. This method does not
     * guarantee that the playback rate will change.
     * This method corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#setPlaybackRate
     *
     * @param suggestedRate A playback rate to suggest for the player.
     */
    func setPlaybackRate(suggestedRate: Float) {
        let command: String = "player.setPlaybackRate(\(suggestedRate));"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    func availablePlaybackRates(callback: @escaping (YTResult<[Float]>) -> Void)  {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getAvailablePlaybackRates();") { (result, error) in
            if let result = result as? [Float] {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    // MARK: - Setting playback behavior for playlists

    /**
     * Sets whether the player should loop back to the first video in the playlist
     * after it has finished playing the last video. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#loopPlaylist
     *
     * @param loop A boolean representing whether the player should loop.
     */
    func setLoop(_ loop: Bool) {
        let loopPlayListValue: String = String(loop)
        let command: String = "player.setLoop(\(loopPlayListValue));"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Sets whether the player should shuffle through the playlist. This method
     * corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#shufflePlaylist
     *
     * @param shuffle A boolean representing whether the player should
     *                shuffle through the playlist.
     */
    func setShuffle(_ shuffle: Bool) {
        let shufflePlayListValue: String = String(shuffle)
        let command: String = "player.setShuffle(\(shufflePlayListValue));"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    // MARK: - Playback status

    /**
     * Returns a number between 0 and 1 that specifies the percentage of the video
     * that the player shows as buffered. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getVideoLoadedFraction
     *
     * @return A float value between 0 and 1 representing the percentage of the video
     *         already loaded.
     */
    func videoLoadedFraction(callback: @escaping (YTResult<Float>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getVideoLoadedFraction();") { (result, error) in
            if let result = result as? Float {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Returns the state of the player. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getPlayerState
     *
     * @return |YTPlayerState| representing the state of the player.
     */
    func playerState(callback: @escaping (YTResult<YTPlayerState>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getPlayerState();") { (result, error) in
            if let result = result as? String {
                callback(.success(YTPlayerState(rawValue: result) ?? .unknownCode))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Returns the elapsed time in seconds since the video started playing. This
     * method corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getCurrentTime
     *
     * @return Time in seconds since the video started playing.
     */
    func currentTime(callback: @escaping (YTResult<Float>) -> Void)  {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getCurrentTime();") { (result, error) in
            if let result = result as? Float {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    // MARK: - Playback quality

    // Playback quality. These methods correspond to the JavaScript
    // methods defined here:
    //   https://developers.google.com/youtube/js_api_reference#Playback_quality

    /**
     * Returns the playback quality. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getPlaybackQuality
     *
     * @return YTPlaybackQuality representing the current playback quality.
     */
    func playbackQuality(callback: @escaping (YTResult<YTPlaybackQuality>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getPlaybackQuality();") { (result, error) in
            if let result = result as? String {
                callback(.success(YTPlaybackQuality(rawValue: result) ?? YTPlaybackQuality.unknownQuality))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Suggests playback quality for the video. It is recommended to leave this setting to
     * |default|. This method corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#setPlaybackQuality
     *
     * @param quality YTPlaybackQuality value to suggest for the player.
     */
    func setPlaybackQuality(suggestedQuality: YTPlaybackQuality) {
        let qualityValue = suggestedQuality.rawValue
        let command: String = "player.setPlaybackQuality('\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Gets a list of the valid playback quality values, useful in conjunction with
     * YTPlayerView::setPlaybackQuality. This method corresponds to the
     * JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getAvailableQualityLevels
     *
     * @return An NSArray containing available playback quality levels. Returns nil if there is an error.
     */
    func availableQualityLevels(callback: @escaping (YTResult<[YTPlaybackQuality]>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getAvailableQualityLevels().toString();") { (result, error) in
            if let combinedResult = result as? String {
                let resultStrings: [String] = combinedResult.components(separatedBy: ",")
                callback(.success(resultStrings.flatMap { YTPlaybackQuality(rawValue: $0) }))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    // MARK: - Video information methods

    /**
     * Returns the duration in seconds since the video of the video. This
     * method corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getDuration
     *
     * @return Length of the video in seconds.
     */
    func duration(callback: @escaping (YTResult<TimeInterval>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getDuration();") { (result, error) in
            if let result = result as? TimeInterval {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Returns the YouTube.com URL for the video. This method corresponds
     * to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getVideoUrl
     *
     * @return The YouTube.com URL for the video. Returns nil if no video is loaded yet.
     */
    func videoUrl(callback: @escaping (YTResult<URL>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getVideoUrl();") { (result, error) in
            if let result = (result as? String).flatMap ({ URL(string: $0) }) {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Returns the embed code for the current video. This method corresponds
     * to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getVideoEmbedCode
     *
     * @return The embed code for the current video. Returns nil if no video is loaded yet.
     */
    func videoEmbedCode(callback: @escaping (YTResult<String>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getVideoEmbedCode();") { (result, error) in
            if let result = result as? String {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }


    // MARK: - Playlist methods

    /**
     * Returns an ordered array of video IDs in the playlist. This method corresponds
     * to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getPlaylist
     *
     * @return An NSArray containing all the video IDs in the current playlist. |nil| on error.
     */
    func playlist(callback: @escaping (YTResult<[String]>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getPlaylist();") { (result, error) in
            if let result = result as? [String] {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }

    /**
     * Returns the 0-based index of the currently playing item in the playlist.
     * This method corresponds to the JavaScript API defined here:
     *   https://developers.google.com/youtube/iframe_api_reference#getPlaylistIndex
     *
     * @return The 0-based index of the currently playing item in the playlist.
     */
    func playlistIndex(callback: @escaping (YTResult<Int>) -> Void) {
        guard let webView = self.webView else {
            callback(.failure(YTPlayerError.noWebView))
            return
        }

        webView.evaluateJavaScript("player.getPlaylistIndex();") { (result, error) in
            if let result = result as? Int {
                callback(.success(result))
            } else if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(YTPlayerError.invalidReturnValue))
            }
        }
    }
}
