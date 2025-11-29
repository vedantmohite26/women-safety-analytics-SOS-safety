// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyA-rOjxCCmH3S2FNrgu5gt0iTei778l8Gg",
    authDomain: "women-safety-analytics-a-dabd0.firebaseapp.com",
    databaseURL: "https://women-safety-analytics-a-dabd0-default-rtdb.firebaseio.com",
    projectId: "women-safety-analytics-a-dabd0",
    storageBucket: "women-safety-analytics-a-dabd0.firebasestorage.app",
    messagingSenderId: "462311074646",
    appId: "1:462311074646:android:6c149581bbae77e74604f7"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();

console.log('Firebase initialized successfully');
