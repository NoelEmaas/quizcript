#!/bin/bash

source crud.sh

function init_db() {
    [ ! -e "database.json" ] && echo '{"quizzes:" []}' > database.json
}

function take_quiz() {
    local quiz_id=$(quiz_selection)
    start_quiz "$quiz_id"
}

function start_quiz() {
    local quiz_id="$1"
    local score=0
    local quiz_title=$(get_quiz_title "$quiz_id")
    local exit_status

    readarray -t questions < <(get_all_questions "$quiz_id")
    readarray -t answers < <(get_all_answers "$quiz_id")

    local num_questions=${#questions[@]}

    while true; do
        for ((i=0; i<num_questions; i++)); do
            local question=${questions[$i]}
            local correct_answer=${answers[$i]}
            local user_answer
            
            function get_user_answer() {            
                user_answer=$(dialog --clear --title "$quiz_title" --inputbox "\nCurrent Score: ${score}/${num_questions}\n\n${question}\n\n" 12 60 2>&1 >/dev/tty)
                exit_status=$?

                if [ $exit_status -ne 0 ]; then
                    dialog --clear --title "$quiz_title" --yesno "\nWould you like to stop the quiz?" 7 40 2>&1 >/dev/tty
                    exit_status=$?

                    if [ $exit_status -eq 0 ]; then
                        take_quiz
                        break
                    else
                        get_user_answer
                    fi
                fi
            }

            get_user_answer

            if [ "$user_answer" == "$correct_answer" ]; then
                score=$((score+1))
                dialog --title "Quiz" --msgbox "Correct!" 6 30
            else
                dialog --title "Quiz" --msgbox "Incorrect. \nThe correct answer is: ${correct_answer}" 8 40
            fi
        done

        dialog --title "Quiz Results" --msgbox "\nYour final score is: ${score}/${num_questions}\n" 8 40
        dialog --clear --title "$quiz_title" --yesno "\nWould you like to retake the quiz?\n" 7 40 2>&1 >/dev/tty

        exit_status=$?
        
        if [ $exit_status -eq 1 ]; then
            take_quiz
            break
        fi

        score=0
    done
}

function create_quiz() {
    local quiz_title
    local exit_status
    
    quiz_title=$(dialog --clear --title "Create a Quiz" --inputbox "\nEnter the title of the quiz\n" 8 40 2>&1 >/dev/tty)
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        local quiz_id=$(get_number_of_quizzes)

        # create the quiz
        add_quiz "$quiz_title"

        # add questions to the quiz
        add_new_questions "$quiz_id"
    fi
}

function add_new_questions() {
    local quiz_id="$1"
    local exit_status

    while true; do
        add_new_question "$quiz_id"

        dialog --clear --title "Add Questions" --yesno "\nWould you like to add another question?\n" 7 40 2>&1 >/dev/tty
        exit_status=$?

        if [ $exit_status -eq 1 ]; then
            show_quiz_selection
            break
        fi
    done
}

function add_new_question() {
    local quiz_id="$1"
    local question=""
    local answer=""
    local exit_status

    dialog --title "Add Question" \
        --form "\nEnter a new question and its answer:\n" 12 70 0 \
        "Question:" 1 1 "$question" 1 20 200 0 \
        "Answer:" 2 1 "$answer" 2 20 200 0 \
        2>&1 >/dev/tty

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # retrieve the values from the input fields
        question=$(echo "$question" | sed 's/"//g')
        answer=$(echo "$answer" | sed 's/"//g')

        echo "Question: $question"
        echo "Answer: $answer"

        # add the question to the quiz
        add_question "$quiz_id" "$question" "$answer"
    fi
}

function manage_quiz() {
    local quiz_id="$1"
    local choice
    local exit_status

    choice=$(dialog --backtitle "Quiz Manager" \
        --title "Menu" \
        --menu "Choose an option:" 12 60 4 \
        1 "Take Quiz" \
        2 "Edit Quiz Title" \
        3 "View Questions" \
        4 "Add New Question" \
        5 "Delete Quiz" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case $choice in
            1) take_quiz "$quiz_id" ;;
            3) edit_quiz ;;
            4) delete_quiz ;;
            *) break ;;
        esac
    fi
}

function manage_question() {
    local quiz_id="$1"
    local question_id="$2"
    local choice
    local exit_status

    choice=$(dialog --backtitle "Quiz Manager" \
        --title "Menu" \
        --menu "Choose an option:" 12 60 4 \
        1 "Edit Question" \
        2 "Delete Question" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case $choice in
            1) take_quiz "$quiz_id" ;;
            3) edit_quiz ;;
            4) delete_quiz ;;
            *) break ;;
        esac
    fi
}

function quiz_selection() {
    local quiz_option=()

    local choice
    local exit_status

    readarray -t quizzes < <(get_quiz_titles)

    # create the options from the quizzes array
    for i in "${!quizzes[@]}"; do
        quiz_option+=("$((i + 1))" "${quizzes[$i]}")
    done

    # display the quiz selection menu
    choice=$(dialog --clear --title "Take a Quiz" --menu "Choose a quiz" 20 40 ${#quizzes[@]} "${quiz_option[@]}" 2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # return the index of the selected quiz (0-based)
        echo $((choice - 1))
    fi
}

function question_selection() {
    local quiz_id=$1
    local question_option=()

    local choice
    local exit_status

    readarray -t questions < <(get_all_questions "$quiz_id")

    # create the options from the questions array
    for i in "${!questions[@]}"; do
        question_option+=("$((i + 1))" "${questions[$i]}")
    done

    # display the quiz selection menu
    choice=$(dialog --clear --title "Take a Quiz" --menu "Choose a quiz" 20 40 ${#questions[@]} "${question_option[@]}" 2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # return the index of the selected quiz (0-based)
        echo $((choice - 1))
    else
        main
    fi
}

function menu_dialog() { 
    dialog --backtitle "Quiz Manager" \
        --title "Menu" \
        --menu "Choose an option:" 12 60 4 \
        1 "Take a Quiz" \
        2 "Create a Quiz" \
        3 "Edit a Quiz" \
        4 "Delete a Quiz" \
        5 "Exit" \
        2>&1 >/dev/tty
}

function main() {
    init_db

    while true; do
        local choice=$(menu_dialog)
        case $choice in
            1) take_quiz ;;
            2) break ;;
            3) break ;;
            4) break ;;
            5) break ;;
            *) break ;;
        esac
    done
}

main