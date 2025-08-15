import React, { useState, useEffect } from 'react';
import './App.css';
import SplashScreen from './components/SplashScreen';
import DogGallery from './components/DogGallery';
import DogPage from './components/DogPage';
import AddEditDog from './components/AddEditDog';

function App() {
  const [showSplash, setShowSplash] = useState(true);
  const [currentView, setCurrentView] = useState('gallery');
  const [selectedDog, setSelectedDog] = useState(null);
  const [editingDog, setEditingDog] = useState(null);
  const [dogs, setDogs] = useState([]);
  const [customActivities, setCustomActivities] = useState([]);

  useEffect(() => {
    const timer = setTimeout(() => setShowSplash(false), 2500);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    const savedDogs = localStorage.getItem('doglog-dogs');
    if (savedDogs) {
      setDogs(JSON.parse(savedDogs));
    }
    
    const savedCustomActivities = localStorage.getItem('doglog-custom-activities');
    if (savedCustomActivities) {
      setCustomActivities(JSON.parse(savedCustomActivities));
    }
  }, []);

  const saveDogs = (updatedDogs) => {
    setDogs(updatedDogs);
    localStorage.setItem('doglog-dogs', JSON.stringify(updatedDogs));
  };

  const addDog = (dogData) => {
    const newDog = {
      id: Date.now(),
      ...dogData,
      activities: {}
    };
    saveDogs([...dogs, newDog]);
    setCurrentView('gallery');
    setEditingDog(null);
  };

  const updateDog = (dogData) => {
    const updatedDogs = dogs.map(dog => 
      dog.id === editingDog.id ? { ...dog, ...dogData } : dog
    );
    saveDogs(updatedDogs);
    setCurrentView('gallery');
    setEditingDog(null);
  };

  const deleteDog = (dogId) => {
    const updatedDogs = dogs.filter(dog => dog.id !== dogId);
    saveDogs(updatedDogs);
    setCurrentView('gallery');
    setSelectedDog(null);
  };

  const updateDogActivities = (dogId, date, activities) => {
    const updatedDogs = dogs.map(dog => {
      if (dog.id === dogId) {
        return {
          ...dog,
          activities: {
            ...dog.activities,
            [date]: activities
          }
        };
      }
      return dog;
    });
    saveDogs(updatedDogs);
  };

  const addCustomActivity = (activityName) => {
    if (!customActivities.includes(activityName)) {
      const updatedActivities = [...customActivities, activityName];
      setCustomActivities(updatedActivities);
      localStorage.setItem('doglog-custom-activities', JSON.stringify(updatedActivities));
    }
  };

  if (showSplash) {
    return <SplashScreen />;
  }

  return (
    <div className="App">
      {currentView === 'gallery' && (
        <DogGallery 
          dogs={dogs}
          onSelectDog={(dog) => {
            setSelectedDog(dog);
            setCurrentView('dog');
          }}
          onAddDog={() => {
            setEditingDog(null);
            setCurrentView('add');
          }}
        />
      )}
      
      {currentView === 'dog' && selectedDog && (
        <DogPage 
          dog={selectedDog}
          onBack={() => setCurrentView('gallery')}
          onEdit={() => {
            setEditingDog(selectedDog);
            setCurrentView('edit');
          }}
          onDelete={() => deleteDog(selectedDog.id)}
          onUpdateActivities={updateDogActivities}
          customActivities={customActivities}
          onAddCustomActivity={addCustomActivity}
        />
      )}
      
      {(currentView === 'add' || currentView === 'edit') && (
        <AddEditDog 
          dog={editingDog}
          onSave={editingDog ? updateDog : addDog}
          onCancel={() => setCurrentView('gallery')}
          isEdit={currentView === 'edit'}
        />
      )}
    </div>
  );
}

export default App
