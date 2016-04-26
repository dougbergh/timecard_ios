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
    }
    
    var currentlyActiveTask: Task?
    
    var finishedTasks = [Task]()    // Tasks that have been finished but not reported
    var reportingTasks = [Task]()   // Tasks in the process of being reported
    var reportedTasks = [Task]()    // Tasks that have been finished and reported
    
    func taskStarted( task: Task ) {
        currentlyActiveTask = task
    }
    
    func taskCanceled( task: Task ) {
        currentlyActiveTask  = nil
    }
    
    func taskEnded( time: NSDate ) {
        let task = currentlyActiveTask
        if task != nil {
            task!.endTime = time
            finishedTasks.append(task!)
            currentlyActiveTask = nil
        }
    }
    
    //
    // Return an array of all tasks that have not been reported and that
    // started during the interval bounded by start & end
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
    func removeTasksInInterval( start:NSDate, end:NSDate ) -> [Task] {
        
        var ret:[Task] = [Task]()
        
        while finishedTasks.isEmpty == false {
            let task = finishedTasks[0]
            if task.startTime.timeIntervalSinceDate(start) >= 0 && end.timeIntervalSinceDate(task.startTime) > 0 {
                ret.append(finishedTasks.removeFirst())
            } else { break }
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

    func saveTasks(tasksToSave:[Task]) {
        var date:NSDate?
        var total: NSTimeInterval = 0
        var taskNamesArray = [String]()
        for task in tasksToSave {
            date = task.startTime
            total += task.duration
            taskNamesArray.append(task.desc!)
        }

        if date != nil {
            taskNamesArray = dedup(taskNamesArray)
            let taskNames = taskNamesArray.joinWithSeparator(",")
            sheetService.setTasksDelegate(self)
            sheetService.save(date!,total: total,taskNames: taskNames)
        }
    }
    
    func saveComplete( succeeded:Bool ) {
        if succeeded {
            reportedTasks += reportingTasks
        } else {
            // Put 'em back, try again in a second
            insertToFrontOfFinished(reportingTasks)
        }
        reportingTasks.removeAll()
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
        var tasks = [String]()
        for task in finishedTasks {
            if task.desc != nil {
                tasks.append(task.desc!)
            }
        }
        return dedup(tasks)
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
                return endTime!.timeIntervalSinceDate(startTime)
            } else {
                return NSDate().timeIntervalSinceDate(startTime)
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
}