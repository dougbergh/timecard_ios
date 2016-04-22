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
    
    // Tasks that have been finished - some have been saved, some have not
    var finishedTasks = [Task]()
    
//    var taskHistory = [(NSDate,[Task])]()
    
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
    
    func totalDurationToday() -> NSTimeInterval {
        let start = Clock.dayStart(NSDate())
        return totalDurationInterval(start, end: NSDate())
    }
    
    //
    // Return an array of all tasks that started during the interval bounded by start & end
    //
    func getTasksInInterval(start:NSDate,end:NSDate) -> [Task] {
        var tasks = [Task]()
        for task in finishedTasks {
            if task.startTime.timeIntervalSinceDate(start) >= 0 && end.timeIntervalSinceDate(task.startTime) > 0 {
                tasks.append(task)
            }
        }
        return tasks
    }
    
    func totalDurationInterval(start:NSDate,end:NSDate) -> NSTimeInterval {

        var total: NSTimeInterval = 0
        let tasks = getTasksInInterval(start,end: end)
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
    
    func totalDurationTodayAsString() -> String? {
        return Clock.getDurationString(totalDurationToday())
    }

    func totalDurationIntervalAsString(start:NSDate,end:NSDate) -> String? {
        return Clock.getDurationString(totalDurationInterval(start,end: end))
    }
    
    //
    // Called onV
    func checkForDailyActivity() {
        
        let now = NSDate()
        
        // check for task left on overnight
        if currentlyActiveTask != nil && !Clock.sameDay(now,date2: (currentlyActiveTask?.startTime)!) {
            // sho' 'nuf, she forgot to stop the last task of the night
            correctOvernightTask()
        }
        
        // check for tasks from a previous day that need to be saved (this is the first run of a new day)
        if  finishedTasks.isEmpty == false {
            
            let task = finishedTasks[0]
            
            if !Clock.sameDay(task.startTime,date2: NSDate()) {
            
//            if debugCount > 59 {
                
                debugCount = 0
                
                // bingo, there are tasks to save
                let tasksToSave = getTasksInInterval(task.startTime, end: Clock.dayEnd(task.startTime))
                
                saveTasks(tasksToSave)
            } else {
                debugCount += 1
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
            sheetService.save(date!,total: total,taskNames: taskNames)
        }
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
        return tasks
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