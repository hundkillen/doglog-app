import React, { useState, useRef } from 'react';
import './AddEditDog.css';

const AddEditDog = ({ dog, onSave, onCancel, isEdit }) => {
  const [formData, setFormData] = useState({
    name: dog?.name || '',
    breed: dog?.breed || '',
    dateOfBirth: dog?.dateOfBirth || '',
    gender: dog?.gender || 'male',
    notes: dog?.notes || '',
    photo: dog?.photo || null
  });
  
  const fileInputRef = useRef(null);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formData.name.trim()) return;
    
    const age = formData.dateOfBirth ? 
      Math.floor((new Date() - new Date(formData.dateOfBirth)) / (365.25 * 24 * 60 * 60 * 1000)) : null;
    
    onSave({
      ...formData,
      age
    });
  };

  const handlePhotoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        setFormData(prev => ({ ...prev, photo: e.target.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className="add-edit-dog">
      <div className="form-container">
        <header className="form-header">
          <h2>{isEdit ? 'Edit Dog' : 'Add New Dog'}</h2>
        </header>
        
        <form onSubmit={handleSubmit} className="dog-form">
          <div className="photo-section">
            <div className="photo-preview" onClick={() => fileInputRef.current?.click()}>
              {formData.photo ? (
                <img src={formData.photo} alt="Dog preview" />
              ) : (
                <div className="photo-placeholder">
                  <span>📸</span>
                  <p>Add Photo</p>
                </div>
              )}
            </div>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handlePhotoChange}
              style={{ display: 'none' }}
            />
          </div>

          <div className="form-grid">
            <div className="form-group">
              <label htmlFor="name">Name *</label>
              <input
                id="name"
                type="text"
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                placeholder="Enter dog's name"
                required
              />
            </div>

            <div className="form-group">
              <label htmlFor="breed">Breed</label>
              <input
                id="breed"
                type="text"
                value={formData.breed}
                onChange={(e) => setFormData(prev => ({ ...prev, breed: e.target.value }))}
                placeholder="e.g., Golden Retriever"
              />
            </div>

            <div className="form-group">
              <label htmlFor="dateOfBirth">Date of Birth</label>
              <input
                id="dateOfBirth"
                type="date"
                value={formData.dateOfBirth}
                onChange={(e) => setFormData(prev => ({ ...prev, dateOfBirth: e.target.value }))}
              />
            </div>

            <div className="form-group">
              <label htmlFor="gender">Gender</label>
              <select
                id="gender"
                value={formData.gender}
                onChange={(e) => setFormData(prev => ({ ...prev, gender: e.target.value }))}
              >
                <option value="male">Male</option>
                <option value="female">Female</option>
              </select>
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="notes">Notes</label>
            <textarea
              id="notes"
              value={formData.notes}
              onChange={(e) => setFormData(prev => ({ ...prev, notes: e.target.value }))}
              placeholder="Any additional information about your dog..."
              rows="3"
            />
          </div>

          <div className="form-actions">
            <button type="button" onClick={onCancel} className="cancel-btn">
              Cancel
            </button>
            <button type="submit" className="save-btn">
              {isEdit ? 'Save Changes' : 'Add Dog'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AddEditDog;