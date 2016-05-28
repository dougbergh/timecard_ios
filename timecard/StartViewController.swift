//
//  StartViewController.swift
//  timecard
//
//  Created by DBergh on 4/20/16.
//  Copyright © 2016 DougBergh. All rights reserved.
//

import Foundation

class StartViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var allNames:[String]!
    var autocompleteNames:[String] = [String]()
    var delegate:StartDelegate? = nil

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var choicesTableView: UITableView!
    
//    init() {
//        super.init()
//    }
    
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        choicesTableView.delegate = self
        choicesTableView.dataSource = self
        choicesTableView.scrollEnabled = true
        choicesTableView.rowHeight = 24
        choicesTableView.hidden = false
        
        autocompleteNames = allNames.sort{ $0 < $1 }    // cause all names to appear before the user types anything
        choicesTableView.reloadData()

        textField.autocorrectionType = .No
        textField.becomeFirstResponder()
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
    {
        choicesTableView.hidden = false
        let substring = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
        
        searchAutocompleteEntriesWithSubstring(substring)
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(textField: UITextField)
    {
        delegate!.confirmStartTask(textField.text!)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func searchAutocompleteEntriesWithSubstring(substring: String)
    {
        autocompleteNames.removeAll(keepCapacity: false)
        
        for curString in allNames
        {
            let myString:NSString! = curString as NSString
            
            let substringRange :NSRange! = myString.rangeOfString(substring)
            
            if (substringRange.location  == 0)
            {
                autocompleteNames.append(curString)
            }
        }
        
        choicesTableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autocompleteNames.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let index = indexPath.row as Int
        let cellIdentifier = "AutoCompleteRowIdentifier"
        let cell = UITableViewCell(style: UITableViewCellStyle.Default , reuseIdentifier: cellIdentifier)
        
        cell.textLabel!.text = autocompleteNames[index]
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selectedCell : UITableViewCell = tableView.cellForRowAtIndexPath(indexPath)!
        textField.text = selectedCell.textLabel!.text
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            let deleted = autocompleteNames.removeAtIndex(indexPath.row)
            delegate!.deleteNameFromAllNames(deleted)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }
}
