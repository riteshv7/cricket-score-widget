#!/bin/bash
# Compile and run the Cricket Menu Bar SwiftUI application
swiftc "Sources/cricket score widget/Config.swift" \
       "Sources/cricket score widget/Models.swift" \
       "Sources/cricket score widget/APIClient.swift" \
       "Sources/cricket score widget/MatchSelector.swift" \
       "Sources/cricket score widget/MatchService.swift" \
       "Sources/cricket score widget/cricket_score_widget.swift" \
       -o cricket_score_widget

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful. Starting Cricket Menu Bar app..."
    echo "The app is running in the background. Look at your macOS top menu bar!"
    echo "Press Command+Q or click the menu item and select 'Quit' to stop the app."
    ./cricket_score_widget
else
    echo "❌ Compilation failed."
fi
