/**
 * WorkerJob.js  —  WORKER VIEW
 * Place at: frontend/src/pages/Jobs/WorkerJob.js
 *
 * Location tab shows the same LiveTrackingMap as the customer (TrackWorker).
 * Destination resolved from customer's raw GPS lat/lng — not text geocoding.
 * Worker's own position comes from navigator.geolocation (real GPS chip).
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import axios from 'axios';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { io } from 'socket.io-client';
import LiveTrackingMap from '../Map/LiveTrackingMap';

const API = 'http://localhost:5000';

// Reverse-geocode GPS → human-readable place name (label only, not for positioning)
const reverseGeocode = async (lat, lng) => {
  try {
    const r = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`,
      { headers: { 'Accept-Language': 'en' } }
    );
    const d = await r.json();
    if (d?.address) {
      const place = d.address.village || d.address.town || d.address.city || d.address.suburb || '';
      const district = d.address.county || d.address.state_district || '';
      return [place, district].filter(Boolean).join(', ') || d.display_name?.split(',').slice(0,3).join(', ');
    }
  } catch (_) {}
  return null;
};

// ─────────────────────────────────────────────────────────────────────────────
const WorkerJob = () => {
  const { jobId } = useParams();
  const { token } = useAuth();
  const navigate  = useNavigate();

  const [job,             setJob]             = useState(null);
  const [otp,             setOtp]             = useState(null);
  const [payment,         setPayment]         = useState(null);
  const [bond,            setBond]            = useState(null);
  const [otpInput,        setOtpInput]        = useState('');
  const [loading,         setLoading]         = useState(true);
  const [activeTab,       setActiveTab]       = useState('details');
  const [locationSharing, setLocationSharing] = useState(false);
  const [completionPhoto, setCompletionPhoto] = useState(null);
  const [completing,      setCompleting]      = useState(false);
  const [customerAddress, setCustomerAddress] = useState(null);
  const [workerPos,       setWorkerPos]       = useState(null); // {lat,lng} — real GPS
  const [destPos,         setDestPos]         = useState(null); // {lat,lng,label} — customer GPS
  const [currentPlace,    setCurrentPlace]    = useState(null); // "Koorali, Thrissur"

  const watchIdRef = useRef(null);
  const socketRef  = useRef(null);
  const tokenRef   = useRef(token);
  tokenRef.current = token;

  // ── Socket ────────────────────────────────────────────────────────────────
  useEffect(() => {
    const socket = io(API, { transports: ['websocket', 'polling'] });
    socketRef.current = socket;
    socket.emit('join_room', jobId);

    // Both worker and customer maps read workerPos from this broadcast.
    // Single source of truth — both profiles always show identical coordinates.
    socket.on('worker_location_update', ({ latitude, longitude }) => {
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      if (!isNaN(lat) && !isNaN(lng)) setWorkerPos({ lat, lng });
    });

    return () => socket.disconnect();
  }, [jobId]);

  // ── Fetch all job data ────────────────────────────────────────────────────
  const fetchAll = useCallback(async () => {
    try {
      const hdr = { Authorization: `Bearer ${tokenRef.current}` };
      const jobRes = await axios.get(`${API}/api/jobs/${jobId}`, { headers: hdr });
      const j = jobRes.data.job;
      setJob(j);

      try { const r = await axios.get(`${API}/api/otp/${jobId}`, { headers: hdr });       setOtp(r.data.otp); }         catch (_) {}
      try { const r = await axios.get(`${API}/api/payments/${jobId}`, { headers: hdr });  setPayment(r.data.payment); } catch (_) {}
      try { const r = await axios.get(`${API}/api/bonds/${jobId}`, { headers: hdr });     setBond(r.data.bond); }       catch (_) {}

      // Customer address (for display text)
      try {
        const r = await axios.get(`${API}/api/applications/${jobId}/customer-address`, { headers: hdr });
        setCustomerAddress(r.data);
      } catch (_) {}

      // ── DESTINATION GPS: raw coordinates only, never geocode text ────────
      // Priority: customer-address GPS → customer profile GPS → job GPS
      let destLat = null, destLng = null, destLabel = '';

      // 1. Application / customer-address endpoint
      try {
        const r = await axios.get(`${API}/api/applications/${jobId}/customer-address`, { headers: hdr });
        const a = r.data;
        if (a?.latitude && a?.longitude) {
          destLat   = parseFloat(a.latitude);
          destLng   = parseFloat(a.longitude);
          destLabel = a.address || a.area || '';
        }
      } catch (_) {}

      // 2. Customer profile GPS
      if (!destLat) {
        try {
          // get customer user_id from job, then fetch their profile
          const custId = j.customer_id || j.user_id;
          if (custId) {
            const r = await axios.get(`${API}/api/auth/user/${custId}`, { headers: hdr });
            const u = r.data.user;
            if (u?.latitude && u?.longitude) {
              destLat   = parseFloat(u.latitude);
              destLng   = parseFloat(u.longitude);
              destLabel = u.address || '';
            }
          }
        } catch (_) {}
      }

      // 3. Job record GPS
      if (!destLat && j.latitude && j.longitude) {
        destLat   = parseFloat(j.latitude);
        destLng   = parseFloat(j.longitude);
        destLabel = j.location || '';
      }

      if (destLat && destLng) {
        if (!destLabel) destLabel = await reverseGeocode(destLat, destLng) || '';
        setDestPos({ lat: destLat, lng: destLng, label: destLabel });
      }

    } catch (err) { console.error('WorkerJob fetchAll:', err.message); }
    finally { setLoading(false); }
  }, [jobId]);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // ── GPS sharing ───────────────────────────────────────────────────────────
  const shareLocation = () => {
    if (!navigator.geolocation) {
      alert('Geolocation not supported. Use Chrome on a real device.');
      return;
    }
    if (watchIdRef.current !== null) return;

    const onPosition = async (pos) => {
      const { latitude, longitude, accuracy } = pos.coords;

      // ── ACCURACY GATE ────────────────────────────────────────────────────
      // The browser's first callback is almost always an IP/WiFi fix with
      // accuracy of 500–5000 m — this is what shows "Anthiyam" instead of Pala.
      // We MUST discard it and wait for the GPS chip to warm up (≤150 m).
      if (accuracy > 150) {
        setCurrentPlace(`⏳ Waiting for GPS… (accuracy ${Math.round(accuracy)} m)`);
        return; // skip this fix — do not update map or emit to socket
      }
      // ────────────────────────────────────────────────────────────────────

      setLocationSharing(true);

      // Show place name from real GPS coords
      reverseGeocode(latitude, longitude).then(name => {
        if (name) setCurrentPlace(name);
      });

      // JWT → worker id
      let workerId = null;
      try { workerId = JSON.parse(atob(tokenRef.current.split('.')[1])).id; } catch (_) {}

      // Emit to server → server saves to DB + broadcasts to BOTH worker & customer.
      // Both maps get workerPos from the 'worker_location_update' socket event.
      // Do NOT call setWorkerPos directly here.
      socketRef.current?.emit('update_location', { jobId, latitude, longitude, workerId });

      // REST backup save
      try {
        await axios.put(
          `${API}/api/workers/location`,
          { latitude, longitude, jobId },
          { headers: { Authorization: `Bearer ${tokenRef.current}` } }
        );
      } catch (_) {}
    };

    const onError = (err) => {
      const msgs = {
        1: 'Location permission denied. Allow location in your browser settings.',
        2: 'Cannot get GPS signal. Move outdoors or check location settings.',
        3: 'GPS timed out. Move to open sky and try again.',
      };
      alert(msgs[err.code] || 'Could not get location.');
      setLocationSharing(false);
      watchIdRef.current = null;
    };

    watchIdRef.current = navigator.geolocation.watchPosition(onPosition, onError, {
      enableHighAccuracy: true, // forces GPS chip, not WiFi/IP
      maximumAge:         0,    // never accept a cached position
      timeout:            30000, // give chip up to 30 s to get a satellite fix
    });
  };

  const stopLocation = () => {
    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
    setLocationSharing(false);
    setCurrentPlace(null);
  };

  useEffect(() => () => {
    if (watchIdRef.current !== null) navigator.geolocation.clearWatch(watchIdRef.current);
  }, []);

  // ── Job actions ───────────────────────────────────────────────────────────
  const verifyOtp = async () => {
    if (!otpInput || otpInput.length < 4) { alert('Enter the OTP from the customer.'); return; }
    try {
      const res = await axios.post(
        `${API}/api/otp/${jobId}/verify`,
        { otp_code: otpInput },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      alert(res.data.message || 'OTP verified!');
      setOtpInput(''); fetchAll();
    } catch (err) { alert(err.response?.data?.message || 'Invalid OTP.'); }
  };

  const completeJob = async () => {
    if (!completionPhoto) { alert('Select a completion photo first.'); return; }
    if (!window.confirm('Submit photo and mark job complete?')) return;
    setCompleting(true);
    try {
      const fd = new FormData();
      fd.append('photo', completionPhoto);
      await axios.post(`${API}/api/completion/${jobId}`, fd, {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
      });
      alert('✅ Job completed!');
      stopLocation(); fetchAll();
    } catch (err) { alert(err.response?.data?.message || 'Failed.'); }
    finally { setCompleting(false); }
  };

  const confirmPayment = async () => {
    try {
      await axios.put(`${API}/api/payments/${jobId}/received`, {}, {
        headers: { Authorization: `Bearer ${token}` },
      });
      alert('Payment confirmed!'); fetchAll();
    } catch (_) { alert('Failed to confirm payment.'); }
  };

  const raiseDispute = async () => {
    const reason = prompt('Briefly describe the issue:');
    if (!reason) return;
    const description = prompt('More details (optional):') || reason;
    try {
      await axios.post(`${API}/api/disputes/${jobId}`, { reason, description }, {
        headers: { Authorization: `Bearer ${token}` },
      });
      alert('✅ Dispute raised.'); fetchAll();
    } catch (err) { alert(err.response?.data?.message || 'Failed.'); }
  };

  // ── Render ────────────────────────────────────────────────────────────────
  if (loading) return <div style={s.center}>Loading job…</div>;
  if (!job)    return <div style={s.center}><p>Job not found.</p><button style={s.btnBack} onClick={() => navigate(-1)}>← Go Back</button></div>;

  const status          = job.status;
  const workerArrived   = otp?.is_used;
  const arrivalDeadline = job.arrival_deadline ? new Date(job.arrival_deadline) : null;
  const now             = new Date();
  const minsLeft        = arrivalDeadline ? Math.floor((arrivalDeadline - now) / 60000) : null;
  const deadlineIsLate  = minsLeft !== null && minsLeft < 0;
  const deadlineUrgent  = minsLeft !== null && minsLeft <= 10 && minsLeft >= 0;

  const tabs = ['details'];
  if (['assigned', 'in_progress'].includes(status)) tabs.push('otp', 'location', 'chat');
  if (['assigned', 'in_progress', 'completed'].includes(status)) tabs.push('payment');
  if (bond) tabs.push('bond');

  return (
    <div style={s.page}>

      {/* Header */}
      <div style={s.header}>
        <button style={s.backBtn} onClick={() => navigate('/worker-dashboard')}>← Dashboard</button>
        <div style={{ textAlign: 'center' }}>
          <h2 style={s.headerTitle}>{job.title}</h2>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
            <span style={{ ...s.badge, background: getStatusBg(status), color: getStatusTxt(status) }}>
              {status.replace('_', ' ').toUpperCase()}
            </span>
            <span style={{ ...s.badge, background: job.urgency === 'urgent' ? '#fee2e2' : '#dbeafe', color: job.urgency === 'urgent' ? '#991b1b' : '#1d4ed8' }}>
              {job.urgency === 'urgent' ? '🔴 URGENT' : '🔵 SCHEDULED'}
            </span>
          </div>
        </div>
        <div style={s.headerRate}>Rs.{job.rate}</div>
      </div>

      {workerArrived && <div style={s.arrivedBanner}>✅ Arrival verified — Job is in progress!</div>}

      {status === 'assigned' && !workerArrived && arrivalDeadline && (
        <div style={{ padding: '12px 24px', background: deadlineIsLate ? '#fee2e2' : deadlineUrgent ? '#fef3c7' : '#ede9fe', borderBottom: `3px solid ${deadlineIsLate ? '#ef4444' : deadlineUrgent ? '#f59e0b' : '#4f46e5'}` }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', maxWidth: 800, margin: '0 auto' }}>
            <p style={{ fontWeight: 'bold', fontSize: 14, margin: 0, color: deadlineIsLate ? '#991b1b' : deadlineUrgent ? '#92400e' : '#3730a3' }}>
              {deadlineIsLate ? '🚨 You are LATE!' : deadlineUrgent ? '⚠️ Arrive soon!' : '⏱ Arrival Deadline'}
            </p>
            <p style={{ fontSize: 22, fontWeight: 'bold', margin: 0, color: deadlineIsLate ? '#ef4444' : deadlineUrgent ? '#f59e0b' : '#4f46e5' }}>
              {deadlineIsLate ? `+${Math.abs(minsLeft)}m` : `${minsLeft}m`}
            </p>
          </div>
        </div>
      )}

      {status === 'assigned' && !workerArrived && !arrivalDeadline && (
        <div style={s.actionBanner}>⚠️ Go to the customer's location and verify OTP to start!</div>
      )}

      {/* Tabs */}
      <div style={s.tabs}>
        {tabs.map(t => (
          <button key={t} style={activeTab === t ? s.tabActive : s.tab} onClick={() => setActiveTab(t)}>
            {t === 'details' && '📋 Details'}{t === 'otp' && '🔑 Verify OTP'}
            {t === 'location' && '📍 Location'}{t === 'chat' && '💬 Chat'}
            {t === 'payment' && '💰 Payment'}{t === 'bond' && '🔒 Bond'}
          </button>
        ))}
      </div>

      <div style={s.content}>

        {/* DETAILS */}
        {activeTab === 'details' && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>Job Details</h3>
            <div style={s.grid}>
              {[['Title', job.title], ['Labor Type', job.labor_type], ['Area', job.location],
                ['Rate', `Rs.${job.rate}`], ['Urgency', job.urgency.toUpperCase()],
                ['Workers Needed', job.workers_needed], ['Customer', job.customer_name],
                ['Contact', job.customer_phone], ['Status', status.replace('_', ' ').toUpperCase()],
                ['Posted', new Date(job.created_at).toLocaleDateString()],
              ].map(([k, v]) => (
                <div key={k} style={s.gridItem}>
                  <p style={s.gridKey}>{k}</p><p style={s.gridVal}>{v}</p>
                </div>
              ))}
            </div>
            {job.scheduled_time && (
              <div style={s.scheduledBox}>
                <p style={s.scheduledLbl}>📅 Scheduled arrival:</p>
                <p style={s.scheduledVal}>{new Date(job.scheduled_time).toLocaleString()}</p>
              </div>
            )}
            <div style={s.descBox}><p style={s.gridKey}>Description</p><p style={s.descText}>{job.description}</p></div>
            {job.photo_url && <img src={job.photo_url} alt="job" style={s.jobImg} />}
            <div style={s.contactBox}>
              <h4 style={s.contactTitle}>Customer Contact</h4>
              <p style={s.contactName}>{job.customer_name}</p>
              {customerAddress?.address && (
                <div style={s.addrBox}>
                  <p style={s.addrLabel}>📍 Full Address</p>
                  <p style={s.addrText}>{customerAddress.address}</p>
                  <a href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(customerAddress.address + ', Kerala, India')}`}
                    target="_blank" rel="noreferrer" style={s.btnGoogleMaps}>🗺️ Google Maps</a>
                </div>
              )}
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 12 }}>
                <a href={`tel:${job.customer_phone}`} style={s.btnCall}>📞 Call</a>
                {['assigned', 'in_progress'].includes(status) && (
                  <button style={s.btnChat} onClick={() => navigate(`/chat/${jobId}`)}>💬 Chat</button>
                )}
                {['assigned', 'in_progress'].includes(status) && (
                  <button style={s.btnNav} onClick={() => setActiveTab('location')}>📍 Navigate</button>
                )}
              </div>
            </div>
            {status === 'in_progress' && (
              <div style={s.completeBox}>
                <p style={s.completeLbl}>📸 Upload completion photo:</p>
                <input type="file" accept="image/*" onChange={e => setCompletionPhoto(e.target.files[0])} style={{ display: 'block', marginBottom: 12 }} />
                {completionPhoto && <p style={{ color: '#10b981', fontSize: 13, marginBottom: 10 }}>✅ {completionPhoto.name}</p>}
                <button style={completing ? { ...s.btnComplete, background: '#9ca3af', cursor: 'not-allowed' } : s.btnComplete}
                  onClick={completeJob} disabled={completing}>
                  {completing ? 'Uploading…' : '✅ Submit & Complete Job'}
                </button>
              </div>
            )}
            {['assigned', 'in_progress', 'completed'].includes(status) && (
              <div style={{ marginTop: 16, paddingTop: 12, borderTop: '1px solid #f3f4f6' }}>
                <button onClick={raiseDispute} style={{ background: 'none', border: '1px solid #ef4444', color: '#ef4444', padding: '8px 16px', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
                  ⚠️ Raise a Dispute
                </button>
              </div>
            )}
          </div>
        )}

        {/* OTP */}
        {activeTab === 'otp' && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>Verify Your Arrival</h3>
            {otp?.is_used ? (
              <div style={{ textAlign: 'center', padding: 40 }}>
                <p style={{ fontSize: 48, margin: '0 0 12px 0' }}>✅</p>
                <p style={{ fontSize: 20, fontWeight: 'bold', color: '#065f46', margin: '0 0 8px 0' }}>Arrival confirmed!</p>
                <p style={{ color: '#666' }}>Job is now in progress.</p>
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: 20 }}>
                <p style={{ fontSize: 15, color: '#555', marginBottom: 24 }}>Ask the customer for their OTP:</p>
                <input style={s.otpInput} type="text" placeholder="6-digit OTP"
                  value={otpInput} onChange={e => setOtpInput(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  maxLength={6} inputMode="numeric" />
                <button style={s.btnVerify} onClick={verifyOtp}>✅ Verify & Start Job</button>
              </div>
            )}
          </div>
        )}

        {/* LOCATION */}
        {activeTab === 'location' && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>📍 Live Location</h3>
            <p style={{ color: '#555', fontSize: 14, marginBottom: 16 }}>
              Your GPS is shared with the customer. Both of you see the same map below.
            </p>

            {/* Status — clearly shows GPS warmup state */}
            {!locationSharing ? (
              <div>
                <div style={{ background: '#fef3c7', border: '2px solid #f59e0b', borderRadius: 10, padding: '14px 18px', marginBottom: 16 }}>
                  <p style={{ color: '#92400e', fontWeight: 'bold', fontSize: 14, margin: '0 0 4px 0' }}>
                    {currentPlace || '⏳ Acquiring GPS… please wait'}
                  </p>
                  <p style={{ color: '#92400e', fontSize: 12, margin: 0 }}>
                    Your browser returns a rough IP location first. Waiting for GPS chip (accuracy ≤150 m)…
                  </p>
                </div>
                <button style={s.btnStartLoc} onClick={shareLocation}>
                  📍 Start Sharing Live Location
                </button>
              </div>
            ) : (
              <div>
                <div style={{ display: 'flex', gap: 12, marginBottom: 12 }}>
                  <div style={{ background: '#d1fae5', padding: 14, borderRadius: 10, flex: 1 }}>
                    <p style={{ color: '#065f46', fontWeight: 'bold', margin: '0 0 4px 0', fontSize: 14 }}>
                      ✅ GPS active — customer can see you
                    </p>
                    <p style={{ color: '#065f46', fontSize: 13, margin: 0 }}>
                      {currentPlace ? `📍 ${currentPlace}` : '⏳ Waiting for accurate GPS fix…'}
                    </p>
                  </div>
                  <button onClick={stopLocation} style={{ background: '#ef4444', color: '#fff', border: 'none', padding: '0 20px', borderRadius: 10, cursor: 'pointer', fontSize: 14, fontWeight: 'bold' }}>
                    ⏹ Stop
                  </button>
                </div>
                {workerPos && (
                  <div style={{ background: '#0f172a', borderRadius: 8, padding: '8px 14px', marginBottom: 12, display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
                    <span style={{ color: '#64748b', fontSize: 11 }}>📡 GPS</span>
                    <span style={{ color: '#10b981', fontSize: 12, fontFamily: 'monospace', fontWeight: 'bold' }}>
                      {workerPos.lat.toFixed(6)}°, {workerPos.lng.toFixed(6)}°
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* Destination box */}
            {destPos && (
              <div style={{ background: '#f0fdf4', border: '1.5px solid #86efac', borderRadius: 10, padding: 14, marginBottom: 14 }}>
                <p style={{ fontSize: 11, fontWeight: 'bold', color: '#065f46', textTransform: 'uppercase', margin: '0 0 6px 0' }}>🏁 Customer Destination</p>
                <p style={{ fontSize: 14, color: '#374151', margin: 0 }}>{destPos.label || `${destPos.lat.toFixed(5)}, ${destPos.lng.toFixed(5)}`}</p>
                {customerAddress?.address && customerAddress.address !== destPos.label && (
                  <p style={{ fontSize: 13, color: '#6b7280', margin: '4px 0 0 0' }}>{customerAddress.address}</p>
                )}
                <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
                  {customerAddress?.phone && (
                    <a href={`tel:${customerAddress.phone}`} style={s.btnCall}>📞 Call</a>
                  )}
                  <a href={`https://www.google.com/maps/dir/?api=1&destination=${destPos.lat},${destPos.lng}`}
                    target="_blank" rel="noreferrer" style={s.btnGoogleMaps}>🗺️ Navigate</a>
                </div>
              </div>
            )}

            {/* ── THE MAP (same as customer's TrackWorker) ── */}
            <div style={{ height: 360, borderRadius: 14, overflow: 'hidden', border: '1px solid #e5e7eb', marginBottom: 10 }}>
              <LiveTrackingMap workerPos={workerPos} destPos={destPos} height="360px" />
            </div>

            {/* Legend */}
            <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
              <LegDot color="#4f46e5" label="You (live GPS)" />
              <LegDot color="#ef4444" label="Customer" pin />
              <LegLine color="#10b981" label="Route ahead" />
              <LegLine color="#6366f1" dash label="Path taken" />
            </div>
          </div>
        )}

        {/* CHAT */}
        {activeTab === 'chat' && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>Chat with Customer</h3>
            <button style={s.btnPrimary} onClick={() => navigate(`/chat/${jobId}`)}>💬 Open Chat</button>
          </div>
        )}

        {/* PAYMENT */}
        {activeTab === 'payment' && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>Payment Status</h3>
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 28 }}>
              {[{ label: 'Job Done', done: status === 'completed' }, { label: 'Payment Sent', done: payment?.payment_sent }, { label: 'You Confirmed', done: payment?.payment_received }]
                .map((step, i) => (
                  <React.Fragment key={i}>
                    <div style={{ textAlign: 'center', minWidth: 80 }}>
                      <div style={{ width: 44, height: 44, borderRadius: '50%', background: step.done ? '#10b981' : '#e5e7eb', color: step.done ? '#fff' : '#666', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: step.done ? 20 : 16, fontWeight: 'bold', margin: '0 auto 8px' }}>
                        {step.done ? '✓' : i + 1}
                      </div>
                      <p style={{ fontSize: 11, color: '#666', margin: 0 }}>{step.label}</p>
                    </div>
                    {i < 2 && <div style={{ flex: 1, height: 2, background: '#e5e7eb', marginBottom: 24 }} />}
                  </React.Fragment>
                ))}
            </div>
            {payment?.payment_sent && !payment?.payment_received && (
              <div style={{ background: '#d1fae5', padding: 24, borderRadius: 12, textAlign: 'center' }}>
                <p style={{ fontSize: 18, fontWeight: 'bold', color: '#065f46', margin: '0 0 8px 0' }}>💰 Customer sent Rs.{job.rate}!</p>
                <button style={s.btnConfirm} onClick={confirmPayment}>✅ Confirm Received</button>
              </div>
            )}
            {payment?.payment_received && (
              <div style={{ textAlign: 'center', padding: 30 }}>
                <p style={{ fontSize: 40, margin: '0 0 12px 0' }}>🎉</p>
                <p style={{ fontSize: 18, fontWeight: 'bold', color: '#065f46' }}>Rs.{job.rate} received!</p>
              </div>
            )}
            {!payment?.payment_sent && (
              <div style={{ background: '#f8fafc', padding: 24, borderRadius: 12, textAlign: 'center' }}>
                <p style={{ color: '#666', fontSize: 15, margin: 0 }}>
                  {status === 'completed' ? 'Waiting for customer to send payment…' : 'Payment available after job completion.'}
                </p>
              </div>
            )}
          </div>
        )}

        {/* BOND */}
        {activeTab === 'bond' && bond && (
          <div style={s.card}>
            <h3 style={s.cardTitle}>🔒 Commitment Bond</h3>
            <div style={s.grid}>
              {[['Job', bond.job_title], ['Bond Amount', `Rs.${bond.bond_amount || 'N/A'}`],
                ['No-Show Risk', `${bond.no_show_probability}%`], ['Status', bond.status?.toUpperCase()]
              ].map(([k, v]) => (
                <div key={k} style={s.gridItem}><p style={s.gridKey}>{k}</p><p style={s.gridVal}>{v}</p></div>
              ))}
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

// ── Small components ──────────────────────────────────────────────────────────
const LegDot = ({ color, label, pin }) => (
  <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: '#6b7280' }}>
    <span style={{ width: 11, height: 11, borderRadius: pin ? '50% 50% 50% 0' : '50%', background: color, transform: pin ? 'rotate(-45deg)' : 'none', display: 'inline-block', flexShrink: 0 }} />
    {label}
  </span>
);
const LegLine = ({ color, label, dash }) => (
  <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: '#6b7280' }}>
    <span style={{ width: 22, height: 3, background: color, borderRadius: 2, display: 'inline-block', opacity: dash ? 0.6 : 1 }} />
    {label}
  </span>
);

const getStatusBg  = st => ({ open:'#d1fae5', assigned:'#fef3c7', in_progress:'#dbeafe', completed:'#ede9fe', cancelled:'#fee2e2' }[st] || '#f3f4f6');
const getStatusTxt = st => ({ open:'#065f46', assigned:'#92400e', in_progress:'#1d4ed8', completed:'#4f46e5', cancelled:'#991b1b' }[st] || '#333');

const s = {
  page:          { minHeight: '100vh', background: '#f0f4f8' },
  center:        { textAlign: 'center', marginTop: 100, fontSize: 18, color: '#666', padding: 20 },
  btnBack:       { background: '#4f46e5', color: '#fff', border: 'none', padding: '10px 20px', borderRadius: 8, cursor: 'pointer', marginTop: 16 },
  header:        { background: '#1a1a2e', padding: '16px 30px', color: '#fff', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  backBtn:       { background: 'transparent', color: '#a5b4fc', border: '1px solid #a5b4fc', padding: '8px 16px', borderRadius: 8, cursor: 'pointer', fontSize: 14 },
  headerTitle:   { fontSize: 20, fontWeight: 'bold', margin: '0 0 6px 0' },
  badge:         { display: 'inline-block', padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 'bold' },
  headerRate:    { fontSize: 24, fontWeight: 'bold', color: '#a5b4fc' },
  arrivedBanner: { background: '#d1fae5', color: '#065f46', padding: '14px 30px', textAlign: 'center', fontWeight: 'bold', fontSize: 15 },
  actionBanner:  { background: '#fef3c7', color: '#92400e', padding: '14px 30px', textAlign: 'center', fontWeight: 'bold', fontSize: 15 },
  tabs:          { display: 'flex', background: '#fff', borderBottom: '1px solid #eee', padding: '0 30px', overflowX: 'auto' },
  tab:           { padding: '14px 18px', border: 'none', background: 'transparent', cursor: 'pointer', fontSize: 14, color: '#666', whiteSpace: 'nowrap' },
  tabActive:     { padding: '14px 18px', border: 'none', background: 'transparent', cursor: 'pointer', fontSize: 14, color: '#4f46e5', borderBottom: '3px solid #4f46e5', fontWeight: 'bold', whiteSpace: 'nowrap' },
  content:       { padding: 30, maxWidth: 800, margin: '0 auto' },
  card:          { background: '#fff', borderRadius: 16, padding: 28, boxShadow: '0 2px 12px rgba(0,0,0,0.08)' },
  cardTitle:     { fontSize: 20, fontWeight: 'bold', color: '#1a1a2e', margin: '0 0 20px 0' },
  grid:          { display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(180px,1fr))', gap: 12, marginBottom: 20 },
  gridItem:      { background: '#f8fafc', padding: 14, borderRadius: 10 },
  gridKey:       { fontSize: 11, color: '#999', margin: '0 0 4px 0', textTransform: 'uppercase', fontWeight: 'bold' },
  gridVal:       { fontSize: 15, fontWeight: 'bold', color: '#1a1a2e', margin: 0 },
  scheduledBox:  { background: '#fef3c7', padding: 16, borderRadius: 10, marginBottom: 16, border: '2px solid #f59e0b' },
  scheduledLbl:  { fontSize: 13, color: '#92400e', fontWeight: 'bold', margin: '0 0 6px 0' },
  scheduledVal:  { fontSize: 20, fontWeight: 'bold', color: '#1a1a2e', margin: 0 },
  descBox:       { background: '#f8fafc', padding: 16, borderRadius: 10, marginBottom: 16 },
  descText:      { fontSize: 15, color: '#444', lineHeight: 1.7, margin: '8px 0 0 0' },
  jobImg:        { width: '100%', height: 200, objectFit: 'cover', borderRadius: 10, marginBottom: 16 },
  contactBox:    { background: '#f0f9ff', padding: 20, borderRadius: 12, marginTop: 16 },
  contactTitle:  { fontSize: 16, fontWeight: 'bold', color: '#1a1a2e', margin: '0 0 8px 0' },
  contactName:   { fontSize: 18, fontWeight: 'bold', color: '#333', margin: '0 0 10px 0' },
  addrBox:       { background: '#fff', border: '1.5px solid #10b981', borderRadius: 8, padding: 12, marginBottom: 14 },
  addrLabel:     { fontSize: 11, fontWeight: 'bold', color: '#065f46', margin: '0 0 4px 0', textTransform: 'uppercase' },
  addrText:      { fontSize: 15, fontWeight: 600, color: '#1a1a2e', margin: '0 0 8px 0', lineHeight: 1.5 },
  btnGoogleMaps: { display: 'inline-block', background: '#1d4ed8', color: '#fff', padding: '8px 14px', borderRadius: 7, textDecoration: 'none', fontSize: 13, fontWeight: 'bold' },
  btnCall:       { background: '#10b981', color: '#fff', padding: '10px 18px', borderRadius: 8, textDecoration: 'none', fontSize: 14, fontWeight: 'bold', display: 'inline-block' },
  btnChat:       { background: '#4f46e5', color: '#fff', border: 'none', padding: '10px 18px', borderRadius: 8, cursor: 'pointer', fontSize: 14, fontWeight: 'bold' },
  btnNav:        { background: '#0ea5e9', color: '#fff', border: 'none', padding: '10px 18px', borderRadius: 8, cursor: 'pointer', fontSize: 14, fontWeight: 'bold' },
  completeBox:   { background: '#f0fdf4', border: '2px solid #10b981', padding: 20, borderRadius: 12, marginTop: 20 },
  completeLbl:   { fontWeight: 'bold', color: '#065f46', marginBottom: 12, fontSize: 15 },
  btnComplete:   { background: '#10b981', color: '#fff', border: 'none', padding: 14, borderRadius: 10, cursor: 'pointer', fontSize: 16, fontWeight: 'bold', width: '100%' },
  otpInput:      { display: 'block', margin: '0 auto 16px', padding: 16, fontSize: 28, textAlign: 'center', letterSpacing: 12, borderRadius: 10, border: '2px solid #4f46e5', width: 240, fontWeight: 'bold', color: '#4f46e5' },
  btnVerify:     { background: '#10b981', color: '#fff', border: 'none', padding: '14px 32px', borderRadius: 10, cursor: 'pointer', fontSize: 16, fontWeight: 'bold' },
  btnStartLoc:   { background: '#4f46e5', color: '#fff', border: 'none', padding: '14px 28px', borderRadius: 10, cursor: 'pointer', fontSize: 15, fontWeight: 'bold', width: '100%', marginBottom: 16 },
  btnPrimary:    { background: '#4f46e5', color: '#fff', border: 'none', padding: '14px 28px', borderRadius: 10, cursor: 'pointer', fontSize: 15, fontWeight: 'bold', width: '100%' },
  btnConfirm:    { background: '#10b981', color: '#fff', border: 'none', padding: '14px 32px', borderRadius: 10, cursor: 'pointer', fontSize: 16, fontWeight: 'bold' },
};

export default WorkerJob;