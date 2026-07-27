/**
 * TrackWorker.js  —  CUSTOMER VIEW
 * Place at: frontend/src/pages/Map/TrackWorker.js
 *
 * Destination is resolved from the customer's actual GPS coordinates
 * stored in their profile (latitude/longitude columns) — NOT from
 * geocoding a text address which gives wrong locations for Kerala villages.
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import axios from 'axios';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { io } from 'socket.io-client';
import LiveTrackingMap from './LiveTrackingMap';

const API = 'http://localhost:5000';

// ── Only used as label text — NOT for placing the map pin ────────────────────
// The pin is placed from raw lat/lng coordinates, never from geocoding
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
const TrackWorker = () => {
  const { jobId }  = useParams();
  const { token }  = useAuth();
  const navigate   = useNavigate();

  const [job,         setJob]         = useState(null);
  const [workerPos,   setWorkerPos]   = useState(null);
  const [destPos,     setDestPos]     = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [loading,     setLoading]     = useState(true);
  const [liveStatus,  setLiveStatus]  = useState('connecting');

  const tokenRef = useRef(token);
  tokenRef.current = token;

  const handleLocationUpdate = useCallback((lat, lng) => {
    const numLat = parseFloat(lat);
    const numLng = parseFloat(lng);
    if (isNaN(numLat) || isNaN(numLng)) return;
    setWorkerPos({ lat: numLat, lng: numLng });
    setLastUpdated(new Date());
  }, []);

  // ── Init: fetch job + resolve destination from raw GPS coords ────────────
  useEffect(() => {
    const init = async () => {
      try {
        const hdr = { Authorization: `Bearer ${tokenRef.current}` };

        const jobRes = await axios.get(`${API}/api/jobs/${jobId}`, { headers: hdr });
        const j = jobRes.data.job;
        setJob(j);

        // ── DESTINATION: use raw GPS lat/lng — never geocode from text ───
        // Priority order:
        // 1. Customer profile has explicit latitude/longitude saved
        // 2. Job record has latitude/longitude
        // 3. Application record has customer GPS
        // Only fall back to text geocoding as absolute last resort

        let destLat = null, destLng = null, destLabel = '';

        // 1. Customer profile GPS
        try {
          const profileRes = await axios.get(`${API}/api/auth/profile`, { headers: hdr });
          const user = profileRes.data.user;
          if (user?.latitude && user?.longitude) {
            destLat   = parseFloat(user.latitude);
            destLng   = parseFloat(user.longitude);
            destLabel = user.address || '';
          }
        } catch (_) {}

        // 2. Job lat/lng
        if (!destLat && j.latitude && j.longitude) {
          destLat   = parseFloat(j.latitude);
          destLng   = parseFloat(j.longitude);
          destLabel = j.location || '';
        }

        // 3. Application / customer-address endpoint (has GPS stored)
        if (!destLat) {
          try {
            const appRes = await axios.get(
              `${API}/api/applications/${jobId}/customer-address`, { headers: hdr }
            );
            const a = appRes.data;
            if (a?.latitude && a?.longitude) {
              destLat   = parseFloat(a.latitude);
              destLng   = parseFloat(a.longitude);
              destLabel = a.address || a.area || '';
            }
          } catch (_) {}
        }

        // 4. Absolute last resort: geocode text (less accurate for villages)
        if (!destLat && j.location) {
          try {
            const r = await fetch(
              `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(j.location + ', Kerala, India')}&format=json&limit=1`,
              { headers: { 'Accept-Language': 'en' } }
            );
            const d = await r.json();
            if (d[0]) {
              destLat   = parseFloat(d[0].lat);
              destLng   = parseFloat(d[0].lon);
              destLabel = j.location;
            }
          } catch (_) {}
        }

        if (destLat && destLng) {
          // Get a human-readable label from real coords (not used for positioning)
          if (!destLabel) {
            destLabel = await reverseGeocode(destLat, destLng) || '';
          }
          setDestPos({ lat: destLat, lng: destLng, label: destLabel });
        }

        // Load last-known worker GPS from DB (so map isn't blank on open)
        try {
          const locRes = await axios.get(`${API}/api/workers/location/${jobId}`, { headers: hdr });
          const loc = locRes.data.location || locRes.data;
          if (loc?.latitude && loc?.longitude) {
            handleLocationUpdate(loc.latitude, loc.longitude);
          }
        } catch (_) {}

      } catch (err) {
        console.error('TrackWorker init:', err.message);
      } finally {
        setLoading(false);
      }
    };
    init();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jobId]);

  // ── Socket ────────────────────────────────────────────────────────────────
  useEffect(() => {
    const socket = io(API, { transports: ['websocket', 'polling'] });
    socket.on('connect',       () => setLiveStatus('live'));
    socket.on('disconnect',    () => setLiveStatus('reconnecting'));
    socket.on('connect_error', () => setLiveStatus('reconnecting'));
    socket.emit('join_room', jobId);
    // Server broadcasts 'worker_location_update' after worker emits 'update_location'
    socket.on('worker_location_update', ({ latitude, longitude }) => {
      if (latitude && longitude) handleLocationUpdate(latitude, longitude);
    });
    return () => socket.disconnect();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jobId]);

  if (loading) return (
    <div style={{ height: '100vh', background: '#0f172a', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
      <div style={{ width: 40, height: 40, border: '4px solid #334155', borderTop: '4px solid #4f46e5', borderRadius: '50%', animation: 'spin 0.9s linear infinite' }} />
      <p style={{ color: '#94a3b8', margin: 0 }}>Loading tracking map…</p>
      <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
    </div>
  );

  const statusColor = { live: '#10b981', reconnecting: '#f59e0b', connecting: '#9ca3af' }[liveStatus];
  const statusLabel = { live: '🟢 Live', reconnecting: '🟡 Reconnecting…', connecting: '⚪ Connecting…' }[liveStatus];

  return (
    <div style={{ height: '100vh', background: '#0f172a', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

      {/* Header */}
      <div style={s.header}>
        <button style={s.backBtn} onClick={() => navigate(-1)}>← Back</button>
        <h2 style={s.title}>📍 Live Worker Tracking</h2>
        <span style={{ ...s.pill, background: statusColor }}>{statusLabel}</span>
      </div>

      {/* Job bar */}
      {job && (
        <div style={s.jobBar}>
          <p style={s.jobTitle}>{job.title}</p>
          <p style={s.jobMeta}>📍 {job.location} · 🔧 {job.labor_type}</p>
        </div>
      )}

      {/* Stats bar */}
      <div style={s.statsBar}>
        {workerPos ? (
          <div style={s.statsRow}>
            <Stat icon="🔵" label="Status" value="Tracking active" />

            {lastUpdated && <>
              <div style={s.div} />
              <Stat icon="🔄" label="Updated" value={lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })} />
            </>}
          </div>
        ) : (
          <Stat icon="⏳" label="Status" value="Waiting for worker to start sharing…" />
        )}
      </div>

      {/* Map — fills remaining space */}
      <div style={{ flex: 1, minHeight: 0 }}>
        <LiveTrackingMap
          workerPos={workerPos}
          destPos={destPos}
          height="100%"
        />
      </div>

      {/* Legend */}
      <div style={s.legend}>
        <LegDot color="#4f46e5" label="Worker (live GPS)" />
        <LegDot color="#ef4444" label="Your location" pin />
        <LegLine color="#10b981" label="Route ahead" />
        <LegLine color="#6366f1" dash label="Path taken" />
      </div>

    </div>
  );
};

const Stat = ({ icon, label, value, highlight }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 14px 4px 0' }}>
    <span style={{ fontSize: 16 }}>{icon}</span>
    <div>
      <p style={{ margin: 0, fontSize: 9, color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>{label}</p>
      <p style={{ margin: 0, fontSize: 13, fontWeight: 'bold', color: highlight ? '#10b981' : '#fff' }}>{value}</p>
    </div>
  </div>
);

const LegDot = ({ color, label, pin }) => (
  <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: '#94a3b8' }}>
    <span style={{ width: 11, height: 11, borderRadius: pin ? '50% 50% 50% 0' : '50%', background: color, transform: pin ? 'rotate(-45deg)' : 'none', display: 'inline-block', flexShrink: 0 }} />
    {label}
  </span>
);

const LegLine = ({ color, label, dash }) => (
  <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: '#94a3b8' }}>
    <span style={{ width: 22, height: 3, background: color, borderRadius: 2, display: 'inline-block', opacity: dash ? 0.6 : 1, backgroundImage: dash ? `repeating-linear-gradient(90deg,${color} 0,${color} 5px,transparent 5px,transparent 9px)` : 'none' }} />
    {label}
  </span>
);

const s = {
  header:   { background: '#1e293b', padding: '12px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #334155', flexShrink: 0 },
  backBtn:  { background: 'transparent', color: '#a5b4fc', border: '1px solid #a5b4fc', padding: '7px 14px', borderRadius: 8, cursor: 'pointer', fontSize: 13 },
  title:    { color: '#fff', fontSize: 16, fontWeight: 'bold', margin: 0 },
  pill:     { color: '#fff', padding: '4px 12px', borderRadius: 20, fontSize: 12, fontWeight: 700 },
  jobBar:   { background: '#1e293b', padding: '8px 20px', borderBottom: '1px solid #334155', flexShrink: 0 },
  jobTitle: { color: '#fff', fontWeight: 'bold', fontSize: 14, margin: '0 0 2px 0' },
  jobMeta:  { color: '#94a3b8', fontSize: 12, margin: 0 },
  statsBar: { background: '#1e293b', padding: '8px 20px', borderBottom: '1px solid #334155', flexShrink: 0, overflowX: 'auto' },
  statsRow: { display: 'flex', alignItems: 'center', minWidth: 'max-content' },
  div:      { width: 1, height: 28, background: '#334155', margin: '0 14px 0 0', flexShrink: 0 },
  legend:   { background: '#1e293b', padding: '8px 20px', borderTop: '1px solid #334155', display: 'flex', gap: 16, flexWrap: 'wrap', flexShrink: 0 },
};

export default TrackWorker;