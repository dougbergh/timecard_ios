//
//  GoogleSheetService.swift
//  timecard
//
//  Created by DBergh on 4/12/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

protocol SheetServiceProtocol {
    func saveDay(date:NSDate,total:NSTimeInterval,taskNames:String)
    func setTasksDelegate( delegate:Tasks )
}

class GoogleSheetService : NSObject, SheetServiceProtocol {
    
    // backend spreadsheet
    // Google Sheets implementation
    
    private let kKeychainItemName = "Google Apps Script Execution API"
    private let kClientID = "970084832900-q2tn9dfqfv31l93ehfj0vbkvmpteibf9.apps.googleusercontent.com"
    private let kScriptId = "MYk98rtcC6ioYF8bKxS5alPnnEaOUkRCL"
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    private let scopes = ["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/spreadsheets"]
    let service = GTLService()
    
    var tasksDelegate: Tasks?
    
    // When the parent view loads, initialize the Google Apps Script Execution API service
    func viewDidLoad() {
        
        if let auth = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychainForName(
            kKeychainItemName,
            clientID: kClientID,
            clientSecret: nil) {
            service.authorizer = auth
        }
    }
    
    // When the view appears, ensure that the Google Apps Script Execution API service is authorized
    // and perform API calls
    func canAuth() -> Bool {
        
        if let authorizer = service.authorizer,
            canAuth = authorizer.canAuthorize where canAuth {
            return true
        } else {
            return false
        }
    }
    
    func setTasksDelegate( delegate:Tasks ) {
        tasksDelegate = delegate
    }
    
    //=================================================================================================
    
    // Google API
    
    func monthYear(date:NSDate) -> (String,String) {
        let fmt = NSDateFormatter()
        fmt.dateStyle = NSDateFormatterStyle.LongStyle
        let dateString = fmt.stringFromDate(date)
        let dateArray = dateString.characters.split(" ")
        let month = String(dateArray[0])
        let year = String(dateArray[2])
        
        return (month,year)
    }
    
    func saveTask(date:NSDate,total:NSTimeInterval,taskName:String) {
        let (month,year) = monthYear(date)
        let filename = "\(month) \(year) tasks"
        
        save(filename,date: date,total: total,taskNames: taskName)
    }
    
    func saveDay(date:NSDate,total:NSTimeInterval,taskNames:String) {
        let (month,year) = monthYear(date)
        let filename = "\(month) \(year)"
        
        save(filename,date: date,total: total,taskNames: taskNames)
        
    }
    
    func save(fileName:String,date:NSDate,total:NSTimeInterval,taskNames:String) {
        
        let fmt = NSDateFormatter()
        fmt.dateStyle = NSDateFormatterStyle.ShortStyle
        
        let baseUrl = "https://script.googleapis.com/v1/scripts/\(kScriptId):run"
        let url = GTLUtilities.URLWithString(baseUrl, queryParameters: nil)
        
        // Create an execution request object.
        let request = GTLObject()
        request.setJSONValue("appendRowToMonthly", forKey: "function")
        request.setJSONValue("\(fileName)|\(fmt.stringFromDate(date))|\(Clock.getDurationString(total)!)|\(taskNames)", forKey: "parameters")
        
        // Make the API request.
        service.fetchObjectByInsertingObject(request,
                                             forURL: url,
                                             delegate: self,
       didFinishSelector: #selector(self.displayResultWithTicket(_:finishedWithObject:error:)))
    }
    
    // Displays the result returned by the Apps Script function.
    @objc func displayResultWithTicket(ticket: GTLServiceTicket,
                                        finishedWithObject object : GTLObject,
                                                           error : NSError?) {
        
        var success = true
        
        if let error = error {
            // The API encountered a problem before the script started executing.
            print(("The API returned the error: ",
                      message: error.localizedDescription))
            success = false

         } else if let apiError = object.JSON["error"] as? [String: AnyObject] {
            // The API executed, but the script returned an error.
            
            // Extract the first (and only) set of error details and cast as
            // a Dictionary. The values of this Dictionary are the script's
            // 'errorMessage' and 'errorType', and an array of stack trace
            // elements (which also need to be cast as Dictionaries).
            let details = apiError["details"] as! [[String: AnyObject]]
            var errMessage = String(
                format:"Script error message: %@\n",
                details[0]["errorMessage"] as! String)
            
            if let stacktrace =
                details[0]["scriptStackTraceElements"] as? [[String: AnyObject]] {
                // There may not be a stacktrace if the script didn't start
                // executing.
                for trace in stacktrace {
                    let f = trace["function"] as? String ?? "Unknown"
                    let num = trace["lineNumber"] as? Int ?? -1
                    errMessage += "\t\(f): \(num)\n"
                }
            }
            
            // Set the output as the compiled error message.
            print(errMessage)
            
            success = false
        } else {
            // no error? don't want no stinking output
            // The result provided by the API needs to be cast into the
            // correct type, based upon what types the Apps Script function
            // returns.
//            if let response = object.JSON["response"] as! [String: AnyObject]? {
//                output.text = response.description
//            }
        }
        
        tasksDelegate?.saveComplete(success)
    }
}
