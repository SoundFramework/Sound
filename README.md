# Sound

Sound is a work-in-progress, experimental web framework written with Swift 
and Swift-NIO. The goal of this project is to define some best practices 
for writing secure web frameworks and to present a working demonstration of 
these practices.

## Configuration

Using Swift Package Manager, add Sound to your dependencies:

```
let package = Package(
    name: "project_name",
    dependencies: [
       .package(url: "git@github.com:SoundFramework/Sound.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "project_name",
            dependencies: ["Sound"]),
    ]
)
```

## Hello, world!

```
import Sound

let app = Sound()

app.get("/") { conn, _ in
    conn.text("Hello, world!")
}
app.get("/hello/#name") { conn, params in
    let name = params["name"]!
    conn.text("Hello, \(name)!")
}

app.listen()
```

Then run with: `$ swift run`
