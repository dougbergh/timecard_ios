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
        func deleteNameFromAllNames(deleted:String)
    }
    
    class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ClockDelegate, StartDelegate {
        
        // view

        //        @IBOutlet weak var bgImage: UIImageView!
        @IBOutlet weak var timeLabel: UILabel!
        @IBOutlet weak var stopButton: UIButton!
        @IBOutlet weak var startButton: UIButton!
        @IBOutlet weak var activeTaskView: UIView!
        @IBOutlet weak var activeTaskLabel: UILabel!
        @IBOutlet weak var activeTaskTableView: UITableView!
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
            }
            
            activeTaskTableView.dataSource = self
            activeTaskTableView.delegate = self
            drawBlackBorder(activeTaskView)
            
            drawBlackBorder(totalTodayView)
            
            drawBlackBorder(sheetLinkButton)
        }

        override func viewDidAppear(animated: Bool) {
            
            //  (re)set state
            
            if taskActive {
                self.setActiveTaskInView()
            } else {
                clearActiveTaskInView(nil)
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
            self.setActiveTaskInView()
        }
        
        func deleteNameFromAllNames(deleted: String) {
            tasks.deleteNameFromAllNames(deleted)
        }
        
        //
        // Stop an existing task
        //
        @IBOutlet var stopConfirmTextField: UITextField!
        @IBAction func stopTaskOnTouch(sender: UIButton) {
            
            let menu = UIAlertController(title: nil, message: "Confirm Task Description", preferredStyle: UIAlertControllerStyle.Alert)
            
            menu.addTextFieldWithConfigurationHandler(stopConfigurationTextField)
            
            menu.addAction(UIAlertAction(title: "OK", style: .Default , handler: { (action) in
                self.tasks.currentlyActiveTask!.desc = self.stopConfirmTextField.text
                self.tasks.taskEnded(NSDate())
                self.clearActiveTaskInView(sender)
            }))
            self.presentViewController(menu, animated: true, completion: nil)
        }
        
        func stopConfigurationTextField(textField: UITextField!) {
            textField.text = self.tasks.currentlyActiveTask!.desc
            self.stopConfirmTextField = textField
        }
        
        func setActiveTaskInView() {
            
            activeTaskView.hidden = false
            activeTaskLabel.text = "Active Task"
            
            startButton.hidden = true
            stopButton.hidden = false
        }
        
        func setActiveTaskInModel(date:NSDate, desc:String?) {
            
            let task = Task( start: date, description: desc )
            tasks.taskStarted( task )
        }
        
        func clearActiveTaskInView(sender:UIButton?) {
            activeTaskView.hidden = true
            startButton.hidden = false
            stopButton.hidden = true
        }
        
        func updateTime( newTime: NSDate ) {
            timeLabel.text = Clock.getTimeString( newTime )
            
            if taskActive == true {
                tasks.currentlyActiveTask!.updateTime( newTime )
                activeTaskTableView.reloadData()
            }

            totalTodayDurationLabel.text = tasks.totalDurationIntervalAsString(Clock.dayStart(NSDate()),end: Clock.dayEnd(NSDate()))
            
            // If this is the first run of a day, there is bookkeeping to do..
            tasks.checkForDailyActivity()
        }
        
        func drawBlackBorder(view: UIView) {
            view.layer.borderColor = UIColor.blackColor().CGColor
            view.layer.borderWidth = 2.0
            view.layer.cornerRadius = 8
        }
        
        func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 3  // name, start, duration
        }
        
        func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: UITableViewCellStyle.Value2, reuseIdentifier: nil)
            switch indexPath.item {
            case 0:
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = tasks.currentlyActiveTask?.desc
            case 1:
                cell.textLabel?.text = "Started"
                cell.detailTextLabel?.text = Clock.getTimeString(tasks.currentlyActiveTask?.startTime)
            case 2:
                cell.textLabel?.text = "Time So Far"
                cell.detailTextLabel?.text = tasks.currentlyActiveTask?.durationAsString(NSDate())
            default: break
            }
            
            return cell
        }
        
        func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
            
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
            
//            if let error = error {
//                sheetService.service.authorizer = nil
//                showAlert("Authentication Error", message: error.localizedDescription)
//                return
//            }
            
            sheetService.service.authorizer = authResult
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    extension ViewController {
        // Helper for showing an alert
        static func showAlert(title : String, message: String) {
            let alert = UIAlertView(
                title: title,
                message: message,
                delegate: nil,
                cancelButtonTitle: "OK"
            )
            alert.show()
        }

    }
