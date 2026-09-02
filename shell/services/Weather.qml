pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.utils
import qs.services

Singleton {
    id: root

    property string city
    property string loc
    property var cc
    property list<var> forecast
    property list<var> hourlyForecast
    property string locationSearchQuery: ""
    property bool locationSearchLoading: false
    property string locationSearchError: ""
    property list<var> locationSearchResults: []
    property int locationSearchToken: 0

    readonly property string icon: cc ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: cc?.weatherDesc ?? I18n.tr("No weather")
    readonly property string temp: formatTemp(cc?.tempC)
    readonly property string feelsLike: formatTemp(cc?.feelsLikeC)
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"

    readonly property var cachedCities: new Map()

    function formatTemp(temp) {
        return GlobalConfig.services.useFahrenheit ? `${temp !== undefined ? Math.round(toFahrenheit(temp)) : "--"}°F` : `${temp !== undefined ? Math.round(temp) : "--"}°C`;
    }

    function normalizeCoords(lat, lon) {
        if (!isFinite(lat) || !isFinite(lon))
            return "";

        return `${lat.toFixed(4)},${lon.toFixed(4)}`;
    }

    function buildLocationLabel(result) {
        const parts = [];

        if (result?.name)
            parts.push(result.name);
        if (result?.admin1 && result.admin1 !== result.name)
            parts.push(result.admin1);
        if (result?.country)
            parts.push(result.country);

        return parts.join(", ");
    }

    function queueLocationSearch(query) {
        locationSearchQuery = (query ?? "").trim();
        locationSearchError = "";

        if (locationSearchQuery.length < 2) {
            locationSearchToken++; // invalidate any in-flight searches
            locationSearchLoading = false;
            locationSearchResults = [];
            locationSearchDebounce.stop();
            return;
        }

        locationSearchDebounce.restart();
    }

    function searchLocations(query) {
        const trimmed = (query ?? "").trim();
        if (trimmed.length < 2) {
            locationSearchLoading = false;
            locationSearchResults = [];
            locationSearchError = "";
            return;
        }

        const token = ++locationSearchToken;
        locationSearchLoading = true;
        locationSearchError = "";

        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(trimmed)}&count=10&language=en&format=json`;

        const onSuccess = function(text) {
            if (token !== locationSearchToken)
                return;

            locationSearchLoading = false;

            let json;
            try {
                json = JSON.parse(text);
            } catch (e) {
                locationSearchResults = [];
                locationSearchError = I18n.tr("Couldn't parse location results. Check your connection and try again.");
                return;
            }
            const results = [];

            if (json.results) {
                for (const result of json.results) {
                    const item = {
                        name: result.name ?? "",
                        admin1: result.admin1 ?? "",
                        country: result.country ?? "",
                        timezone: result.timezone ?? "",
                        latitude: result.latitude,
                        longitude: result.longitude
                    };
                    item.label = buildLocationLabel(item);
                    results.push(item);
                }
            }

            locationSearchResults = results;
        };

        const onError = function() {
            if (token !== locationSearchToken)
                return;

            locationSearchLoading = false;
            locationSearchResults = [];
            locationSearchError = I18n.tr("Couldn't fetch locations. Check your connection and try again.");
        };

        Requests.get(url, onSuccess, onError);
    }

    function applyLocationResult(result) {
        if (!result)
            return false;

        const coords = normalizeCoords(Number(result.latitude), Number(result.longitude));
        if (!coords)
            return false;

        const label = result.label || buildLocationLabel(result) || result.name || "";

        const prevLoc = loc;

        GlobalConfig.services.weatherLocation = coords;
        loc = coords;
        if (label)
            city = label;
        if (label)
            cachedCities.set(coords, label);

        if (coords === prevLoc)
            fetchWeatherData();
        return true;
    }

    function resetToAutoLocation() {
        GlobalConfig.services.weatherLocation = "";
        loc = "";
        city = "";
        reload();
    }

    function reload() {
        const configLocation = GlobalConfig.services.weatherLocation;

        if (configLocation) {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                loc = configLocation;
                fetchCityFromCoords(configLocation);
            } else {
                fetchCoordsFromCity(configLocation, true);
            }
        } else if (!loc || timer.elapsed() > 900) {
            Requests.get("https://ipinfo.io/json", text => {
                const response = JSON.parse(text);
                if (response.loc) {
                    loc = response.loc;
                    city = response.city ?? "";
                    timer.restart();
                }
            });
        }
    }

    function fetchCityFromCoords(coords) {
        if (cachedCities.has(coords)) {
            city = cachedCities.get(coords);
            return;
        }

        const [lat, lon] = coords.split(",").map(s => s.trim());

        const fallbackToBigDataCloud = () => {
            const fallbackUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en`;
            Requests.get(fallbackUrl, text => {
                const geo = JSON.parse(text);
                const geoCity = geo.city || geo.locality;
                if (geoCity) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                } else {
                    city = "Unknown City";
                }
            });
        };

        const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=geocodejson`;
        Requests.get(nominatimUrl, text => {
            const geo = JSON.parse(text).features?.[0]?.properties.geocoding;
            if (geo) {
                const geoCity = geo.type === "city" ? geo.name : geo.city;
                if (geoCity) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                    return;
                }
            }
            fallbackToBigDataCloud();
        }, fallbackToBigDataCloud);
    }

    function fetchCoordsFromCity(cityName, persistCoords) {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&language=en&format=json`;

        Requests.get(url, text => {
            const json = JSON.parse(text);
            if (json.results && json.results.length > 0) {
                const result = json.results[0];
                const coords = normalizeCoords(result.latitude, result.longitude);
                if (!coords) {
                    loc = "";
                    reload();
                    return;
                }

                loc = coords;
                city = buildLocationLabel(result) || result.name;
                cachedCities.set(coords, city);

                if (persistCoords)
                    GlobalConfig.services.weatherLocation = coords;
            } else {
                loc = "";
                reload();
            }
        });
    }

    function fetchWeatherData() {
        const url = getWeatherUrl();
        if (url === "")
            return;

        Requests.get(url, text => {
            const json = JSON.parse(text);
            if (!json.current || !json.daily)
                return;

            cc = {
                weatherCode: json.current.weather_code,
                weatherDesc: getWeatherCondition(json.current.weather_code),
                tempC: json.current.temperature_2m,
                feelsLikeC: json.current.apparent_temperature,
                humidity: json.current.relative_humidity_2m,
                windSpeed: json.current.wind_speed_10m,
                isDay: json.current.is_day,
                sunrise: json.daily.sunrise[0].replace("T", " "),
                sunset: json.daily.sunset[0].replace("T", " ")
            };

            const forecastList = [];
            for (let i = 0; i < json.daily.time.length; i++)
                forecastList.push({
                    date: json.daily.time[i].replace(/-/g, "/"),
                    maxTempC: json.daily.temperature_2m_max[i],
                    minTempC: json.daily.temperature_2m_min[i],
                    maxTempF: Math.round(json.daily.temperature_2m_max[i] * 9 / 5 + 32),
                    minTempF: Math.round(json.daily.temperature_2m_min[i] * 9 / 5 + 32),
                    weatherCode: json.daily.weather_code[i],
                    icon: Icons.getWeatherIcon(json.daily.weather_code[i])
                });
            forecast = forecastList;

            const hourlyList = [];
            const now = new Date();
            for (let i = 0; i < json.hourly.time.length; i++) {
                const time = new Date(json.hourly.time[i].replace("T", " "));

                if (time < now)
                    continue;

                hourlyList.push({
                    timestamp: json.hourly.time[i],
                    hour: time.getHours(),
                    tempC: Math.round(json.hourly.temperature_2m[i]),
                    precipChance: json.hourly.precipitation_probability[i],
                    weatherCode: json.hourly.weather_code[i],
                    icon: Icons.getWeatherIcon(json.hourly.weather_code[i])
                });
            }
            hourlyForecast = hourlyList;
        });
    }

    function toFahrenheit(celcius) {
        return celcius * 9 / 5 + 32;
    }

    function getWeatherUrl() {
        if (!loc || loc.indexOf(",") === -1)
            return "";

        const [lat, lon] = loc.split(",").map(s => s.trim());
        const baseUrl = "https://api.open-meteo.com/v1/forecast";
        const params = ["latitude=" + lat, "longitude=" + lon, "hourly=weather_code,temperature_2m,precipitation_probability", "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset", "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m", "timezone=auto", "forecast_days=7"];

        return baseUrl + "?" + params.join("&");
    }

    function getWeatherCondition(code) {
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[code] || "Unknown";
    }

    onLocChanged: fetchWeatherData()

    Connections {
        function onWeatherLocationChanged(): void {
            root.reload();
        }

        target: GlobalConfig.services
    }

    Timer {
        id: locationSearchDebounce

        interval: 300
        repeat: false
        onTriggered: searchLocations(root.locationSearchQuery)
    }

    Timer {
        interval: 3600000 // 1 hour
        running: true
        repeat: true
        onTriggered: fetchWeatherData()
    }

    ElapsedTimer {
        id: timer
    }
}
