# ManagedObjectSerializable
A protocol that defines common methods to serialize NSManagedObject into JSON and viceversa

## Usage NSManaged to JSON:
1. Import the module on your project in manual mode (Embedded Bynary)
2. Import ManagedObjectSerializable
3. Inherits Managedobject from yuor NSManagedObject model

```swift
class Person : ManagedObject{
  @NSManaged var firstName : String?
  @NSManaged var lastName : String?
}

let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context)

person.firstName = "foo"
person.lastName = "bar"

let dictRepresentation = person.dictionary?
let jsonData = dictRepresentation?.jsonData

//Use the json data or the dictionary representation as you like
//Enjoy!
```

## Usage JSON to NSManaged:

```swift
class Person : ManagedObject{
  @NSManaged var firstName : String?
  @NSManaged var lastName : String?
}

let wsData : [String : Any] = [
    "firstName" : "foo"
    "lastname"  : "bar"
]

let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context)

person.update(from: wsData)

//Use the json data or the dictionary representation as you like
//Enjoy!
```
