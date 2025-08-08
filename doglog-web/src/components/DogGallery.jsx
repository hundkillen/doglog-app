import React from 'react';
import './DogGallery.css';

const DogGallery = ({ dogs, onSelectDog, onAddDog }) => {
  return (
    <div className="dog-gallery">
      <header className="gallery-header">
        <h1>DogLog</h1>
        <p>Your furry friends' daily tracker</p>
      </header>
      
      <div className="dogs-grid">
        {dogs.map(dog => (
          <div 
            key={dog.id} 
            className="dog-card"
            onClick={() => onSelectDog(dog)}
          >
            <div className="dog-photo">
              {dog.photo ? (
                <img src={dog.photo} alt={dog.name} />
              ) : (
                <div className="photo-placeholder">🐕</div>
              )}
            </div>
            <div className="dog-info">
              <h3>{dog.name}</h3>
              <p>{dog.breed}</p>
              <p>{dog.age ? `${dog.age} years old` : 'Age not set'}</p>
            </div>
          </div>
        ))}
        
        <div className="add-dog-card" onClick={onAddDog}>
          <div className="add-icon">+</div>
          <p>Add Dog</p>
        </div>
      </div>
      
      {dogs.length === 0 && (
        <div className="empty-state">
          <div className="empty-icon">🐾</div>
          <h2>No dogs yet!</h2>
          <p>Add your first furry friend to get started tracking their activities.</p>
        </div>
      )}
    </div>
  );
};

export default DogGallery;