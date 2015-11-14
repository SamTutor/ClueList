//
//  EditToDoViewController.swift
//  ClueList
//
//  Created by Ryan Rose on 10/26/15.
//  Copyright © 2015 GE. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import EventKit

//protocol for the delegate
protocol EditToDoViewControllerDelegate {
    func didSetReminder(item: ToDoItem)
}

class EditToDoViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var textField: UITextField!
    @IBOutlet var priorityControl: UISegmentedControl!
    @IBOutlet weak var myDatePicker: UIDatePicker!
    @IBOutlet weak var mySwitch: UISwitch!
    @IBOutlet weak var dateControls: UIView!
    
    var appDelegate: AppDelegate?
    var eventStore: EKEventStore?
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataManager.sharedInstance.managedObjectContext
    }
    var todo: ToDoItem?
    
    var delegate: EditToDoViewControllerDelegate! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textField.delegate = self
        
        // update toolbar
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .Plain, target: self, action: "cancelButtonPressed")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .Plain, target: self, action: "saveButtonPressed")
        title = "Edit Task"
        
        appDelegate = UIApplication.sharedApplication().delegate
            as? AppDelegate
        if appDelegate!.eventStore == nil {
            appDelegate!.eventStore = EKEventStore()
        }
        eventStore = appDelegate!.eventStore
        
        mySwitch.addTarget(self, action: Selector("stateChanged:"), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        textField.text = todo!.text
        textField.becomeFirstResponder()
        // hide date controls until permission is granted to access EventKit
        dateControls.hidden = true
        
        if (todo?.deadline != nil) {
            mySwitch.setOn(true, animated:true)
        } else {
            mySwitch.setOn(false, animated:true)
        }
        myDatePicker.hidden = !mySwitch.on
        
        priorityControl.selectedSegmentIndex = todo!.priority as Int
        
        //ask user permission to access calendar to set reminders
        checkCalendarAuthorizationStatus()
    }
    
    // show/hide date picker based on UISwitch state
    func stateChanged(switchState: UISwitch) {
        myDatePicker.hidden = !switchState.on
    }
    
    // MARK: EventKit Access: https://www.andrewcbancroft.com/2015/05/14/beginners-guide-to-eventkit-in-swift-requesting-permission/
    
    func checkCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatusForEntityType(EKEntityType.Reminder)
        
        switch (status) {
        case EKAuthorizationStatus.NotDetermined:
            // This happens on first-run
            requestAccessToCalendar()
        case EKAuthorizationStatus.Authorized:
            // we have permission, display the reminders controls
            dateControls.hidden = false
        case EKAuthorizationStatus.Restricted, EKAuthorizationStatus.Denied:
            // We need to help them give us permission
            needPermissionView()
        }
    }
    
    func requestAccessToCalendar() {
        eventStore!.requestAccessToEntityType(EKEntityType.Reminder, completion: {
            (accessGranted: Bool, error: NSError?) in
            
            if accessGranted == true {
                dispatch_async(dispatch_get_main_queue(), {
                    self.dateControls.hidden = false
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.needPermissionView()
                })
            }
        })
    }
    
    func needPermissionView() {
        dispatch_async(dispatch_get_main_queue(), {
            // Create the alert controller
            let alertController = UIAlertController(title: "Alert", message: "This application needs access to your calendar in order to set reminders", preferredStyle: .Alert)
            
            // Create the actions
            let okAction = UIAlertAction(title: "Go to Settings", style: UIAlertActionStyle.Default) {
                UIAlertAction in
                let openSettingsUrl = NSURL(string: UIApplicationOpenSettingsURLString)
                UIApplication.sharedApplication().openURL(openSettingsUrl!)
            }
            let cancelAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel) {
                UIAlertAction in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            
            // Add the actions
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)
            
            // Present the controller
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    
    // creates reminder and adds it to the event store: http://www.techotopia.com/index.php/Using_iOS_8_Event_Kit_and_Swift_to_Create_Date_and_Location_Based_Reminders
    func createReminder(item: ToDoItem) {
        let reminder = EKReminder(eventStore: eventStore!)
        
        reminder.title = item.text
        reminder.calendar = eventStore!.defaultCalendarForNewReminders()
        let date = myDatePicker.date
        let alarm = EKAlarm(absoluteDate: date)
        reminder.addAlarm(alarm)
        
        // save the reminder to the event store
        dispatch_async(dispatch_get_main_queue()) {
            do {
                try self.eventStore!.saveReminder(reminder, commit: true)
                //set the deadline date to the reminder date
                item.deadline = date
                try! item.managedObjectContext!.save()
                // call the delegate method to update the parent tableview
                self.delegate.didSetReminder(item)
            } catch {
                let nserror = error as NSError
                NSLog("Reminder failed with error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    func cancelButtonPressed() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func saveButtonPressed() {
        guard let title = textField.text else {
            presentViewController(UIAlertController(title: "Can't update Task", message: "Task can't be blank", preferredStyle: .Alert), animated: true, completion: nil)
            return
        }
        
        let toDo = todo as ToDoItem!
        toDo.text = title
        createReminder(todo!)
        toDo.priority = toDo.selectedPriority(self.priorityControl.selectedSegmentIndex).rawValue
        toDo.metaData.internalOrder = ToDoMetaData.maxInternalOrder(sharedContext)+1
        toDo.metaData.updateSectionIdentifier()
        CoreDataManager.sharedInstance.saveContext()
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: UITextField Delegates
    
    /**
     * Called when 'return' key pressed. return NO to ignore.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    /**
     * Called when the user click on the view (outside the UITextField).
     */
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        textField.resignFirstResponder()
    }
    
}