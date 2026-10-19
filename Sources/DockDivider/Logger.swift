import os

// Failures go to the system log, so a bug report can include them:
// /usr/bin/log show --last 1h --predicate 'subsystem == "io.github.luantedesco.dock-divider"'
let logger = Logger(subsystem: "io.github.luantedesco.dock-divider", category: "DockDivider")
