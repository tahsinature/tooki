import SwiftUI

// Bypass the SwiftUI macro unavailable in Command Line Tools builds.
typealias ViewState<Value> = SwiftUI.State<Value>
