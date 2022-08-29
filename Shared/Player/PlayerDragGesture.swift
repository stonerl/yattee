import Defaults
import SwiftUI

extension VideoPlayerView {
    var playerDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
        #if os(iOS)
            .updating($dragGestureOffset) { value, state, _ in
                guard isVerticalDrag else { return }
                var translation = value.translation
                translation.height = max(0, translation.height)
                state = translation
            }
        #endif
            .updating($dragGestureState) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard player.presentingPlayer,
                      !playerControls.presentingControlsOverlay else { return }

                if playerControls.presentingControls, !player.musicMode {
                    playerControls.presentingControls = false
                }

                if player.musicMode {
                    player.backend.stopControlsUpdates()
                }

                let verticalDrag = value.translation.height
                let horizontalDrag = value.translation.width

                #if os(iOS)
                    if viewDragOffset > 0, !isVerticalDrag {
                        isVerticalDrag = true
                    }
                #endif

                if !isVerticalDrag, horizontalPlayerGestureEnabled, abs(horizontalDrag) > seekGestureSensitivity, !isHorizontalDrag {
                    isHorizontalDrag = true
                    player.seek.onSeekGestureStart()
                    viewDragOffset = 0
                }

                if horizontalPlayerGestureEnabled, isHorizontalDrag {
                    player.seek.updateCurrentTime {
                        let time = player.backend.playerItemDuration?.seconds ?? 0
                        if player.seek.gestureStart.isNil {
                            player.seek.gestureStart = time
                        }
                        let timeSeek = (time / player.playerSize.width) * horizontalDrag * seekGestureSpeed

                        player.seek.gestureSeek = timeSeek
                    }
                    return
                }

                guard verticalDrag > 0 else { return }
                viewDragOffset = verticalDrag

                if verticalDrag > 60,
                   player.playingFullScreen
                {
                    player.exitFullScreen(showControls: false)
                    #if os(iOS)
                        if Defaults[.rotateToPortraitOnExitFullScreen] {
                            Orientation.lockOrientation(.allButUpsideDown, andRotateTo: .portrait)
                        }
                    #endif
                }
            }
            .onEnded { _ in
                onPlayerDragGestureEnded()
            }
    }

    func onPlayerDragGestureEnded() {
        if horizontalPlayerGestureEnabled, isHorizontalDrag {
            isHorizontalDrag = false
            player.seek.onSeekGestureEnd()
        }

        isVerticalDrag = false

        guard player.presentingPlayer,
              !playerControls.presentingControlsOverlay else { return }

        if viewDragOffset > 100 {
            withAnimation(Constants.overlayAnimation) {
                viewDragOffset = Self.hiddenOffset
            }
            player.backend.setNeedsDrawing(false)
        } else {
            withAnimation(Constants.overlayAnimation) {
                viewDragOffset = 0
            }
            player.backend.setNeedsDrawing(true)
            player.show()

            if player.musicMode {
                player.backend.startControlsUpdates()
            }
        }
    }
}
