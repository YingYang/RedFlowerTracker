//
//  XiaoHongHuaApp.swift
//  XiaoHongHua
//
//  Created by ying_lasaraleen on 9/5/25.
//

import SwiftUI
import SwiftData

@main
struct XiaoHongHuaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Transaction.self)
    }
}
