import SwiftUI

// Use the property wrapper directly so Command Line Tools builds don't require
// the SwiftUIMacros plugin introduced by the macOS 27 SDK.
typealias ViewState<Value> = SwiftUI.State<Value>
