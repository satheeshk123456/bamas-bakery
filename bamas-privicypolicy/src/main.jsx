import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import PrivacyPolicy from './PrivacyPolicy.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        {/* Main route Play Store / App Store will link to */}
        <Route path="/privicypolicy" element={<PrivacyPolicy />} />
        {/* Also serve it at the common correct spelling, just in case */}
        <Route path="/privacypolicy" element={<PrivacyPolicy />} />
        <Route path="/privacy-policy" element={<PrivacyPolicy />} />
        {/* Visiting the bare domain also shows the policy */}
        <Route path="/" element={<Navigate to="/privicypolicy" replace />} />
        <Route path="*" element={<Navigate to="/privicypolicy" replace />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
)
