/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The Guess Together group activity definition.
*/

import CoreTransferable
import GroupActivities

struct GuessTogetherActivity: GroupActivity, Transferable {
    static let activityIdentifier: String = "com.cwp57.activity.objectTracking"
    
    var metadata: GroupActivityMetadata = {
        var metadata = GroupActivityMetadata()
        metadata.title = "Object Tracking"
        return metadata
    }()
}
