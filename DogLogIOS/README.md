# DogLog iOS App

A native iOS app for tracking dog behavior and daily activities, built with SwiftUI and SwiftData.

## Features

- **Dog Management**: Add, edit, and manage multiple dogs with photos and details
- **Activity Tracking**: Log daily activities with good/okay/bad outcomes
- **Calendar View**: Visual calendar showing activity patterns with color-coded days
- **Local Storage**: All data stored locally using SwiftData
- **Landscape Mode**: Optimized for landscape orientation as specified in requirements

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Modern local data persistence (iOS 17+)
- **MVVM Pattern**: Clean separation of concerns
- **PhotosPicker**: Native photo selection integration

## Key Components

### Data Models
- `Dog`: Core entity with name, breed, photo, etc.
- `Activity`: Individual activity entries with date, type, outcome, and notes

### Views
- `SplashScreenView`: Animated app launch screen
- `DogGalleryView`: Grid of dog cards
- `AddEditDogView`: Form for creating/editing dogs
- `DogDetailView`: Individual dog page with calendar
- `CalendarView`: Custom calendar with activity color coding
- `DailyActivityView`: Daily activity logging interface

### Core Features
- Color-coded calendar days (Green=Good, Orange=Okay, Red=Bad)
- Photo management with PhotosPicker
- Swipe-to-delete functionality
- Form validation and error handling

## Setup Instructions

1. Open Xcode
2. Create a new iOS project with these settings:
   - Template: App
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: No (we're using SwiftData instead)
3. Replace the generated files with the files in this directory
4. Configure Info.plist with the provided settings
6. Build and run

## File Structure

```
DogLogIOS/
├── DogLogApp.swift           # Main app entry point
├── ContentView.swift         # Root content view
├── SplashScreenView.swift    # Launch screen
├── DogGalleryView.swift      # Main gallery
├── AddEditDogView.swift      # Dog form
├── DogDetailView.swift       # Dog details
├── CalendarView.swift        # Calendar component
├── DailyActivityView.swift   # Activity logging
├── Models.swift              # SwiftData models
├── Info.plist               # App configuration
└── README.md               # This file
```

## Requirements Met

✅ Landscape mode only  
✅ Splash screen with animation  
✅ Dog gallery with rounded squares  
✅ Add/edit dog functionality  
✅ Photo upload support  
✅ Calendar view with color coding  
✅ Daily activity tracking  
✅ Good/Okay/Bad outcome system  
✅ Notes for activities  
✅ Local data persistence  

## Next Steps

- Add AI analysis after 2 weeks of data
- Implement weather integration
- Add export functionality
- Include health tracking features
- Add push notifications for reminders