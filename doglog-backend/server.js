const express = require('express');
const cors = require('cors');
const { OpenAI } = require('openai');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:8080',
    'https://localhost:3000',
    'https://localhost:8080',
    // Add your production domains here
    'https://doglog-app.netlify.app',
    'https://doglog-app.vercel.app',
    // Allow any subdomain for deployment flexibility
    /^https:\/\/.*\.netlify\.app$/,
    /^https:\/\/.*\.vercel\.app$/,
    /^https:\/\/.*\.railway\.app$/
  ],
  credentials: true
}));
app.use(express.json());

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'DogLog AI Backend is running!' });
});

// Update API key endpoint
app.post('/api/update-key', (req, res) => {
  try {
    const { apiKey } = req.body;
    
    // Allow clearing the API key
    if (!apiKey || apiKey === '') {
      process.env.OPENAI_API_KEY = '';
      global.openai = null;
      return res.json({ message: 'API key cleared successfully' });
    }
    
    if (!apiKey.startsWith('sk-')) {
      return res.status(400).json({ error: 'Invalid API key format' });
    }
    
    // Update the OpenAI configuration
    process.env.OPENAI_API_KEY = apiKey;
    
    // Create new OpenAI instance with updated key
    global.openai = new OpenAI({
      apiKey: apiKey,
    });
    
    res.json({ message: 'API key updated successfully' });
  } catch (error) {
    console.error('API Key Update Error:', error);
    res.status(500).json({ error: 'Failed to update API key' });
  }
});

// AI Analysis endpoint
app.post('/api/analyze', async (req, res) => {
  try {
    const { dogName, activities, dayRatings, behaviorRatings = {}, breed, age, behaviorIssues = '', triggerData = {}, trainingSessions = {}, language = 'en' } = req.body;

    if (!dogName || !activities || !dayRatings) {
      return res.status(400).json({ error: 'Missing required data' });
    }

    // Prepare data for AI analysis
    const analysisData = prepareAnalysisData(dogName, activities, dayRatings, behaviorRatings, breed, age, behaviorIssues, triggerData, trainingSessions);
    
    if (analysisData.totalDays < 3) {
      return res.json({
        insights: [],
        message: `Need at least 3 days of data for AI analysis. Currently have ${analysisData.totalDays} days.`
      });
    }

    // Create AI prompt
    const prompt = createAnalysisPrompt(analysisData, language);

    // Call OpenAI API
    const currentOpenAI = global.openai || openai;
    if (!currentOpenAI || (!process.env.OPENAI_API_KEY && !global.openai)) {
      return res.status(400).json({ 
        error: 'OpenAI API key not configured',
        message: 'Please add your OpenAI API key in the settings to use AI analysis.'
      });
    }
    
    const completion = await currentOpenAI.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: "You are a professional dog behaviorist and veterinary consultant with 15+ years of experience analyzing canine behavior patterns. Provide specific, actionable insights based on activity data."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 2000
    });

    const aiResponse = completion.choices[0].message.content;
    
    // Parse AI response into structured insights
    const structuredInsights = parseAIResponse(aiResponse, dogName);

    res.json({
      insights: structuredInsights,
      rawResponse: aiResponse,
      analysisData: analysisData
    });

  } catch (error) {
    console.error('AI Analysis Error:', error);
    res.status(500).json({ 
      error: 'Failed to analyze dog behavior data',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Analyze trigger patterns
function analyzeTriggerPatterns(triggerData, allDates) {
  const analysis = {
    commonTriggers: {},
    environmentalPatterns: {},
    socialPatterns: {},
    triggerFrequency: {},
    totalTriggerDays: 0
  };
  
  const triggerDates = Object.keys(triggerData);
  analysis.totalTriggerDays = triggerDates.length;
  
  triggerDates.forEach(date => {
    const dayTriggers = triggerData[date];
    
    // Count all triggers
    ['environment', 'social', 'triggers'].forEach(category => {
      if (dayTriggers[category]) {
        dayTriggers[category].forEach(trigger => {
          if (!analysis.commonTriggers[trigger]) {
            analysis.commonTriggers[trigger] = 0;
          }
          analysis.commonTriggers[trigger]++;
        });
      }
    });
  });
  
  return analysis;
}

// Analyze training sessions
function analyzeTrainingSessions(trainingSessions, allDates) {
  const analysis = {
    totalSessions: 0,
    totalMinutes: 0,
    commandsWorked: {},
    sessionsPerWeek: 0,
    averageSessionLength: 0,
    mostCommonCommands: [],
    trainingDays: 0
  };
  
  const sessionDates = Object.keys(trainingSessions);
  analysis.trainingDays = sessionDates.length;
  
  sessionDates.forEach(date => {
    const daySessions = trainingSessions[date] || [];
    daySessions.forEach(session => {
      analysis.totalSessions++;
      analysis.totalMinutes += session.duration;
      
      session.commands.forEach(command => {
        if (!analysis.commandsWorked[command]) {
          analysis.commandsWorked[command] = 0;
        }
        analysis.commandsWorked[command]++;
      });
    });
  });
  
  if (analysis.totalSessions > 0) {
    analysis.averageSessionLength = Math.round(analysis.totalMinutes / analysis.totalSessions);
    analysis.sessionsPerWeek = Math.round((analysis.totalSessions / allDates.length) * 7);
    
    // Get most common commands
    analysis.mostCommonCommands = Object.entries(analysis.commandsWorked)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([command, count]) => ({ command, count }));
  }
  
  return analysis;
}

// Prepare data for AI analysis
function prepareAnalysisData(dogName, activities, dayRatings, behaviorRatings = {}, breed = 'Mixed breed', age = null, behaviorIssues = '', triggerData = {}, trainingSessions = {}) {
  const allDates = Object.keys(activities).filter(date => activities[date] && activities[date].length > 0).sort();
  
  const activitySummary = {};
  const dayRatingCounts = { good: 0, okay: 0, bad: 0 };
  const sequentialPatterns = [];

  // Process activities
  allDates.forEach(date => {
    activities[date].forEach(activity => {
      if (!activitySummary[activity.name]) {
        activitySummary[activity.name] = { good: 0, okay: 0, bad: 0, total: 0 };
      }
      activitySummary[activity.name][activity.outcome]++;
      activitySummary[activity.name].total++;
    });
  });

  // Process day ratings
  Object.values(dayRatings).forEach(rating => {
    if (dayRatingCounts[rating] !== undefined) {
      dayRatingCounts[rating]++;
    }
  });

  // Analyze sequential patterns
  for (let i = 1; i < allDates.length; i++) {
    const prevDate = allDates[i-1];
    const currentDate = allDates[i];
    const prevRating = dayRatings[prevDate];
    const currentRating = dayRatings[currentDate];
    const prevActivities = activities[prevDate] || [];
    
    if (prevRating && currentRating) {
      sequentialPatterns.push({
        date: currentDate,
        dayTransition: `${prevRating} → ${currentRating}`,
        previousActivities: prevActivities.map(a => `${a.name}(${a.outcome})`).join(', ')
      });
    }
  }

  // Analyze behavior progress if behavior issues exist
  const behaviorProgress = {};
  if (behaviorIssues && Object.keys(behaviorRatings).length > 0) {
    const behaviors = behaviorIssues.split(/[,;]/).map(b => b.trim()).filter(b => b.length > 0);
    
    behaviors.forEach(behavior => {
      const ratings = [];
      Object.keys(behaviorRatings).forEach(date => {
        if (behaviorRatings[date][behavior] !== undefined) {
          ratings.push({
            date,
            rating: behaviorRatings[date][behavior]
          });
        }
      });
      
      if (ratings.length > 0) {
        ratings.sort((a, b) => new Date(a.date) - new Date(b.date));
        const recent = ratings.slice(-7); // Last 7 ratings
        const average = recent.reduce((sum, r) => sum + r.rating, 0) / recent.length;
        const trend = ratings.length > 1 ? ratings[ratings.length - 1].rating - ratings[0].rating : 0;
        
        behaviorProgress[behavior] = {
          totalRatings: ratings.length,
          recentAverage: Math.round(average),
          trend: trend > 5 ? 'improving' : trend < -5 ? 'declining' : 'stable',
          trendValue: trend,
          latestRating: ratings[ratings.length - 1].rating,
          ratings: recent
        };
      }
    });
  }

  // Analyze trigger patterns
  const triggerAnalysis = analyzeTriggerPatterns(triggerData, allDates);
  
  // Analyze training sessions
  const trainingAnalysis = analyzeTrainingSessions(trainingSessions, allDates);

  return {
    dogName,
    breed,
    age,
    behaviorIssues,
    behaviorProgress,
    triggerAnalysis,
    trainingAnalysis,
    totalDays: allDates.length,
    dateRange: allDates.length > 0 ? `${allDates[0]} to ${allDates[allDates.length - 1]}` : 'No data',
    activitySummary,
    dayRatingCounts,
    sequentialPatterns: sequentialPatterns.slice(-10), // Last 10 patterns
    totalRatedDays: Object.keys(dayRatings).length
  };
}

// Create detailed prompt for AI analysis
function createAnalysisPrompt(data, language = 'en') {
  const { dogName, breed, age, behaviorIssues, behaviorProgress, triggerAnalysis, trainingAnalysis, totalDays, activitySummary, dayRatingCounts, sequentialPatterns } = data;
  
  const languageInstructions = {
    en: 'Please respond in English.',
    es: 'Por favor responde en español.',
    fr: 'Veuillez répondre en français.',
    de: 'Bitte antworten Sie auf Deutsch.',
    it: 'Per favore rispondi in italiano.',
    pt: 'Por favor responda em português.',
    nl: 'Gelieve te antwoorden in het Nederlands.',
    sv: 'Vänligen svara på svenska.',
    da: 'Venligst svar på dansk.',
    no: 'Vennligst svar på norsk.'
  };
  
  const langInstruction = languageInstructions[language] || languageInstructions.en;
  
  const behaviorFocus = behaviorIssues ? `**URGENT: This dog has specific behavior problems that must be addressed in your analysis:**
${behaviorIssues}

YOUR ANALYSIS MUST include specific solutions, training techniques, and activity modifications for these exact behavior issues. Do not provide generic advice - focus on these specific problems.

` : '';

  return `${behaviorFocus}Analyze the behavior patterns for ${dogName}, a ${age ? age + '-year-old ' : ''}${breed}.

**Data Summary:**
- Total days tracked: ${totalDays}
- Day ratings: ${dayRatingCounts.good} good, ${dayRatingCounts.okay} okay, ${dayRatingCounts.bad} bad days

**Activity Performance:**
${Object.entries(activitySummary).map(([activity, stats]) => 
  `- ${activity}: ${stats.good}/${stats.total} successful (${Math.round(stats.good/stats.total*100)}% success rate)`
).join('\n')}

**Recent Sequential Patterns:**
${sequentialPatterns.map(pattern => 
  `- ${pattern.dayTransition} after: ${pattern.previousActivities}`
).join('\n')}${Object.keys(behaviorProgress).length > 0 ? `

**Behavior Progress Tracking:**
${Object.entries(behaviorProgress).map(([behavior, progress]) => 
  `- ${behavior}: ${progress.recentAverage}/100 average (${progress.trend}) - ${progress.totalRatings} days tracked`
).join('\n')}` : ''}${triggerAnalysis.totalTriggerDays > 0 ? `

**Trigger & Environmental Analysis:**
- Total days with trigger data: ${triggerAnalysis.totalTriggerDays}
- Most common triggers: ${Object.entries(triggerAnalysis.commonTriggers).sort((a,b) => b[1] - a[1]).slice(0,5).map(([trigger, count]) => `${trigger} (${count}x)`).join(', ')}
${Object.keys(triggerAnalysis.commonTriggers).length > 0 ? '- Key insight: Identify correlation between triggers and behavior ratings' : ''}` : ''}${trainingAnalysis.totalSessions > 0 ? `

**Training Progress Analysis:**
- Total training sessions: ${trainingAnalysis.totalSessions} sessions (${trainingAnalysis.totalMinutes} minutes)
- Training frequency: ${trainingAnalysis.sessionsPerWeek} sessions/week
- Average session length: ${trainingAnalysis.averageSessionLength} minutes
- Most practiced commands: ${trainingAnalysis.mostCommonCommands.map(cmd => `${cmd.command} (${cmd.count}x)`).join(', ')}
- Training consistency: ${trainingAnalysis.trainingDays}/${totalDays} days with training` : ''}

Please provide analysis in exactly this format:

**WEEKLY_STRATEGY:**
[Provide specific weekly schedule recommendations based on the data${behaviorIssues ? ` with special focus on addressing: ${behaviorIssues}` : ''}]

**ACTION_PLAN:**
[List 3-5 specific actionable steps for this week${behaviorIssues ? ` that directly address the behavior issues: ${behaviorIssues}` : ''}]

**SUCCESS_METRICS:**
[Define measurable goals and targets to track${behaviorIssues ? `, including specific improvement metrics for: ${behaviorIssues}` : ''}]

**PATTERN_INSIGHTS:**
[Identify specific behavioral patterns and correlations from the data${behaviorIssues ? ` and explain how current activities relate to the behavior issues: ${behaviorIssues}` : ''}]${behaviorIssues ? `

**BEHAVIOR_SOLUTIONS:**
[Provide specific, actionable solutions for each behavior issue: ${behaviorIssues}. Include specific training techniques, environmental changes, and activity modifications that can help with these exact problems.]` : ''}

Focus on:
1. Identifying activities that predict good/bad days
2. Optimal scheduling based on success patterns
3. Specific breed-related considerations for ${breed}
4. Data-driven recommendations, not generic advice
5. Actionable insights the owner can implement immediately${triggerAnalysis.totalTriggerDays > 0 ? `
6. **TRIGGER ANALYSIS:** Use trigger data to identify environmental and social patterns affecting behavior
   - Recommend trigger avoidance or desensitization strategies
   - Connect specific triggers to behavior decline patterns
   - Suggest environmental modifications based on trigger frequency` : ''}${trainingAnalysis.totalSessions > 0 ? `
${triggerAnalysis.totalTriggerDays > 0 ? '7' : '6'}. **TRAINING OPTIMIZATION:** Analyze training effectiveness and provide specific improvements
   - Evaluate training consistency and session frequency
   - Recommend focus areas based on command practice data
   - Suggest training schedule adjustments for better results
   - Connect training progress to behavior improvement trends` : ''}${behaviorIssues ? `
6. **CRITICAL PRIORITY:** The dog has these specific behavior problems that MUST be addressed: ${behaviorIssues}
   - Every recommendation should consider how it helps with: ${behaviorIssues}
   - Analyze if current activities are making these behaviors better or worse
   - Provide specific training techniques and modifications for: ${behaviorIssues}
   - Connect daily ratings to progress/regression in these behavior issues
   - Suggest activities specifically chosen to improve: ${behaviorIssues}` : ''}

${langInstruction}`;
}

// Parse AI response into structured insights
function parseAIResponse(aiResponse, dogName) {
  const insights = [];
  
  try {
    const sections = {
      'WEEKLY_STRATEGY': 'positive',
      'ACTION_PLAN': 'warning', 
      'SUCCESS_METRICS': 'positive',
      'PATTERN_INSIGHTS': 'neutral',
      'BEHAVIOR_SOLUTIONS': 'warning'
    };

    Object.entries(sections).forEach(([sectionKey, type]) => {
      const sectionMatch = aiResponse.match(new RegExp(`\\*\\*${sectionKey}:\\*\\*([\\s\\S]*?)(?=\\*\\*[A-Z_]+:\\*\\*|$)`, 'i'));
      
      if (sectionMatch) {
        let content = sectionMatch[1].trim();
        
        // Clean up the content and add proper formatting
        content = content.replace(/^\n+/, '').replace(/\n+$/, '');
        
        const title = sectionKey.replace(/_/g, ' ').toLowerCase()
          .replace(/\b\w/g, l => l.toUpperCase());
        
        const emoji = {
          'Weekly Strategy': '🎯',
          'Action Plan': '📋', 
          'Success Metrics': '📈',
          'Pattern Insights': '🧠',
          'Behavior Solutions': '🎯'
        }[title] || '💡';

        insights.push({
          type: type,
          title: `${emoji} ${title}`,
          description: content
        });
      }
    });

    // If parsing failed, create a single insight with the full response
    if (insights.length === 0) {
      insights.push({
        type: 'positive',
        title: '🧠 AI Behavioral Analysis',
        description: aiResponse
      });
    }

  } catch (error) {
    console.error('Error parsing AI response:', error);
    insights.push({
      type: 'positive',
      title: '🧠 AI Behavioral Analysis',
      description: aiResponse
    });
  }

  return insights;
}

// Start server
app.listen(PORT, () => {
  console.log(`🐕 DogLog AI Backend running on http://localhost:${PORT}`);
  console.log(`📊 OpenAI integration: ${process.env.OPENAI_API_KEY ? '✅ Active' : '❌ Missing API Key'}`);
});