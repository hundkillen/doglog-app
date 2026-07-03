# DogLog Development Notes

## Major Feature Expansion Plan

### Training Week Integration & Enhancement

#### Core Changes
1. **Rename "Example Week" → "Suggested Training Week"**
   - Update all UI text, variable names, and documentation
   - Make it clear this is a personalized training suggestion

2. **Enhanced User Experience**
   - **Proactive Suggestion**: When user opens dog profile and no Suggested Training Week exists + ChatGPT enabled → prompt user to create one
   - **Editable Content**: Users can modify the generated training week to fit their schedule
   - **Persistent Storage**: Save training weeks accessible across the entire app (not just in AI Insights)

#### Morning Forecast Enhancements
3. **Expandable Activities**
   - Make forecast activities expandable to show detailed information
   - Include exercise instructions, training tips, and context
   - Rich content display for better user understanding

4. **Activity Integration**
   - **Calendar Export**: Add activities from both Morning Forecast and Suggested Training Week to device calendar
   - **Duplicate Prevention**: Check existing calendar events before adding to prevent duplicates
   - **"Done" Button**: Allow users to mark activities as completed and automatically log them to current day with same data structure as "Add Activity"

#### Technical Implementation
5. **Storage Architecture**
   - Ensure Suggested Training Week data is accessible from all parts of app
   - Implement proper caching and data persistence
   - Handle data synchronization across views

6. **Calendar Integration**
   - Use EventKit framework for iOS calendar integration
   - Request calendar permissions appropriately
   - Handle calendar access edge cases

#### Code Cleanup
7. **Test Environment Management**
   - Hide test buttons from production UI but keep functionality for development
   - Remove "Test Data" button before app release (development-only feature)
   - Maintain clean separation between development and production features

8. **Tutorial Updates**
   - Completely rewrite tutorial to reflect new features
   - Include Suggested Training Week workflow
   - Update screenshots and descriptions
   - Add guidance for calendar integration features

## Implementation Priority
1. Rename and make training week editable
2. Add proactive prompts in dog profile
3. Implement expandable activities in Morning Forecast
4. Add calendar integration with duplicate prevention
5. Implement "Done" button functionality
6. Clean up test features and update tutorial

## Technical Notes
- Current Example Week integration is complete and working
- Build system is stable
- Need to maintain backwards compatibility during renaming
- Calendar integration requires EventKit framework
- Should consider user privacy for calendar access

## User Experience Goals
- Seamless workflow from AI-generated suggestions to daily implementation
- Reduce friction in following training recommendations
- Provide clear, actionable guidance with detailed instructions
- Enable easy tracking and completion of training activities
- Integrate with user's existing calendar and workflow tools

## Apple Watch Integration
### Core Features
- **Quick Activity Logging**: Log activities during walks/training without phone
- **Morning Forecast Notifications**: Receive daily forecasts and reminders on wrist
- **Simple Completion Tracking**: Tap to mark activities as done
- **Voice Memos**: Quick voice notes about dog behavior during activities
- **Haptic Reminders**: Gentle notifications for training times

### Technical Implementation
- WatchOS companion app development
- Data synchronization between iPhone and Watch
- Offline capability for logging during walks
- Voice-to-text for behavior notes

## Gamification System
### Badge System
- **Training Consistency**: Badges for daily/weekly training streaks
- **Skill Development**: Badges for mastering different training categories
- **Health & Wellness**: Badges for maintaining good daily ratings
- **Social Achievements**: Badges for dog park visits, social interactions
- **Milestone Rewards**: Special badges for major developmental achievements

### Streak Tracking
- **Daily Training Streaks**: Consecutive days of logged activities
- **Good Day Streaks**: Consecutive days rated as "good"
- **Forecast Following**: Streaks for following morning forecast recommendations
- **Weekly Goal Completion**: Completing suggested training week activities

### Progress Rewards
- **Level System**: Dog "levels up" based on consistent training and development
- **Unlock New Features**: Advanced training suggestions unlock with progress
- **Celebration Animations**: Visual rewards for achievements
- **Progress Sharing**: Share milestones with friends/family

### Achievement Categories
- **Trainer Badges**: Consistency in training activities
- **Explorer Badges**: Trying new activities and locations
- **Social Butterfly**: Dog interaction and socialization achievements
- **Health Champion**: Maintaining good health and mood ratings
- **Master Trainer**: Advanced training technique completions

## Implementation Priority (Updated)
1. Rename and make training week editable
2. Add proactive prompts in dog profile
3. Implement expandable activities in Morning Forecast
4. Add calendar integration with duplicate prevention
5. Implement "Done" button functionality
6. **Basic Gamification**: Badge system and streak tracking
7. **Apple Watch App**: Core functionality and notifications
8. **Advanced Gamification**: Achievement unlocks and progress rewards
9. Clean up test features and update tutorial