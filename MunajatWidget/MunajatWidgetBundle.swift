//
//  MunajatWidgetBundle.swift
//  MunajatWidget
//
//  Created by Achraf Trabelsi on 12/05/2026.
//

import WidgetKit
import SwiftUI

@main
struct MunajatWidgetBundle: WidgetBundle {
    init() {
        // Widget extensions are a separate process, so the host app's
        // `FontRegistrar.registerBundledFonts()` call in AdhkarApp.init
        // doesn't reach us. Re-register here so Font.amiri works on tile.
        FontRegistrar.registerBundledFonts()
    }

    var body: some Widget {
        CurrentPeriodWidget()
    }
}
