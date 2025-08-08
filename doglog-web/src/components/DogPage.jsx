import React, { useState } from 'react';
import Calendar from './Calendar';
import DailyActivity from './DailyActivity';
import './DogPage.css';

const DogPage = ({ dog, onBack, onEdit, onDelete, onUpdateActivities }) => {
  const [currentView, setCurrentView] = useState('calendar');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

  const handleDateSelect = (date) => {
    setSelectedDate(date);
    setCurrentView('activity');
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
          />
        )}
      </main>
    </div>
  );
};

export default DogPage;