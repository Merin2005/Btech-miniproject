# WorkLink – Errands & Labor Marketplace

WorkLink is a web-based marketplace that connects customers with skilled, semi-skilled, and unskilled workers for completing day-to-day jobs and errands. The platform allows customers to post jobs, workers to apply for available jobs, and administrators to manage the overall system efficiently.

---

## Live Demo

🌐 Application URL:
https://worklink-frontend-9as1.onrender.com

---

## Features

### Customer
- User Registration & Login
- Create and Manage Jobs
- Upload Job Images
- View Job Applications
- Hire Workers
- Live Worker Tracking
- OTP-Based Job Verification
- Rate Workers after Job Completion

### Worker
- User Registration & Login
- Create Worker Profile
- Browse Available Jobs
- Apply for Jobs
- Update Live Location
- Complete Assigned Jobs
- Upload Completion Proof

### Admin
- Manage Users
- Monitor Jobs
- View Platform Statistics

---

## Tech Stack

### Frontend
- React.js
- React Router
- Axios
- Leaflet Maps

### Backend
- Node.js
- Express.js
- Socket.IO
- JWT Authentication
- Multer

### Database
- PostgreSQL

---

## Project Structure

```
worklink/
│
├── frontend/
│   ├── src/
│   ├── public/
│   └── package.json
│
├── backend/
│   ├── controllers/
│   ├── routes/
│   ├── uploads/
│   ├── server.js
│   └── package.json
│
└── README.md
```

---

## Installation

### Clone the Repository

```bash
git clone https://github.com/Merin2005/Btech-miniproject.git
```

### Frontend

```bash
cd frontend
npm install
npm start
```

### Backend

```bash
cd backend
npm install
npm run dev
```

---

## Environment Variables

Create a `.env` file inside the backend folder and configure:

```
PORT=
DB_USER=
DB_HOST=
DB_NAME=
DB_PASSWORD=
DB_PORT=
JWT_SECRET=
GROQ_API_KEY=
```

---

## Key Functionalities

- Secure User Authentication
- Job Posting and Management
- Worker Job Applications
- Live Worker Location Tracking
- OTP-Based Work Verification
- Image Upload for Job Completion
- Real-Time Notifications using Socket.IO
- Worker Rating System

---

## Future Enhancements

- Online Payment Gateway
- AI-Based Worker Recommendation
- Chat System
- Push Notifications
- Mobile Application
- Multi-language Support

---

## Team

- Merin Sebastian
- Athira Renjith
- Poorna M
-  Vismaya Vinod
   
---

## License

This project is developed for academic purposes as part of the B.Tech Computer Science and Engineering curriculum.
