# 🐕 DogLog AI Backend

Real ChatGPT-4 integration for professional dog behavior analysis.

## 🚀 Quick Setup

### 1. Install Dependencies
```bash
cd doglog-backend
npm install
```

### 2. Get OpenAI API Key
1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign up/login and create a new API key
3. Copy your API key (starts with `sk-...`)

### 3. Configure Environment
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and add your API key
nano .env
```

Replace `sk-your-openai-api-key-here` with your actual API key:
```
OPENAI_API_KEY=sk-proj-your-actual-api-key-here
PORT=3001
NODE_ENV=development
```

### 4. Start the Server
```bash
npm start
```

You should see:
```
🐕 DogLog AI Backend running on http://localhost:3001
📊 OpenAI integration: ✅ Active
```

## 🧪 Testing the API

### Health Check
```bash
curl http://localhost:3001/health
```

### Test Analysis
```bash
curl -X POST http://localhost:3001/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "dogName": "Buddy",
    "breed": "Golden Retriever",
    "age": 3,
    "activities": {
      "2024-01-01": [{"name": "Long Walk", "outcome": "good"}],
      "2024-01-02": [{"name": "Vet Visit", "outcome": "bad"}]
    },
    "dayRatings": {
      "2024-01-01": "good",
      "2024-01-02": "bad"
    }
  }'
```

## 🎯 How It Works

1. **Frontend** sends dog activity data to backend
2. **Backend** processes data and creates intelligent prompts
3. **OpenAI GPT-4** analyzes patterns like a professional behaviorist
4. **AI Response** is parsed into structured insights
5. **Frontend** displays personalized recommendations

## 💰 Cost Estimate

- **GPT-4**: ~$0.01-0.05 per analysis
- **GPT-3.5**: ~$0.001-0.01 per analysis
- Typical monthly usage: $1-10 depending on frequency

## 🔧 Development

```bash
# Development with auto-restart
npm run dev

# Check if OpenAI key is working
node -e "console.log(process.env.OPENAI_API_KEY ? 'Key loaded' : 'No key found')"
```

## 🚨 Troubleshooting

### "Missing API Key" Error
- Check your `.env` file exists
- Verify API key starts with `sk-`
- Restart the server after changing `.env`

### "Insufficient Quota" Error
- Add billing info to your OpenAI account
- Check your usage limits

### Connection Errors
- Ensure server is running on port 3001
- Check firewall settings
- Verify frontend is calling correct URL

## 🔒 Security Notes

- **Never commit** your `.env` file
- **Keep API keys secret** - don't share or expose them
- **Monitor usage** to prevent unexpected charges
- **Use environment variables** in production