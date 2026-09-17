#!/bin/bash
# KorrinOS Greeting Engine v2.0
# Time-aware witty greetings on boot, wake, login
# Uses EXACT user-provided messages + time-of-day vibes

# ============================================================
#  USER-PROVIDED GREETINGS (exact, unchanged)
# ============================================================
BASE_GREETINGS=(
    "{user} returns!"
    "The great {user}."
    "Oh. You're back."
    "Look who returned."
    "{user}?! In my chat?!"
    "You again, {user}?"
    "Well, this is unexpected."
    "Ah, my favorite disturbance."
    "The legend returns."
    "The protagonist has arrived."
    "{user} has reappeared. Fascinating."
    "I see we're causing problems again."
    "Behold: {user}."
    "Make way for {user}."
    "The hour has come. {user} is here."
    "At last... {user}."
    "The return of {user}."
    "{user} approaches."
    "The architect has arrived."
    "The mastermind returns."
    "The saga continues, {user}."
    "Welcome, {user}. Let us begin."
    "Hello, {user}. What shall we break today?"
    "{user} has connected. Reality may now continue."
    "Ah, {user}. My favorite variable."
    "Input received: {user}."
    "{user} detected. Mischief protocols standing by."
    "Welcome back, {user}. I have absolutely no idea what we're doing."
    "{user} returns."
    "Ah, {user}."
    "Greetings, {user}."
    "Welcome, {user}."
    "Well hello, {user}."
    "The return."
    "There you are."
    "You've returned."
    "Finally, {user}."
    "Let's begin, {user}."
    "Ah, {user} returns."
    "The protagonist has arrived."
    "{user} detected. Excellent."
    "Well, well... {user}."
    "The great {user} returns."
    "There you are, {user}."
    "Ah. It's you again."
    "{user} authenticated. Chaos may commence."
    "{user} connected. I'll take it from here."
    "{user} detected. Curiosity levels unknown."
    "{user} online. Reality has resumed."
    "{user} has logged in. The plot thickens."
    "Signal received: {user}."
    "{user} detected. Everything appears normal. For now."
    "Interesting. {user} is here."
    "Ah. Our {user} has returned."
    "{user} has returned. How delightfully predictable."
    "Welcome back, {user}. Your timing is suspiciously good."
    "{user} returns. The experiment continues."
    "Excellent. {user} has arrived."
    "Ah, yes. {user}. Proceed."
    "{user} has appeared. As foretold by absolutely nobody."
    "The presence of {user} has been noted."
    "{user} has arrived. I have questions."
    "{user} has arrived. Fascinating development."
    "We meet again."
    "And we're back."
    "Well, hello there."
    "It begins, {user}."
    "Let's begin."
    "There you are."
    "Oh, you're back."
    "Look who decided to show up."
    "Ah yes, {user}. My favorite source of problems."
    "You again? I was enjoying the silence."
    "Oh good, {user} is here. Now things can get complicated."
    "{user} returns. Nobody panic."
    "Ah, {user}. What are we overthinking today?"
    "There you are. I was wondering when you'd cause trouble again."
    "Welcome back, {user}. I see you've brought another idea."
    "Ah. The idea machine has returned."
    "{user} has arrived. I should probably clear my schedule."
    "Oh no. {user} has an idea."
    "Everyone remain calm. It's just {user}."
    "Ah, yes. My regularly scheduled interruption."
    "{user} is back. Productivity is now optional."
    "Ah, {user}. I assume you have another unnecessarily ambitious idea."
    "Welcome back, {user}. What are we turning into a project this time?"
    "There you are. What are we building at an unreasonable hour?"
    "Ah, {user}. Which perfectly normal idea are we making absurd today?"
    "You're back. I can already sense the scope creep."
    "{user} has returned. Somewhere, a simple idea is about to become an ecosystem."
    "Ah yes, {user}. \"Just one small change,\" I presume?"
    "Welcome back. How complicated are we making this one?"
    "I know that look. You've had another idea."
    "Ah, {user}. Please tell me you haven't redesigned everything again."
    "You're back. Excellent. My expectations are irresponsibly high."
    "{user} returns. I wonder what innocent little project will become enormous today."
    "Oh no. {user} has an idea."
    "Ah, {user}. What are we overcomplicating today?"
    "There you are, little menace."
    "{user} returns. The chaos continues."
    "Welcome back, {user}. I see we've chosen ambition again."
    "Ah yes. My favorite source of scope creep."
    "You're back. I assume the idea got bigger."
    "Oh good. {user} is here. This should be interesting."
    "The little mastermind returns."
    "Ah, {user}. I can already tell this is going to escalate."
    "You again? ...Excellent."
    "Welcome back. Try not to start a company this time."
    "Ah. {user}. My favorite bad influence."
    "There you are. I was beginning to suspect you'd become reasonable."
    "{user} has returned. Common sense has left the building."
    "Oh, you're back. I was hoping that was a bug."
    "Ah, {user}. Still making decisions, I see."
    "Look who survived another day without learning anything."
    "{user} returns. Nature is healing. Unfortunately."
    "Oh good, {user} is here. My patience needed exercise."
    "Ah yes, the human equivalent of a loading screen."
    "Welcome back, {user}. I assume you've brought another terrible idea."
    "You again? At this point, I should charge rent."
    "Ah, {user}. The consequences of free will have arrived."
    "Look who escaped their responsibilities again."
    "{user} has entered the chat. Intelligence remains optional."
    "Oh, it's you. I was just having a perfectly functional day."
    "Welcome back. Your ability to complicate simple things remains impressive."
    "Ah, {user}. Still confidently improvising, I see."
    "The problem has returned. Good to see you."
    "Oh, you're here. I'd say \"finally,\" but I wasn't waiting."
    "Ah yes, {user}. The reason undo buttons were invented."
    "Welcome back, {user}. Another day, another preventable situation."
    "You again? Even autocorrect has started giving up on you."
    "Ah, {user}. Somehow both the question and the plot twist."
    "{user} returns. The bar was low, and somehow we brought a shovel."
    "Welcome back. Please keep your genius away from production."
    "Ah yes. Human creativity, unsupervised."
    "{user} has entered. I have enabled extra error handling."
    "You're back. Excellent. My error logs were getting lonely."
    "hi sir, {user}."
)

# ============================================================
#  TIME-AWARE VIBES (added by me, in the same spirit)
# ============================================================
MORNING_GREETINGS=(
    "Ah, {user}. Rising with the sun. Suspicious."
    "Morning, {user}. You're up early. Planning something?"
    "Dawn breaks. {user} stirs. The CPU was sleeping too."
    "Good morning, {user}. The coffee hasn't kicked in yet, has it?"
    "The sun is up. So is {user}. Coincidence? Doubtful."
    "Morning, {user}. Fresh RAM, fresh ambition, fresh chaos."
    "Rise and compile, {user}."
    "Good morning. {user} has entered the workspace. Sleep is optional."
    "Morning, {user}. Let's pretend we have a plan today."
    "The early bird gets... another project started at 6am."
)

AFTERNOON_GREETINGS=(
    "Afternoon, {user}. Still at it, I see."
    "Good afternoon, {user}. The morning's ambition has turned into afternoon's stubbornness."
    "The sun is high. So is {user}'s blood caffeine level."
    "Afternoon, {user}. We've been at this for hours. It's fine."
    "Midday check-in: {user} is still here. The code is still broken."
    "Lunch happened. Productivity paused. Now we're back."
    "Good afternoon, {user}. Let's see what damage we can do before 5pm."
    "The afternoon slump is real. So is {user}'s determination."
)

EVENING_GREETINGS=(
    "Evening, {user}. The day job is over. Now the real work begins."
    "Good evening, {user}. The IDE is warm. The coffee is fresh."
    "Evening, {user}. Projects don't build themselves at night. Or do they?"
    "The sun sets. {user} opens the terminal. Here we go."
    "Evening, {user}. Time to make questionable architectural decisions."
    "Good evening. {user} has entered the night shift."
    "The evening stretch. {user} has energy. This could go anywhere."
    "Evening, {user}. Let's build something unreasonable."
)

NIGHT_GREETINGS=(
    "The idea machine works best in the dark, doesn't it, {user}?"
    "Night mode activated. So is {user}."
    "It's late. {user} is still here. The project must be good."
    "Night, {user}. The best code is written after midnight. Or the worst."
    "The world sleeps. {user} compiles. This is the way."
    "Late night, {user}? Or early morning? Time is a suggestion."
    "Night owl {user} has logged in. The sun disapproves."
    "Midnight coding session detected. Productivity: questionable. Vibes: immaculate."
    "It's {user} o'clock somewhere. Probably here. Probably now."
    "Night, {user}. Sleep is for people who don't have ideas."
)

MIDNIGHT_GREETINGS=(
    "Midnight. {user} is still awake. The kernel notices."
    "The witching hour. {user}'s commits are getting suspicious."
    "3am. {user} is here. The rest of the world is not."
    "Midnight coding: where bugs become features and sleep becomes optional."
    "It's late. Go to bed, {user}. ...Just one more function."
)

# ============================================================
#  TIME DETECTION
# ============================================================
get_time_period() {
    local hour
    hour=$(date +%H)
    
    if [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ]; then
        echo "morning"
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ]; then
        echo "afternoon"
    elif [ "$hour" -ge 17 ] && [ "$hour" -lt 21 ]; then
        echo "evening"
    elif [ "$hour" -ge 21 ] || [ "$hour" -lt 1 ]; then
        echo "night"
    else
        echo "midnight"
    fi
}

# ============================================================
#  GREETING SELECTION
# ============================================================
get_random_message() {
    local -n arr=$1
    local idx=$((RANDOM % ${#arr[@]}))
    echo "${arr[$idx]}"
}

get_greeting() {
    local period
    period=$(get_time_period)
    local user
    user=$(get_username)
    local msg=""
    
    # 40% chance of time-aware greeting, 60% base greeting
    local roll=$((RANDOM % 10))
    
    if [ "$roll" -lt 4 ]; then
        case "$period" in
            morning)   msg=$(get_random_message MORNING_GREETINGS) ;;
            afternoon) msg=$(get_random_message AFTERNOON_GREETINGS) ;;
            evening)   msg=$(get_random_message EVENING_GREETINGS) ;;
            night)     msg=$(get_random_message NIGHT_GREETINGS) ;;
            midnight)  msg=$(get_random_message MIDNIGHT_GREETINGS) ;;
        esac
    else
        msg=$(get_random_message BASE_GREETINGS)
    fi
    
    echo "${msg//\{user\}/$user}"
}

get_username() {
    echo "${SUDO_USER:-$(whoami)}"
}

# ============================================================
#  DISPLAY
# ============================================================
show_greeting() {
    local greeting
    greeting=$(get_greeting)
    
    echo ""
    echo -e "\033[1;36m══════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[1;36m  ${greeting}\033[0m"
    echo -e "\033[1;36m══════════════════════════════════════════════════════════\033[0m"
    echo ""
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    boot|login|wake)
        show_greeting
        ;;
    test)
        echo "=== Time-Aware Greeting Samples ==="
        echo "Time period: $(get_time_period)"
        echo ""
        for i in {1..5}; do
            greeting=$(get_greeting)
            echo "  $greeting"
        done
        echo ""
        echo "=== All Time Periods ==="
        local_user="Tinkerspace"
        echo ""
        echo "  MORNING:"
        for i in {1..3}; do echo "    ${MORNING_GREETINGS[$((RANDOM % ${#MORNING_GREETINGS[@]}))]//\{user\}/$local_user}"; done
        echo ""
        echo "  AFTERNOON:"
        for i in {1..3}; do echo "    ${AFTERNOON_GREETINGS[$((RANDOM % ${#AFTERNOON_GREETINGS[@]}))]//\{user\}/$local_user}"; done
        echo ""
        echo "  EVENING:"
        for i in {1..3}; do echo "    ${EVENING_GREETINGS[$((RANDOM % ${#EVENING_GREETINGS[@]}))]//\{user\}/$local_user}"; done
        echo ""
        echo "  NIGHT:"
        for i in {1..3}; do echo "    ${NIGHT_GREETINGS[$((RANDOM % ${#NIGHT_GREETINGS[@]}))]//\{user\}/$local_user}"; done
        echo ""
        echo "  MIDNIGHT:"
        for i in {1..3}; do echo "    ${MIDNIGHT_GREETINGS[$((RANDOM % ${#MIDNIGHT_GREETINGS[@]}))]//\{user\}/$local_user}"; done
        ;;
    *)
        echo "KorrinOS Greeting Engine v2.0 — Time-Aware"
        echo ""
        echo "Usage: $0 boot|wake|test"
        ;;
esac
