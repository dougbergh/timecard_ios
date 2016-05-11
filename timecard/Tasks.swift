//
//  Tasks.swift
//  timecard
//
//  Created by DBergh on 3/11/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

class Tasks {
    
    var sheetService: SheetServiceProtocol!
    
    var debugCount = 0
    
    func setSheetService(svc:SheetServiceProtocol) {
        sheetService = svc
        
        // make sure we get saveComplete
        sheetService.setTasksDelegate(self)
    }
    
    var currentlyActiveTask: Task?
    
    var finishedTasks = [Task]()    // Tasks that have been finished but not reported
    var reportingTasks = [Task]()   // Tasks in the process of being reported
    var reportedTasks = [Task]()    // Tasks that have been finished and reported
    var allNames = [String]()
    
    let persistentStore = NSUserDefaults.standardUserDefaults()
    let persistentStoreKey = "timecardFinishedTasks"
    let persistentStoreNamesKey = "timecardAllNames"
    let persistentStoreCurrentTaskKey = "timecardCurrentTask"
    
    //
    // The app is starting, this object is initializing. Reset state from persistent store.
    //
    func viewDidLoad() {
        
        if let values = persistentStore.objectForKey(persistentStoreKey) {
            let strings = values as! [String]
            for json in strings {
                let task = Task(input: json)
                finishedTasks.append(task)
            }
        }
        
        if let values = persistentStore.objectForKey(persistentStoreNamesKey) {
            allNames = values as! [String]
        }
    }
    
    func taskStarted( task: Task ) {
        currentlyActiveTask = task
        persistentStore.setObject(task.jsonString(), forKey: persistentStoreCurrentTaskKey)
    }
    
    func taskCanceled( task: Task ) {
        currentlyActiveTask  = nil
        persistentStore.setObject(nil, forKey: persistentStoreCurrentTaskKey)
    }
    
    func taskEnded( time: NSDate ) {
        let task = currentlyActiveTask
        if task != nil {
            task!.endTime = time
            
            // Add the newly completed task to the finished array and persistent store
            // (replace the whole persistent array 'cause it's easy)
            finishedTasks.append(task!)
            persistentStore.setObject(nil, forKey: persistentStoreKey)
            persistentStore.setObject(finishedTasksAsJsonArray(), forKey: persistentStoreKey)

            // Likewise for the allNames array
            allNames.append(task!.desc!)
            allNames = dedup(allNames)
            persistentStore.setObject(nil, forKey: persistentStoreNamesKey)
            persistentStore.setObject(allNames, forKey: persistentStoreNamesKey)

            currentlyActiveTask = nil
        }
    }
    
    //
    // Return an array of all tasks in the source array during the interval bounded by start & end
    //
    func getTasksInInterval(source:[Task],start:NSDate,end:NSDate) -> [Task] {
        var ret = [Task]()
        for task in source {
            if task.startTime.timeIntervalSinceDate(start) >= 0 && end.timeIntervalSinceDate(task.startTime) > 0 {
                ret.append(task)
            }
        }
        return ret
    }
    
    //
    // Remove all tasks in the interval from the finishedTasks array
    // (note: in swift, parameters are immutable so we can't pass the array
    // from which to remove the tasks as a parameter)
    //
    func removeTasksInInterval( start:NSDate, end:NSDate ) -> [Task] {
        
        var ret:[Task] = [Task]()
        
        while finishedTasks.isEmpty == false {
            let task = finishedTasks[0]
            if task.startTime.timeIntervalSinceDate(start) >= 0 && task.startTime.timeIntervalSinceDate(end) < 0 {
                ret.append(finishedTasks.removeFirst())
            } else { break }    // tasks are in chronological order, so we can break out when we find one
        }
        
        return ret
    }
    
    func insertToFrontOfFinished(tasksToInsert:[Task]) {
        let temp = finishedTasks
        finishedTasks.removeAll()
        finishedTasks += tasksToInsert
        finishedTasks += temp
    }
    
    //
    // Return the total amount of time in all tasks, independent of state
    //
    func totalDurationInterval(start:NSDate,end:NSDate) -> NSTimeInterval {

        var total: NSTimeInterval = 0
        var tasks = getTasksInInterval(reportedTasks,start: start,end: end)
        for task in tasks {
            total += task.duration
        }
        tasks = getTasksInInterval(reportingTasks,start: start,end: end)
        for task in tasks {
            total += task.duration
        }
        tasks = getTasksInInterval(finishedTasks,start: start,end: end)
        for task in tasks {
            total += task.duration
        }
        if currentlyActiveTask != nil &&
            currentlyActiveTask!.startTime.timeIntervalSinceDate(start) > 0 &&
            end.timeIntervalSinceDate(currentlyActiveTask!.startTime) > 0 {
            total += currentlyActiveTask!.duration
        }

        return total
    }
    
    func totalDurationToday() -> NSTimeInterval {
        let start = Clock.dayStart(NSDate())
        return totalDurationInterval(start, end: NSDate())
    }
    
    func totalDurationTodayAsString() -> String? {
        return Clock.getDurationString(totalDurationToday())
    }

    func totalDurationIntervalAsString(start:NSDate,end:NSDate) -> String? {
        return Clock.getDurationString(totalDurationInterval(start,end: end))
    }
    
    //
    // Determine whether there are tasks that need to be reported, 
    // i.e. it's a new day
    //
    func checkForDailyActivity() {
        
        // nothing to do
        if  finishedTasks.isEmpty == true {
            return
        }
        
        // request outstanding
        if ( reportingTasks.isEmpty == false ) {
            print("request outstanding; not saving")
            return
        }
        
        let now = NSDate()
        
        // check for task left on overnight
        if currentlyActiveTask != nil && !Clock.sameDay(now,date2: (currentlyActiveTask?.startTime)!) {
            // sho' 'nuf, she forgot to stop the last task of the night
            correctOvernightTask()
        }
        
        // check for tasks from a previous day that need to be saved
        let task = finishedTasks[0]
        if Clock.sameDay(task.startTime, date2: now) == false {
//        if true {      // XXX for debugging
        
            // save one prior day's tasks (if the app hasn't run for a couple days,
            // it will take a couple iterations to catch up to the present)
            let end = Clock.dayEnd(task.startTime)
            let tasksToSave = removeTasksInInterval(task.startTime, end: end)
            
            // note that we have a request outstanding.
            if tasksToSave.isEmpty == false {
                reportingTasks += tasksToSave
                
                // ...and save!
                saveTasks(tasksToSave)
            }
        }
    }

    func saveTasks(input:[Task]) {
        
        var date:NSDate?
        var total: NSTimeInterval = 0
        var taskNamesArray = [String]()
        var paramString:String = String()
        
        // consolidate duplicate tasks - i.e. if the user worked on the 
        // same task more than one time period in the day
        let tasksToSave = consolidate(input)

        // prep date, total and parameters
        for task in tasksToSave {
            date = task.startTime
            let duration = task.duration
            total += duration
            taskNamesArray.append(task.desc!)
            paramString += "\(Clock.getDateString(date!))|\(Clock.getDurationString(task.duration))|\(task.desc!)|"
        }

        // If there are tasks to save, save them and the day summary
        if date != nil {
            let (month, year) = Clock.monthYear(date!)
            sheetService.save("\(month) \(year) tasks", params: paramString)

            let taskNames = taskNamesArray.joinWithSeparator(",")
            sheetService.saveTotal("\(month) \(year)",date: date!, total: total, taskNames: taskNames)
        }
    }
    
    func saveComplete( succeeded:Bool ) {
        if succeeded {
            // Move 'em to reported. No need to update persistent storage
            // here because it's a single array containing reportingTasks
            // (by virtue of them having been added to finishedTasks earlier)
            reportedTasks += reportingTasks
        } else {
            // Put 'em back, try again in a second
            insertToFrontOfFinished(reportingTasks)
        }
        reportingTasks.removeAll()
    }
    
    func consolidate(tasks:[Task]) -> [Task] {
        var retVal = [Task]()
        var dup = false
        for task in tasks {
            for test in retVal {
                if test.desc == task.desc {
                    test.duration += task.duration
                    dup = true
                }
            }
            if dup == false {
                retVal.append(task)
            }
            dup = false
        }
        return retVal
    }

    func dedup(tasks:[String]) -> [String] {
        var retVal = [String]()
        var dup = false
        for task in tasks {
            for test in retVal {
                if test == task {
                    dup = true
                }
            }
            if dup == false {
                retVal.append(task)
            }
            dup = false
        }
        return retVal
    }
    
    // 
    // Clean up the fact that the last task of the day was left on overnight
    // 1st pass: do nothing
    //
    func correctOvernightTask() {
    }
    
    func getAllNames() -> [String] {
        
        return allNames
        
//        var tasks = [String]()
//        for task in finishedTasks {
//            if task.desc != nil {
//                tasks.append(task.desc!)
//            }
//        }
//        for task in reportingTasks {
//            if task.desc != nil {
//                tasks.append(task.desc!)
//            }
//        }
//        for task in reportedTasks {
//            if task.desc != nil {
//                tasks.append(task.desc!)
//            }
//        }
//        return dedup(tasks)
    }
    
    func finishedTasksAsJsonArray() -> [String] {
        
        var ret: [String] = [String]()
        for task in finishedTasks {
            ret.append(task.jsonString())
        }
        return ret
    }
}

class Task {
    
    enum Category {
        case teachingClass
        case readingObservations
    }
    
    var startTime: NSDate!
    var endTime: NSDate?
    var cat: Category?
    var desc: String?
    var duration: NSTimeInterval {
        set {
        }
        get {
            if endTime != nil {
                return round(endTime!.timeIntervalSinceDate(startTime))
            } else {
                return round(NSDate().timeIntervalSinceDate(startTime))
            }
        }
    }
    
    // Initializer used when only start time is known
    init( start: NSDate ) {
        startTime = start
    }
    
    init( start: NSDate, description:String? ) {
        startTime = start
        if description != nil {
            self.desc = description
        }
    }
    
    init( input:String ) {
        // motherfucker: can't run SwiftyJSON and GTL together.
        
        let encodedInput = input.dataUsingEncoding(NSUTF8StringEncoding)! as NSData
        
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(encodedInput, options: .AllowFragments)
            
            if let startTime = json["startTime"] as? String {
                self.startTime = Clock.dateFromString( startTime )
            }
            if let endTime = json["endTime"] as? String {
                self.endTime = Clock.dateFromString( endTime )
            }
            if let desc = json["desc"] as? String {
                self.desc = desc
            }
            if let duration = json["duration"] as? String {
                self.duration = NSTimeInterval(duration)!
            }
        } catch {
            print("error serializing JSON \(input): \(error)")
        }
    }
    
    func updateTime(now:NSDate) {
        duration = now.timeIntervalSinceDate(startTime)
    }
    
    func durationAsString(stop:NSDate) -> String? {
        if endTime != nil {
            return Clock.getDurationString(startTime, stop: endTime!)
        } else {
            return Clock.getDurationString(startTime, stop: stop)
        }
    }
    
    func jsonString() -> String {
        let request = GTLObject()
        request.setJSONValue(Clock.getDateTimeString(startTime), forKey: "startTime")
        request.setJSONValue(Clock.getDateTimeString(endTime), forKey: "endTime")
        request.setJSONValue(desc, forKey: "desc")
        request.setJSONValue(duration, forKey: "duration")
        
        return request.JSONString()
    }
}
