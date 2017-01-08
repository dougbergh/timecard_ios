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
    
    func setSheetService(_ svc:SheetServiceProtocol) {
        sheetService = svc
        
        // make sure we get saveComplete
        sheetService.setTasksDelegate(self)
    }
    
    var currentlyActiveTask: Task?
    
    var finishedTasks = [Task]()    // Tasks that have been finished but not reported
    var reportingTasks = [Task]()   // Tasks in the process of being reported
    var reportedTasks = [Task]()    // Tasks that have been finished and reported
    var allNames = [String]()
    
    let persistentStoreActiveKey = "timecardActiveTask"
    let persistentStoreFinishedKey = "timecardFinishedTasks"
    let persistentStoreNamesKey = "timecardAllNames"
    
    //
    // The app is starting, this object is initializing. Reset state from persistent store.
    //
    func viewDidLoad() {
        
        if let value = UserDefaults.standard.value(forKey: persistentStoreActiveKey) {
            let json = value as! String
            currentlyActiveTask = Task(input: json)
        }
    
        if let values = UserDefaults.standard.value(forKey: persistentStoreFinishedKey) {
            let strings = values as! [String]
            for json in strings {
                let task = Task(input: json)
                finishedTasks.append(task)
            }
        }
        
        if let values = UserDefaults.standard.value(forKey: persistentStoreNamesKey) {
            allNames = values as! [String]
        }
    }
    
    func taskStarted( _ task: Task ) {
        currentlyActiveTask = task
        
        UserDefaults.standard.setValue(nil, forKey: persistentStoreActiveKey)
        if let json = activeTaskAsJsonString() {
            UserDefaults.standard.setValue(json, forKey: persistentStoreActiveKey)
        }
    }
    
    func taskCanceled( _ task: Task ) {
        currentlyActiveTask  = nil
    }
    
    func taskEnded( _ time: Date ) {
        let task = currentlyActiveTask
        if task != nil {
            task!.endTime = time
            
            UserDefaults.standard.setValue(nil, forKey: persistentStoreActiveKey)
            
            // Add the newly completed task to the finished array and persistent store
            // (replace the whole persistent array 'cause it's easy)
            finishedTasks.append(task!)
            UserDefaults.standard.setValue(nil, forKey: persistentStoreFinishedKey)
            UserDefaults.standard.setValue(finishedTasksAsJsonArray(), forKey: persistentStoreFinishedKey)

            // Likewise for the allNames array
            allNames.append(task!.desc!)
            allNames = dedup(allNames)
            UserDefaults.standard.setValue(nil, forKey: persistentStoreNamesKey)
            UserDefaults.standard.setValue(allNames, forKey: persistentStoreNamesKey)

            currentlyActiveTask = nil
            
            debugCount += 1
        }
    }
    
    //
    // Return an array of all tasks in the source array during the interval bounded by start & end
    //
    func getTasksInInterval(_ source:[Task],start:Date,end:Date) -> [Task] {
        var ret = [Task]()
        for task in source {
            if task.startTime.timeIntervalSince(start) >= 0 && end.timeIntervalSince(task.startTime) > 0 {
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
    func removeTasksInInterval( _ start:Date, end:Date ) -> [Task] {
        
        var ret:[Task] = [Task]()
        
        while finishedTasks.isEmpty == false {
            let task = finishedTasks[0]
            if task.startTime.timeIntervalSince(start) >= 0 && task.startTime.timeIntervalSince(end) < 0 {
                ret.append(finishedTasks.removeFirst())
            } else { break }    // tasks are in chronological order, so we can break out when we find one
        }
        
        return ret
    }
    
    func insertToFrontOfFinished(_ tasksToInsert:[Task]) {
        let temp = finishedTasks
        finishedTasks.removeAll()
        finishedTasks += tasksToInsert
        finishedTasks += temp
    }
    
    //
    // Return the total amount of time in all tasks, independent of state
    //
    func totalDurationInterval(_ start:Date,end:Date) -> TimeInterval {

        var total: TimeInterval = 0

        var tasks = getTasksInInterval(reportingTasks,start: start,end: end)
        for task in tasks {
            total += task.duration
        }

        tasks = getTasksInInterval(finishedTasks,start: start,end: end)
        for task in tasks {
            total += task.duration
        }

        if currentlyActiveTask != nil &&
            currentlyActiveTask!.startTime.timeIntervalSince(start) > 0 &&
            end.timeIntervalSince(currentlyActiveTask!.startTime) > 0 {
            total += currentlyActiveTask!.duration
        }

        return total
    }
    
    func totalDurationToday() -> TimeInterval {
        let start = Clock.dayStart(Date())
        return totalDurationInterval(start, end: Date())
    }
    
    func totalDurationTodayAsString() -> String? {
        return Clock.getDurationString(totalDurationToday())
    }

    func totalDurationIntervalAsString(_ start:Date,end:Date) -> String? {
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
            Flurry.logEvent("request outstanding; not saving")
            return
        }
        
        let now = Date()
        
        // check for task left on overnight
        if currentlyActiveTask != nil && !Clock.sameDay(now,date2: (currentlyActiveTask?.startTime)!) {
            // sho' 'nuf, she forgot to stop the last task of the night
            correctOvernightTask()
        }
        
        // check for tasks from a previous day that need to be saved
        let task = finishedTasks[0]
        if Clock.sameDay(task.startTime, date2: now) == false {
        
//        if debugCount >= 2 { // XXX for debugging
            debugCount = 0
        
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

    //
    // If there are tasks to save, save them and the day summary
    //
    func saveTasks(_ input:[Task]) {
        
        var total: TimeInterval = 0
        var taskNamesArray = [String]()
        var paramString:String = String()
        
        if input.count == 0 {return}
        
        print( "saving \(input.count)" )
        Flurry.logEvent( "saving \(input.count)" )
        
        let dateColumn:String = Clock.getDateString(input[0].startTime)
        let (month, year) = Clock.monthYear(input[0].startTime)
        
        // consolidate duplicate tasks - i.e. if the user worked on the
        // same task more than one time period in the day
        let tasksToSave = consolidate(input)
        
        // prep date, total and parameters
        for task in tasksToSave {
            let duration = task.duration
            total += duration
            taskNamesArray.append(task.desc!)
            paramString += "\(dateColumn)|\(Clock.getDurationString(task.duration))|\(task.desc!)|"
        }
        
        // save individual (consolidated) tasks
        sheetService.save("\(month) \(year) tasks", params: paramString)
        
        // save day's summary
        let taskNames = taskNamesArray.joined(separator: ",")
        let decimal = round(Clock.durationAsDecimal(seconds: total) * 100) / 100
        sheetService.saveTotal("\(month) \(year)",
                               date: dateColumn,
                               total: "\(decimal)",
                               taskNames: taskNames)
    }
    
    func saveComplete( _ succeeded:Bool, error:String? ) {
        if succeeded {
            print( "save SUCCESS; \(reportingTasks.count) saved" )
            Flurry.logEvent( "save SUCCESS; \(reportingTasks.count) saved" )
            // Move 'em to reported. No need to update persistent storage
            // here because it's a single array containing reportingTasks
            // (by virtue of them having been added to finishedTasks earlier)
            reportedTasks += reportingTasks
        } else {
            print( "save FAIL: \(error); \(reportingTasks.count) to retry" )
            Flurry.logEvent( "save FAIL: \(error); \(reportingTasks.count) to retry" )
            // Put 'em back, try again in a second
            insertToFrontOfFinished(reportingTasks)
            
            ViewController.showAlert("saveFAIL", message:error! )
            
        }
        reportingTasks.removeAll()
    }
    
    func consolidate(_ tasks:[Task]) -> [ConsolidatedTask] {
        var retVal = [ConsolidatedTask]()
        var dup = false
        for task in tasks {
            for test in retVal {
                if test.desc == task.desc {
                    test.duration += task.duration
                    dup = true
                }
            }
            if dup == false {
                let consolidatedTask = ConsolidatedTask(desc: task.desc!)
                consolidatedTask.duration = task.duration
                retVal.append(consolidatedTask)
            }
            dup = false
        }
        return retVal
    }

    func dedup(_ tasks:[String]) -> [String] {
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
    }
    
    func activeTaskAsJsonString() -> String? {
        return currentlyActiveTask?.jsonString()
    }
    
    func finishedTasksAsJsonArray() -> [String] {
        
        var ret: [String] = [String]()
        for task in finishedTasks {
            ret.append(task.jsonString())
        }
        return ret
    }
    
    func deleteNameFromAllNames( _ deleted:String ) {
        if let index = allNames.index( of: deleted ) {
            allNames.remove(at: index)
        }
        UserDefaults.standard.setValue(nil, forKey: persistentStoreNamesKey)
        UserDefaults.standard.setValue(allNames, forKey: persistentStoreNamesKey)
    }
}

class Task {
    
    enum Category {
        case teachingClass
        case readingObservations
    }
    
    var startTime: Date!
    var endTime: Date?
    var cat: Category?
    var desc: String?
    var duration: TimeInterval {
        set {
        }
        get {
            if endTime != nil {
                return round(endTime!.timeIntervalSince(startTime))
            } else {
                return round(Date().timeIntervalSince(startTime))
            }
        }
    }
    
    // Initializer used when only start time is known
    init( start: Date ) {
        startTime = start
    }
    
    init( start: Date, description:String? ) {
        startTime = start
        if description != nil {
            self.desc = description
        }
    }
    
    init( input:String ) {
        // motherfucker: can't run SwiftyJSON and GTL together.
        
        let encodedInput = input.data(using: String.Encoding.utf8)! as Data
        
        do {
            let json = try JSONSerialization.jsonObject(with: encodedInput, options: .allowFragments) as! [String:Any]
            
            if let startTime = json["startTime"] as? String {
                self.startTime = Clock.dateFromString( startTime )
            }
            if let endTime = json["endTime"] as? String {
                if endTime.characters.count != 0 {
                    self.endTime = Clock.dateFromString( endTime )
                }
            }
            if let desc = json["desc"] as? String {
                self.desc = desc
            }
            if let duration = json["duration"] as? String {
                self.duration = TimeInterval(duration)!
            }
        } catch {
            Flurry.logEvent("error serializing JSON \(input): \(error)")
        }
    }
    
    func updateTime(_ now:Date) {
        duration = now.timeIntervalSince(startTime)
    }
    
    func durationAsString(_ stop:Date) -> String? {
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
        
        return request.jsonString()
    }
    
    func toString() -> String {
        return "\(desc!) \(Clock.getDateTimeString((startTime)))"
    }
}

class ConsolidatedTask {
    var desc:String!
    var duration: TimeInterval = 0.0
    
    init( desc: String ) {
        self.desc = desc
    }
}
