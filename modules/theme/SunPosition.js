.pragma library

// Where the sun is: solar azimuth / altitude for a moment and a place
// (NOAA solar calculator equations, accurate to a fraction of a degree,
// no atmospheric refraction). Pure; unit tested in
// tests/sun-position.test.cjs. Read by the Lighting singleton.

var RAD = Math.PI / 180;

function wrap(v, m) {
    return ((v % m) + m) % m;
}

// ms: epoch milliseconds (UTC). lat/lon in degrees (east positive).
// Returns { azimuth: degrees clockwise from north, altitude: degrees above
// the horizon (negative below), declination }.
function position(ms, lat, lon) {
    var jd = ms / 86400000 + 2440587.5;
    var t = (jd - 2451545) / 36525;
    var l0 = wrap(280.46646 + t * (36000.76983 + t * 0.0003032), 360);
    var m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    var e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    var c = Math.sin(m * RAD) * (1.914602 - t * (0.004817 + 0.000014 * t))
        + Math.sin(2 * m * RAD) * (0.019993 - 0.000101 * t)
        + Math.sin(3 * m * RAD) * 0.000289;
    var omega = 125.04 - 1934.136 * t;
    var lambda = l0 + c - 0.00569 - 0.00478 * Math.sin(omega * RAD);
    var eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    var eps = eps0 + 0.00256 * Math.cos(omega * RAD);
    var decl = Math.asin(Math.sin(eps * RAD) * Math.sin(lambda * RAD));

    var y = Math.pow(Math.tan(eps * RAD / 2), 2);
    var eqTime = 4 / RAD * (y * Math.sin(2 * l0 * RAD)
        - 2 * e * Math.sin(m * RAD)
        + 4 * e * y * Math.sin(m * RAD) * Math.cos(2 * l0 * RAD)
        - 0.5 * y * y * Math.sin(4 * l0 * RAD)
        - 1.25 * e * e * Math.sin(2 * m * RAD));

    var utcMinutes = wrap(ms / 60000, 1440);
    var solarTime = wrap(utcMinutes + eqTime + 4 * lon, 1440);
    var ha = (solarTime / 4 - 180) * RAD;
    var phi = lat * RAD;

    var cosZen = Math.sin(phi) * Math.sin(decl) + Math.cos(phi) * Math.cos(decl) * Math.cos(ha);
    var zenith = Math.acos(Math.max(-1, Math.min(1, cosZen)));
    var az = Math.atan2(Math.sin(ha), Math.cos(ha) * Math.sin(phi) - Math.tan(decl) * Math.cos(phi)) / RAD + 180;
    return {
        azimuth: wrap(az, 360),
        altitude: 90 - zenith / RAD,
        declination: decl / RAD
    };
}

// Typical latitude of the populated land in each whole-hour UTC offset
// (keyed by the offset in hours, east positive): a rough stand-in when
// neither a location nor coordinates are known.
var OFFSET_LATITUDE = {
    "-10": 21, "-9": 61, "-8": 37, "-7": 39, "-6": 32, "-5": 40, "-4": 18,
    "-3": -23, "-2": -4, "-1": 38, "0": 51, "1": 48, "2": 48, "3": 55,
    "4": 25, "5": 33, "6": 40, "7": 13, "8": 31, "9": 36, "10": -33,
    "11": -34, "12": -37, "13": -21
};

// tzOffsetMinutes: Date.getTimezoneOffset() (minutes WEST of UTC, so -60
// in Central Europe). Returns { lat, lon } in the middle of the zone.
function fromTimezone(tzOffsetMinutes) {
    var east = -tzOffsetMinutes / 60;
    var key = String(Math.round(east));
    var lat = OFFSET_LATITUDE[key];
    return {
        lat: lat === undefined ? (east < 0 ? 35 : 40) : lat,
        lon: Math.max(-180, Math.min(180, east * 15))
    };
}

// "lat,lon" (a weather.location written as coordinates) or null.
function parseCoords(text) {
    var m = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/.exec(String(text || ""));
    if (!m)
        return null;
    var lat = parseFloat(m[1]);
    var lon = parseFloat(m[2]);
    if (Math.abs(lat) > 90 || Math.abs(lon) > 180)
        return null;
    return { lat: lat, lon: lon };
}

// The place to compute for: known coordinates, else "lat,lon" text, else
// the timezone stand-in. Each argument may be missing.
function resolvePlace(lat, lon, locationText, tzOffsetMinutes) {
    if (isFinite(lat) && isFinite(lon) && lat !== null && lon !== null)
        return { lat: lat, lon: lon, source: "location" };
    var parsed = parseCoords(locationText);
    if (parsed)
        return { lat: parsed.lat, lon: parsed.lon, source: "coords" };
    var tz = fromTimezone(tzOffsetMinutes || 0);
    return { lat: tz.lat, lon: tz.lon, source: "timezone" };
}
