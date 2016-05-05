    //
    //  ViewController.swift
    //  timecard
    //
    //  Created by DBergh on 3/10/16.
    //  Copyright © 2016 DougBergh. All rights reserved.
    //
    
    import UIKit
    
    protocol StartDelegate {
        func confirmStartTask(name:String)
    }
    
    class ViewController: UIViewController, ClockDelegate, StartDelegate {
        
        // view

        //        @IBOutlet weak var bgImage: UIImageView!
        @IBOutlet weak var timeLabel: UILabel!
        @IBOutlet weak var stopButton: UIButton!
        @IBOutlet weak var startButton: UIButton!
        @IBOutlet weak var activeTaskView: UIView!
        @IBOutlet weak var activeTaskLabel: UILabel!
        @IBOutlet weak var activeTaskStartTimeLabel: UILabel!
        @IBOutlet weak var activeTaskDurationLabel: UILabel!
        @IBOutlet weak var totalTodayView: UIView!
        @IBOutlet weak var totalTodayLabel: UILabel!
        @IBOutlet weak var totalTodayDurationLabel: UILabel!
        @IBOutlet weak var datePickerView: UIDatePicker!
        @IBOutlet weak var sheetLinkButton: UIButton!
        
        @IBAction func sheetLinkButtonPressed(sender: UIButton) {
            if let url = NSURL(string: "https://drive.google.com/drive/my-drive") {
                UIApplication.sharedApplication().openURL(url)
            }

        }
        
        // backend spreadsheet 
        // Google Sheets implementation
        let sheetService = GoogleSheetService()
        
        
        // Google API
        private let kKeychainItemName = "Google Apps Script Execution API"
        // =====
        private let kClientID = "970084832900-q2tn9dfqfv31l93ehfj0vbkvmpteibf9.apps.googleusercontent.com"
        private let kScriptId = "MYk98rtcC6ioYF8bKxS5alPnnEaOUkRCL"
        
        
        // If modifying these scopes, delete your previously saved credentials by
        // resetting the iOS simulator or uninstall the app.
        private let scopes = ["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/spreadsheets"]
        private let service = GTLService()
        let output = UITextView()
        

        
        // model
        
        var tasks: Tasks!   // historian of tasks
        var clock: Clock!   // timekeeper

        
        // controller
        
        var taskActive: Bool {
            get {
                if tasks == nil { return false }
                if tasks.currentlyActiveTask == nil { return false }
                return true
            }
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            // set up data structures
            
            sheetService.viewDidLoad()
            
            if clock == nil { clock = Clock(clockDelegate: self) }
            
            timeLabel.text = Clock.getTimeString( NSDate() )
            
            if tasks == nil {
                tasks = Tasks()
                tasks.setSheetService(sheetService)
                tasks.viewDidLoad()
            } else {
                print("viewDidLoad and tasks!=nil")
            }
            
            if activeTaskView == nil {
                activeTaskView = UIView()
                drawBlackBorder(activeTaskView)
            }
            
            drawBlackBorder(totalTodayView)
            
//            datePickerView.datePickerMode = UIDatePickerMode.Date
//            datePickerView.addTarget(self, action: #selector(ViewController.datePickerChanged(_:)), forControlEvents: UIControlEvents.ValueChanged)
            
            drawBlackBorder(sheetLinkButton)
            sheetLinkButton.setTitle("Previous Days' Totals", forState: UIControlState.Normal)
        }

        override func viewDidAppear(animated: Bool) {
            
            //  (re)set state
            
            if taskActive {
                startButton.hidden = true
                stopButton.hidden = false
                activeTaskView.hidden = false
            } else {
                startButton.hidden = false
                stopButton.hidden = true
                activeTaskView.hidden = true
            }
            
            // ensure that the Google Apps Script Execution API service is authorized - this 
            // is where the Google login alert appears
            if sheetService.canAuth() {
            } else {
                presentViewController(createAuthController(),animated: true,completion: nil)
            }
        }
        
        //=================================================================================================
        
        
        //
        // Start a new task - with AlertAction to enter name
        //
//        @IBAction func startTaskOnTouch(sender: UIButton) {
//            
//            let menu = UIAlertController(title: nil, message: "Task Description", preferredStyle: UIAlertControllerStyle.Alert)
//            
//            menu.addTextFieldWithConfigurationHandler(configurationTextField)
//            
//            menu.addAction(UIAlertAction(title: "OK", style: .Default , handler: { (UIAlertAction)in
//                let date = NSDate()
//                self.setActiveTaskInModel(date, desc: menu.textFields![0].text)
//                self.setActiveTaskInView(date)
//            }))
//            self.presentViewController(menu, animated: true, completion: nil)
//        }
//        func configurationTextField(textField: UITextField!) {
//            textField.text = ""
//        }
        
        //
        // User has pressed the Start button. The system creates a segue to the StartViewController
        // to allow the user to enter the task's name (or select from past tasks).
        // Here, we prep the StartViewController with the necessary context.
        //
        override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
            
            let destVC = segue.destinationViewController as! StartViewController
            destVC.delegate = self
            destVC.allNames = tasks.getAllNames()
        }

        //
        // The user has completed entering a task name in the StartViewController
        //
        func confirmStartTask( name:String ) {
            let date = NSDate()
            self.setActiveTaskInModel(date, desc: name)
            self.setActiveTaskInView(date)
        }
        
        //
        // Stop an existing task
        //
        @IBAction func stopTaskOnTouch(sender: UIButton) {
            
            let menu = UIAlertController(title: nil, message: "Confirm Task Description", preferredStyle: UIAlertControllerStyle.Alert)
            
            menu.addTextFieldWithConfigurationHandler(stopConfigurationTextField)
            
            menu.addAction(UIAlertAction(title: "OK", style: .Default , handler: { (UIAlertAction)in
                self.tasks.taskEnded(NSDate())
                self.clearActiveTaskInView(sender)
            }))
            self.presentViewController(menu, animated: true, completion: nil)
        }
        
        func stopConfigurationTextField(textField: UITextField!) {
            textField.text = self.tasks.currentlyActiveTask!.desc
        }
        
        func setActiveTaskInView(startTime: NSDate) {
            
            drawBlackBorder(activeTaskView)
            activeTaskView.hidden = false
            activeTaskLabel.text = tasks.currentlyActiveTask!.desc
            activeTaskStartTimeLabel.text = Clock.getTimeString(startTime)
            startButton.hidden = true
            stopButton.hidden = false
        }
        
        func setActiveTaskInModel(date:NSDate, desc:String?) {
            
            let task = Task( start: date, description: desc )
            tasks.taskStarted( task )
        }
        
        func clearActiveTaskInView(sender:UIButton?) {
            activeTaskView.hidden = true
            if sender != nil { sender!.hidden = true }
            startButton.hidden = false
        }
        
        func updateTime( newTime: NSDate ) {
            timeLabel.text = Clock.getTimeString( newTime )
            
            if taskActive == true {
                tasks.currentlyActiveTask!.updateTime( newTime )
                let duration = tasks.currentlyActiveTask!.durationAsString(newTime)
                activeTaskDurationLabel.text = duration
            }
//            updateTotal(datePickerView)
            totalTodayDurationLabel.text = tasks.totalDurationIntervalAsString(Clock.dayStart(NSDate()),end: Clock.dayEnd(NSDate()))
            
            // If this is the first run of a day, there is bookkeeping to do..
            tasks.checkForDailyActivity()
        }
        
        func drawBlackBorder(view: UIView) {
            view.layer.borderColor = UIColor.blackColor().CGColor
            view.layer.borderWidth = 2.0
            view.layer.cornerRadius = 8
        }
        
        func datePickerChanged(datePicker:UIDatePicker) {
            // work around fuckism in UIDatePicker: can't prevent year from being dislpayed and changed -
            // by disallowing the year to change
            datePicker.date = Clock.thisYear( datePicker.date )
            updateTotal(datePicker)
        }
        
        func updateTotal(datePicker:UIDatePicker) {
            let morning = Clock.dayStart(datePicker.date)
            let evening = Clock.dayEnd(datePicker.date)
            let total = tasks.totalDurationIntervalAsString(morning,end: evening)
            totalTodayDurationLabel.text = total
        }
        
        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
            // Dispose of any resources that can be recreated.
        }
        
        
        // Creates the auth controller for authorizing access to Google Apps Script Execution API
        private func createAuthController() -> GTMOAuth2ViewControllerTouch {
            let scopeString = scopes.joinWithSeparator(" ")
            return GTMOAuth2ViewControllerTouch(
                scope: scopeString,
                clientID: kClientID,
                clientSecret: nil,
                keychainItemName: kKeychainItemName,
                delegate: self,
                finishedSelector: #selector(ViewController.viewController(_:finishedWithAuth:error:))
            )
        }
        
        // Handle completion of the authorization process, and update the Google Apps Script Execution API
        // with the new credentials.
        func viewController(vc : UIViewController,
                            finishedWithAuth authResult : GTMOAuth2Authentication, error : NSError?) {
            
            if let error = error {
                sheetService.service.authorizer = nil
                showAlert("Authentication Error", message: error.localizedDescription)
                return
            }
            
            sheetService.service.authorizer = authResult
            dismissViewControllerAnimated(true, completion: nil)
        }
        
        // Helper for showing an alert
        func showAlert(title : String, message: String) {
            let alert = UIAlertView(
                title: title,
                message: message,
                delegate: nil,
                cancelButtonTitle: "OK"
            )
            alert.show()
        }
    }
    
