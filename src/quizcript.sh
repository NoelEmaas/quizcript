#!/bin/bash

source crud.sh

function init_db() {
    [ ! -e "database.json" ] && echo '{"quizzes:" []}' > database.json
}

function take_quiz() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local exit_status
    
    readarray -t questions < <(get_all_questions "$quiz_id")
    readarray -t answers < <(get_all_answers "$quiz_id")

    local num_questions=${#questions[@]}

    while true; do
        start_quiz questions answers "$num_questions" "$quiz_id" "$quiz_title"

        dialog --clear --title "$quiz_title" --yesno "\nWould you like to retake the quiz?\n" 7 40 2>&1 >/dev/tty
        exit_status=$?

        if [ $exit_status -eq 1 ]; then
            manage_quiz "$quiz_id"
            break
        fi
    done

    manage_quiz "$quiz_id"
}

function start_quiz() {
    local -n questions="$1"
    local -n answers="$2"
    local num_questions="$3"
    local quiz_id="$4"
    local quiz_title="$5"
    local score=0

    local question_order=( $(seq 0 $((num_questions-1)) | shuf) )
    
    for i in "${question_order[@]}"; do
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
                    manage_quiz "$quiz_id"
                    break
                else
                    get_user_answer
                fi
            fi
        }

        get_user_answer

        if [ "$user_answer" == "$correct_answer" ]; then
            score=$((score+1))
            dialog --title "$quiz_title" --msgbox "\nCorrect!" 6 30
        else
            dialog --title "$quiz_title" --msgbox "\nIncorrect.\n\nThe correct answer is:\n${correct_answer}" 11 40
        fi
    done

    dialog --title "Quiz Results" --msgbox "\nYour final score is: ${score}/${num_questions}\n" 8 40
}

function update_title() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local new_title
    local exit_status

    while true; do
        new_title=$(dialog --clear --title "Edit Quiz Title" --inputbox "\nCurrent Title:\n${quiz_title} \n\nEnter the new title of the quiz\n" 12 60 2>&1 >/dev/tty)
        exit_status=$?
    
        if [ $exit_status -eq 0 ]; then
            # check if the new title is empty
            if [ -z "$new_title" ]; then
                dialog --clear --title "Edit Quiz Title" --msgbox "\nTitle cannot be empty!\n" 8 40
                continue
            fi

            # update the quiz title
            edit_quiz_title "$quiz_id" "$new_title"
            dialog --clear --title "Edit Quiz Title" --msgbox "\nQuiz Title Updated Successfully!\n" 8 40
            manage_quiz "$quiz_id"
            break
        else
            manage_quiz "$quiz_id"
            break
        fi
    done
}

function create_quiz() {
    local quiz_title
    local exit_status

    while true; do
        quiz_title=$(dialog --clear --title "Create a Quiz" --inputbox "\nEnter the title of the quiz\n" 8 40 3>&1 1>&2 2>&3)
        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            if [ -z "$quiz_title" ]; then
                dialog --clear --title "Create a Quiz" --msgbox "\nTitle cannot be empty!\n" 8 40
                continue
            fi

            local quiz_id=$(get_number_of_quizzes)
            add_quiz "$quiz_title"
            add_new_questions "$quiz_id"
            break
        else
            if [ $(get_number_of_quizzes) -eq 0 ]; then
                main
            else
                quiz_menu
            fi
            break
        fi
    done
}

function add_new_questions() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local values
    local exit_status
    local question=""
    local answer=""

    while true; do
        question_data=$(dialog --clear --title "Add Question: $quiz_title" \
            --ok-label "Add" \
            --form "\nEnter a new question and its answer:\n" 12 70 0 \
            "Question:" 1 1 "$question" 1 20 200 0 \
            "Answer:" 2 1 "$answer" 2 20 200 0 \
            2>&1 >/dev/tty)

        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            question=$(echo "$question_data" | sed -n 1p)
            answer=$(echo "$question_data" | sed -n 2p)

            if [ -z "$question" ] || [ -z "$answer" ]; then
                dialog --clear --title "Add Questions" --msgbox "\nQuestion or Answer cannot be empty!\n" 8 40
                continue
            fi

            add_question "$quiz_id" "$question" "$answer"
        else
            if [ $(get_question_count "$quiz_id") -eq 0 ]; then
                manage_quiz "$quiz_id"
            else
                question_menu "$quiz_id"
            fi
        fi

        dialog --clear --title "Add Questions" --yesno "\nQuestion Added Successfully!\nWould you like to add another question?\n" 10 40 2>&1 >/dev/tty
        exit_status=$?

        if [ $exit_status -eq 1 ]; then
            question_menu "$quiz_id"
            break
        fi
    done
}

function delete_entire_quiz() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local exit_status

    dialog --clear --title "Delete Quiz: $quiz_title" --yesno "\nAre you sure you want to delete this quiz?\n" 7 50 2>&1 >/dev/tty
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        delete_quiz "$quiz_id"
        dialog --clear --title "Delete Quiz" --msgbox "\nQuiz Deleted Successfully!\n" 8 40

        if [ $(get_number_of_quizzes) -eq 0 ]; then
            no_quiz_yet
        else
            quiz_menu
        fi
    else
        manage_quiz "$quiz_id"
    fi
}

function update_qa() {
    local quiz_id="$1"
    local question_id="$2"

    local question=$(get_question "$quiz_id" "$question_id")
    local answer=$(get_answer "$quiz_id" "$question_id")

    local values
    local exit_status

    while true; do
        new_question_data=$(dialog --clear --title "Edit Question" \
            --ok-label "Update" \
            --form "\nEdit the question and its answer:\n" 12 70 0 \
            "Question:" 1 1 "$question" 1 20 200 0 \
            "Answer:" 2 1 "$answer" 2 20 200 0 \
            2>&1 >/dev/tty)

        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            question=$(echo "$new_question_data" | sed -n 1p)
            answer=$(echo "$new_question_data" | sed -n 2p)

            if [ -z "$question" ] || [ -z "$answer" ]; then
                dialog --clear --title "Edit Question" --msgbox "\nQuestion or Answer cannot be empty!\n" 8 40
                continue
            fi

            # update the question and answer
            edit_question "$quiz_id" "$question_id" "$question" 
            edit_answer "$quiz_id" "$question_id" "$answer"

            dialog --clear --title "Edit Question" --msgbox "\nQuestion Updated Successfully!\n" 8 40
            manage_question "$quiz_id" "$question_id"
            break
        else
            manage_question "$quiz_id" "$question_id"
            break
        fi
    done
}

function delete_qa() {
    local quiz_id="$1"
    local question_id="$2"
    local exit_status

    dialog --clear --title "Delete Question" --yesno "\nAre you sure you want to delete this question?\n" 7 50 2>&1 >/dev/tty
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        delete_question "$quiz_id" "$question_id"
        dialog --clear --title "Delete Question" --msgbox "\nQuestion Deleted Successfully!\n" 8 40

        if [ $(get_question_count "$quiz_id") -eq 0 ]; then
            no_question_yet "$quiz_id"
        else
            question_menu "$quiz_id"
        fi
    else
        manage_question "$quiz_id" "$question_id"
    fi
}

function manage_question() {
    local quiz_id="$1"
    local question_id="$2"
    local question=$(get_question "$quiz_id" "$question_id")
    local answer=$(get_answer "$quiz_id" "$question_id")
    local choice
    local exit_status

    choice=$(dialog --backtitle "Question Menu: " \
        --title "Manage Question" \
        --menu "\nQuestion: $question\nAnswer: $answer\n\nChoose an option:\n" 14 60 4 \
        1 "Edit Question" \
        2 "Delete Question" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case $choice in
            1) update_qa "$quiz_id" "$question_id";;
            2) delete_qa "$quiz_id" "$question_id";;
            *) break ;;
        esac
    else
        question_menu "$quiz_id"
    fi
}

function manage_quiz() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local choice
    local exit_status

    choice=$(dialog --backtitle "Quiz Manager" \
        --title "Quiz: $quiz_title" \
        --menu "\nChoose an option:\n" 12 60 4 \
        1 "Take Quiz" \
        2 "Edit Quiz Title" \
        3 "Manage Questions" \
        4 "Delete Quiz" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case $choice in
            1) take_quiz "$quiz_id" ;;
            2) update_title "$quiz_id" ;;
            3) 
                if [ $(get_question_count "$quiz_id") -eq 0 ]; then
                    no_question_yet "$quiz_id"
                else
                    question_menu "$quiz_id"
                fi
                ;;
            4) delete_entire_quiz "$quiz_id" ;;
            *) break ;;
        esac
    else
        quiz_menu
    fi
}

function quiz_menu() {
    local quiz_id
    local exit_status

    local quiz_option=()

    readarray -t quizzes < <(get_quiz_titles)

    # create the options from the quizzes array
    for i in "${!quizzes[@]}"; do
        quiz_option+=("$((i + 1))" "${quizzes[$i]}")
    done

    # display the quiz selection menu
    quiz_id=$(dialog --clear \
        --ok-label "Select" \
        --extra-button --extra-label "Create Quiz" \
        --cancel-label "Back" \
        --title "Quiz Menu" \
        --menu "\nChoose a quiz\n" 20 65 \
        ${#quizzes[@]} "${quiz_option[@]}" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        (( quiz_id-- ))
        manage_quiz "$quiz_id"
    elif [ $exit_status -eq 3 ]; then
        create_quiz
    else
        main
    fi
}

function question_menu() {
    local quiz_id="$1"
    local question_id
    local exit_status

    local quiz_title=$(get_quiz_title "$quiz_id")
    local question_option=()

    readarray -t questions < <(get_all_questions "$quiz_id")

    # create the options from the questions array
    for i in "${!questions[@]}"; do
        question_option+=("$((i + 1))" "${questions[$i]}")
    done

    # display the quiz selection menu
    question_id=$(dialog --clear \
        --ok-label "Select" \
        --extra-button --extra-label "Add Question" \
        --cancel-label "Back" \
        --title "Question Menu: $quiz_title" \
        --menu "\nChoose a question\n" 20 75 \
        ${#questions[@]} "${question_option[@]}" \
        2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        (( question_id-- ))
        manage_question "$quiz_id" "$question_id"
    elif [ $exit_status -eq 3 ]; then
        add_new_questions "$quiz_id"
    else
        manage_quiz "$quiz_id"
    fi
}

function no_quiz_yet() {
    local exit_status

    dialog --clear \
        --ok-label "Create Quiz" \
        --cancel-label "Back" \
        --title "Quiz Menu" \
        --msgbox "\nNo quizzes yet!\n" 8 40

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        create_quiz
    else
        main
    fi
}

function no_question_yet() {
    local quiz_id="$1"
    local exit_status

    dialog --clear \
        --ok-label "Add Question" \
        --cancel-label "Back" \
        --title "Question Menu" \
        --msgbox "\nNo questions yet!\n" 8 40

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        add_new_questions "$quiz_id"
    else
        manage_quiz "$quiz_id"
    fi
}

function main() {    
    local exit_status
    init_db

    dialog --exit-label "Continue" --title "Welcome To" --textbox banner.txt 17 91
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        if [ $(get_number_of_quizzes) -eq 0 ]; then
            no_quiz_yet
        else
            quiz_menu
        fi
    fi

    clear
    exit 0
}

main