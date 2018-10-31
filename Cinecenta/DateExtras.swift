//
//  DateExtras.swift
//  Cinecenta
//
//  Created by Mark Alldritt on 2018-10-19.
//  Copyright © 2018 Mark Alldritt. All rights reserved.
//

import UIKit

public extension Date {
    
    static public var today : Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.day, .month, .year, .hour, .minute, .second], from: Date())
        
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        let today = calendar.date(from: components)
        
        return today!
    }
    
    static public var yesterday : Date {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        
        return yesterday!
    }
    
    static public var tomorrow : Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        
        return tomorrow!
    }
    
    public var zeroHour : Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.day, .month, .year, .hour, .minute, .second], from: self)
        
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components)!
    }
    
    public var nextDay : Date {
        let calendar = Calendar.current
        
        return calendar.date(byAdding: .day, value: 1, to: zeroHour)!
    }

}
