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
        
        // backend spreadsheet 
        // Google Sheets implementation
        let sheetService = GoogleSheetService()
        
        
        // Google API
        private let kKeychainItemName = "Google Apps Script Execution API"
//        private let kClientID = "372245564407-c58g1pbe0chkqpdl66v4non1hrike30f.apps.googleusercontent.com"
//        private let kScriptId = "M4TjLR3wP6pwa1L50fZMY1PnnEaOUkRCL"
//        private let kClientID = "876244791287-vhcspc4sf6ahlp26v0focp5gj2aij51v.apps.googleusercontent.com"
//        private let kScriptId = "MZq2EboWEHbZs7vcYvh55GPnnEaOUkRCL"
        
//        private let kScriptId = "M4KHtVf505JzlVOQwz3EOnUbOSAplbjFt"
        
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
            
            sheetService.viewDidLoad()
            
            //                    bgImage.image = UIImage(named: "bgImage")
            //                    bgImage.alpha = 0.1
            
            if clock == nil { clock = Clock(clockDelegate: self) }
            
            timeLabel.text = Clock.getTimeString( NSDate() )
            
            if tasks == nil {
                tasks = Tasks()
                tasks.setSheetService(sheetService)
            }
            
            if activeTaskView == nil {
                activeTaskView = UIView()
                drawBlackBorder(activeTaskView)
            }
            
            drawBlackBorder(totalTodayView)
            
            if taskActive {
                if clock == nil { clock = Clock(clockDelegate: self) }
                
                startButton.hidden = true
                stopButton.hidden = false
                activeTaskView.hidden = false
            } else {
                startButton.hidden = false
                stopButton.hidden = true
                activeTaskView.hidden = true
            }
            
            datePickerView.datePickerMode = UIDatePickerMode.Date
            datePickerView.addTarget(self, action: #selector(ViewController.datePickerChanged(_:)), forControlEvents: UIControlEvents.ValueChanged)
        }

        // When the view appears, ensure that the Google Apps Script Execution API service is authorized
        override func viewDidAppear(animated: Bool) {
            
            if sheetService.canAuth() {
                
            } else {
                presentViewController(createAuthController(),animated: true,completion: nil)
            }
        }
        
        //=================================================================================================
        
        
        //
        // Start a new task
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
        // Start a new task
        //
//        @IBAction func startTaskOnTouch(sender: UIButton) {
//            
//            
//            let alert = StartViewController()
//            alert.delegate = self
//            alert.choices = tasks.getAllNames()
//            
////            performSegueWithIdentifier("startSegue",sender:sender)
//            self.presentViewController(alert, animated: true, completion: nil)
//        }
        
        override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
            
            let destVC = segue.destinationViewController as! StartViewController
            destVC.delegate = self
            destVC.choices = tasks.getAllNames()
            
//            guard let segueId = segue.identifier else { return }
//            
//            switch segueId {
//            case "startSegue":
//                let destVC = segue.destinationViewController as! StartViewController
//                destVC.delegate = self
//                break
//            default:
//                break
//            }
        }

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
            updateTotal(datePickerView)
            
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
    
