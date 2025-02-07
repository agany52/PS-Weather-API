# City coordinates and town name
$latitude = 43.0731  # Madison, WI latitude
$longitude = -89.4012  # Madison, WI longitude
$townName = "Madison"

# URL for Open Meteo API to get current weather with "feels like" temperature
$currentWeatherUrl = "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&temperature_unit=fahrenheit&timezone=America/Chicago"

# URL for Open Meteo API to get the 7-day forecast with snowfall
$forecastUrl = "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&daily=temperature_2m_max,temperature_2m_min,weathercode,windspeed_10m_max,precipitation_probability_max,snowfall_sum&timezone=America/Chicago"

# Fetching the current weather data
$currentWeatherResponse = Invoke-RestMethod -Uri $currentWeatherUrl

# Fetching the 7-day forecast data
$forecastResponse = Invoke-RestMethod -Uri $forecastUrl


# Wind chill calculation
function Calculate-WindChill($tempF, $windMph) {
    if ($tempF -lt 50 -and $windMph -gt 3) {
        return [math]::Round(35.74 + 0.6215 * $tempF - 35.75 * [math]::Pow($windMph, 0.16) + 0.4275 * $tempF * [math]::Pow($windMph, 0.16), 1)
    } else {
        return $tempF
    }
}

# Heat index calculation
function Calculate-HeatIndex($tempF, $humidity) {
    if ($tempF -gt 80) {
        return [math]::Round(-42.379 + 2.04901523 * $tempF + 10.14333127 * $humidity - 0.22475541 * $tempF * $humidity - 6.83783 * [math]::Pow(10, -3) * [math]::Pow($tempF, 2) - 5.481717 * [math]::Pow(10, -2) * [math]::Pow($humidity, 2) + 1.22874 * [math]::Pow(10, -3) * [math]::Pow($tempF, 2) * $humidity + 8.5282 * [math]::Pow(10, -4) * $tempF * [math]::Pow($humidity, 2) - 1.99 * [math]::Pow(10, -6) * [math]::Pow($tempF, 2) * [math]::Pow($humidity, 2), 1)
    } else {
        return $tempF
    }
}

# Current Weather (Verify field names)
$currentDate = [datetime]::Now
$currentTempFahrenheit = $null
$currentHumidity = $null
$currentWindSpeedMph = $null

if ($currentWeatherResponse.current_weather.temperature -ne $null) {
    $currentTempFahrenheit = [math]::Round($currentWeatherResponse.current_weather.temperature, 1)
}

if ($currentWeatherResponse.current_weather.humidity -ne $null) {
    $currentHumidity = $currentWeatherResponse.current_weather.humidity
}

if ($currentWeatherResponse.current_weather.windspeed -ne $null) {
    $currentWindSpeedMph = $currentWeatherResponse.current_weather.windspeed
}

if ($currentTempFahrenheit -lt 50) {
    $feelsLikeTempFahrenheit = Calculate-WindChill $currentTempFahrenheit $currentWindSpeedMph
} elseif ($currentTempFahrenheit -gt 80) {
    $feelsLikeTempFahrenheit = Calculate-HeatIndex $currentTempFahrenheit $currentHumidity
} else {
    $feelsLikeTempFahrenheit = $currentTempFahrenheit
}

$currentWeatherDescription = "Unknown weather"
if ($currentWeatherResponse.current_weather.weathercode -ne $null) {
    $currentWeatherDescription = switch ($currentWeatherResponse.current_weather.weathercode) {
        0 { "Clear sky" }
        1 { "Mainly clear" }
        2 { "Partly cloudy" }
        3 { "Overcast" }
        45 { "Fog" }
        48 { "Depositing rime fog" }
        51 { "Drizzle: Light" }
        53 { "Drizzle: Moderate" }
        55 { "Drizzle: Dense intensity" }
        56 { "Freezing Drizzle: Light" }
        57 { "Freezing Drizzle: Dense intensity" }
        61 { "Rain: Slight" }
        63 { "Rain: Moderate" }
        65 { "Rain: Heavy intensity" }
        66 { "Freezing Rain: Light" }
        67 { "Freezing Rain: Heavy intensity" }
        71 { "Snow fall: Slight" }
        73 { "Snow fall: Moderate" }
        75 { "Snow fall: Heavy intensity" }
        77 { "Snow grains" }
        80 { "Rain showers: Slight" }
        81 { "Rain showers: Moderate" }
        82 { "Rain showers: Violent" }
        85 { "Snow showers: Slight" }
        86 { "Snow showers: Heavy" }
        95 { "Thunderstorm: Slight or moderate" }
        96 { "Thunderstorm with slight hail" }
        99 { "Thunderstorm with heavy hail" }
        default { "Unknown weather" }
    }
}

# Define ASCII art for different weather conditions
$currentAsciiArt = switch ($currentWeatherDescription) {
    "Clear sky" { @"
    \  /
  _ /""._
"@ }
    "Mainly clear" { @"
    \  /
  _ /""._
"@ }
    "Partly cloudy" { @"
  .--.
 (    )
(___(__)
"@ }
    "Overcast" { @"
  .--.
 (    )
(___(__)
"@ }
    "Rain" { @"
     .--.
   (    )
  (___(__)
     '  '
"@ }
    "Snow" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
    "Fog" { @"
   _____
  /     \
 /       \
 |_______|
"@ }
    default { @"
   ???
"@ }
}

Write-Host ("Current Weather: {0:dddd, MMMM dd}: {1}{2}F (feels like {3}{2}F) - {4}. Wind: {5} mph.`n{6}" -f $currentDate, $currentTempFahrenheit, [char]176, $feelsLikeTempFahrenheit, $currentWeatherDescription, $currentWindSpeedMph, $currentAsciiArt)

# 7-Day Forecast
Write-Host "`n7-Day Weather Forecast for $townName"
for ($i = 0; $i -lt 7; $i++) {
    $date = [datetime]::Parse($forecastResponse.daily.time[$i])
    $maxTempCelsius = $forecastResponse.daily.temperature_2m_max[$i]
    $minTempCelsius = $forecastResponse.daily.temperature_2m_min[$i]
    $maxTempFahrenheit = [math]::Round(($maxTempCelsius * 9/5) + 32, 1)
    $minTempFahrenheit = [math]::Round(($minTempCelsius * 9/5) + 32, 1)
    $windSpeedMaxKph = $forecastResponse.daily.windspeed_10m_max[$i]
    $windSpeedMaxMph = [math]::Round($windSpeedMaxKph * 0.621371, 1)
    $precipProbability = $forecastResponse.daily.precipitation_probability_max[$i]
    $snowfallCm = $forecastResponse.daily.snowfall_sum[$i]
    $snowfallInches = [math]::Round($snowfallCm * 0.393701, 1)
    
    # Translate weather code to description
    $weatherCode = $forecastResponse.daily.weathercode[$i]
    $weatherDescription = switch ($weatherCode) {
        0 { "Clear sky" }
        1 { "Mainly clear" }
        2 { "Partly cloudy" }
        3 { "Overcast" }
        45 { "Fog" }
        48 { "Depositing rime fog" }
        51 { "Drizzle: Light" }
        53 { "Drizzle: Moderate" }
        55 { "Drizzle: Dense intensity" }
        56 { "Freezing Drizzle: Light" }
        57 { "Freezing Drizzle: Dense intensity" }
        61 { "Rain: Slight" }
        63 { "Rain: Moderate" }
        65 { "Rain: Heavy intensity" }
        66 { "Freezing Rain: Light" }
        67 { "Freezing Rain: Heavy intensity" }
        71 { "Snow fall: Slight" }
        73 { "Snow fall: Moderate" }
        75 { "Snow fall: Heavy intensity" }
        77 { "Snow grains" }
        80 { "Rain showers: Slight" }
        81 { "Rain showers: Moderate" }
        82 { "Rain showers: Violent" }
        85 { "Snow showers: Slight" }
        86 { "Snow showers: Heavy" }
        95 { "Thunderstorm: Slight or moderate" }
        96 { "Thunderstorm with slight hail" }
        99 { "Thunderstorm with heavy hail" }
        default { "Unknown weather" }
    }
    
    # Define ASCII art for different weather conditions
    $asciiArt = switch ($weatherDescription) {
        "Clear sky" { @"
    \  /
  _ /""._
"@ }
        "Mainly clear" { @"
    \  /
  _ /""._
"@ }
        "Partly cloudy" { @"
  .--.
 (    )
(___(__)
"@ }
        "Overcast" { @"
  .--.
 (    )
(___(__)
"@ }
        "Fog" { @"
   _____
  /     \
 /       \
 |_______|
"@ }
        "Drizzle: Light" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Drizzle: Moderate" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Drizzle: Dense intensity" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Freezing Drizzle: Light" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Freezing Drizzle: Dense intensity" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Rain: Slight" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Rain: Moderate" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Rain: Heavy intensity" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Freezing Rain: Light" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Freezing Rain: Heavy intensity" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Snow fall: Slight" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Snow fall: Moderate" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Snow fall: Heavy intensity" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Snow grains" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Rain showers: Slight" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Rain showers: Moderate" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Rain showers: Violent" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Snow showers: Slight" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Snow showers: Heavy" { @"
    .-""-.
   (     )
  (___|___)
     * * *
"@ }
        "Thunderstorm: Slight or moderate" { @"
     .--.
   (    )
  (___(__)
   ' ' ' '
"@ }
        "Thunderstorm with slight hail" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        "Thunderstorm with heavy hail" { @"
     .--.
   (    )
  (___(__)
  ' ' ' ' '
"@ }
        default { "Unknown weather" }
        }
    
    Write-Host ("{0:dddd, MMMM dd}: High {1}{2}F / Low {3}{2}F - {4}. `n{5}" -f $date, $maxTempFahrenheit, [char]176, $minTempFahrenheit, $weatherDescription, $asciiArt)
    Write-Host("")
    Write-Host ("    Wind speed: {0} mph" -f $windSpeedMaxMph)
    Write-Host ("    Chance of precipitation: {0}%" -f $precipProbability)
    Write-Host ("    Snowfall expected: {0} inches" -f $snowfallInches)
    Write-Host("")
}


Pause