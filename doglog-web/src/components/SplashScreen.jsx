import React from 'react';
import './SplashScreen.css';

const SplashScreen = () => {
  return (
    <div className="splash-screen">
      <div className="splash-content">
        <div className="logo-container">
          <div className="paw-icon">🐾</div>
          <h1 className="app-name">DogLog</h1>
          <p className="app-tagline">Track • Analyze • Improve</p>
        </div>
      </div>
    </div>
  );
};

export default SplashScreen;