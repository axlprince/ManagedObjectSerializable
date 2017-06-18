//
//  ManagedObjectSerializable.swift
//  MyLifeSave
//
//  Created by AxlPrince on 16/06/17.
//  Copyright © 2017 Vincenzo Masciarelli. All rights reserved.
//

import Foundation
import CoreData


typealias ErrorCode = Int
typealias ErrorDescription = String

enum ManagedObjectSerializableError : Error{
    case invalidReverseSerializationJson(ErrorCode, ErrorDescription)
    case noContextFounded(ErrorCode, ErrorDescription)
    case sourceObjectNotConformToProtocol(ErrorCode, ErrorDescription)
}

public protocol ManagedObjectSerializable {
    var serialized : Bool {get set}
    var dictionary : [String : Any]? {get}
    var jsonData : Data? {get}
    
    func update(from dict: [String : Any]) throws
}


// MARK: - NSManagedObject implementation of ManagedObjectSerializable
extension ManagedObjectSerializable where Self : ManagedObject{
    
    /// This property give us the JSON representation for communication over Network
    var jsonData : Data?{
        if let retVal = self.dictionary{
            return try? JSONSerialization.data(withJSONObject: retVal, options: .prettyPrinted)
        }
        return nil
    }
    
    /// This property give us the Dictionary representation of an NSManagedObject
    var dictionary : [String : Any]? {
        serialized = true
        let propertiesName = Array(self.entity.attributesByName.keys)
        let relationships = Array(self.entity.relationshipsByName.keys)
        
        var dictionary : [String : Any] = [:]
        
        for name in propertiesName{
            //We check if exist a value for the property
            if let storedValue = value(forKey: name){
                dictionary[name] = storedValue
            }
        }
        
        for relationship in relationships{
            //We are checking for a To-Many Relationship
            if let value = value(forKey: relationship), let set = value as? NSSet{
                dictionary[relationship] = makeDictionary(from: set)
            }else if let value = value(forKey: relationship), let orderedSet = value as? NSOrderedSet{
                dictionary[relationship] = makeDictionary(from: orderedSet)
            }else if let value = value(forKey: relationship), let managedObject = value as? ManagedObjectSerializable{
                //Here we are in a To-One Reltionship
                if !serialized, let dict = managedObject.dictionary{
                    dictionary[relationship] = dict
                }
            }
        }
        
        return dictionary
    }
    
    private func makeDictionary(from set: NSSet) -> NSMutableSet{
        let setOfDictionary = NSMutableSet(capacity: set.count)
        //Cycle to make all the objects in the relationship dictionary
        for object in set{
            if let managedObject = object as? ManagedObjectSerializable, !managedObject.serialized, let dict = managedObject.dictionary, !managedObject.serialized{
                setOfDictionary.add(dict)
            }
        }
        return setOfDictionary
    }
    
    private func makeDictionary(from set: NSOrderedSet) -> NSMutableSet{
        let setOfDictionary = NSMutableSet(capacity: set.count)
        //Cycle to make all the objects in the relationship dictionary
        for object in set{
            if let managedObject = object as? ManagedObjectSerializable, !managedObject.serialized, let dict = managedObject.dictionary{
                setOfDictionary.add(dict)
            }
        }
        return setOfDictionary
    }
    
    
    //MARK : - Restoring methods from json to ManagedObject
    
    func update(from dict: [String : Any]) throws{
        
        
        for (key, value) in dict{
            #if DEBUG
                print("Property name : \(key)")
            #endif
            //check to undestand the relationship type. To-One Relationship
            if let data = value as? [String : Any]{
                
                if let managedObject = self.value(forKey: key) as? ManagedObjectSerializable{
                    try? managedObject.update(from: data)
                    self.setValue(managedObject, forKey: key)
                }else{
                    //We try to generate the managedObject if not throw the error corresponding the failure
                    if let className = getClassName(from: key){
                        do{
                            let obj = try createManagedObject(from:data, className: className)
                            self.setValue(obj, forKey: key)
                        }catch let e {
                            throw e
                        }
                    }
                }
            }else if let data = value as? [[String : Any]] {
                //if let name =
                //here we have a To-Many Relationship
                let actualManagedObjects = self.mutableSetValue(forKey: key)
                // FIXME: Here we can delete from local storage objects not properly synchronized with external service
                //We remove all the objects in the collecion to
                actualManagedObjects.removeAllObjects()
                if let className = getClassName(from: key){
                    print("className: \(className)")
                    for dictionary in data{
                        //We try to generate the managedObject if not throw the error corresponding the failure
                        do{
                            let obj = try createManagedObject(from:dictionary, className: className )
                            actualManagedObjects.add(obj)
                            
                        }catch let e {
                            throw e
                        }
                    }
                    self.setValue(actualManagedObjects, forKey: key)
                }
            }else{
                //For NSDate type we only support the time interval initializer
                if let attribute = entity.attributesByName[key], attribute.attributeType == .dateAttributeType{
                    if let timeInterval = dict[key] as? TimeInterval{
                        let date = NSDate(timeIntervalSinceReferenceDate: timeInterval)
                        self.setValue(date, forKey: key)
                        continue
                    }
                    //if we can't extract the time interval we set the value to nil
                    self.setValue(nil, forKey: key)
                }else{
                    //standard attribute
                    self.setValue(value, forKey: key)
                }
            }
        }
    }
    
    
    private func createManagedObject(from dict: [String : Any], className : String) throws -> ManagedObjectSerializable{
        if let context = managedObjectContext{
            let object = NSEntityDescription.insertNewObject(forEntityName: className, into: context)
            if let serializable = object as? ManagedObjectSerializable{
                try? serializable.update(from: dict)
                return serializable
            }else{
                throw ManagedObjectSerializableError.sourceObjectNotConformToProtocol(22, "The object you are trying to deserialize is not conform to ManagedObjectSerializable protocol")
            }
        }else{
            throw ManagedObjectSerializableError.noContextFounded(21, "No NSManagedObjectContext found for this operation \(#function)")
        }
    }
    
    
    private func getClassName(from key: String) -> String?{
        if let attributes = entity.relationshipsByName[key], let relationEntity = attributes.destinationEntity{
            return relationEntity.managedObjectClassName
        }
        return nil
    }
}
