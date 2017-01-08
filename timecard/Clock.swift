//
//  Clock.swift
//  timecard
//
//  Created by DBergh on 3/13/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

protocol ClockDelegate {
    func updateTime( _ newTime: Date )
}

class Clock {
    
    var timer = Timer()
    
    let delegate: ClockDelegate!
    
    init( clockDelegate: ClockDelegate ) {
        
        delegate = clockDelegate
        
        self.timer = Timer.scheduledTimer(timeInterval: 1.0,
            target: self,
            selector: #selector(Clock.tick),
            userInfo: nil,
            repeats: true)
    }
    
    @objc func tick() {
        delegate.updateTime( Date() )
    }
    
    func stop() {
        timer.invalidate()
    }
}

extension Clock {
    
    //
    // Return the full date & time as a string (suitable for saving in persistent store)
    //
    static func getDateTimeString(_ date:Date?) -> String {
        if date == nil { return "" }
        return DateFormatter.localizedString(from: date!, dateStyle: .short, timeStyle: .medium)
    }

    //
    // Return just the date as a string (suitable for specifying sheets filename)
    //
    static func getDateString(_ date:Date?) -> String {
        if date == nil { return "" }
        return DateFormatter.localizedString(from: date!, dateStyle: .short, timeStyle: .none)
    }
    
    //
    // Return just the time (without the date) as a string (suitable for displaying on the UI)
    //
    static func getTimeString(_ date:Date?) -> String {
        if date == nil { return "" }
        return DateFormatter.localizedString(from: date!, dateStyle: .none, timeStyle: .medium)
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
    static func dateFromString(_ input:String) -> Date {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateStyle = .short
        fmt.timeStyle = .medium
        return fmt.date(from: input)!
    }
    
    static func getDurationString(_ start:Date, stop:Date) -> String {
        let interval = stop.timeIntervalSince(start)
        return getDurationString(interval)
    }
    
    static func getDurationString(_ interval:TimeInterval) -> String {
        let (d,h,m,s) = durationsFromSeconds(seconds: interval)
        var retVal = ""
        if d > 0 { retVal += "\(d)d " }
        if h > 0 { retVal += "\(h)h " }
        if m > 0 { retVal += "\(m)m " }
        retVal += "\(s)s"
        return retVal
    }
    
    static func durationsFromSeconds(seconds s: TimeInterval) -> (days:Int,hours:Int,minutes:Int,seconds:Int) {
        return (Int(s / (24 * 3600.0)),Int((s.truncatingRemainder(dividingBy: (24 * 3600.0))) / 3600.0),Int(s.truncatingRemainder(dividingBy: 3600) / 60.0),Int(s.truncatingRemainder(dividingBy: 60.0)))
    }
    
    static func durationAsDecimal( seconds interval: TimeInterval ) -> Float {
        var (_,h,m,s) = durationsFromSeconds(seconds: interval)
        
        m += ( s>=30 ? 1 : 0)
        
        let fraction = Float(m) / 60.0
        
        let ret:Float = Float(h) + fraction
        
        return ret
    }
    
    //
    // Return an NSDate that represents the first instant of today
    //
    static func dayStart( _ date:Date ) -> Date {
        
        let cal = Calendar.current
        
        var components = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        components.hour = 0
        components.minute = 0
        components.second = 0

        let updated = Calendar.current.date(from: components)
        
        return updated!
    }
    
    //
    // Return an NSDate that represents the last instant of today
    //
    static func dayEnd( _ date:Date ) -> Date {
        
        let cal = Calendar.current
        
        var components = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let updated = Calendar.current.date(from: components)
        
        return updated!
    }
    
    //
    // Return an NSDate that represents the first instant of this year
    //
    static func thisYear( _ date:Date ) -> Date {
        
        let cal = Calendar.current
        
        var argComponents = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        let nowComponents = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: Date())
        
        argComponents.year = nowComponents.year
        
        let updated = Calendar.current.date(from: argComponents)
        
        return updated!
    }
    
    static func sameDay( _ date1:Date, date2:Date ) -> Bool {
        let cal = Calendar.current
        let components1 = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date1)
        let components2 = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date2)

        return components1.day == components2.day
    }
    
    static func sameMinute( _ date1:Date, date2:Date ) -> Bool {
        let cal = Calendar.current
        let components1 = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date1)
        let components2 = (cal as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date2)
        
        return components1.minute == components2.minute
    }
    
    static func moreThanOneDayOld( _ date1:Date, date2:Date ) -> Bool {
        
        let oneDay : TimeInterval = 60*60*24

        let diff = date2.timeIntervalSince(date1)
        
        return diff > oneDay
    }
    
    static func dayEndYesterday( _ date:Date ) -> Date {
        let yesterday = date.addingTimeInterval(-60*60*24)
        return dayEnd(yesterday)
    }
    
    static func monthYear(_ date:Date) -> (String,String) {
        let fmt = DateFormatter()
        fmt.dateStyle = DateFormatter.Style.long
        let dateString = fmt.string(from: date)
        let dateArray = dateString.characters.split(separator: " ")
        let month = String(dateArray[0])
        let year = String(dateArray[2])
        
        return (month,year)
    }
}
