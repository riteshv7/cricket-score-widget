#!/bin/bash
# Compile and run the Maidan Menu Bar SwiftUI application
swiftc "Sources/Maidan/Config.swift" \
       "Sources/Maidan/Models.swift" \
       "Sources/Maidan/APIClient.swift" \
       "Sources/Maidan/MatchSelector.swift" \
       "Sources/Maidan/MatchService.swift" \
       "Sources/Maidan/Maidan.swift" \
       -o Maidan

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful. Starting Maidan Menu Bar app..."
    echo "The app is running in the background. Look at your macOS top menu bar!"
    echo "Press Command+Q or click the menu item and select 'Quit' to stop the app."
    ./Maidan
else
    echo "❌ Compilation failed."
fi
