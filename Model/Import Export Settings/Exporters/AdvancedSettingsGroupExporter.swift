import Defaults
import SwiftyJSON

final class AdvancedSettingsGroupExporter: SettingsGroupExporter {
    override var globalJSON: JSON {
        [
            "showPlayNowInBackendContextMenu": Defaults[.showPlayNowInBackendContextMenu],
            "showMPVPlaybackStats": Defaults[.showMPVPlaybackStats],
            "mpvEnableLogging": Defaults[.mpvEnableLogging],
            "mpvCacheSecs": Defaults[.mpvCacheSecs],
            "mpvCachePauseWait": Defaults[.mpvCachePauseWait],
            "showCacheStatus": Defaults[.showCacheStatus],
            "feedCacheSize": Defaults[.feedCacheSize]
        ]
    }
}
