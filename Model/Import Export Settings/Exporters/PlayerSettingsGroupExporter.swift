import Defaults
import SwiftyJSON

final class PlayerSettingsGroupExporter: SettingsGroupExporter {
    override var globalJSON: JSON {
        [
            "playerInstanceID": Defaults[.playerInstanceID] ?? "",
            "pauseOnHidingPlayer": Defaults[.pauseOnHidingPlayer],
            "closeVideoOnEOF": Defaults[.closeVideoOnEOF],
            "expandVideoDescription": Defaults[.expandVideoDescription],
            "collapsedLinesDescription": Defaults[.collapsedLinesDescription],
            "showChapters": Defaults[.showChapters],
            "expandChapters": Defaults[.expandChapters],
            "showRelated": Defaults[.showRelated],
            "showInspector": Defaults[.showInspector].rawValue,
            "playerSidebar": Defaults[.playerSidebar].rawValue,
            "showKeywords": Defaults[.showKeywords],
            "enableReturnYouTubeDislike": Defaults[.enableReturnYouTubeDislike],
            "closePiPOnNavigation": Defaults[.closePiPOnNavigation],
            "closePiPOnOpeningPlayer": Defaults[.closePiPOnOpeningPlayer],
            "closePlayerOnOpeningPiP": Defaults[.closePlayerOnOpeningPiP]
        ]
    }

    override var platformJSON: JSON {
        var export = JSON()

        #if !os(macOS)
            export["pauseOnEnteringBackground"].bool = Defaults[.pauseOnEnteringBackground]
        #endif

        #if !os(tvOS)
            export["showScrollToTopInComments"].bool = Defaults[.showScrollToTopInComments]
        #endif

        #if os(iOS)
            export["honorSystemOrientationLock"].bool = Defaults[.honorSystemOrientationLock]
            export["enterFullscreenInLandscape"].bool = Defaults[.enterFullscreenInLandscape]
            export["rotateToLandscapeOnEnterFullScreen"].string = Defaults[.rotateToLandscapeOnEnterFullScreen].rawValue
        #endif

        return export
    }
}
