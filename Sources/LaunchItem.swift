//
//  LaunchItem.swift
//  SuperDelegate
//
//  Created by Dan Federman on 4/26/16.
//  Copyright © 2016 Square, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


public enum LaunchItem: CustomStringConvertible, Equatable {
    case remoteNotification(item: RemoteNotification)
    case localNotification(item: UILocalNotification)
    case openURL(item: URLToOpen)
    @available(iOS 9.0, *)
    case shortcut(item: UIApplicationShortcutItem)
    case userActivity(item: NSUserActivity)
    case sourceApplication(bundleIdentifier: String)
    case unknown(launchOptions: [UIApplication.LaunchOptionsKey : Any])
    case none
    
    // MARK: Equatable
    
    public static func ==(lhs: LaunchItem, rhs: LaunchItem) -> Bool {
        switch (lhs, rhs) {
        case let (.remoteNotification(itemLHS), .remoteNotification(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.localNotification(itemLHS), .localNotification(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.openURL(itemLHS), .openURL(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.shortcut(itemLHS), .shortcut(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.userActivity(itemLHS), .userActivity(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.sourceApplication(itemLHS), .sourceApplication(itemRHS)) where itemLHS == itemRHS:
            return true
        case let (.unknown(itemLHS), .unknown(itemRHS)):
            // Use NSDictionary's equality tests, since this is an NSDictionary in the Objective-C headers of UIApplicationDelegate.
            return (itemLHS as NSDictionary) == (itemRHS as NSDictionary)
        case (.none, .none):
            return true
            
        // Xcode 8.0 doesn't properly recognize pattern matching as exhaustive, so this requires a default case <https://github.com/square/SuperDelegate/pull/25#discussion_r177470662>.
        // Once we update the minimum Xcode version to 9.0, this should be replaced with pattern matching.
        default:
            return false
        }
    }
    
    // MARK: Initialization
    
    init(launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        if let launchRemoteNotification = RemoteNotification(remoteNotification: launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable : Any]) {
            self = .remoteNotification(item: launchRemoteNotification)
            
        } else if let launchLocalNotification = launchOptions?[UIApplication.LaunchOptionsKey.localNotification] as? UILocalNotification {
            self = .localNotification(item: launchLocalNotification)
            
        } else if let launchURL = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
            let sourceApplicationBundleID = launchOptions?[UIApplication.LaunchOptionsKey.sourceApplication] as? String
            let annotation = launchOptions?[UIApplication.LaunchOptionsKey.annotation]
            
            if #available(iOS 9.0, *) {
                self = .openURL(item: URLToOpen(
                    url: launchURL,
                    sourceApplicationBundleID: sourceApplicationBundleID,
                    annotation: annotation,
                    copyBeforeUse: launchOptions?[UIApplication.LaunchOptionsKey.openInPlace] as? Bool ?? false
                    )
                )
                
            } else {
                self = .openURL(item: URLToOpen(
                    url: launchURL,
                    sourceApplicationBundleID: sourceApplicationBundleID,
                    annotation: annotation,
                    copyBeforeUse: false
                    )
                )
            }
            
        } else if #available(iOS 9.0, *), let launchShortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            self = .shortcut(item: launchShortcutItem)
            
        } else if let userActivityDictionary = launchOptions?[UIApplication.LaunchOptionsKey.userActivityDictionary] as? [UIApplication.LaunchOptionsKey : Any],
            let launchUserActivity = userActivityDictionary[UIApplication.LaunchOptionsKey.userActivity] as? NSUserActivity {
            self = .userActivity(item: launchUserActivity)
            
        } else if let sourceApplication = launchOptions?[UIApplication.LaunchOptionsKey.sourceApplication] as? String {
            self = .sourceApplication(bundleIdentifier: sourceApplication)
            
        } else if let launchOptions = launchOptions, !launchOptions.isEmpty {
            self = .unknown(launchOptions: launchOptions)
            
        } else {
            self = .none
        }
    }
    
    // MARK: CustomStringConvertible
    
    public var description: String {
        // Creating a custom string for LaunchItem to prevent a crash when printing any enum values with associated items on iOS 8. Swift accesses the class of every possible associated object when printing an enum instance with an asssociated value, no matter which case the instance represents. This causes a crash on iOS 8 since swift attempts to access UIApplicationShortcutItem, which doesn't exist on iOS 8. Filed rdar://26699861 – hoping for a fix in Swift 3.
        switch self {
        case let .remoteNotification(item):
            return "LaunchItem.remoteNotification: \(item)"
        case let .localNotification(item):
            return "LaunchItem.localNotification: \(item)"
        case let .openURL(item):
            return "LaunchItem.openURL: \(item)"
        case let .shortcut(item):
            return "LaunchItem.shortcut: \(item)"
        case let .userActivity(item):
            return "LaunchItem.userActivity: \(item)"
        case let .sourceApplication(item):
            return "LaunchItem.sourceApplication: \(item)"
        case let .unknown(launchOptions):
            return "LaunchItem.unknown: \(launchOptions)"
        case .none:
            return "LaunchItem.none"
        }
    }
    
    // MARK: Public Properties
    
    /// The launch options that were used to construct the enum, for passing into third party APIs.
    public var launchOptions: [UIApplication.LaunchOptionsKey : Any] {
        switch self {
        case let .remoteNotification(item):
            return [
                UIApplication.LaunchOptionsKey.remoteNotification  : item.remoteNotificationDictionary
            ]
            
        case let .localNotification(item):
            return [
                UIApplication.LaunchOptionsKey.localNotification : item
            ]
            
        case let .openURL(item):
            var launchOptions: [UIApplication.LaunchOptionsKey : Any] = [
                UIApplication.LaunchOptionsKey.url : item.url
            ]
            
            if let sourceApplicationBundleID = item.sourceApplicationBundleID {
                launchOptions[UIApplication.LaunchOptionsKey.sourceApplication] = sourceApplicationBundleID
            }
            
            if let annotation = item.annotation {
                launchOptions[UIApplication.LaunchOptionsKey.annotation] = annotation
            }
            
            if #available(iOS 9.0, *) {
                launchOptions[UIApplication.LaunchOptionsKey.openInPlace] = item.copyBeforeUse
            }
            
            return launchOptions
            
        case let .shortcut(item):
            if #available(iOS 9.0, *) {
                return [
                    UIApplication.LaunchOptionsKey.shortcutItem : item
                ]
            } else {
                // If we are a .shortcut and we are not on iOS 9 or later, something absolutely terrible has happened.
                fatalError()
            }
            
        case let .userActivity(item):
            return [
                UIApplication.LaunchOptionsKey.userActivityDictionary : [
                    UIApplication.LaunchOptionsKey.userActivityType : item.activityType,
                    UIApplication.LaunchOptionsKey.userActivity : item
                ]
            ]
            
        case let .sourceApplication(item):
            return [
                UIApplication.LaunchOptionsKey.sourceApplication : item
            ]
            
        case let .unknown(launchOptions):
            return launchOptions
            
        case .none:
            return [:]
        }
    }
}
