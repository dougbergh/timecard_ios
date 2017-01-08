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
        choicesTableView.isScrollEnabled = true
        choicesTableView.rowHeight = 24
        choicesTableView.isHidden = false     // cause all names to appear before the user types anything
        
        allNames = allNames.sorted{ $0 < $1 }
        autocompleteNames = allNames
        choicesTableView.reloadData()

        textField.autocorrectionType = .no
        textField.becomeFirstResponder()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        choicesTableView.isHidden = false
        let substring = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        
        searchAutocompleteEntriesWithSubstring(substring)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        delegate!.confirmStartTask(textField.text!)
        self.dismiss(animated: true, completion: nil)
    }
    
    func searchAutocompleteEntriesWithSubstring(_ substring: String)
    {
        autocompleteNames.removeAll(keepingCapacity: false)
        
        for curString in allNames
        {
            let myString:NSString! = curString as NSString
            
            let substringRange :NSRange! = myString.range(of: substring)
            
            if (substringRange.location  == 0 || substring.isEmpty == true)
            {
                autocompleteNames.append(curString)
            }
        }
        
        choicesTableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autocompleteNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let index = indexPath.row as Int
        let cellIdentifier = "AutoCompleteRowIdentifier"
        let cell = UITableViewCell(style: UITableViewCellStyle.default , reuseIdentifier: cellIdentifier)
        
        cell.textLabel!.text = autocompleteNames[index]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCell : UITableViewCell = tableView.cellForRow(at: indexPath)!
        textField.text = selectedCell.textLabel!.text
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            let deleted = autocompleteNames.remove(at: indexPath.row)
            delegate!.deleteNameFromAllNames(deleted)
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
    }
}
