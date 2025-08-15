import React, { useState } from 'react';
import Calendar from './Calendar';
import DailyActivity from './DailyActivity';
import './DogPage.css';

const DogPage = ({ dog, onBack, onEdit, onDelete, onUpdateActivities, customActivities, onAddCustomActivity }) => {
  const [currentView, setCurrentView] = useState('calendar');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

  const handleDateSelect = (date) => {
    setSelectedDate(date);
    setCurrentView('activity');
  };

  const generateTestData = () => {
    const activities = [
      'Nosework', 'Obedience Training', 'Long Walk', 'Playdate', 'Vet Visit',
      'Rest Day', 'Agility', 'Grooming', 'Swimming', 'Feeding', 'Play Time'
    ];
    const outcomes = ['good', 'okay', 'bad'];
    const dayRatings = ['good', 'okay', 'bad'];
    
    // Generate data for the last 30 days
    for (let i = 0; i < 30; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateKey = date.toISOString().split('T')[0];
      
      // Random number of activities (1-4)
      const numActivities = Math.floor(Math.random() * 4) + 1;
      const dayActivities = [];
      
      for (let j = 0; j < numActivities; j++) {
        const randomActivity = activities[Math.floor(Math.random() * activities.length)];
        const randomOutcome = outcomes[Math.floor(Math.random() * outcomes.length)];
        
        dayActivities.push({
          id: Date.now() + j + i * 1000,
          name: randomActivity,
          outcome: randomOutcome,
          notes: Math.random() > 0.7 ? `Random note for ${randomActivity}` : ''
        });
      }
      
      // Add daily notes with rating
      const randomDayRating = dayRatings[Math.floor(Math.random() * dayRatings.length)];
      dayActivities.push({
        id: 'notes',
        type: 'notes',
        content: `Test day ${i + 1} - Random daily notes for ${dog.name}`,
        rating: randomDayRating
      });
      
      onUpdateActivities(dog.id, dateKey, dayActivities);
    }
    
    alert(`Generated test data for ${dog.name} - 30 days of random activities and ratings!`);
  };

  return (
    <div className="dog-page">
      <header className="dog-header">
        <div className="header-left">
          <button onClick={onBack} className="back-btn">← Back</button>
        </div>
        
        <div className="dog-title">
          <div className="dog-avatar">
            {dog.photo ? (
              <img src={dog.photo} alt={dog.name} />
            ) : (
              <div className="avatar-placeholder">🐕</div>
            )}
          </div>
          <div className="dog-details">
            <h1>{dog.name}</h1>
            <p>{dog.breed} {dog.age && `• ${dog.age} years old`}</p>
          </div>
        </div>
        
        <div className="header-right">
          <button onClick={generateTestData} className="test-btn">🎲 Test Data</button>
          <button onClick={onEdit} className="edit-btn">Edit</button>
          <button onClick={onDelete} className="delete-btn">Delete</button>
        </div>
      </header>

      <nav className="view-nav">
        <button 
          className={`nav-btn ${currentView === 'calendar' ? 'active' : ''}`}
          onClick={() => setCurrentView('calendar')}
        >
          📅 Calendar
        </button>
        <button 
          className={`nav-btn ${currentView === 'activity' ? 'active' : ''}`}
          onClick={() => setCurrentView('activity')}
        >
          📝 Daily Log
        </button>
      </nav>

      <main className="dog-content">
        {currentView === 'calendar' && (
          <Calendar 
            dog={dog}
            onDateSelect={handleDateSelect}
          />
        )}
        
        {currentView === 'activity' && (
          <DailyActivity
            dog={dog}
            date={selectedDate}
            onSave={(activities) => onUpdateActivities(dog.id, selectedDate, activities)}
            onBack={() => setCurrentView('calendar')}
            customActivities={customActivities}
            onAddCustomActivity={onAddCustomActivity}
          />
        )}
      </main>
    </div>
  );
};

export default DogPage;