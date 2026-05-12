# SafeRoute App - Code Structure & Documentation

## 📁 Project Overview
SafeRoute is a comprehensive safety-focused transit navigation application for Metro Manila, Philippines, built with Flutter and Firebase.

## 🏗️ Architecture

### **Core Structure**
```
lib/
├── main.dart                 # App entry point & main map screen
├── models/                   # Data models
│   ├── user.dart             # User profile & preferences
│   ├── auth_state.dart        # Authentication state management
│   ├── transit_route.dart     # Transit modes & route data
│   ├── incident_report.dart    # Safety incident reports
│   ├── risk_assessment.dart   # Route risk analysis
│   └── sos_alert.dart         # Emergency alerts
├── services/                  # Business logic & API layer
│   ├── auth_service.dart       # Firebase authentication
│   ├── firebase_service.dart    # Firebase initialization
│   ├── transit_service.dart     # Route finding algorithms
│   ├── incident_service.dart    # Incident reporting
│   ├── risk_service.dart       # Safety analysis
│   ├── saved_route_service.dart # User saved routes
│   ├── route_history_service.dart # Trip history tracking
│   ├── sos_service.dart         # Emergency services
│   ├── user_service.dart        # User management
│   ├── ml_risk_prediction_service.dart # AI-powered safety
│   └── barangay_data_service.dart # Local safety data
├── providers/                 # State management
│   └── auth_provider.dart      # Authentication state
├── screens/                   # UI screens
│   ├── login_screen.dart        # User authentication
│   ├── register_screen.dart      # New user registration
│   ├── profile_screen.dart       # User profile management
│   ├── saved_routes_screen.dart  # Saved routes management
│   ├── route_history_screen.dart  # Trip history
│   ├── settings_screen.dart       # App preferences
│   └── my_apps_screen.dart       # Feature hub
└── widgets/                   # Reusable UI components
    ├── safety_heatmap.dart     # Incident visualization
    ├── incident_report_dialog.dart # Incident reporting UI
    ├── sos_dialog.dart          # Emergency alert UI
    └── route_details_panel.dart # Route information display
```

## 🔐 Authentication System

### **Flow**
1. **Login Screen** → Email/password or Google sign-in
2. **Registration** → Create account with email verification
3. **Main App** → Authenticated users see map with full features
4. **Profile Management** → Edit user info, preferences, and access all features

### **Key Components**
- **AuthService**: Firebase Auth integration with email/password & Google
- **AuthProvider**: State management using Provider pattern
- **User Model**: Complete profile with preferences
- **AuthState**: Authentication status tracking

## 🗺️ Core Features

### **1. Multi-Modal Route Planning**
- **Transit Modes**: P2P Bus, Carousel Bus, City Bus, MRT, LRT, Jeepney, Modern Jeepney, UV Express
- **Route Finding**: Real-time route calculation with multiple options
- **Safety Scoring**: AI-powered risk assessment for each route
- **Cost Calculation**: Accurate fare estimation across different modes

### **2. Safety Features**
- **Heatmap**: Real-time incident visualization on map
- **Incident Reporting**: User-reported safety concerns
- **Risk Assessment**: ML-based safety predictions
- **SOS System**: Emergency contact and alert system
- **Location Sharing**: Optional location sharing for safety

### **3. User Management**
- **Profile System**: Complete user information management
- **Saved Routes**: Favorite and frequently used routes
- **Route History**: Complete trip tracking and analytics
- **Preferences**: Customizable app experience

### **4. Data Persistence**
- **Firebase Firestore**: User data, routes, history, incidents
- **Real-time Updates**: Live data synchronization
- **Offline Support**: Local caching for critical features

## 📱 Screen Details

### **Main Screen (main.dart)**
- **Google Maps Integration**: Interactive map with real-time location
- **Route Visualization**: Polylines, markers, and route segments
- **Search Functionality**: Google Places autocomplete for locations
- **Quick Actions**: Save routes, report incidents, SOS button
- **Multi-route Selection**: Compare different route options
- **Safety Overlays**: Toggle incident heatmap display

### **Profile Screen (profile_screen.dart)**
- **User Information**: Display name, email, photo, member since
- **Edit Profile**: Update display name and phone number
- **Account Statistics**: Show login frequency and account age
- **Quick Access**: Direct navigation to all app features
- **Email Verification**: Show verification status

### **Saved Routes (saved_routes_screen.dart)**
- **Route Cards**: Visual representation with transport mode icons
- **Map Preview**: Mini-map showing route overview
- **Route Details**: Time, cost, safety score, addresses
- **Actions**: Navigate, save, delete routes
- **Search & Filter**: Find specific saved routes
- **Empty State**: Call-to-action for first-time users

### **Route History (route_history_screen.dart)**
- **Trip Timeline**: Chronological list of completed journeys
- **Trip Details**: Start/end points, duration, cost, safety
- **Search Function**: Filter history by location or transport mode
- **Actions**: Reuse routes, save to favorites, delete items
- **Statistics**: Total trips, average time, cost tracking
- **Clear History**: Bulk delete with confirmation

### **Settings (settings_screen.dart)**
- **Account Settings**: Email notifications, location sharing
- **Preferences**: Default transport, dark mode, language
- **Safety Settings**: Emergency contacts, privacy controls
- **Data Management**: Storage usage and privacy controls
- **About Section**: App version, terms, privacy policy
- **Real-time Save**: Instant preference synchronization

### **My Apps Hub (my_apps_screen.dart)**
- **Grid Layout**: 2x2 grid of feature cards
- **Feature Cards**: Profile, Saved Routes, History, Settings, SOS, Safety, Trip Planner, Transport Guide
- **Visual Design**: Color-coded cards with icons and descriptions
- **Navigation**: Direct access to all major app sections
- **Future Expansion**: Placeholder cards for upcoming features

## 🔧 Technical Implementation

### **State Management**
- **Provider Pattern**: Using Flutter Provider for global state
- **Authentication State**: Real-time auth status tracking
- **Local State**: Screen-specific state management with setState

### **API Integration**
- **Google Maps API**: Places autocomplete and route display
- **Firebase Auth**: User authentication and profile management
- **Firebase Firestore**: Real-time data synchronization
- **Geolocation**: Current location and route tracking

### **Data Models**
- **User Model**: Profile, preferences, authentication data
- **Route Models**: Multi-modal routes with segments and safety data
- **Incident Models**: Safety reports with location and severity
- **History Models**: Trip tracking with analytics

### **UI Components**
- **Material Design 3**: Modern, consistent interface
- **Custom Widgets**: Reusable components for common patterns
- **Responsive Design**: Adapts to different screen sizes
- **Error Handling**: User-friendly error messages and recovery

## 🎨 Design System

### **Color Palette**
- **Primary**: Blue (#2196F3) - Main app color
- **Secondary**: Various colors for transport modes
- **Success**: Green (#4CAF50) - Positive actions
- **Warning**: Orange (#FF9800) - Alerts and warnings
- **Error**: Red (#F44336) - Errors and dangers

### **Typography**
- **Headlines**: Bold, 24px for titles
- **Body**: Regular, 16px for content
- **Caption**: Small, 12px for metadata
- **Consistent**: Material Design 3 text styles

### **Iconography**
- **Transport Icons**: Unique icons for each transit mode
- **Action Icons**: Consistent Material icons throughout
- **Status Indicators**: Clear visual feedback for states

## 🔒 Security & Privacy

### **Authentication Security**
- **Firebase Auth**: Secure authentication with email verification
- **Password Requirements**: Minimum 6 characters with validation
- **Session Management**: Automatic logout and token refresh
- **OAuth Integration**: Google sign-in with proper scopes

### **Data Privacy**
- **Location Data**: User-controlled sharing preferences
- **Personal Information**: Optional profile fields with privacy controls
- **Data Encryption**: Firebase-provided encryption in transit
- **Data Deletion**: User can delete all personal data

## 📊 Analytics & Tracking

### **User Analytics**
- **Trip Counting**: Total journeys and frequency
- **Route Preferences**: Most used transport modes
- **Safety Metrics**: Incident reports and risk scores
- **App Usage**: Feature utilization tracking

### **Performance Monitoring**
- **Route Calculation**: Timing and accuracy metrics
- **API Usage**: Rate limiting and error tracking
- **Crash Reporting**: Automatic error collection
- **User Feedback**: In-app rating and review system

## 🚀 Future Enhancements

### **Planned Features**
- **Trip Planner**: Advanced journey planning with reminders
- **Transport Guide**: Detailed information about each transit mode
- **Social Features**: Route sharing and community insights
- **Offline Mode**: Downloadable maps for areas with poor connectivity
- **Accessibility**: Voice navigation and screen reader support
- **Analytics Dashboard**: Personal travel statistics and insights

### **Technical Improvements**
- **Performance**: Optimize route calculation algorithms
- **UI/UX**: Enhanced animations and micro-interactions
- **Battery Optimization**: Reduced power consumption for background features
- **Network Efficiency**: Smart caching and data compression

---

## 📝 Development Notes

### **Key Dependencies**
- `flutter`: Core framework
- `firebase_auth`: Authentication
- `cloud_firestore`: Database
- `google_maps_flutter`: Maps and location
- `provider`: State management
- `geolocator`: Location services

### **Development Commands**
```bash
flutter pub get          # Install dependencies
flutter run              # Run development app
flutter build            # Build for production
flutter test             # Run tests
```

### **Code Style**
- **Dart Style**: Following official Dart conventions
- **Flutter Lints**: Enforced code quality
- **Documentation**: Comprehensive code comments
- **Error Handling**: Proper try-catch blocks with user feedback

---

This documentation provides a complete overview of the SafeRoute application architecture, features, and implementation details. Each component is designed with modularity, scalability, and maintainability in mind.
