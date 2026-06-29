# Split Buddy 🌍💸

Split Buddy is a full-stack, cross-platform expense sharing application built with Flutter and a Dart (Shelf) backend. It allows users to create groups, share expenses, chat securely with end-to-end encryption (E2EE), and settle balances seamlessly. 

The app features a custom MongoDB backend running alongside a compiled Flutter web application in a unified Docker container.

## Features ✨
* **Expense Tracking:** Create groups and split bills with friends.
* **Real-time Synchronization:** See expenses, balances, and activities update in real time.
* **End-to-End Encrypted Chat:** Secure group messaging using AES encryption.
* **Live Location Sharing:** See where your friends are during group trips.
* **AI Trip Planner:** Generate personalized travel itineraries using Gemini AI.
* **Full Stack Dart:** One language for both the frontend (Flutter) and backend (Shelf).

---

## 🚀 How to Run the Project Locally

Follow these steps if you want to run or contribute to this project on your local machine.

### Prerequisites
1. **Flutter SDK** (v3.19 or higher)
2. **Dart SDK** (v3.0 or higher)
3. **MongoDB** (running locally on `mongodb://localhost:27017` or a cloud instance)

### 1. Clone the repository
```bash
git clone https://github.com/rohancoder19/Split_Buddy.git
cd Split_Buddy
```

### 2. Install Dependencies
Get all the required packages for the Flutter frontend and the Dart backend:
```bash
flutter pub get
```

### 3. Setup Environment Variables
If you want to use the AI Trip Planner, you need a Gemini API Key.
You can run the app with the API key by passing it via Dart defines:
```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_api_key_here
```

### 4. Running the Backend Server
The backend is built with `shelf_router` and `mongo_dart`. It also serves the compiled Flutter web app static files. 
To start the backend server on `localhost:3000`:
```bash
dart run bin/server.dart
```

### 5. Running the Flutter App (Development Mode)
If you want to work on the UI with hot-reload, run the Flutter app separately:
```bash
flutter run
```
*(Make sure to update the `baseUrl` inside `lib/services/api_service.dart` to point to `http://localhost:3000` during local development).*

---

## 🐳 Deployment (Docker & Cloud Run / Render)

This project contains a `Dockerfile` that builds both the Flutter web app and the Dart server into a single container.

**To build the Docker image:**
```bash
docker build -t split-buddy .
```

**To run the Docker image:**
```bash
docker run -p 8080:8080 split-buddy
```

You can deploy this repository directly to **Google Cloud Run** or **Render.com** using the included `Dockerfile` and `render.yaml`.