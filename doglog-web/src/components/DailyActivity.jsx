import React, { useState, useEffect } from 'react';
import './DailyActivity.css';

const DailyActivity = ({ dog, date, onSave, onBack, customActivities, onAddCustomActivity }) => {
  const [activities, setActivities] = useState([]);
  const [availableActivities, setAvailableActivities] = useState([]);
  const [newActivity, setNewActivity] = useState('');
  const [dailyNotes, setDailyNotes] = useState('');
  const [dailyRating, setDailyRating] = useState('');
  const [showDailyRatingPopup, setShowDailyRatingPopup] = useState(false);
  
  useEffect(() => {
    const defaultActivities = [
      'Nosework', 'Obedience Training', 'Long Walk', 'Playdate', 'Vet Visit',
      'Rest Day', 'Agility', 'Grooming', 'Swimming', 'Feeding', 'Play Time'
    ];
    setAvailableActivities([...defaultActivities, ...customActivities]);
  }, [customActivities]);

  useEffect(() => {
    const existingActivities = dog.activities?.[date] || [];
    setActivities(existingActivities);
    
    const notesEntry = existingActivities.find(a => a.type === 'notes');
    setDailyNotes(notesEntry?.content || '');
    setDailyRating(notesEntry?.rating || '');
  }, [dog, date]);

  const formatDate = (dateString) => {
    const date = new Date(dateString + 'T00:00:00');
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  };

  const addActivity = (activityName) => {
    const newActivityItem = {
      id: Date.now(),
      name: activityName,
      outcome: 'good',
      notes: ''
    };
    setActivities([...activities, newActivityItem]);
  };

  const updateActivity = (id, field, value) => {
    setActivities(activities.map(activity => 
      activity.id === id ? { ...activity, [field]: value } : activity
    ));
  };

  const removeActivity = (id) => {
    setActivities(activities.filter(activity => activity.id !== id));
  };

  const addCustomActivity = () => {
    if (newActivity.trim()) {
      addActivity(newActivity.trim());
      onAddCustomActivity(newActivity.trim());
      setNewActivity('');
    }
  };

  const handleSave = () => {
    const activitiesToSave = [...activities];
    if (dailyNotes.trim() || dailyRating) {
      activitiesToSave.push({
        id: 'notes',
        type: 'notes',
        content: dailyNotes,
        rating: dailyRating
      });
    }
    onSave(activitiesToSave);
  };

  const handleDailyNotesClick = () => {
    setShowDailyRatingPopup(true);
  };

  const handleDailyRatingSelect = (rating) => {
    setDailyRating(rating);
    setShowDailyRatingPopup(false);
  };

  const getOutcomeColor = (outcome) => {
    switch (outcome) {
      case 'good': return '#4CAF50';
      case 'okay': return '#FFB300';
      case 'bad': return '#F44336';
      default: return '#e1e5e9';
    }
  };

  return (
    <div className="daily-activity">
      <div className="activity-container">
        <header className="activity-header">
          <button onClick={onBack} className="back-btn">← Calendar</button>
          <div className="date-title">
            <h2>{formatDate(date)}</h2>
            <p>Log {dog.name}'s activities</p>
          </div>
          <button onClick={handleSave} className="save-btn">Save Day</button>
        </header>

        <div className="activity-content">
          <section className="quick-add-section">
            <h3>Quick Add Activities</h3>
            <div className="activity-buttons">
              {availableActivities.map(activity => (
                <button
                  key={activity}
                  onClick={() => addActivity(activity)}
                  className="activity-btn"
                >
                  + {activity}
                </button>
              ))}
            </div>
            
            <div className="custom-activity">
              <input
                type="text"
                value={newActivity}
                onChange={(e) => setNewActivity(e.target.value)}
                placeholder="Add custom activity..."
                onKeyPress={(e) => e.key === 'Enter' && addCustomActivity()}
              />
              <button onClick={addCustomActivity} disabled={!newActivity.trim()}>
                Add
              </button>
            </div>
          </section>

          <section className="logged-activities-section">
            <h3>Today's Activities ({activities.length})</h3>
            
            {activities.length === 0 ? (
              <div className="empty-activities">
                <p>No activities logged yet. Add some activities above!</p>
              </div>
            ) : (
              <div className="activities-list">
                {activities.map(activity => (
                  <div key={activity.id} className="activity-item">
                    <div className="activity-main">
                      <h4>{activity.name}</h4>
                      <button 
                        onClick={() => removeActivity(activity.id)}
                        className="remove-btn"
                      >
                        ×
                      </button>
                    </div>
                    
                    <div className="outcome-selector">
                      <span>How did it go?</span>
                      <div className="outcome-buttons">
                        {['good', 'okay', 'bad'].map(outcome => (
                          <button
                            key={outcome}
                            className={`outcome-btn ${activity.outcome === outcome ? 'active' : ''}`}
                            onClick={() => updateActivity(activity.id, 'outcome', outcome)}
                            style={{ 
                              borderColor: getOutcomeColor(outcome),
                              backgroundColor: activity.outcome === outcome ? getOutcomeColor(outcome) : 'transparent',
                              color: activity.outcome === outcome ? 'white' : getOutcomeColor(outcome)
                            }}
                          >
                            {outcome === 'good' ? '😊 Good' : 
                             outcome === 'okay' ? '😐 Okay' : 
                             '😞 Bad'}
                          </button>
                        ))}
                      </div>
                    </div>

                    <textarea
                      value={activity.notes}
                      onChange={(e) => updateActivity(activity.id, 'notes', e.target.value)}
                      placeholder="Add notes about this activity..."
                      rows="2"
                      className="activity-notes"
                    />
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="daily-notes-section">
            <div className="daily-notes-header">
              <h3>Daily Notes</h3>
              <button 
                className={`daily-rating-btn ${dailyRating}`}
                onClick={handleDailyNotesClick}
              >
                {dailyRating ? 
                  (dailyRating === 'good' ? '😊 Good Day' : 
                   dailyRating === 'okay' ? '😐 Okay Day' : 
                   '😞 Bad Day') : 
                  '📝 Rate Day'}
              </button>
            </div>
            <textarea
              value={dailyNotes}
              onChange={(e) => setDailyNotes(e.target.value)}
              placeholder="How was the overall day? Any observations or special notes..."
              rows="4"
              className="daily-notes"
            />
          </section>

          {showDailyRatingPopup && (
            <div className="rating-popup-overlay" onClick={() => setShowDailyRatingPopup(false)}>
              <div className="rating-popup" onClick={(e) => e.stopPropagation()}>
                <h3>How was {dog.name}'s day overall?</h3>
                <div className="rating-options">
                  <button 
                    className="rating-option good"
                    onClick={() => handleDailyRatingSelect('good')}
                  >
                    😊 Good Day
                  </button>
                  <button 
                    className="rating-option okay"
                    onClick={() => handleDailyRatingSelect('okay')}
                  >
                    😐 Okay Day
                  </button>
                  <button 
                    className="rating-option bad"
                    onClick={() => handleDailyRatingSelect('bad')}
                  >
                    😞 Bad Day
                  </button>
                </div>
                <button 
                  className="cancel-rating"
                  onClick={() => setShowDailyRatingPopup(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default DailyActivity;