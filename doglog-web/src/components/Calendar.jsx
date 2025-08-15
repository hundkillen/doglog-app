import React, { useState } from 'react';
import './Calendar.css';

const Calendar = ({ dog, onDateSelect }) => {
  const [currentDate, setCurrentDate] = useState(new Date());
  
  const today = new Date();
  const currentYear = currentDate.getFullYear();
  const currentMonth = currentDate.getMonth();
  
  const firstDayOfMonth = new Date(currentYear, currentMonth, 1);
  const lastDayOfMonth = new Date(currentYear, currentMonth + 1, 0);
  const firstDayWeekday = firstDayOfMonth.getDay();
  const daysInMonth = lastDayOfMonth.getDate();
  
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  const previousMonth = () => {
    setCurrentDate(new Date(currentYear, currentMonth - 1, 1));
  };
  
  const nextMonth = () => {
    setCurrentDate(new Date(currentYear, currentMonth + 1, 1));
  };
  
  const getDayStatus = (day) => {
    const dateKey = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const dayActivities = dog.activities?.[dateKey];
    
    if (!dayActivities || dayActivities.length === 0) {
      return 'none';
    }

    // Check for daily rating first (from notes)
    const notesEntry = dayActivities.find(a => a.type === 'notes');
    if (notesEntry && notesEntry.rating) {
      return notesEntry.rating;
    }
    
    // Fallback to activity outcomes
    const outcomes = dayActivities.filter(a => a.outcome).map(activity => activity.outcome);
    if (outcomes.length === 0) return 'none';
    
    const goodCount = outcomes.filter(o => o === 'good').length;
    const badCount = outcomes.filter(o => o === 'bad').length;
    const okayCount = outcomes.filter(o => o === 'okay').length;
    
    if (badCount > goodCount && badCount > okayCount) return 'bad';
    if (goodCount >= okayCount && goodCount >= badCount) return 'good';
    return 'okay';
  };
  
  const handleDateClick = (day) => {
    const dateKey = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    onDateSelect(dateKey);
  };
  
  const renderCalendarDays = () => {
    const days = [];
    
    // Empty cells for days before the first day of the month
    for (let i = 0; i < firstDayWeekday; i++) {
      days.push(<div key={`empty-${i}`} className="calendar-day empty"></div>);
    }
    
    // Days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const isToday = 
        currentYear === today.getFullYear() && 
        currentMonth === today.getMonth() && 
        day === today.getDate();
      
      const status = getDayStatus(day);
      const dateKey = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const hasActivities = dog.activities?.[dateKey]?.length > 0;
      
      days.push(
        <div
          key={day}
          className={`calendar-day ${status} ${isToday ? 'today' : ''} ${hasActivities ? 'has-activities' : ''}`}
          onClick={() => handleDateClick(day)}
        >
          <span className="day-number">{day}</span>
          {hasActivities && (
            <div className="activity-indicators">
              {dog.activities[dateKey].filter(a => a.outcome).slice(0, 3).map((activity, index) => (
                <div 
                  key={index} 
                  className={`activity-dot ${activity.outcome}`}
                  title={activity.name}
                ></div>
              ))}
              {dog.activities[dateKey].filter(a => a.outcome).length > 3 && (
                <div className="activity-dot more">+{dog.activities[dateKey].filter(a => a.outcome).length - 3}</div>
              )}
            </div>
          )}
        </div>
      );
    }
    
    return days;
  };
  
  return (
    <div className="calendar">
      <div className="calendar-header">
        <button onClick={previousMonth} className="nav-arrow">‹</button>
        <h2>{monthNames[currentMonth]} {currentYear}</h2>
        <button onClick={nextMonth} className="nav-arrow">›</button>
      </div>
      
      <div className="calendar-weekdays">
        {dayNames.map(day => (
          <div key={day} className="weekday">{day}</div>
        ))}
      </div>
      
      <div className="calendar-grid">
        {renderCalendarDays()}
      </div>
      
      <div className="calendar-legend">
        <div className="legend-item">
          <div className="legend-color good"></div>
          <span>Good Day</span>
        </div>
        <div className="legend-item">
          <div className="legend-color okay"></div>
          <span>Okay Day</span>
        </div>
        <div className="legend-item">
          <div className="legend-color bad"></div>
          <span>Bad Day</span>
        </div>
      </div>
    </div>
  );
};

export default Calendar;