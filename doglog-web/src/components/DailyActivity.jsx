import React, { useState, useEffect } from 'react';
import './DailyActivity.css';

const DailyActivity = ({ dog, date, onSave, onBack }) => {
  const [activities, setActivities] = useState([]);
  const [availableActivities, setAvailableActivities] = useState([
    'Nosework', 'Obedience Training', 'Long Walk', 'Playdate', 'Vet Visit',
    'Rest Day', 'Agility', 'Grooming', 'Swimming', 'Feeding', 'Play Time'
  ]);
  const [newActivity, setNewActivity] = useState('');
  const [dailyNotes, setDailyNotes] = useState('');
  
  useEffect(() => {
    const existingActivities = dog.activities?.[date] || [];
    setActivities(existingActivities);
    
    const existingNotes = existingActivities.find(a => a.type === 'notes')?.content || '';
    setDailyNotes(existingNotes);
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
      setAvailableActivities([...availableActivities, newActivity.trim()]);
      setNewActivity('');
    }
  };

  const handleSave = () => {
    const activitiesToSave = [...activities];
    if (dailyNotes.trim()) {
      activitiesToSave.push({
        id: 'notes',
        type: 'notes',
        content: dailyNotes
      });
    }
    onSave(activitiesToSave);
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
            <h3>Daily Notes</h3>
            <textarea
              value={dailyNotes}
              onChange={(e) => setDailyNotes(e.target.value)}
              placeholder="How was the overall day? Any observations or special notes..."
              rows="4"
              className="daily-notes"
            />
          </section>
        </div>
      </div>
    </div>
  );
};

export default DailyActivity;