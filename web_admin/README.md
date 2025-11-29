# Women Safety Analytics - Admin Web Dashboard

A modern, responsive admin dashboard for monitoring and managing the Women Safety Analytics system.

## Features

### 📊 Dashboard Overview
- **Real-time Statistics**: Monitor total users, active SOS alerts, resolved cases, and average response times
- **Interactive Charts**: Visualize alert activity over time with beautiful gradient charts
- **Modern UI**: Clean, professional interface with smooth animations and transitions

### 🚨 SOS Alert Management
- View all active and resolved SOS alerts
- Quick action buttons to view details or resolve alerts
- Real-time status updates with color-coded badges
- User location and timestamp information

### 👥 User Management
- Complete user directory with contact information
- Display both Firebase Auth phone numbers and custom contact numbers
- Search functionality to quickly find users
- Verification status indicators

### 🎨 Design Features
- **Responsive Layout**: Works seamlessly on desktop, tablet, and mobile devices
- **Dark Sidebar**: Professional dark-themed navigation
- **Gradient Accents**: Eye-catching gradient colors throughout
- **Smooth Animations**: Micro-interactions for better user experience
- **Modern Typography**: Uses Inter font for clean, readable text

## Setup Instructions

### Option 1: Open Directly in Browser
1. Navigate to the `web_admin` folder
2. Open `index.html` in your web browser

### Option 2: Use a Local Server (Recommended)
```bash
# Navigate to the web_admin directory
cd "c:\fakt projects\project 2\flutter_application_1\web_admin"

# Option 1: Using Python
python -m http.server 8000

# Option 2: Using Node.js (if you have http-server installed)
npx http-server -p 8000

# Then open http://localhost:8000 in your browser
```

## File Structure

```
web_admin/
├── index.html      # Main HTML structure
├── styles.css      # All styling and animations
├── script.js       # Interactive functionality
└── README.md       # This file
```

## Technology Stack

- **HTML5**: Semantic markup
- **CSS3**: Modern styling with gradients, flexbox, grid
- **Vanilla JavaScript**: No framework dependencies
- **Canvas API**: For chart rendering

## Future Enhancements

To connect this dashboard to your Firebase backend, you'll need to:

1. **Add Firebase SDK**
   ```html
   <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
   <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js"></script>
   ```

2. **Initialize Firebase**
   ```javascript
   const firebaseConfig = {
     // Your Firebase config here
   };
   firebase.initializeApp(firebaseConfig);
   const db = firebase.firestore();
   ```

3. **Fetch Real Data**
   ```javascript
   // Example: Listen to SOS alerts
   db.collection('sos_alerts')
     .where('status', '==', 'active')
     .onSnapshot(snapshot => {
       // Update UI with real alerts
     });
   ```

4. **User Authentication**
   - Add Firebase Authentication
   - Implement admin login flow
   - Protect dashboard routes

## Color Scheme

- Primary: `#E91E63` (Pink/Red - Safety/Alert)
- Secondary: `#2196F3` (Blue - Trust/Calm)
- Success: `#10B981` (Green)
- Danger: `#EF4444` (Red)
- Warning: `#F59E0B` (Amber)

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## License

Part of the Women Safety Analytics project.
