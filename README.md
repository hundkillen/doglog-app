# 🐕 DogLog - AI-Powered Dog Behavior Tracker

A Progressive Web App for tracking and analyzing your dog's behavior patterns with professional AI insights.

![DogLog Banner](https://img.shields.io/badge/DogLog-PWA%20Ready-brightgreen) ![iOS Compatible](https://img.shields.io/badge/iOS-Compatible-blue) ![AI Powered](https://img.shields.io/badge/AI-ChatGPT%20Integrated-orange)

## ✨ Features

### 📊 **Behavior Tracking**
- Daily behavior progress sliders for specific issues
- Activity logging with outcome tracking
- Day-by-day mood rating system
- Comprehensive behavior pattern analysis

### 🧠 **AI Analysis**
- **ChatGPT Integration**: Professional dog behaviorist insights
- **Local Analysis**: Offline pattern detection
- **Trigger Analysis**: Environmental and social context tracking
- **Training Optimization**: Session tracking and progress analytics

### 📱 **Progressive Web App**
- Install on iPhone home screen like native app
- Offline functionality with service worker
- Auto-update capabilities
- Native iOS experience

### 🖼️ **Photo Management**
- Multiple photo galleries per dog
- Profile picture selection
- Instagram-style gallery display
- Direct photo upload from dog pages

### 🎯 **Advanced Features**
- Training session logger with command tracking
- Trigger and context analysis (weather, social, environmental)
- PDF export of AI analysis results
- Example week calendar generation
- Behavior correlation insights

## 🚀 **Quick Start**

### Frontend (PWA)
1. Clone the repository
2. Open `doglog-full-demo.html` in your browser
3. For production, deploy to Netlify/Vercel

### Backend (API)
1. Navigate to `doglog-backend/` directory
2. Install dependencies: `npm install`
3. Create `.env` file with your OpenAI API key:
   ```
   OPENAI_API_KEY=your_api_key_here
   ```
4. Start server: `npm start`
5. Server runs on `http://localhost:3001`

## 📁 **Project Structure**

```
doglog-app/
├── doglog-full-demo.html    # Main PWA application
├── manifest.json            # PWA manifest
├── sw.js                   # Service worker
├── icons/                  # App icons for PWA
├── doglog-backend/         # Node.js API server
│   ├── server.js          # Express server with ChatGPT
│   ├── package.json       # Dependencies
│   └── .env.example       # Environment template
└── README.md              # This file
```

## 🔧 **Installation as PWA**

### iOS (iPhone/iPad)
1. Open the app in Safari
2. Tap the Share button (□↗)
3. Scroll down and tap "Add to Home Screen"
4. Tap "Add" to install

### Android
1. Open the app in Chrome
2. Tap the menu (⋮) 
3. Tap "Add to Home Screen" or "Install App"

## 🛠️ **Development**

### Prerequisites
- Node.js 16+ for backend
- Modern web browser with PWA support
- OpenAI API key for ChatGPT integration

### Local Development
1. Start backend: `cd doglog-backend && npm start`
2. Start frontend: Open `doglog-full-demo.html` in browser
3. For HTTPS (PWA testing): Use `python3 -m http.server 8080`

### Deployment
- **Frontend**: Netlify, Vercel, GitHub Pages
- **Backend**: Railway, Render, Heroku
- **Full Stack**: Vercel (supports both)

## 🎨 **Design Philosophy**

- **Instagram-inspired UI**: Clean, familiar interface
- **Mobile-first**: Optimized for iPhone usage
- **Professional insights**: ChatGPT provides expert-level behavioral analysis
- **Data-driven**: All recommendations based on actual tracked patterns

## 📊 **AI Integration**

The app integrates with OpenAI's ChatGPT-4 to provide:
- Professional dog behaviorist analysis
- Specific trigger correlation insights
- Training effectiveness evaluation
- Personalized weekly strategies
- Behavior improvement recommendations

## 🔮 **Future Features**
- Push notifications for training reminders
- Multi-dog household management
- Veterinarian sharing capabilities
- Advanced photo analysis with AI
- Community features and tips sharing

## 📝 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 **Contributing**

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Built with ❤️ for dog lovers who want to understand and improve their furry friends' behavior patterns.**