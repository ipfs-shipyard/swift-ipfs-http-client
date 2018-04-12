# swift-ipfs-api

[![](https://img.shields.io/badge/made%20by-Protocol%20Labs-blue.svg?style=flat-square)](http://ipn.io)
[![](https://img.shields.io/badge/project-IPFS-blue.svg?style=flat-square)](http://ipfs.io/)
[![](https://img.shields.io/badge/freenode-%23ipfs-blue.svg?style=flat-square)](http://webchat.freenode.net/?channels=%23ipfs)
[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

![](https://ipfs.io/ipfs/QmQJ68PFMDdAsgCZvA1UVzzn18asVcf7HVvCDgpjiSCAse)

> A Swift client library for the IPFS API.

For more information about [IPFS](http://ipfs.io) or the [API commands](http://ipfs.io/docs/commands) click the links.

The Swift IPFS API shell/client is an asynchronous library that provides native calls to an IPFS node.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [Examples](#examples)
- [Requirements](#requirements)
- [Contribute](#contribute)
- [License](#license)

## Install

In the root of your project:

-  Add a Cartfile (or use an existing one) with the following:
```
github "ipfs/swift-ipfs-api" "master"
```
- To fetch and build the dependencies, type:

```carthage update --platform Mac```

or

```carthage update --platform iOS```

or

```carthage update```

if you want both platforms.

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

do {
  let api = try IpfsApi(host: "127.0.0.1", port: 5001)

  try api.id() { (idData : JsonType) in
    guard let id = idData.object?["ID"]?.string else {
      return
    }
    print("Yay, I've got an id: \(id)")
  }
} catch {
  print(error.localizedDescription)
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
Swift 3

## Contribute

Feel free to join in. All welcome. Open an [issue](https://github.com/ipfs/swift-ipfs-api/issues)!

This repository falls under the IPFS [Code of Conduct](https://github.com/ipfs/community/blob/master/code-of-conduct.md).

[![](https://cdn.rawgit.com/jbenet/contribute-ipfs-gif/master/img/contribute.gif)](https://github.com/ipfs/community/blob/master/contributing.md)

## License

[MIT](LICENSE)
