//
//  GoogleSheetService.swift
//  timecard
//
//  Created by DBergh on 4/12/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

protocol SheetServiceProtocol {
    func saveTotal(_ fileName:String,date:String,total:String,taskNames:String)
    func save(_ fileName:String,params:String)
    func setTasksDelegate( _ delegate:Tasks )
}

class GoogleSheetService : NSObject, SheetServiceProtocol {
    
    // backend spreadsheet
    // Google Sheets implementation
    
    fileprivate let kKeychainItemName = "Google Apps Script Execution API"
    fileprivate let kClientID = "970084832900-q2tn9dfqfv31l93ehfj0vbkvmpteibf9.apps.googleusercontent.com"
    fileprivate let kScriptId = "MYk98rtcC6ioYF8bKxS5alPnnEaOUkRCL"
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    fileprivate let scopes = ["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/spreadsheets"]
    let service = GTLService()
    
    var tasksDelegate: Tasks?
    
    // When the parent view loads, initialize the Google Apps Script Execution API service
    func viewDidLoad() {
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.bool(forKey: "hasRunBefore") == false {
            
            // remove keychain items here XXX recover from changing Google password by deleting when re-installing.
            // XXX do the better thing too: re-login after getting an error
            
            
            // update the flag indicator
            userDefaults.set(true, forKey: "hasRunBefore")
            userDefaults.synchronize() // forces the app to update the NSUserDefaults
        }
        
        if let auth = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychain(
            forName: kKeychainItemName,
            clientID: kClientID,
            clientSecret: nil) {
            service.authorizer = auth
        }
    }
    
    // When the view appears, ensure that the Google Apps Script Execution API service is authorized
    // and perform API calls
    func canAuth() -> Bool {
        
        if let authorizer = service.authorizer,
            let canAuth = authorizer.canAuthorize, canAuth {
            return true
        } else {
            return false
        }
    }
    
    func setTasksDelegate( _ delegate:Tasks ) {
        tasksDelegate = delegate
    }
    
    //=================================================================================================
    
    // Google API
    
    func saveTotal(_ fileName:String,date:String,total:String,taskNames:String) {
        
        save(fileName,params: "\(date)|\(total)|\(taskNames)")
    }
    
    func save(_ fileName:String,params:String) {
    
        let baseUrl = "https://script.googleapis.com/v1/scripts/\(kScriptId):run"
        let url = GTLUtilities.url(with: baseUrl, queryParameters: nil)
        
        // Create an execution request object.
        let request = GTLObject()
        request.setJSONValue("appendRowsToSheet", forKey: "function")
        request.setJSONValue("\(fileName)|\(params)", forKey: "parameters")
        
        // Make the API request.
        service.fetchObject(byInserting: request,
                                             for: url,
                                             delegate: self,
                                             didFinish: #selector(self.requestCompleted(_:finishedWithObject:error:)))
    }
    
    // Handle the result returned by the Apps Script function 
    // - throw an error if there was one,
    // - do nothing if there was no error
    @objc func requestCompleted(_ ticket: GTLServiceTicket,
                                finishedWithObject object : GTLObject,
                                                   error : NSError?) {
        
        if let error = error {
            // The API encountered a problem before the script started executing.
            let event = "Google API returned error: \(error.localizedDescription)"
            
            print(event)
            Flurry.logEvent(event)
            
            tasksDelegate?.saveComplete(false,error: event)
            
         } else if let apiError = object.json["error"] as? [String: AnyObject] {
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
            
            print( errMessage )
            Flurry.logEvent(errMessage)
            
            tasksDelegate?.saveComplete(false, error: errMessage)
        } else {
            // no error? don't want no stinking output
            // The result provided by the API needs to be cast into the
            // correct type, based upon what types the Apps Script function
            // returns.
//            if let response = object.JSON["response"] as! [String: AnyObject]? {
//                output.text = response.description
//            }
            
            tasksDelegate?.saveComplete(true, error: nil)
        }
    }
}
