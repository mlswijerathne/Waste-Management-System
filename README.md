# Waste Management SystemA comprehensive Flutter application designed to address urban waste management challenges by connecting residents, drivers, and city management through a digital platform.## Table of Contents- [Overview](#overview)- [Features](#features)- [Screenshots](#screenshots)- [User Roles](#user-roles)- [Technologies Used](#technologies-used)- [Setup](#setup)## OverviewThis Waste Management System is a mobile application that facilitates efficient waste collection and management in urban areas. The system connects three main stakeholders:1. **Residents** - Can report cleanliness issues, request special garbage collection, track waste collection vehicles, and receive notifications2. **Drivers** - Can view assigned routes, report breakdowns, manage special garbage requests, and update route completion status3. **City Management** - Can manage routes, assign drivers, handle resident reports, and oversee the entire waste management operation

## Features

### Resident Features
- Report cleanliness issues with location selection and photo upload
- Request special garbage collection services
- Track active waste collection routes in real-time
- View recent reports and requests
- Receive notifications about collection schedules and updates
- Update profile and location settings

### Driver Features
- View and manage assigned collection routes
- Mark collection points as completed
- Report vehicle breakdowns with details and location
- Handle special garbage collection requests
- View cleanliness issues assigned to them
- Receive notifications about new assignments

### City Management (Admin) Features
- Create and manage collection routes
- Assign routes to drivers
- View and manage all cleanliness issues
- Handle vehicle breakdown reports
- Process special garbage collection requests
- Monitor active drivers and routes
- Access analytics and reports on waste management operations






## User Roles

### Resident
The primary users who report issues and request services. Residents can track garbage collection vehicles and receive notifications about collection schedules.

### Driver
Responsible for waste collection operations. Drivers follow assigned routes, report issues, and update collection status.

### City Management (Admin)
Oversees the entire waste management system, assigns routes to drivers, handles resident reports, and manages operational aspects.

## Technologies Used

- **Frontend**: Flutter
- **Backend**: Firebase (Authentication, Firestore, Storage, Messaging)
- **Maps & Location**: Google Maps, Geolocator
- **Authentication**: Firebase Auth, Google Sign-In
- **Notifications**: Firebase Messaging
- **State Management**: Provider

## Setup

1. Clone the repository
2. Install Flutter (version 3.7.0 or higher)
3. Run `flutter pub get` to install dependencies
4. Configure Firebase project and add required configuration files
5. Run `flutter run` to launch the application
