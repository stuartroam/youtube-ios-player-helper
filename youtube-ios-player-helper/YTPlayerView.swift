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

// These are instances of String because we get them from parsing a URL. It would be silly to
// convert these into an integer just to have to convert the URL query string value into an integer
// as well for the sake of doing a value comparison. A full list of response error codes can be
// found here:
//      https://developers.google.com/youtube/iframe_api_reference

/** These enums represent the state of the current video in the player. */
enum YTPlayerState: String {
    case unstartedCode = "-1"
    case endedCode = "0"
    case playingCode = "1"
    case pausedCode = "2"
    case bufferingCode = "3"
    case queuedCode = "5"
    case unknownCode = "unknown"
}

/** These enums represent the resolution of the currently loaded video. */
enum YTPlaybackQuality: String {
    case smallQuality = "small"
    case mediumQuality = "medium"
    case largeQuality = "large"
    case hd720Quality = "hd720"
    case hd1080Quality = "hd1080"
    case highResQuality = "highres"
    case autoQuality = "auto"
    case defaultQuality = "default"
    case unknownQuality = "unknown"
}

/** These enums represent error codes thrown by the player. */
enum YTPlayerError: String, Error {
    case invalidParamErrorCode = "2"
    case html5ErrorCode = "5"
    case videoNotFoundErrorCode = "100"
    case notEmbeddableErrorCode = "101"
    case cannotFindVideoErrorCode = "105"
    case sameAsNotEmbeddableErrorCode = "150"
    case unknownCode = "unknown"
    case invalidReturnValue = "invalidReturnValue"
    case noWebView = "noWebView"
}

// Constants representing player callbacks.
enum YTPlayerCallback: String {
    case onReady = "onReady"
    case onStateChange = "onStateChange"
    case onPlaybackQualityChange = "onPlaybackQualityChange"
    case onError = "onError"
    case onPlayTime = "onPlayTime"

    //case onYouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case onYouTubeIframeAPIFailedToLoad = "onYouTubeIframeAPIFailedToLoad"
}

enum YTResult<T> {
    case success(T)
    case failure(Error)
}

let YTPlayerEmbedUrlRegexPattern = "^http(s)://(www.)youtube.com/embed/(.*)$"
let YTPlayerAdUrlRegexPattern = "^http(s)://pubads.g.doubleclick.net/pagead/conversion/"
let YTPlayerOAuthRegexPattern = "^http(s)://accounts.google.com/o/oauth2/(.*)$"
let YTPlayerStaticProxyRegexPattern = "^https://content.googleapis.com/static/proxy.html(.*)$"
let kYTPlayerSyndicationRegexPattern = "^https://tpc.googlesyndication.com/sodar/(.*).html$"

/**
 * A delegate for ViewControllers to respond to YouTube player events outside
 * of the view, such as changes to video playback state or playback errors.
 * The callback functions correlate to the events fired by the IFrame API.
 * For the full documentation, see the IFrame documentation here:
 *     https://developers.google.com/youtube/iframe_api_reference#Events
 */

protocol YTPlayerViewDelegate: class {

    /**
     * Invoked when the player view is ready to receive API calls.
     *
     * @param playerView The YTPlayerView instance that has become ready.
     */
    func playerViewDidBecomeReady(sender: YTPlayerView)

    /**
     * Callback invoked when player state has changed, e.g. stopped or started playback.
     *
     * @param playerView The YTPlayerView instance where playback state has changed.
     * @param state YTPlayerState designating the new playback state.
     */
    func playerViewDidChange(toState state: YTPlayerState, sender: YTPlayerView)

    /**
     * Callback invoked when playback quality has changed.
     *
     * @param playerView The YTPlayerView instance where playback quality has changed.
     * @param quality YTPlaybackQuality designating the new playback quality.
     */
    func playerViewDidChange(toQuality quality: YTPlaybackQuality, sender: YTPlayerView)

    /**
     * Callback invoked when an error has occured.
     *
     * @param playerView The YTPlayerView instance where the error has occurred.
     * @param error YTPlayerError containing the error state.
     */
    func playerView(receivedError: YTPlayerError, sender: YTPlayerView)

    /**
     * Callback invoked frequently when playBack is plaing.
     *
     * @param playerView The YTPlayerView instance where the error has occurred.
     * @param playTime float containing curretn playback time.
     */
    func playerView(didPlayTime playTime: Float, sender: YTPlayerView)
}

class YTPlayerView: UIView {

    /// A delegate to be notified on playback events
    weak var delegate: YTPlayerViewDelegate?

    var originURL: URL?

    weak var webView: WKWebView?

    /**
     * This method loads the player with the given video ID and player variables. Player variables
     * specify optional parameters for video playback. For instance, to play a YouTube
     * video inline, the following playerVars dictionary would be used:
     *
     * @code
     * @{ @"playsinline" : @1 };
     * @endcode
     *
     * Note that when the documentation specifies a valid value as a number (typically 0, 1 or 2),
     * both strings and integers are valid values. The full list of parameters is defined at:
     *   https://developers.google.com/youtube/player_parameters?playerVersion=HTML5.
     *
     * This method reloads the entire contents of the UIWebView and regenerates its HTML contents.
     * To change the currently loaded video without reloading the entire UIWebView, use the
     * YTPlayerView::cueVideoById:startSeconds:suggestedQuality: family of methods.
     *
     * @param videoId The YouTube video ID of the video to load in the player view.
     * @param playerVars An NSDictionary of player parameters.
     * @return YES if player has been configured correctly, NO otherwise.
     */
    func load(videoId: String, playerVars: [String: Any] = [:]) -> Bool {
        let playerParams: [String: Any] = [
            "videoId": videoId,
            "playerVars": playerVars
        ]
        return load(playerParams: playerParams)
    }

    /**
     * This method loads the player with the given playlist ID and player variables. Player variables
     * specify optional parameters for video playback. For instance, to play a YouTube
     * video inline, the following playerVars dictionary would be used:
     *
     * @code
     * @{ @"playsinline" : @1 };
     * @endcode
     *
     * Note that when the documentation specifies a valid value as a number (typically 0, 1 or 2),
     * both strings and integers are valid values. The full list of parameters is defined at:
     *   https://developers.google.com/youtube/player_parameters?playerVersion=HTML5.
     *
     * This method reloads the entire contents of the UIWebView and regenerates its HTML contents.
     * To change the currently loaded video without reloading the entire UIWebView, use the
     * YTPlayerView::cuePlaylistByPlaylistId:index:startSeconds:suggestedQuality:
     * family of methods.
     *
     * @param playlistId The YouTube playlist ID of the playlist to load in the player view.
     * @param playerVars An NSDictionary of player parameters.
     * @return YES if player has been configured correctly, NO otherwise.
     */
    func load(playlistId: String, playerVars: [String: Any] = [:]) -> Bool {
        var modifiedPlayerVars: [String: Any] = playerVars
        modifiedPlayerVars["playlist"] = "listType"
        modifiedPlayerVars["list"] = playlistId

        let playerParams: [String: Any] = [
            "playerVars": modifiedPlayerVars
        ]

        return load(playerParams: playerParams)
    }



    // MARK: - Cueing methods

    /**
     * Cues a given video by its video ID for playback starting at the given time and with the
     * suggested quality. Cueing loads a video, but does not start video playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cueVideoById
     *
     * @param videoId A video ID to cue.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(videoId: String, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.cueVideoById('\(videoId)', \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Cues a given video by its video ID for playback starting and ending at the given times
     * with the suggested quality. Cueing loads a video, but does not start video playback. This
     * method corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cueVideoById
     *
     * @param videoId A video ID to cue.
     * @param startSeconds Time in seconds to start the video when playVideo() is called.
     * @param endSeconds Time in seconds to end the video after it begins playing.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(videoId: String, startSeconds: TimeInterval, endSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let endSecondsValue: NSNumber = NSNumber(value: endSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command = "player.cueVideoById({'videoId': '\(videoId)', 'startSeconds': \(startSecondsValue), 'endSeconds': \(endSecondsValue), 'suggestedQuality': '\(qualityValue)'});"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Loads a given video by its video ID for playback starting at the given time and with the
     * suggested quality. Loading a video both loads it and begins playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadVideoById
     *
     * @param videoId A video ID to load and begin playing.
     * @param startSeconds Time in seconds to start the video when it has loaded.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(videoId: String, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value :startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.loadVideoById('\(videoId)', \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Loads a given video by its video ID for playback starting and ending at the given times
     * with the suggested quality. Loading a video both loads it and begins playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadVideoById
     *
     * @param videoId A video ID to load and begin playing.
     * @param startSeconds Time in seconds to start the video when it has loaded.
     * @param endSeconds Time in seconds to end the video after it begins playing.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(videoId: String, startSeconds: TimeInterval, endSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let endSecondsValue: NSNumber = NSNumber(value: endSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.loadVideoById({'videoId': '\(videoId)', 'startSeconds': \(startSecondsValue), 'endSeconds': \(endSecondsValue), 'suggestedQuality': '\(qualityValue)'});"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Cues a given video by its URL on YouTube.com for playback starting at the given time
     * and with the suggested quality. Cueing loads a video, but does not start video playback.
     * This method corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cueVideoByUrl
     *
     * @param videoURL URL of a YouTube video to cue for playback.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(videoURL: String, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.cueVideoByUrl('\(videoURL)', \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Cues a given video by its URL on YouTube.com for playback starting at the given time
     * and with the suggested quality. Cueing loads a video, but does not start video playback.
     * This method corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cueVideoByUrl
     *
     * @param videoURL URL of a YouTube video to cue for playback.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param endSeconds Time in seconds to end the video after it begins playing.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(videoURL: String, startSeconds: TimeInterval, endSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let endSecondsValue: NSNumber = NSNumber(value: endSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.cueVideoByUrl('\(videoURL)', \(startSecondsValue), \(endSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Loads a given video by its video ID for playback starting at the given time
     * with the suggested quality. Loading a video both loads it and begins playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadVideoByUrl
     *
     * @param videoURL URL of a YouTube video to load and play.
     * @param startSeconds Time in seconds to start the video when it has loaded.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(videoURL: String, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.loadVideoByUrl('\(videoURL)', \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Loads a given video by its video ID for playback starting and ending at the given times
     * with the suggested quality. Loading a video both loads it and begins playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadVideoByUrl
     *
     * @param videoURL URL of a YouTube video to load and play.
     * @param startSeconds Time in seconds to start the video when it has loaded.
     * @param endSeconds Time in seconds to end the video after it begins playing.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(videoURL: String, startSeconds: TimeInterval, endSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let endSecondsValue: NSNumber = NSNumber(value: endSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.loadVideoByUrl('\(videoURL)', \(startSecondsValue), \(endSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    // MARK: - Cueing methods for lists

    /**
     * Cues a given playlist with the given ID. The |index| parameter specifies the 0-indexed
     * position of the first video to play, starting at the given time and with the
     * suggested quality. Cueing loads a playlist, but does not start video playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cuePlaylist
     *
     * @param playlistId Playlist ID of a YouTube playlist to cue.
     * @param index A 0-indexed position specifying the first video to play.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(playlistId: String, index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let playlistIdString: String = "'\(playlistId)'"
        cue(playlist: playlistIdString, index: index, startSeconds: startSeconds, suggestedQuality: suggestedQuality)
    }

    /**
     * Cues a playlist of videos with the given video IDs. The |index| parameter specifies the
     * 0-indexed position of the first video to play, starting at the given time and with the
     * suggested quality. Cueing loads a playlist, but does not start video playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#cuePlaylist
     *
     * @param videoIds An NSArray of video IDs to compose the playlist of.
     * @param index A 0-indexed position specifying the first video to play.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func cue(videoIds: [String], index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        cue(playlist: self.string(from: videoIds), index: index, startSeconds: startSeconds, suggestedQuality: suggestedQuality)
    }

    /**
     * Loads a given playlist with the given ID. The |index| parameter specifies the 0-indexed
     * position of the first video to play, starting at the given time and with the
     * suggested quality. Loading a playlist starts video playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadPlaylist
     *
     * @param playlistId Playlist ID of a YouTube playlist to cue.
     * @param index A 0-indexed position specifying the first video to play.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(playlistId: String, index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let playlistIdString: String = "'\(playlistId)'"
        load(playlist: playlistIdString, index: index, startSeconds: startSeconds, suggestedQuality: suggestedQuality)
    }

    /**
     * Loads a playlist of videos with the given video IDs. The |index| parameter specifies the
     * 0-indexed position of the first video to play, starting at the given time and with the
     * suggested quality. Loading a playlist starts video playback. This method
     * corresponds with its JavaScript API equivalent as documented here:
     *    https://developers.google.com/youtube/iframe_api_reference#loadPlaylist
     *
     * @param videoIds An NSArray of video IDs to compose the playlist of.
     * @param index A 0-indexed position specifying the first video to play.
     * @param startSeconds Time in seconds to start the video when YTPlayerView::playVideo is called.
     * @param suggestedQuality YTPlaybackQuality value suggesting a playback quality.
     */
    func load(videoIds: [String], index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        load(playlist: self.string(from: videoIds), index: index, startSeconds: startSeconds, suggestedQuality: suggestedQuality)
    }




    //    - (BOOL)webView:(UIWebView *)webView
    //shouldStartLoadWithRequest:(NSURLRequest *)request
    //navigationType:(UIWebViewNavigationType)navigationType {
    //    if ([request.URL.host isEqual: self.originURL.host]) {
    //        return YES
    //    } else if ([request.URL.scheme isEqual:@"ytplayer"]) {
    //        [self notifyDelegateOfYouTubeCallbackUrl:request.URL]
    //        return NO
    //    } else if ([request.URL.scheme isEqual: @"http"] || [request.URL.scheme isEqual:@"https"]) {
    //        return [self handleHttpNavigationToUrl:request.URL]
    //    }
    //    return YES
    //    }
    //
    //    - (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    //        }

    // MARK: - Private methods

    /**
     * Private method to handle "navigation" to a callback URL of the format
     * ytplayer://action?data=someData
     * This is how the UIWebView communicates with the containing Objective-C code.
     * Side effects of this method are that it calls methods on this class's delegate.
     *
     * @param url A URL of the format ytplayer://action?data=value.
     */
    func notifyDelegateOfYouTubeCallbackUrl(url: URL) {
        guard
            let action: String = url.host,
            let callback: YTPlayerCallback = YTPlayerCallback(rawValue: action)
            else {
                return
        }

        // We know the query can only be of the format ytplayer://action?data=SOMEVALUE,
        // so we parse out the value.
        let query: String? = url.query
        let data: String?

        let queryComponents: [String] = query?.components(separatedBy: "=") ?? []
        if queryComponents.count >= 2 {
            data = queryComponents[1]
        } else {
            data = nil
        }

        switch callback {
        case .onReady:
            delegate?.playerViewDidBecomeReady(sender: self)
        case .onStateChange:
            let state: YTPlayerState = data.flatMap { YTPlayerState(rawValue: $0) } ?? .unknownCode
            delegate?.playerViewDidChange(toState: state, sender: self)
        case .onPlaybackQualityChange:
            let quality: YTPlaybackQuality = data.flatMap { YTPlaybackQuality(rawValue: $0) } ?? .unknownQuality
            delegate?.playerViewDidChange(toQuality: quality, sender: self)
        case .onError:
            let error: YTPlayerError = data.flatMap { YTPlayerError(rawValue: $0) } ?? .unknownCode
            delegate?.playerView(receivedError: error, sender: self)
        case .onPlayTime:
            if let time: Float = data.flatMap ({ Float($0) }) {
                delegate?.playerView(didPlayTime: time, sender: self)
            }
        case .onYouTubeIframeAPIFailedToLoad:
            break
        }
    }

    func handleHttpNavigation(to url: URL) -> Bool {
        // Usually this means the user has clicked on the YouTube logo or an error message in the
        // player. Most URLs should open in the browser. The only http(s) URL that should open in this
        // UIWebView is the URL for the embed, which is of the format:
        //     http(s)://www.youtube.com/embed/[VIDEO ID]?[PARAMETERS]

        let absoluteURL: String = url.absoluteString
        let absoluteURLRange: NSRange = NSRange(location: 0, length: (absoluteURL as NSString).length)

        let ytMatch: NSTextCheckingResult?
        if let ytRegex = try? NSRegularExpression(pattern: YTPlayerEmbedUrlRegexPattern, options: [.caseInsensitive]) {
            ytMatch = ytRegex.firstMatch(in: absoluteURL, options: [], range: absoluteURLRange)
        } else {
            ytMatch = nil
        }

        let adMatch: NSTextCheckingResult?
        if let adRegex = try? NSRegularExpression(pattern: YTPlayerAdUrlRegexPattern, options: [.caseInsensitive]) {
            adMatch = adRegex.firstMatch(in: absoluteURL, options: [], range: absoluteURLRange)
        } else {
            adMatch = nil
        }

        let syndicationMatch: NSTextCheckingResult?
        if let syndicationRegex = try? NSRegularExpression(pattern: kYTPlayerSyndicationRegexPattern, options: [.caseInsensitive]) {
            syndicationMatch = syndicationRegex.firstMatch(in: absoluteURL, options: [], range: absoluteURLRange)
        } else {
            syndicationMatch = nil
        }

        let oauthMatch: NSTextCheckingResult?
        if let oauthRegex = try? NSRegularExpression(pattern: YTPlayerOAuthRegexPattern, options: [.caseInsensitive]) {
            oauthMatch = oauthRegex.firstMatch(in: absoluteURL, options: [], range: absoluteURLRange)
        } else {
            oauthMatch = nil
        }

        let staticProxyMatch: NSTextCheckingResult?
        if let staticProxyRegex = try? NSRegularExpression(pattern: YTPlayerStaticProxyRegexPattern, options: [.caseInsensitive]) {
            staticProxyMatch = staticProxyRegex.firstMatch(in: absoluteURL, options: [], range: absoluteURLRange)
        } else {
            staticProxyMatch = nil
        }

        if ytMatch != nil || adMatch != nil || oauthMatch != nil || staticProxyMatch != nil || syndicationMatch != nil {
            return true
        } else {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url)
            } else {
                UIApplication.shared.openURL(url)
            }
            return false
        }
    }


    /**
     * This method loads an iframe player with the given player parameters. Usually you may want to use
     * -loadWithVideoId:playerVars: or -loadWithPlaylistId:playerVars: instead of this method does not handle
     * video_id or playlist_id at all. The full list of parameters is defined at:
     *   https://developers.google.com/youtube/player_parameters?playerVersion=HTML5.
     *
     * @param additionalPlayerParams An NSDictionary of parameters in addition to required parameters
     *                               to instantiate the HTML5 player with. This differs depending on
     *                               whether a single video or playlist is being loaded.
     * @return YES if successful, NO if not.
     */
    func load(playerParams: [String: Any]) -> Bool {
        let playerCallbacks: [String: Any] = [
            "onReady" : "onReady",
            "onStateChange" : "onStateChange",
            "onPlaybackQualityChange" : "onPlaybackQualityChange",
            "onError" : "onPlayerError"
        ]

        var mutablePlayerParams: [String: Any] = playerParams
        mutablePlayerParams["events"] = playerCallbacks

        if mutablePlayerParams["height"] == nil {
            mutablePlayerParams["height"] = "100%"
        }
        if mutablePlayerParams["width"] == nil {
            mutablePlayerParams["width"] = "100%"
        }

        if let playerVars: [String: Any] = mutablePlayerParams["playerVars"] as? [String: Any] {
            if let origin = playerVars["origin"] as? URL {
                self.originURL = origin
            } else {
                self.originURL = URL(string: "about:blank")!
            }
        } else {
            // This must not be empty so we can render a '{}' in the output JSON
            let playerVars: [String: Any] = [:]
            mutablePlayerParams["playerVars"] = playerVars
        }

        self.webView?.navigationDelegate = nil
        self.webView?.removeFromSuperview()
        let webView: WKWebView = createNewWebView()
        self.webView = webView
        addSubview(webView)

        guard
            let iframePlayerURL: URL = Bundle.main.url(forResource: "YTPlayerView-iframe-player", withExtension: "html"),
            let fileHandle: FileHandle = try? FileHandle(forReadingFrom: iframePlayerURL),
            let embedHTMLTemplate: String = String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8)
            else {
                assert(false, "Unable to locate or read YTPlayerView-iframe-player.html")
                return false
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: playerParams, options: [.prettyPrinted])
            let playerVarsJsonString: String =  String(data: jsonData, encoding: .utf8) ?? ""

            let embedHTML: String = String(format: embedHTMLTemplate, playerVarsJsonString)

            webView.loadHTMLString(embedHTML, baseURL: self.originURL)

        } catch let error {
            print("Attempted configuration of player with invalid playerVars: \(playerParams) \tError: \(error)")
            return false
        }

        return true
    }

    /**
     * Private method for cueing both cases of playlist ID and array of video IDs. Cueing
     * a playlist does not start playback.
     *
     * @param cueingString A JavaScript string representing an array, playlist ID or list of
     *                     video IDs to play with the playlist player.
     * @param index 0-index position of video to start playback on.
     * @param startSeconds Seconds after start of video to begin playback.
     * @param suggestedQuality Suggested YTPlaybackQuality to play the videos.
     * @return The result of cueing the playlist.
     */
    private func cue(playlist cueingString: String, index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let indexValue: NSNumber = NSNumber(value: index)
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command = "player.cuePlaylist(\(cueingString), \(indexValue), \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Private method for loading both cases of playlist ID and array of video IDs. Loading
     * a playlist automatically starts playback.
     *
     * @param cueingString A JavaScript string representing an array, playlist ID or list of
     *                     video IDs to play with the playlist player.
     * @param index 0-index position of video to start playback on.
     * @param startSeconds Seconds after start of video to begin playback.
     * @param suggestedQuality Suggested YTPlaybackQuality to play the videos.
     * @return The result of cueing the playlist.
     */
    private func load(playlist cueingString: String, index: Int, startSeconds: TimeInterval, suggestedQuality: YTPlaybackQuality) {
        let indexValue: NSNumber = NSNumber(value: index)
        let startSecondsValue: NSNumber = NSNumber(value: startSeconds)
        let qualityValue: String = suggestedQuality.rawValue
        let command: String = "player.loadPlaylist(\(cueingString), \(indexValue), \(startSecondsValue), '\(qualityValue)');"
        webView?.evaluateJavaScript(command, completionHandler: nil)
    }

    /**
     * Private helper method for converting an NSArray of video IDs into its JavaScript equivalent.
     *
     * @param videoIds An array of video ID strings to convert into JavaScript format.
     * @return A JavaScript array in String format containing video IDs.
     */
    private func string(from videoIdArray: [String]) -> String {
        let formattedVideoIds: [String] = videoIdArray.map { "'\($0)'" }
        return "[\(formattedVideoIds.joined(separator: ", "))]"
    }

    private func createNewWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.backgroundColor = UIColor.clear
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        webView.navigationDelegate = self

        return webView
    }
}

extension YTPlayerView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        guard url.host != originURL?.host else {
            decisionHandler(.allow)
            return
        }

        guard url.scheme != "ytplayer" else {
            notifyDelegateOfYouTubeCallbackUrl(url: url)
            decisionHandler(.cancel)
            return
        }

        if (url.scheme == "http" || url.scheme == "https") && !handleHttpNavigation(to: url) {
            decisionHandler(.cancel)
            return
        } else {
            decisionHandler(.allow)
            return
        }
    }
}
