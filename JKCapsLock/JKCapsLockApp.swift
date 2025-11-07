//
//  JKCapsLockApp.swift
//  JKCapsLock
//
//  Created by Janesh Suthar on 07/11/25.
//

import SwiftUI

@main
struct CapsLockMenuBarApp: App {
    // Connect AppDelegate to manage status item lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

