IPFS API wrapper library written in Swift
=========================================

> A client library for the IPFS API.

For more information about [IPFS](http://ipfs.io) or the [API commands](http://ipfs.io/docs/commands) click the links.

The Swift IPFS API shell/client is an asynchronous library that provides native calls to an IPFS node.

## Installation

In the root of your project:

-  Add a Cartfile (or use an existing one) with the following:
```
github "NeoTeo/swift-ipfs-api"
```
- To fetch and build the dependencies, type:
```carthage update --no-use-binaries --platform Mac```

or

```carthage update --no-use-binaries --platform iOS```

For more information on how to install via Carthage see the [README](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)

## Usage
Add the required frameworks to your project in Xcode:

- In your target's `build phases` tab.

- Click the `+` in the upper left corner and pick the `New Copy Files Phase` from the drop-down.
- Select the Destination `Frameworks` and click the `+` to `Add Other...` buttons.
- Navigate to the Carthage/Build/Mac directory in your project root and select all the frameworks in the folder.

## Examples

In your code: 
```Swift
import SwiftIpfsApi

/// For brevity we are not catching failed try's. You should.
let api = try! SwiftIpfsApi("127.0.0.1", "5001") 

try! api.id() {
    (idData : JsonType) in
                    
    print("Yay, I've got an id: "+ idData.object?["ID"]?.string)
}
```

The Swift IPFS API client is asynchronous, but if you want to use a command synchronously (eg. if you run it in its own thread) you can always use dispatch groups:
```Swift
let group = dispatch_group_create()
dispatch_group_enter(group)

let multihash = try! fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK") 

try! api.refs(multihash, recursive: false) {
    result in
    for mh in result {
        print(b58String(mh))
    }
    
    dispatch_group_leave(group)
}

dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
```

## Requirements
Swift 2.1

## License
MIT
