import Foundation

nonisolated protocol PortOptionProviding {
    var options: [String] { get }
}

nonisolated struct StubPortOptionProvider: PortOptionProviding {
    let options: [String] = [
        "Aberdeen",
        "Brixham",
        "Grimsby",
        "Hull",
        "Lerwick",
        "Milford Haven",
        "Newlyn",
        "Peterhead",
        "Plymouth",
        "Scrabster",
        "Shoreham",
        "Whitby"
    ]
}
