import AVFoundation
import Foundation
import Siesta
import SwiftUI

extension PlayerModel {
    var isLoadingAvailableStreams: Bool {
        streamSelection.isNil || availableStreams.isEmpty
    }

    var isLoadingStream: Bool {
        !stream.isNil && stream != streamSelection
    }

    var availableStreamsSorted: [Stream] {
        availableStreams.sorted(by: streamsSorter)
    }

    func loadAvailableStreams(_ video: Video, onCompletion: @escaping (ResponseInfo) -> Void = { _ in }) {
        captions = nil
        availableStreams = []

        guard let playerInstance else { return }

        guard let api = playerAPI(video) else { return }
        logger.info("loading streams from \(playerInstance.description)")
        fetchStreams(api.video(video.videoID), instance: playerInstance, video: video, onCompletion: onCompletion)
    }

    private func fetchStreams(
        _ resource: Resource,
        instance: Instance,
        video: Video,
        onCompletion: @escaping (ResponseInfo) -> Void = { _ in }
    ) {
        resource
            .load()
            .onSuccess { response in
                if let video: Video = response.typedContent() {
                    VideosCacheModel.shared.storeVideo(video)
                    guard video.videoID == self.currentVideo?.videoID else {
                        self.logger.info("ignoring loaded streams from \(instance.description) as current video has changed")
                        return
                    }
                    self.streamsWithInstance(instance: instance, streams: video.streams) { processedStreams in
                        self.availableStreams = processedStreams
                    }
                } else {
                    self.logger.critical("no streams available from \(instance.description)")
                }
            }
            .onCompletion(onCompletion)
            .onFailure { [weak self] responseError in
                self?.navigation.presentAlert(title: "Could not load streams", message: responseError.userMessage)
                self?.videoBeingOpened = nil
            }
    }

    func streamsWithInstance(instance _: Instance, streams: [Stream], completion: @escaping ([Stream]) -> Void) {
        // Queue for stream processing
        let streamProcessingQueue = DispatchQueue(label: "stream.yattee.streamProcessing.Queue", qos: .userInitiated)
        // Queue for accessing the processedStreams array
        let processedStreamsQueue = DispatchQueue(label: "stream.yattee.processedStreams.Queue")
        // DispatchGroup for managing multiple tasks
        let streamProcessingGroup = DispatchGroup()

        var processedStreams = [Stream]()

        for stream in streams {
            streamProcessingQueue.async(group: streamProcessingGroup) {
                let forbiddenAssetTestGroup = DispatchGroup()
                var hasForbiddenAsset = false

                let (nonHLSAssets, hlsURLs) = self.getAssets(from: [stream])

                if let randomStream = nonHLSAssets.randomElement() {
                    let instance = randomStream.0
                    let asset = randomStream.1
                    let url = randomStream.2
                    let requestRange = randomStream.3

                    // swiftlint:disable:next shorthand_optional_binding
                    if let asset = asset, let instance = instance, !instance.proxiesVideos {
                        if instance.app == .invidious {
                            self.testAsset(url: url, range: requestRange, isHLS: false, forbiddenAssetTestGroup: forbiddenAssetTestGroup) { isForbidden in
                                hasForbiddenAsset = isForbidden
                            }
                        } else if instance.app == .piped {
                            self.testPipedAssets(asset: asset, requestRange: requestRange, isHLS: false, forbiddenAssetTestGroup: forbiddenAssetTestGroup) { isForbidden in
                                hasForbiddenAsset = isForbidden
                            }
                        }
                    }
                } else if let randomHLS = hlsURLs.randomElement() {
                    let instance = randomHLS.0
                    let asset = AVURLAsset(url: randomHLS.1)

                    if instance?.app == .piped {
                        self.testPipedAssets(asset: asset, requestRange: nil, isHLS: true, forbiddenAssetTestGroup: forbiddenAssetTestGroup) { isForbidden in
                            hasForbiddenAsset = isForbidden
                        }
                    }
                }

                forbiddenAssetTestGroup.wait()

                // Post-processing code
                if let instance = stream.instance {
                    if instance.app == .invidious {
                        if hasForbiddenAsset || instance.proxiesVideos {
                            if let audio = stream.audioAsset {
                                stream.audioAsset = InvidiousAPI.proxiedAsset(instance: instance, asset: audio)
                            }
                            if let video = stream.videoAsset {
                                stream.videoAsset = InvidiousAPI.proxiedAsset(instance: instance, asset: video)
                            }
                        }
                    } else if instance.app == .piped, !instance.proxiesVideos, !hasForbiddenAsset {
                        if let hlsURL = stream.hlsURL {
                            PipedAPI.nonProxiedAsset(url: hlsURL) { possibleNonProxiedURL in
                                if let nonProxiedURL = possibleNonProxiedURL {
                                    stream.hlsURL = nonProxiedURL.url
                                }
                            }
                        } else {
                            if let audio = stream.audioAsset {
                                PipedAPI.nonProxiedAsset(asset: audio) { nonProxiedAudioAsset in
                                    stream.audioAsset = nonProxiedAudioAsset
                                }
                            }
                            if let video = stream.videoAsset {
                                PipedAPI.nonProxiedAsset(asset: video) { nonProxiedVideoAsset in
                                    stream.videoAsset = nonProxiedVideoAsset
                                }
                            }
                        }
                    }
                }

                // Append to processedStreams within the processedStreamsQueue
                processedStreamsQueue.sync {
                    processedStreams.append(stream)
                }
            }
        }

        streamProcessingGroup.notify(queue: .main) {
            // Access and pass processedStreams within the processedStreamsQueue block
            processedStreamsQueue.sync {
                completion(processedStreams)
            }
        }
    }

    private func getAssets(from streams: [Stream]) -> (nonHLSAssets: [(Instance?, AVURLAsset?, URL, String?)], hlsURLs: [(Instance?, URL)]) {
        var nonHLSAssets = [(Instance?, AVURLAsset?, URL, String?)]()
        var hlsURLs = [(Instance?, URL)]()

        for stream in streams {
            if stream.isHLS {
                if let url = stream.hlsURL?.url {
                    hlsURLs.append((stream.instance, url))
                }
            } else {
                if let asset = stream.audioAsset {
                    nonHLSAssets.append((stream.instance, asset, asset.url, stream.requestRange))
                }
                if let asset = stream.videoAsset {
                    nonHLSAssets.append((stream.instance, asset, asset.url, stream.requestRange))
                }
            }
        }

        return (nonHLSAssets, hlsURLs)
    }

    private func testAsset(url: URL, range: String?, isHLS: Bool, forbiddenAssetTestGroup: DispatchGroup, completion: @escaping (Bool) -> Void) {
        // In case the range is nil, generate a random one.
        let randomEnd = Int.random(in: 200 ... 800)
        let requestRange = range ?? "0-\(randomEnd)"

        forbiddenAssetTestGroup.enter()
        URLTester.testURLResponse(url: url, range: requestRange, isHLS: isHLS) { statusCode in
            completion(statusCode == HTTPStatus.Forbidden)
            forbiddenAssetTestGroup.leave()
        }
    }

    private func testPipedAssets(asset: AVURLAsset, requestRange: String?, isHLS: Bool, forbiddenAssetTestGroup: DispatchGroup, completion: @escaping (Bool) -> Void) {
        PipedAPI.nonProxiedAsset(asset: asset) { possibleNonProxiedAsset in
            if let nonProxiedAsset = possibleNonProxiedAsset {
                self.testAsset(url: nonProxiedAsset.url, range: requestRange, isHLS: isHLS, forbiddenAssetTestGroup: forbiddenAssetTestGroup, completion: completion)
            } else {
                completion(false)
            }
        }
    }

    func streamsSorter(lhs: Stream, rhs: Stream) -> Bool {
        // Use optional chaining to simplify nil handling
        guard let lhsRes = lhs.resolution?.height, let rhsRes = rhs.resolution?.height else {
            return lhs.kind < rhs.kind
        }

        // Compare either kind or resolution based on conditions
        return lhs.kind == rhs.kind ? (lhsRes > rhsRes) : (lhs.kind < rhs.kind)
    }
}
