//
//  ToDoListTableViewController.swift
//  ClueList
//
//  Created by Ryan Rose on 10/12/15.
//  Copyright © 2015 GE. All rights reserved.
//

import UIKit
import CoreData
import EventKit

class ToDoListTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TableViewCellDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var simpleBtn: UIBarButtonItem!
    @IBOutlet weak var prioritizedBtn: UIBarButtonItem!
    
    let cellIdentifier = "ToDoCell"
    
    let segueIdentifier = "editToDoItem"
    
    let PLACEHOLDER_TEXT = "Enter Task"
    
    // Mark: CoreData properties
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataManager.sharedInstance.managedObjectContext
    }
    
    lazy var fetchControllerDelegate: FetchControllerDelegate = {
        
        let delegate = FetchControllerDelegate(tableView: self.tableView)
        delegate.onUpdate = {
            (indexPath: NSIndexPath?, object: AnyObject) in
            self.configureCell(indexPath!, item: object as! ToDoItem)
        }
        
        return delegate
    }()
    
    lazy var toDoListController: ToDoListController = {
        
        let controller = ToDoListController(managedObjectContext: self.sharedContext)
        controller.delegate = self.fetchControllerDelegate
        
        return controller
    }()
    
    lazy var fetchResultsController: NSFetchedResultsController = {
        
        let controller = self.toDoListController.toDosController
        
        return controller
    }()
    
    var itemToDelete: ToDoItem?
    
    private var tagId = 0
    // flag to hide tableview sections when editing a cell
    private var editingToDo = false
    // flag to toggle tableview editing mode
    private var edit = false
    
    private var editBarButtonItem: UIBarButtonItem!
    private var doneBarButtonItem: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // configure the toolbar
        toolbar.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ITEM)
        if (ToDoListConfiguration.defaultConfiguration(sharedContext).listMode == .Simple) {
            simpleBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ACTIVE)
        } else {
            prioritizedBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ACTIVE)
        }
        // create a "Edit" and "Done" button
        editBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Edit, target: self, action: "toggleEdit")
        doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "toggleEdit")
        // display an Edit button in the navigation bar for this view controller.
        navigationItem.leftBarButtonItem = editBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "toDoItemAdded")
        title = "To Do"
        
        configureTableView()
    }
    
    //use the auto layout constraints to determine each cell's height
    //http://www.raywenderlich.com/87975/dynamic-table-view-cell-height-ios-8-swift
    func configureTableView() {
        // TODO: set this from NSKeyedArchiver
        tableView.allowsSelection = false
        
        // Self-sizing table view cells in iOS 8 require that the rowHeight property of the table view be set to the constant UITableViewAutomaticDimension
        tableView.rowHeight = UITableViewAutomaticDimension
        
        // Self-sizing table view cells in iOS 8 are enabled when the estimatedRowHeight property of the table view is set to a non-zero value.
        // Setting the estimated row height prevents the table view from calling tableView:heightForRowAtIndexPath: for every row in the table on first load;
        // it will only be called as cells are about to scroll onscreen. This is a major performance optimization.
        tableView.estimatedRowHeight = 44.0 // set this to whatever your "average" cell height is; it doesn't need to be very accurate
        
        //differentiate background when cell is dragged
        tableView.backgroundColor = UIColor(hexString: Constants.UIColors.TABLE_BG)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(ToDoCellTableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // this can happen if the app font size was changed from phone settings
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refreshList:", name: UIContentSizeCategoryDidChangeNotification, object: nil)
        // listen for refresh events in case ToDos become overdue
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refreshList", name: "TodoListShouldRefresh", object: nil)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIContentSizeCategoryDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "TodoListShouldRefresh", object: nil)
    }
    
    // This function will be called when the Dynamic Type user setting changes (from the system Settings app)
    func refreshList() {
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    override func setEditing(editing: Bool, animated: Bool)  {
        //toggle tableview editing and update toolbar button text
        tableView.setEditing(editing, animated: animated)
        navigationItem.leftBarButtonItem = editing ? doneBarButtonItem : editBarButtonItem
    }
    
    func toggleEdit() {
        edit = !edit
        setEditing(edit, animated: true)
        toDoListController.showsEmptySections = edit
        //hide checkbox controls when editing
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        for cell in visibleCells {
            cell.checkbox.hidden = edit
        }
    }
    
    @IBAction func viewSimple(sender: AnyObject) {
        prioritizedBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ITEM)
        simpleBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ACTIVE)
        ToDoListConfiguration.defaultConfiguration(sharedContext).listMode = .Simple
    }
    
    @IBAction func viewPrioritized(sender: AnyObject) {
        simpleBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ITEM)
        prioritizedBtn.tintColor = UIColor(hexString: Constants.UIColors.TOOLBAR_ACTIVE)
        ToDoListConfiguration.defaultConfiguration(sharedContext).listMode = .Prioritized
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return toDoListController.sections.count
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return toDoListController.sections[section].numberOfObjects
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let item = toDoListController.toDoAtIndexPath(indexPath)
        let cell = configureCell(indexPath, item: item!)
        
        return cell
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        if sourceIndexPath == destinationIndexPath {
            return
        }
        
        fetchControllerDelegate.ignoreNextUpdates = true // Don't let fetched results controller affect table view
        let toDo = toDoListController.toDoAtIndexPath(sourceIndexPath)! // Trust that we will get a toDo back
        
        if sourceIndexPath.section != destinationIndexPath.section {
            
            let sectionInfo = toDoListController.sections[destinationIndexPath.section]
            toDo.metaData.setSection(sectionInfo.section)
            
            // Update cell
            NSOperationQueue.mainQueue().addOperationWithBlock { // Table view is in inconsistent state, gotta wait
                self.configureCell(destinationIndexPath, item: toDo)
            }
        }
        
        updateInternalOrderForToDo(toDo, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
        
        // Save
        try! toDo.managedObjectContext!.save()
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if editingToDo {
            return ""
        } else {
            return toDoListController.sections[section].name
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        //hide sections if currently editing a item
        if editingToDo {
            return 0.0
        } else {
            return 20.0
        }
    }
    
    // UITableView Section Header customization: http://www.elicere.com/mobile/swift-blog-2-uitableview-section-header-color/
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        //recast your view as a UITableViewHeaderFooterView
        if let header = view as? UITableViewHeaderFooterView {
            header.contentView.backgroundColor = UIColor.whiteColor() //make the background color white
            header.textLabel!.textColor = UIColor(red: 0/255, green: 181/255, blue: 229/255, alpha: 1.0) //make the text color light blue
            header.textLabel!.text = header.textLabel!.text!.uppercaseString
            header.textLabel!.font = UIFont.boldSystemFontOfSize(18)
            header.textLabel!.frame = header.frame
        }
    }
    
    //disable table view swipe to delete since we have a custom swipe action already
    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        //only show delete button if in editing mode
        if (self.tableView.editing) {
            return .Delete
        }
        return .None
    }
    
    func tableView(tableView: UITableView, shouldIndentWhileEditingRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    // Override to support conditional editing of the table view.
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier(segueIdentifier, sender: indexPath)
    }
    
    // MARK: - UITextFieldDelegate delegate methods
    
    func cellDidBeginEditing(editingCell: ToDoCellTableViewCell) {
        editingToDo = true
        //ToDoListConfiguration.defaultConfiguration(sharedContext).listMode = .Simple
        let editingOffset = tableView.contentOffset.y - editingCell.frame.origin.y as CGFloat
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        for cell in visibleCells {
            UIView.animateWithDuration(0.3, animations: {() in
                cell.transform = CGAffineTransformMakeTranslation(0, editingOffset)
                if cell !== editingCell {
                    cell.alpha = 0.3
                }
            })
        }
        
    }
    
    func cellDidEndEditing(editCell: ToDoCellTableViewCell) {
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        for cell: ToDoCellTableViewCell in visibleCells {
            UIView.animateWithDuration(0.3, animations: {() in
                cell.transform = CGAffineTransformIdentity
                if cell !== editCell {
                    cell.alpha = 1.0
                }
            })
        }
        // display table section headers again
        editingToDo = false
        if isEmpty(editCell.toDoItem!.text) {
            // if the user did not enter a ToDo then we need to delete it
            toDoItemRemoved(editCell.toDoItem!)
        } else {
            editCell.toDoItem!.editing = false
            editCell.titleLabel.hidden = false
            editCell.bodyLabel.hidden = false
            editCell.editLabel.hidden = true
            try! editCell.toDoItem!.managedObjectContext!.save()
            // get some factoids for this updated ToDoItem from the API
            getFactoids(editCell)
            // reload the tableview
            tableView.reloadData()
        }
    }
    
    // MARK: - add, delete, edit methods
    
    func toDoItemAdded() {
        // hide table section headers before animating table cells
        editingToDo = true
        let dictionary: [String: AnyObject?] = ["text": PLACEHOLDER_TEXT]
        let toDoItem = ToDoItem(dictionary: dictionary, context: sharedContext)
        toDoItem.editing = true
        try! toDoItem.managedObjectContext!.save()
        tableView.reloadData()
        // enter edit mode
        var editCell: ToDoCellTableViewCell
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        for cell in visibleCells {
            // find the toDoItem and initiate it's delegate
            if (cell.toDoItem === toDoItem) {
                editCell = cell
                editCell.editLabelOnly = true
                // initiate cellDidBeginEditing
                editCell.editLabel.becomeFirstResponder()
                break
            }
        }
    }
    
    func toDoItemRemoved(toDoItem: ToDoItem) {
        // loop over the visible cells to animate delete
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        let lastView = visibleCells[visibleCells.count - 1] as ToDoCellTableViewCell
        var delay = 0.0
        var startAnimating = false
        for i in 0..<visibleCells.count {
            let cell = visibleCells[i]
            if startAnimating {
                UIView.animateWithDuration(0.3, delay: delay, options: .CurveEaseInOut,
                    animations: {() in
                        cell.frame = CGRectOffset(cell.frame, 0.0,
                            -cell.frame.size.height)},
                    completion: {(finished: Bool) in
                        if (cell == lastView) {
                            //we reached the end of the table cells, reload the tableview
                            self.tableView.reloadData()
                        }
                    }
                )
                delay += 0.03
            }
            //remove the cell
            if cell.toDoItem === toDoItem {
                startAnimating = true
                cell.hidden = true
                self.sharedContext.deleteObject(toDoItem)
                CoreDataManager.sharedInstance.saveContext()
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if let toDo = toDoListController.toDoAtIndexPath(indexPath) {
            toDo.completed = !toDo.completed.boolValue
            toDo.metaData.updateSectionIdentifier()
            CoreDataManager.sharedInstance.saveContext()
        }
    }
    
    // method to mark/unmark a ToDo by tapping the checkbox control
    func toggleToDoItem(sender: UIButton) {
        //get the selected ToDoItem by it's id from the UIButton title
        let id = sender.titleLabel!.text
        if let item = toDoListController.toDoById(id!) {
            //toggle the completed status
            item.completed = !item.completed.boolValue
            item.metaData.updateSectionIdentifier()
            CoreDataManager.sharedInstance.saveContext()
        }
    }
    
    // MARK: - UIScrollViewDelegate methods
    
    // a cell that is rendered as a placeholder to indicate where a new item is added
    let placeHolderCell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "PlaceHolderCell")
    // indicates the state of this behavior
    var pullDownInProgress = false
    // table cell row heights are based on the cell's content so we use a static value here since we have no content
    let rowHeight = 50.0 as CGFloat;
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        // this behavior starts when a user pulls down while at the top of the table
        pullDownInProgress = scrollView.contentOffset.y <= 0.0
        placeHolderCell.backgroundColor = UIColor.whiteColor()
        if pullDownInProgress {
            // add the placeholder
            tableView.insertSubview(placeHolderCell, atIndex: 0)
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let scrollViewContentOffsetY = scrollView.contentOffset.y
        
        if pullDownInProgress && scrollView.contentOffset.y <= 0.0 {
            // maintain the location of the placeholder
            placeHolderCell.frame = CGRect(x: 0, y: -rowHeight,
                width: tableView.frame.size.width, height: rowHeight)
            placeHolderCell.textLabel!.textAlignment = .Center
            placeHolderCell.textLabel!.text = -scrollViewContentOffsetY > rowHeight ?
                "Release to update \u{2191}" : "Pull to refresh \u{2193}"
            
            placeHolderCell.alpha = min(1.0, -scrollViewContentOffsetY / rowHeight)
        } else {
            pullDownInProgress = false
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // check whether the user pulled down far enough
        if pullDownInProgress && -scrollView.contentOffset.y > rowHeight {
            // add a new item
            refreshFactoids()
        }
        pullDownInProgress = false
        placeHolderCell.removeFromSuperview()
    }
    

    func refreshFactoids() {
        //loop through the visible cells and select another random factoid to display
        let visibleCells = tableView.visibleCells as! [ToDoCellTableViewCell]
        for cell in visibleCells {
            cell.titleLabel.text = cell.toDoItem!.refreshFactoid()
        }
        //force a reload since content length may have changed
        tableView.reloadData()
    }
    
    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == segueIdentifier {
            //get the selected ToDo by the passed index path
            if let object = toDoListController.toDoAtIndexPath(sender as! NSIndexPath) {
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! EditToDoViewController
                //set selected ToDo for our view controller
                controller.todo = object
            }
        }
    }
    
    // MARK: - Private methods
    
    private func getFactoids(cell: ToDoCellTableViewCell) {
        let indexPath = self.tableView.indexPathForCell(cell)
        let item = cell.toDoItem!
        item.requesting = true

        NetworkClient.sharedInstance().getFactoids(item, completionHandler: { (reload, error) in
            //we have a API response - hide the activity indicator
            item.requesting = false
            if let e = error {
                print("configure cell getFactoids error: \(e)")
            }
            // select a random factoid returned from API
            if item.factoids.count > 0 {
                cell.titleLabel.text = item.getRandomFactoid()
            }
            // reload table cell to turn off activity indicator and update autolayout constraints if content was changed
            if (reload != false) {
                // reload individual table cell: http://stackoverflow.com/questions/26709537/reload-cell-data-in-table-view-with-swift
                self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.None)
            }
        })
    }
    
    private func configureCell(indexPath: NSIndexPath, item: ToDoItem) -> ToDoCellTableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! ToDoCellTableViewCell
        // Configure the cell for this indexPath
        cell.updateFonts()
        
        if (!item.editing) {
            //configure the cell checkbox
            cell.checkbox.delegate = cell
            cell.checkbox.selected = item.completed
            cell.checkbox.toDoItem = item
            //use the UIButton label to store the id for this ToDo
            cell.checkbox.titleLabel!.text = item.id
            cell.checkbox.addTarget(self, action: "toggleToDoItem:", forControlEvents: UIControlEvents.TouchUpInside)
            cell.backgroundColor = UIColor.whiteColor()
            cell.checkbox.hidden = false
            
            //make sure we have a valid ToDo
            if !isEmpty(item.text) {
                //do we have some cached factoids to display or do we need to request some?
                if item.factoids.count > 0 {
                    cell.titleLabel.text = item.getRandomFactoid()
                }
            } else {
                //remove blank ToDoItem from db and tableview
                toDoItemRemoved(item)
            }
            
            //highlight overdue items if we have a reminder set
            if (item.isOverdue) { // the current time is later than the to-do item's deadline
                cell.bodyLabel.textColor = UIColor.redColor()
            } else {
                cell.bodyLabel.textColor = UIColor.blackColor() // we need to reset this because a cell with red subtitle may be returned by dequeueReusableCellWithIdentifier:indexPath:
            }
        }
        
        // are we currently requesting factoids?
        if item.requesting {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
            cell.accessoryView = indicator
            indicator.startAnimating()
        } else {
            //indicator.stopAnimating()
            cell.accessoryType = UITableViewCellAccessoryType.DetailButton
        }
        
        // Make sure the constraints have been added to this cell, since it may have just been created from scratch
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        
        cell.delegate = self
        cell.toDoItem = item
        
        return cell
    }
    
    // Helper to identify if textfield is empty or only contains default placeholder text as a value
    private func isEmpty(str: String) -> Bool {
        if str == Constants.Messages.PLACEHOLDER_TEXT || str == "" {
            return true
        } else {
            return false
        }
    }
    
    private func updateInternalOrderForToDo(toDo: ToDoItem, sourceIndexPath: NSIndexPath, destinationIndexPath: NSIndexPath) {
        
        // Now update internal order to reflect new position
        
        // First get all toDos, in sorted order
        var sortedToDos = toDoListController.fetchedToDos()
        sortedToDos = sortedToDos.filter() {$0 != toDo} // Remove current toDo
        
        // Insert toDo at new place in array
        var sortedIndex = destinationIndexPath.row
        for sectionIndex in 0..<destinationIndexPath.section {
            sortedIndex += toDoListController.sections[sectionIndex].numberOfObjects
            if sectionIndex == sourceIndexPath.section {
                sortedIndex -= 1 // Remember, controller still thinks this toDo is in the old section
            }
        }
        sortedToDos.insert(toDo, atIndex: sortedIndex)
        
        // Regenerate internal order for all toDos
        for (index, toDo) in sortedToDos.enumerate() {
            toDo.metaData.internalOrder = sortedToDos.count-index
        }
    }

}
