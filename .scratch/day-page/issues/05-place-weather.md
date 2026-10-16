# 05: Place and weather

**Spec:** `../spec.md`

**Status:** done

Once a Day when Coar opens, ask for When In Use location (coarse), store the Day's rounded location and place name. WeatherKit (`WeatherService`) gives that Day's conditions, high/low and precipitation, including past Days. Needs the WeatherKit capability and App Service on the App ID. Remove "weather" from DESIGN.md §10.

## Comments
- 2026-10-16 (agent): Done. `PlaceRecorder`: once a Day when Coar opens, with When In Use
  location, a kilometre-accurate fix rounded to two decimals and its city
  (`MKReverseGeocodingRequest`), as a `DayPlace`. Location is asked only from the Day page's
  "Show weather". WeatherKit (`WeatherKitProvider`) gives the Day's condition, high and low
  for any Day with a place, including journal places, with Apple's attribution. "Weather"
  left DESIGN.md §10.
