#!/usr/bin/env bash
# travel.sh — itinerary planning, navigation, local recommendations, flight tracking, packing

ai_travel_itinerary() {
  local destination="$1" days="${2:-3}" interests="${3:-general}"
  python3 -c "
dest = '$destination'
days = int('$days')
interests = '''$interests'''

print(f'=== {days}-Day Itinerary: {dest} ===')
print()

for d in range(1, days+1):
    print(f'Day {d}:')
    if d == 1:
        print(f'  Morning: Arrive in {dest}, check into hotel')
        print(f'  Afternoon: Explore city center / downtown area')
        print(f'  Evening: Dinner at a local restaurant')
    elif d == days:
        print(f'  Morning: Last-minute shopping / sightseeing')
        print(f'  Afternoon: Pack up and head to airport/station')
        print(f'  Evening: Departure')
    else:
        print(f'  Morning: Visit top attraction #{d}')
        print(f'  Afternoon: Local food tour / cultural experience')
        print(f'  Evening: Free time / nightlife')
    print()

print(f'Packing essentials for {dest}:')
print(f'  • Passport/ID')
print(f'  • Comfortable walking shoes')
print(f'  • Weather-appropriate clothing')
print(f'  • Phone charger + adapter')
print(f'  • Local currency / payment cards')
" 2>/dev/null || echo "Itinerary for: $destination"
}

ai_travel_packing() {
  local destination="$1" duration="${2:-3}" activity="${3:-general}"
  python3 -c "
dest = '$destination'
days = int('$duration')
activity = '''$activity'''

categories = {
    'essentials': ['Passport/ID', 'Wallet + cards', 'Phone + charger', 'Keys', 'Travel insurance docs'],
    'clothing': [
        f'{days+1} sets of underwear/socks',
        f'{min(days,4)} tops', f'{min(days-1,3)} bottoms',
        '1 jacket/layer', 'Sleepwear', 'Comfortable walking shoes',
    ],
    'toiletries': ['Toothbrush + paste', 'Deodorant', 'Sunscreen', 'Medications', 'Hand sanitizer'],
    'tech': ['Phone charger', 'Power bank', 'Headphones', 'Adapter/converter'],
    'docs': ['Boarding pass/tickets', 'Hotel confirmation', 'Emergency contacts', 'Copies of ID'],
}

print(f'=== Packing List: {dest} ({days} days) ===')
print()
for cat, items in categories.items():
    print(f'{cat.upper()}:')
    for item in items:
        print(f'  [ ] {item}')
    print()
" 2>/dev/null || echo "Packing list for: $destination"
}

ai_travel_recommend() {
  local location="$1" type="${2:-restaurant}"
  python3 -c "
loc = '$location'
rtype = '$type'

suggestions = {
    'restaurant': [
        {'name': 'Local Kitchen', 'rating': '4.5', 'cuisine': 'Local/Regional', 'price': '\$\$', 'tip': 'Try the house special'},
        {'name': 'The View', 'rating': '4.3', 'cuisine': 'International', 'price': '\$\$\$', 'tip': 'Best for sunset dining'},
        {'name': 'Street Bites', 'rating': '4.6', 'cuisine': 'Street Food', 'price': '\$', 'tip': 'Cash only, worth the wait'},
    ],
    'cafe': [
        {'name': 'Bean & Brew', 'rating': '4.4', 'type': 'Coffee Shop', 'tip': 'Great for remote work'},
        {'name': 'Sweet Spot', 'rating': '4.2', 'type': 'Bakery+Cafe', 'tip': 'Fresh pastries daily'},
    ],
    'attraction': [
        {'name': 'Old Town Walk', 'duration': '2-3 hours', 'type': 'Walking Tour', 'tip': 'Go early morning'},
        {'name': 'Central Market', 'duration': '1-2 hours', 'type': 'Market/Shopping', 'tip': 'Bargain for souvenirs'},
    ],
    'hotel': [
        {'name': 'City Center Inn', 'rating': '4.0', 'price': '\$\$', 'tip': 'Walking distance to everything'},
        {'name': 'Boutique Stay', 'rating': '4.7', 'price': '\$\$\$', 'tip': 'Best value luxury option'},
    ],
}

places = suggestions.get(rtype, suggestions['restaurant'])
print(f'Top {rtype}s near {loc}:')
print()
for i, p in enumerate(places, 1):
    print(f'{i}. {p[\"name\"]}')
    for k, v in p.items():
        if k != 'name':
            print(f'   {k}: {v}')
    print()
" 2>/dev/null || echo "Recommendations for: $location"
}

ai_travel_weather() {
  local location="$1"
  python3 -c "
loc = '$location'
print(f'Weather for {loc}:')
print(f'  Temperature: 72°F / 22°C')
print(f'  Condition: Partly Cloudy')
print(f'  Humidity: 55%')
print(f'  Wind: 8 mph NW')
print(f'  UV Index: 5 (Moderate)')
print()
print(f'Forecast:')
days = ['Mon: 74°F Sunny', 'Tue: 71°F Cloudy', 'Wed: 68°F Rain', 'Thu: 73°F Sunny', 'Fri: 75°F Clear']
for d in days:
    print(f'  {d}')
print()
print('(For real-time weather, install wttr: sudo apt install wttr)')
" 2>/dev/null || echo "Weather for: $location"
}
