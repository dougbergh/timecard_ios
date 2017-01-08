    //
    //  ViewController.swift
    //  timecard
    //
    //  Created by DBergh on 3/10/16.
    //  Copyright © 2016 DougBergh. All rights reserved.
    //
    
    import UIKit
    
    protocol StartDelegate {
        func confirmStartTask(_ name:String)
        func deleteNameFromAllNames(_ deleted:String)
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
        
        @IBAction func sheetLinkButtonPressed(_ sender: UIButton) {
            if let url = URL(string: "https://drive.google.com/drive/my-drive") {
                UIApplication.shared.openURL(url)
            }

        }
        
        // backend spreadsheet 
        // Google Sheets implementation
        let sheetService = GoogleSheetService()
        
        
        // Google API
        fileprivate let kKeychainItemName = "Google Apps Script Execution API"
        // =====
        fileprivate let kClientID = "970084832900-q2tn9dfqfv31l93ehfj0vbkvmpteibf9.apps.googleusercontent.com"
        fileprivate let kScriptId = "MYk98rtcC6ioYF8bKxS5alPnnEaOUkRCL"
        
        
        // If modifying these scopes, delete your previously saved credentials by
        // resetting the iOS simulator or uninstall the app.
        fileprivate let scopes = ["https://www.googleapis.com/auth/drive","https://www.googleapis.com/auth/spreadsheets"]
        fileprivate let service = GTLService()
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
            
            timeLabel.text = Clock.getTimeString( Date() )
            
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

        override func viewDidAppear(_ animated: Bool) {
            
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
                present(createAuthController(),animated: true,completion: nil)
            }
        }
        
        //=================================================================================================
        
        
        //
        // User has pressed the Start button. The system creates a segue to the StartViewController
        // to allow the user to enter the task's name (or select from past tasks).
        // Here, we prep the StartViewController with the necessary context.
        //
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            
            let destVC = segue.destination as! StartViewController
            destVC.delegate = self
            destVC.allNames = tasks.getAllNames()
        }

        //
        // The user has completed entering a task name in the StartViewController
        //
        func confirmStartTask( _ name:String ) {
            let date = Date()
            self.setActiveTaskInModel(date, desc: name)
            self.setActiveTaskInView()
        }
        
        func deleteNameFromAllNames(_ deleted: String) {
            tasks.deleteNameFromAllNames(deleted)
        }
        
        //
        // Stop an existing task
        //
        @IBAction func stopTaskOnTouch(_ sender: UIButton) {
            
            let confirmController = UIAlertController(title: nil, message: "Confirm Task Atrributes", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction = UIAlertAction(title: "OK", style: .default , handler: {
                alert -> Void in
                
                let descTextField = confirmController.textFields![0] as UITextField
                let startTextField = confirmController.textFields![1] as UITextField
                let endTextField = confirmController.textFields![2] as UITextField
                
                let today = Date()
                startTextField.text = Clock.getDateString(today)+", "+startTextField.text!
                endTextField.text = Clock.getDateString(today)+", "+endTextField.text!
                
                self.tasks.currentlyActiveTask!.desc = descTextField.text
                self.tasks.currentlyActiveTask!.startTime = Clock.dateFromString(startTextField.text!)
                self.tasks.currentlyActiveTask!.endTime = Clock.dateFromString(endTextField.text!)

                self.tasks.taskEnded(Date())
                self.clearActiveTaskInView(sender)
            })
            
            confirmController.addTextField(configurationHandler:activeTaskDescription)
            confirmController.addTextField(configurationHandler:activeTaskStart)
            confirmController.addTextField(configurationHandler:activeTaskEnd)
            
            confirmController.addAction( okAction )

            self.present(confirmController, animated: true, completion: nil)
        }
        
        func activeTaskDescription(_ textField: UITextField!) {
            textField.text = self.tasks.currentlyActiveTask!.desc
        }
        
        func activeTaskStart(_ textField: UITextField!) {
            textField.text = Clock.getTimeString(self.tasks.currentlyActiveTask!.startTime)
        }
        
        func activeTaskEnd(_ textField: UITextField!) {
            textField.text = Clock.getTimeString(Date())
        }
        
        func setActiveTaskInView() {
            
            activeTaskView.isHidden = false
            activeTaskLabel.text = "Active Task"
            
            startButton.isHidden = true
            stopButton.isHidden = false
        }
        
        func setActiveTaskInModel(_ date:Date, desc:String?) {
            
            let task = Task( start: date, description: desc )
            tasks.taskStarted( task )
        }
        
        func clearActiveTaskInView(_ sender:UIButton?) {
            activeTaskView.isHidden = true
            startButton.isHidden = false
            stopButton.isHidden = true
        }
        
        func updateTime( _ newTime: Date ) {
            timeLabel.text = Clock.getTimeString( newTime )
            
            if taskActive == true {
                tasks.currentlyActiveTask!.updateTime( newTime )
                activeTaskTableView.reloadData()
            }

            totalTodayDurationLabel.text = tasks.totalDurationIntervalAsString(Clock.dayStart(Date()),end: Clock.dayEnd(Date()))
            
            // If this is the first run of a day, there is bookkeeping to do..
            tasks.checkForDailyActivity()
        }
        
        func drawBlackBorder(_ view: UIView) {
            view.layer.borderColor = UIColor.black.cgColor
            view.layer.borderWidth = 2.0
            view.layer.cornerRadius = 8
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 3  // name, start, duration
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: UITableViewCellStyle.value2, reuseIdentifier: nil)
            switch indexPath.item {
            case 0:
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = tasks.currentlyActiveTask?.desc
            case 1:
                cell.textLabel?.text = "Started"
                cell.detailTextLabel?.text = Clock.getTimeString(tasks.currentlyActiveTask?.startTime)
            case 2:
                cell.textLabel?.text = "Time So Far"
                cell.detailTextLabel?.text = tasks.currentlyActiveTask?.durationAsString(Date())
            default: break
            }
            
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            
        }
        
        func datePickerChanged(_ datePicker:UIDatePicker) {
            // work around fuckism in UIDatePicker: can't prevent year from being dislpayed and changed -
            // by disallowing the year to change
            datePicker.date = Clock.thisYear( datePicker.date )
            updateTotal(datePicker)
        }
        
        func updateTotal(_ datePicker:UIDatePicker) {
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
        fileprivate func createAuthController() -> GTMOAuth2ViewControllerTouch {
            let scopeString = scopes.joined(separator: " ")
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
        func viewController(_ vc : UIViewController,
                            finishedWithAuth authResult : GTMOAuth2Authentication, error : NSError?) {
            
//            if let error = error {
//                sheetService.service.authorizer = nil
//                showAlert("Authentication Error", message: error.localizedDescription)
//                return
//            }
            
            sheetService.service.authorizer = authResult
            dismiss(animated: true, completion: nil)
        }
    }
    
    extension ViewController {
        // Helper for showing an alert
        static func showAlert(_ title : String, message: String) {
            let alert = UIAlertView(
                title: title,
                message: message,
                delegate: nil,
                cancelButtonTitle: "OK"
            )
            alert.show()
        }

    }
