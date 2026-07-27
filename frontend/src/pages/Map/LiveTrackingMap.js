/**
 * LiveTrackingMap.js
 * Place at: frontend/src/pages/Map/LiveTrackingMap.js
 *
 * Swiggy-style live tracking map used by BOTH worker and customer.
 * Shows:
 *   🔵 Animated pulsing dot  = Worker's live GPS
 *   🔴 Red pin               = Customer's destination
 *   ══ Thick green line      = Remaining route to customer (road-snapped)
 *   ── Thin blue dashed      = Path already travelled by worker (road-snapped)
 *   ▬  Bottom bar            = Distance + ETA
 *
 * Props:
 *   workerPos  {lat, lng}          – worker's current GPS position
 *   destPos    {lat, lng, label}   – customer's destination
 *   height     string              – CSS height e.g. "100%" or "340px"
 */

import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// ── Get driving route from OSRM (road-snapped, like Swiggy/Zomato) ───────────
const getRoadRoute = async (fromLat, fromLng, toLat, toLng) => {
  try {
    const url =
      `https://router.project-osrm.org/route/v1/driving/` +
      `${fromLng},${fromLat};${toLng},${toLat}` +
      `?overview=full&geometries=geojson&steps=false`;
    const res  = await fetch(url);
    const data = await res.json();
    if (data.code === 'Ok' && data.routes?.[0]) {
      const route = data.routes[0];
      return {
        // OSRM gives [lng,lat] — flip to [lat,lng] for Leaflet
        coords:  route.geometry.coordinates.map(([lng, lat]) => [lat, lng]),
        distKm:  (route.distance / 1000).toFixed(1),
        etaMins: Math.round(route.duration / 60),
      };
    }
  } catch (_) {}
  return null;
};

// ── Match a single point onto the nearest road ────────────────────────────────
// Used to snap the trail points so the breadcrumb follows roads, not air
const snapToRoad = async (lat, lng) => {
  try {
    const url = `https://router.project-osrm.org/nearest/v1/driving/${lng},${lat}?number=1`;
    const res  = await fetch(url);
    const data = await res.json();
    if (data.code === 'Ok' && data.waypoints?.[0]) {
      const [sLng, sLat] = data.waypoints[0].location;
      return [sLat, sLng];
    }
  } catch (_) {}
  return [lat, lng]; // fall back to raw coords
};

// ── Worker icon: Swiggy-style pulsing blue dot ────────────────────────────────
const makeWorkerIcon = () => L.divIcon({
  className: '',
  html: `
    <div style="position:relative;width:28px;height:28px;">
      <div style="
        position:absolute;inset:0;border-radius:50%;
        background:rgba(79,70,229,0.2);
        animation:lmPulse 1.6s ease-out infinite;
      "></div>
      <div style="
        position:absolute;top:5px;left:5px;
        width:18px;height:18px;border-radius:50%;
        background:#4f46e5;border:3px solid #fff;
        box-shadow:0 2px 10px rgba(79,70,229,0.6);
      "></div>
    </div>
    <style>
      @keyframes lmPulse{
        0%  {transform:scale(0.7);opacity:1}
        100%{transform:scale(2.4);opacity:0}
      }
    </style>`,
  iconSize:   [28, 28],
  iconAnchor: [14, 14],
});

// ── Destination icon: red teardrop pin ───────────────────────────────────────
const makeDestIcon = () => L.divIcon({
  className: '',
  html: `
    <div style="position:relative;width:32px;height:42px;">
      <div style="
        width:32px;height:32px;
        background:#ef4444;border:3px solid #fff;
        border-radius:50% 50% 50% 0;transform:rotate(-45deg);
        box-shadow:0 3px 12px rgba(239,68,68,0.55);
      "></div>
      <div style="
        position:absolute;top:10px;left:10px;
        width:12px;height:12px;border-radius:50%;
        background:#fff;
      "></div>
    </div>`,
  iconSize:   [32, 42],
  iconAnchor: [16, 42],
});

// ─────────────────────────────────────────────────────────────────────────────
const LiveTrackingMap = ({ workerPos, destPos, height = '100%' }) => {
  const containerRef   = useRef(null);
  const mapRef         = useRef(null);
  const workerMarker   = useRef(null);
  const destMarker     = useRef(null);
  const routeLine      = useRef(null);   // green: remaining route ahead
  const trailLine      = useRef(null);   // blue dashed: path already travelled
  const trailPts       = useRef([]);     // road-snapped trail points
  const lastWorkerPos  = useRef(null);   // previous GPS point for trail
  const routeThrottle  = useRef(null);   // prevent spamming OSRM
  const [info, setInfo] = useState(null); // {distKm, etaMins}

  // ── Init Leaflet map once ────────────────────────────────────────────────
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current, {
      zoomControl: true,
      attributionControl: true,
    }).setView([10.0, 76.3], 10);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://openstreetmap.org">OSM</a>',
      maxZoom: 19,
    }).addTo(map);

    mapRef.current = map;

    // Fire invalidateSize repeatedly so Leaflet gets the real container size
    const ro = new ResizeObserver(() => map.invalidateSize());
    ro.observe(containerRef.current);
    [0, 150, 400, 900].forEach(ms => setTimeout(() => map.invalidateSize(), ms));

    return () => {
      ro.disconnect();
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // ── Destination pin — placed from raw lat/lng, NO geocoding ─────────────
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !destPos) return;

    if (destMarker.current) {
      destMarker.current.setLatLng([destPos.lat, destPos.lng]);
    } else {
      destMarker.current = L.marker([destPos.lat, destPos.lng], { icon: makeDestIcon() })
        .addTo(map)
        .bindPopup(
          `<div style="font-size:13px;line-height:1.5">
            <b style="color:#ef4444">📍 Customer Location</b><br>
            <span style="color:#666">${destPos.label || 'Destination'}</span>
          </div>`
        );
    }

    if (!workerPos) {
      map.setView([destPos.lat, destPos.lng], 14);
      setTimeout(() => map.invalidateSize(), 100);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [destPos]);

  // ── Worker GPS update — marker + road-snapped trail + route ──────────────
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !workerPos) return;

    const { lat, lng } = workerPos;

    // 1. Move / create worker marker
    if (workerMarker.current) {
      workerMarker.current.setLatLng([lat, lng]);
    } else {
      workerMarker.current = L.marker([lat, lng], {
        icon: makeWorkerIcon(), zIndexOffset: 1000,
      }).addTo(map)
        .bindPopup('<b style="color:#4f46e5">🔵 Worker — Live GPS</b>');
    }

    // 2. Road-snapped trail (Swiggy-style: follows roads, not air)
    //    Snap new point to nearest road, then append to trail
    const appendTrail = async () => {
      const snapped = await snapToRoad(lat, lng);
      if (!mapRef.current) return; // guard: map unmounted during async snap
      trailPts.current = [...trailPts.current, snapped].slice(-800);

      if (trailLine.current) {
        trailLine.current.setLatLngs(trailPts.current);
      } else {
        if (!mapRef.current) return;
        trailLine.current = L.polyline(trailPts.current, {
          color: '#6366f1',
          weight: 4,
          opacity: 0.55,
          dashArray: '8 6',
          lineJoin: 'round',
          lineCap: 'round',
        }).addTo(mapRef.current);
      }
    };
    appendTrail();

    // 3. Remaining route to destination — throttled to once per 5 s
    //    Uses raw GPS coords directly — NO text geocoding
    if (destPos) {
      clearTimeout(routeThrottle.current);
      routeThrottle.current = setTimeout(async () => {
        const result = await getRoadRoute(lat, lng, destPos.lat, destPos.lng);
        if (!result || !mapRef.current) return; // guard: map unmounted during fetch

        setInfo({ distKm: result.distKm, etaMins: result.etaMins });

        if (routeLine.current) {
          routeLine.current.setLatLngs(result.coords);
        } else {
          if (!mapRef.current) return;
          routeLine.current = L.polyline(result.coords, {
            color: '#10b981',
            weight: 6,
            opacity: 0.9,
            lineJoin: 'round',
            lineCap: 'round',
          }).addTo(mapRef.current);
          // Make sure trail renders below the route
          trailLine.current?.bringToBack?.();
        }

        // Auto-zoom to show both worker and destination (Swiggy behaviour)
        mapRef.current.fitBounds(
          [[lat, lng], [destPos.lat, destPos.lng]],
          { padding: [60, 60], maxZoom: 16, animate: true, duration: 0.8 }
        );
        setTimeout(() => mapRef.current?.invalidateSize(), 80);
      }, 300); // small debounce; real throttle is the 5 s check
    } else {
      // No destination yet — follow the worker at street level
      map.setView([lat, lng], 15, { animate: true, duration: 0.6 });
      setTimeout(() => map.invalidateSize(), 80);
    }

    lastWorkerPos.current = { lat, lng };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [workerPos, destPos]);

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div style={{ position: 'relative', width: '100%', height, overflow: 'hidden' }}>

      {/* Waiting overlay */}
      {!workerPos && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 1000,
          background: 'linear-gradient(135deg,#0f172a,#1e293b)',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: 14,
        }}>
          {/* Animated radar rings */}
          <div style={{ position: 'relative', width: 80, height: 80 }}>
            {[0, 0.5, 1].map(delay => (
              <div key={delay} style={{
                position: 'absolute', inset: 0, borderRadius: '50%',
                border: '2px solid #4f46e5',
                animation: `radarRing 2s ${delay}s ease-out infinite`,
              }} />
            ))}
            <div style={{
              position: 'absolute', top: '50%', left: '50%',
              transform: 'translate(-50%,-50%)',
              width: 20, height: 20, borderRadius: '50%',
              background: '#4f46e5', border: '3px solid #fff',
            }} />
          </div>
          <p style={{ color: '#e2e8f0', fontWeight: 'bold', fontSize: 15, margin: 0 }}>
            Waiting for worker's GPS…
          </p>
          <p style={{ color: '#64748b', fontSize: 12, margin: 0, textAlign: 'center', maxWidth: 220, lineHeight: 1.7 }}>
            Map activates the moment the worker starts sharing location
          </p>
          <style>{`
            @keyframes radarRing {
              0%   { transform: scale(0.3); opacity: 1; }
              100% { transform: scale(1.8); opacity: 0; }
            }
          `}</style>
        </div>
      )}

      {/* Leaflet canvas — always in DOM */}
      <div ref={containerRef} style={{ width: '100%', height: '100%' }} />

      {/* Swiggy-style bottom info bar */}
      {info && workerPos && (
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 500,
          background: 'rgba(15,23,42,0.92)',
          backdropFilter: 'blur(6px)',
          borderTop: '1px solid rgba(255,255,255,0.08)',
          padding: '10px 18px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#10b981', boxShadow: '0 0 0 3px rgba(16,185,129,0.3)' }} />
            <span style={{ color: '#94a3b8', fontSize: 11, textTransform: 'uppercase', fontWeight: 600 }}>Live</span>
          </div>
          <div style={{ display: 'flex', gap: 24 }}>
            <div style={{ textAlign: 'center' }}>
              <p style={{ margin: 0, color: '#94a3b8', fontSize: 10, textTransform: 'uppercase', fontWeight: 600 }}>Distance</p>
              <p style={{ margin: 0, color: '#fff', fontSize: 15, fontWeight: 'bold' }}>{info.distKm} km</p>
            </div>
            <div style={{ width: 1, background: '#334155' }} />
            <div style={{ textAlign: 'center' }}>
              <p style={{ margin: 0, color: '#94a3b8', fontSize: 10, textTransform: 'uppercase', fontWeight: 600 }}>ETA</p>
              <p style={{ margin: 0, fontSize: 15, fontWeight: 'bold', color: info.etaMins < 3 ? '#10b981' : '#fff' }}>
                {info.etaMins < 1 ? 'Arriving!' : `~${info.etaMins} min`}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default LiveTrackingMap;