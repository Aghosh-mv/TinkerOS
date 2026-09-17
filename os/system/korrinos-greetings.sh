#!/bin/bash
# KorrinOS Greeting Engine v1.0
# Shows witty greetings on boot, wake, login
# Uses EXACT user-provided messages. No modifications.

GREETINGS=(
    # --- Set 1 ---
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

    # --- Set 2 ---
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

    # --- Set 3 ---
    "Hello, {user}. What shall we break today?"
    "{user} has connected. Reality may now continue."
    "Ah, {user}. My favorite variable."
    "Input received: {user}."
    "{user} detected. Mischief protocols standing by."
    "Welcome back, {user}. I have absolutely no idea what we're doing."

    # --- Set 4 ---
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

    # --- Set 5 ---
    "Ah, {user} returns."
    "The protagonist has arrived."
    "{user} detected. Excellent."
    "Well, well... {user}."
    "The great {user} returns."
    "There you are, {user}."
    "Ah. It's you again."

    # --- Set 6 ---
    "{user} authenticated. Chaos may commence."
    "{user} connected. I'll take it from here."
    "{user} detected. Curiosity levels unknown."
    "{user} online. Reality has resumed."
    "{user} has logged in. The plot thickens."
    "Signal received: {user}."

    # --- Set 7 ---
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

    # --- Set 8 ---
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

    # --- Set 9 ---
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

    # --- Set 10 ---
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

    # --- Set 11 ---
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

    # --- Set 12 ---
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

    # --- Set 13 ---
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

    # --- Set 14 ---
    "hi sir, {user}."
)

get_username() {
    echo "${SUDO_USER:-$(whoami)}"
}

show_greeting() {
    local user
    user=$(get_username)
    local idx=$((RANDOM % ${#GREETINGS[@]}))
    local msg="${GREETINGS[$idx]}"
    local formatted="${msg//\{user\}/$user}"
    
    echo ""
    echo -e "\033[1;36m══════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[1;36m  ${formatted}\033[0m"
    echo -e "\033[1;36m══════════════════════════════════════════════════════════\033[0m"
    echo ""
}

case "${1:-}" in
    boot|login|wake)
        show_greeting
        ;;
    test)
        echo "=== Sample Greetings ==="
        for i in {1..10}; do
            msg="${GREETINGS[$((RANDOM % ${#GREETINGS[@]}))]}"
            echo "  ${msg//\{user\}/Tinkerspace}"
        done
        ;;
    *)
        echo "Usage: $0 boot|wake|test"
        ;;
esac
