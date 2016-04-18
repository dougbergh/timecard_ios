//
//  Clock.swift
//  timecard
//
//  Created by DBergh on 3/13/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

protocol ClockDelegate {
    func updateTime( newTime: NSDate )
}

class Clock {
    
    var timer = NSTimer()
    
    let delegate: ClockDelegate!
    
    init( clockDelegate: ClockDelegate ) {
        
        delegate = clockDelegate
        
        self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0,
            target: self,
            selector: #selector(Clock.tick),
            userInfo: nil,
            repeats: true)
    }
    
    @objc func tick() {
        delegate.updateTime( NSDate() )
    }
    
    func stop() {
        timer.invalidate()
    }
}

extension Clock {
    static func getTimeString(date:NSDate) -> String {
        return NSDateFormatter.localizedStringFromDate(date, dateStyle: .NoStyle, timeStyle: .ShortStyle)
    }
    // This is the 'correct' way to do this, but I can't make it work
//    static func getDurationString(start:NSDate, stop:NSDate) -> String? {
//        let formatter = NSDateComponentsFormatter()
//        formatter.calendar = NSCalendar.currentCalendar()
//        formatter.allowedUnits = NSCalendarUnit.Second // | NSCalendarUnit.Minute
//        let str = formatter.stringFromDate(start, toDate: stop)
//        return str
//    }
//    static func getDurationString(interval:NSTimeInterval) -> String? {
//        let formatter = NSDateComponentsFormatter()
//        formatter.calendar = NSCalendar.currentCalendar()
//        formatter.allowedUnits = NSCalendarUnit.Minute
//        let str = formatter.stringFromTimeInterval(interval)
//        return str
//    }
    
    static func getDurationString(start:NSDate, stop:NSDate) -> String? {
        let interval = stop.timeIntervalSinceDate(start)
        return getDurationString(interval)
    }
    
    static func getDurationString(interval:NSTimeInterval) -> String? {
        let (d,h,m,s) = durationsFromSeconds(seconds: interval)
        var retVal = ""
        if d > 0 { retVal += "\(d):" }
        if h > 0 { retVal += "\(h):" }
        if h > 0 && m < 10 { retVal += "0" }
        if h > 0 || m > 0 { retVal += "\(m):" }
        if m > 0 && s < 10 { retVal += "0" }
        retVal += "\(s)"
        return retVal
    }
    
    static func durationsFromSeconds(seconds s: NSTimeInterval) -> (days:Int,hours:Int,minutes:Int,seconds:Int) {
        return (Int(s / (24 * 3600.0)),Int((s % (24 * 3600.0)) / 3600.0),Int(s % 3600 / 60.0),Int(s % 60.0))
    }
    
    //
    // Return an NSDate that represents the first instant of today
    //
    static func dayStart( date:NSDate ) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let components = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date)
        
        components.hour = 0
        components.minute = 0
        components.second = 0

        let updated = NSCalendar.currentCalendar().dateFromComponents(components)
        
        return updated!
    }
    
    //
    // Return an NSDate that represents the last instant of today
    //
    static func dayEnd( date:NSDate ) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let components = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date)
        
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let updated = NSCalendar.currentCalendar().dateFromComponents(components)
        
        return updated!
    }
    
    //
    // Return an NSDate that represents the first instant of this year
    //
    static func thisYear( date:NSDate ) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let argComponents = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date)
        let nowComponents = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: NSDate())
        
        argComponents.year = nowComponents.year
        
        let updated = NSCalendar.currentCalendar().dateFromComponents(argComponents)
        
        return updated!
    }
    
    static func sameDay( date1:NSDate, date2:NSDate ) -> Bool {
        let cal = NSCalendar.currentCalendar()
        let components1 = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date1)
        let components2 = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date2)

        return components1.day == components2.day
    }
}
