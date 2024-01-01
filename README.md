Firefox for iOS with Built-in Ethereum Wallet

Explore the future of browsing with our fork of the Firefox browser, enhanced with a built-in Ethereum wallet. This innovative browser seamlessly integrates the power of Firefox's robust features with the functionality of a secure Ethereum wallet, allowing you to browse the web and manage your cryptocurrency effortlessly.

## Key Features:
- **Enhanced Security:** Benefit from the privacy and security features of Firefox, coupled with a dedicated Ethereum wallet for secure cryptocurrency transactions.
- **User-Friendly Wallet Management:** Easily send and receive Ethereum, check your balance, and manage your wallet directly within the browser interface.
- **Seamless Web3 Integration:** Immerse yourself in the decentralized web by effortlessly interacting with decentralized applications (DApps) and smart contracts.

Experience a new era of browsing with our Firefox fork, where the worlds of web browsing and cryptocurrency seamlessly converge. Download now and embark on a journey into the decentralized future.

![Screenshot](https://raw.githubusercontent.com/dworak/EthereumWallet/main/screenshots/image1.png)


This branch (main)
-----------

This branch works with [Xcode 15](https://developer.apple.com/download/all/?q=xcode), Swift 5.8 and supports iOS 15 and above.

*Please note:* Both Intel and M1 macs are supported 🎉 and we use swift package manager.

Please make sure you aim your pull requests in the right direction.

For bug fixes and features for a specific release, use the version branch.

Getting involved
----------------

We encourage you to participate in this open source project. We love Pull Requests, Issue Reports, Feature Requests or any kind of positive contribution. Please read the [Mozilla Community Participation Guidelines](https://www.mozilla.org/en-US/about/governance/policies/participation/) and our [Contributing guidelines](https://github.com/mozilla-mobile/firefox-ios/blob/main/CONTRIBUTING.md) first. 

- You can [file a new issue](https://github.com/mozilla-mobile/firefox-ios/issues/new/choose) or research [existing bugs](https://github.com/mozilla-mobile/firefox-ios/issues)

If more information is required or you have any questions then we suggest reaching out to us via:
- Chat on Element channel [#fx-ios](https://chat.mozilla.org/#/room/#fx-ios:mozilla.org) for general discussion, or write DMs to specific teammates for questions.
- Open a [Github discussion](https://github.com/mozilla-mobile/firefox-ios/discussions) which can be used for general questions.

Want to contribute on the codebase but don't know where to start? Here is a list of [issues that are contributor friendly](https://github.com/mozilla-mobile/firefox-ios/labels/Contributor%20OK), but make sure to read the [Contributing guidelines](https://github.com/mozilla-mobile/firefox-ios/blob/main/CONTRIBUTING.md) first. 

Building the code
-----------------

1. Install the latest [Xcode developer tools](https://developer.apple.com/xcode/downloads/) from Apple.
1. Install, [Brew](https://brew.sh), Node, and a Python3 virtualenv for localization scripts:
    ```shell
    brew update
    brew install node
    pip3 install virtualenv
    ```
1. Clone the repository:
    ```shell
    git clone https://github.com/mozilla-mobile/firefox-ios
    ```
1. Install Node.js dependencies, build user scripts and update content blocker:
    ```shell
    cd firefox-ios
    sh ./bootstrap.sh
    ```
1. Open `Client.xcodeproj` in Xcode.
1. Make sure to select the `Fennec` [scheme](https://developer.apple.com/documentation/xcode/build-system?changes=_2) in Xcode.
1. Select the destination device you want to build on.
1. Run the app with `Cmd + R` or by pressing the `build and run` button.

⚠️ Important: In case you have dependencies issues with SPM, please try the following:
- Xcode -> File -> Packages -> Reset Package Caches

Building User Scripts
-----------------

User Scripts (JavaScript injected into the `WKWebView`) are compiled, concatenated, and minified using [webpack](https://webpack.js.org/). User Scripts to be aggregated are placed in the following directories:

```none
/Client
|-- /Frontend
    |-- /UserContent
        |-- /UserScripts
            |-- /AllFrames
            |   |-- /AtDocumentEnd
            |   |-- /AtDocumentStart
            |-- /MainFrame
                |-- /AtDocumentEnd
                |-- /AtDocumentStart
```

This reduces the total possible number of User Scripts down to four. The compiled output from concatenating and minifying the User Scripts placed in these folders resides in `/Client/Assets` and are named accordingly:

* `AllFramesAtDocumentEnd.js`
* `AllFramesAtDocumentStart.js`
* `MainFrameAtDocumentEnd.js`
* `MainFrameAtDocumentStart.js`

To simplify the build process, these compiled files are checked-in to this repository. When adding or editing User Scripts, these files can be re-compiled with `webpack` manually. This requires Node.js to be installed, and all required `npm` packages can be installed by running `npm install` in the project's root directory. User Scripts can be compiled by running the following `npm` command in the root directory of the project:

```shell
npm run build
```

License
-----------------

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at https://mozilla.org/MPL/2.0/
