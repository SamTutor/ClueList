//
//  ToDoListDataSourceExt.swift
//  ClueList
//
//  Created by Ryan Rose on 10/18/15.
//  Copyright © 2015 GE. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension ToDoListTableViewController {
    
    // MARK: TableView Delegate
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            let todo = fetchedResultsController.objectAtIndexPath(indexPath) as! ToDoItem
            confirmDeleteForToDo(todo)
        }
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        //the delete icon was pressed, display the action sheet for delete confirmation
        let todo = fetchedResultsController.objectAtIndexPath(indexPath) as! ToDoItem
        confirmDeleteForToDo(todo)
        
        return []
    }
    
    func confirmDeleteForToDo(item: ToDoItem) {
        self.itemToDelete = item
        let alertController = UIAlertController(title: nil, message: "Are you sure you want to permanently delete \(item.text)?", preferredStyle: .ActionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
            self.itemToDelete = nil
        }
        alertController.addAction(cancelAction)
        
        let destroyAction = UIAlertAction(title: "Delete", style: .Destructive) { (action) in
            self.deleteToDo()
        }
        alertController.addAction(destroyAction)
        
        self.presentViewController(alertController, animated: true) {
            // ...
        }
    }
    
    func deleteToDo() {
        if let verseToDelete = self.itemToDelete {
            self.sharedContext.deleteObject(verseToDelete)
            do {
                try self.sharedContext.save()
            } catch {
            }
            
            self.itemToDelete = nil
        }
    }
    
    // MARK: NSFetchedResultsControllerDelegate methods
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controller(
        controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            switch type {
            case NSFetchedResultsChangeType.Insert:
                if let insertIndexPath = newIndexPath {
                    self.tableView.insertRowsAtIndexPaths([insertIndexPath], withRowAnimation: UITableViewRowAnimation.Fade)
                }
            case NSFetchedResultsChangeType.Delete:
                if let deleteIndexPath = indexPath {
                    self.tableView.deleteRowsAtIndexPaths([deleteIndexPath], withRowAnimation: UITableViewRowAnimation.Fade)
                }
            case NSFetchedResultsChangeType.Update:
                break
            case NSFetchedResultsChangeType.Move:
                if let deleteIndexPath = indexPath {
                    self.tableView.deleteRowsAtIndexPaths([deleteIndexPath], withRowAnimation: UITableViewRowAnimation.Fade)
                }
                
                if let insertIndexPath = newIndexPath {
                    self.tableView.insertRowsAtIndexPaths([insertIndexPath], withRowAnimation: UITableViewRowAnimation.Fade)
                }
            }
    }
    
    func controller(
        controller: NSFetchedResultsController,
        didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int,
        forChangeType type: NSFetchedResultsChangeType) {
            
            switch type {
            case .Insert:
                let sectionIndexSet = NSIndexSet(index: sectionIndex)
                self.tableView.insertSections(sectionIndexSet, withRowAnimation: UITableViewRowAnimation.Fade)
            case .Delete:
                let sectionIndexSet = NSIndexSet(index: sectionIndex)
                self.tableView.deleteSections(sectionIndexSet, withRowAnimation: UITableViewRowAnimation.Fade)
            default:
                ""
            }
    }
    
    func controller(controller: NSFetchedResultsController, sectionIndexTitleForSectionName sectionName: String) -> String? {
        return sectionName
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
}