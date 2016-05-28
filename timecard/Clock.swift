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
    
    //
    // Return the full date & time as a string (suitable for saving in persistent store)
    //
    static func getDateTimeString(date:NSDate?) -> String {
        if date == nil { return "" }
        return NSDateFormatter.localizedStringFromDate(date!, dateStyle: .ShortStyle, timeStyle: .MediumStyle)
    }

    //
    // Return just the date as a string (suitable for specifying sheets filename)
    //
    static func getDateString(date:NSDate?) -> String {
        if date == nil { return "" }
        return NSDateFormatter.localizedStringFromDate(date!, dateStyle: .ShortStyle, timeStyle: .NoStyle)
    }
    
    //
    // Return just the time (without the date) as a string (suitable for displaying on the UI)
    //
    static func getTimeString(date:NSDate?) -> String {
        if date == nil { return "" }
        return NSDateFormatter.localizedStringFromDate(date!, dateStyle: .NoStyle, timeStyle: .ShortStyle)
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
    
    //
    // Return an NSDate given the input. Assumes the input was created with the 
    // getDateString() function above, which uses dateStyle.ShortStyle and timeStyle.MediumStyle
    //
    static func dateFromString(input:String) -> NSDate {
        let fmt = NSDateFormatter()
        fmt.dateStyle = .ShortStyle
        fmt.timeStyle = .MediumStyle
        return fmt.dateFromString(input)!
    }
    
    static func getDurationString(start:NSDate, stop:NSDate) -> String {
        let interval = stop.timeIntervalSinceDate(start)
        return getDurationString(interval)
    }
    
    static func getDurationString(interval:NSTimeInterval) -> String {
        let (d,h,m,s) = durationsFromSeconds(seconds: interval)
        var retVal = ""
        if d > 0 { retVal += "\(d)d " }
        if h > 0 { retVal += "\(h)h " }
        if m > 0 { retVal += "\(m)m " }
        retVal += "\(s)s"
        return retVal
    }
    
    static func durationsFromSeconds(seconds s: NSTimeInterval) -> (days:Int,hours:Int,minutes:Int,seconds:Int) {
        return (Int(s / (24 * 3600.0)),Int((s % (24 * 3600.0)) / 3600.0),Int(s % 3600 / 60.0),Int(s % 60.0))
    }
    
    static func durationAsDecimal( seconds interval: NSTimeInterval ) -> Float {
        var (_,h,m,s) = durationsFromSeconds(seconds: interval)
        
        m += ( s>=30 ? 1 : 0)
        
        let fraction = Float(m) / 60.0
        
        let ret:Float = Float(h) + fraction
        
        return ret
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
    
    static func sameMinute( date1:NSDate, date2:NSDate ) -> Bool {
        let cal = NSCalendar.currentCalendar()
        let components1 = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date1)
        let components2 = cal.components([.Year, .Month, .Day, .Hour, .Minute, .Second, .Nanosecond], fromDate: date2)
        
        return components1.minute == components2.minute
    }
    
    static func moreThanOneDayOld( date1:NSDate, date2:NSDate ) -> Bool {
        
        let oneDay : NSTimeInterval = 60*60*24

        let diff = date2.timeIntervalSinceDate(date1)
        
        return diff > oneDay
    }
    
    static func dayEndYesterday( date:NSDate ) -> NSDate {
        let yesterday = date.dateByAddingTimeInterval(-60*60*24)
        return dayEnd(yesterday)
    }
    
    static func monthYear(date:NSDate) -> (String,String) {
        let fmt = NSDateFormatter()
        fmt.dateStyle = NSDateFormatterStyle.LongStyle
        let dateString = fmt.stringFromDate(date)
        let dateArray = dateString.characters.split(" ")
        let month = String(dateArray[0])
        let year = String(dateArray[2])
        
        return (month,year)
    }
}
