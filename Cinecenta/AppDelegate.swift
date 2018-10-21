//
//  AppDelegate.swift
//  Cinecenta
//
//  Created by Mark Alldritt on 2018-10-16.
//  Copyright © 2018 Mark Alldritt. All rights reserved.
//

import UIKit
import UserNotifications
import Haneke



//  It was simpler to implement the scraping code in PHP on my server than to do it on the device.  This URL
//  ets a JSON structure of the upcomming showing at Cinecenta (www.cinecenta.com).

let cinecentaURL = URL(string: "https://www.latenightsw.com/mark/cinecenta.php")!



@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    static public func scrapeSite(flushCache: Bool = false, completionHandler: @escaping ([[String:AnyObject]]?, [[String:AnyObject]]?) -> Void) {
        let nextPollTimeKey = "nextPollTime"
        var flushCache = flushCache
        
        if !flushCache {
            //  See if the cached data has expired
            if let nextPollDate = UserDefaults.standard.object(forKey: nextPollTimeKey) as? Date {
                flushCache = Date() > nextPollDate
            }
        }
        if flushCache {
            Shared.JSONCache.remove(key: cinecentaURL.absoluteString)
        }
        Shared.JSONCache.fetch(URL: cinecentaURL).onSuccess { json in
            print("JSON: \(json)")
            
            let today = json.dictionary["today"] as? [[String:AnyObject]]
            let tomorrow = json.dictionary["tomorrow"] as? [[String:AnyObject]]

            UserDefaults.standard.set(Date.tomorrow, forKey: nextPollTimeKey)
            
            completionHandler(today, tomorrow)
        }
    }

    private var nextBackgroundFetchInterval: TimeInterval {
        return Date.tomorrow.timeIntervalSinceNow + 60 * 60 * 4 /* 4 hours */
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (success, error) in
            print("success: \(success), error: \(error)")
        }
        UNUserNotificationCenter.current().delegate = self
        
        UIApplication.shared.setMinimumBackgroundFetchInterval(nextBackgroundFetchInterval)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        AppDelegate.scrapeSite { (today, _) in
            if let today = today, today.count > 0 {
                for show in today {
                    guard let title = show["title"] as? String else { continue }
                    guard let times = show["times"] as? String else { continue }
                    let key = "\(title).\(times)"
                    
                    let notification = UNMutableNotificationContent()
                    notification.title = title
                    notification.body = times
                    notification.userInfo = ["key": key]
                    notification.sound = UNNotificationSound.default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(identifier: key,
                                                        content:notification,
                                                        trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
                        print("error: \(error)")
                    })
                }
            }
            
            //  Update the view
            if let navViewController = self.window?.rootViewController as? UINavigationController,
                let viewController = navViewController.topViewController as? ViewController {
                viewController.refresh()
            }
            
            //  Schedule the next background fetch
            UIApplication.shared.setMinimumBackgroundFetchInterval(self.nextBackgroundFetchInterval)
            
            completionHandler(.newData)
        }
    }

    //  MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let key = response.notification.request.identifier
        
        //  Update the view
        if let navViewController = self.window?.rootViewController as? UINavigationController,
            let viewController = navViewController.topViewController as? ViewController {
            viewController.show(key: key)
        }

        completionHandler()
    }
}

