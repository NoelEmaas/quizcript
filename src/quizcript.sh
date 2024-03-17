#!/bin/bash

source crud.sh

function init_db() {
    [ ! -e "database.json" ] && echo '{"quizzes:" []}' > database.json
}

function quiz_menu() {
    local quiz_id=$(quiz_selection)
    manage_quiz "$quiz_id"
}

function question_menu() {
    local quiz_id="$1"
    local question_id=$(question_selection "$quiz_id")
    manage_question "$quiz_id" "$question_id"
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
            dialog --title "Quiz" --msgbox "Correct!" 6 30
        else
            dialog --title "Quiz" --msgbox "Incorrect. \nThe correct answer is: ${correct_answer}" 8 40
        fi
    done

    dialog --title "Quiz Results" --msgbox "\nYour final score is: ${score}/${num_questions}\n" 8 40
}

function update_title() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local new_title
    local exit_status

    function input_title() {
        new_title=$(dialog --clear --title "Edit Quiz Title" --inputbox "\nCurrent Title: ${quiz_title} \n\nEnter the new title of the quiz\n" 12 40 2>&1 >/dev/tty)
        exit_status=$?
    
        if [ $exit_status -eq 0 ]; then
            # check if the new title is empty
            if [ -z "$new_title" ]; then
                dialog --clear --title "Edit Quiz Title" --msgbox "\nTitle cannot be empty!\n" 8 40
                input_title
            fi

            # update the quiz title
            edit_quiz_title "$quiz_id" "$new_title"
            dialog --clear --title "Edit Quiz Title" --msgbox "\nQuiz Title Updated Successfully!\n" 8 40
            manage_quiz "$quiz_id"
        else
            manage_quiz "$quiz_id"
        fi
    }

    input_title
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

        dialog --clear --title "Add Questions" --yesno "\nQuestion Added Successfully!\nWould you like to add another question?\n" 10 40 2>&1 >/dev/tty
        exit_status=$?

        if [ $exit_status -eq 1 ]; then
            question_menu "$quiz_id"
            break
        fi
    done
}

function add_new_question() {
    local quiz_id="$1"
    local question=""
    local answer=""
    local values
    local exit_status

    # open fd
    exec 3>&1

    # Use a subshell to capture the output of the dialog command
    values=$(dialog --clear --title "Add Question" \
        --ok-label "Add" \
        --form "\nEnter a new question and its answer:\n" 12 70 0 \
        "Question:" 1 1 "$question" 1 20 200 0 \
        "Answer:" 2 1 "$answer" 2 20 200 0 \
        2>&1 1>&3)

    exit_status=$?

    # close fd
    exec 3>&-

    if [ $exit_status -eq 0 ]; then
        readarray -t lines <<<"$values"

        question="${lines[0]}"
        answer="${lines[1]}"

        # Add the question to the quiz
        add_question "$quiz_id" "$question" "$answer"
    else
        manage_quiz "$quiz_id"
    fi
}

function manage_quiz() {
    local quiz_id="$1"
    local quiz_title=$(get_quiz_title "$quiz_id")
    local choice
    local exit_status

    choice=$(dialog --backtitle "Quiz Manager" \
        --title "Quiz: $quiz_title" \
        --menu "\nChoose an option:\n" 14 60 4 \
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
            2) update_title "$quiz_id" ;;
            3) question_menu "$quiz_id" ;;
            4) add_new_questions "$quiz_id" ;;
            5) delete_entire_quiz "$quiz_id" ;;
            *) break ;;
        esac
    else
        quiz_menu
    fi
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
        quiz_menu
    else
        manage_quiz "$quiz_id"
    fi

}

function update_qa() {
    local quiz_id="$1"
    local question_id="$2"

    local question=$(get_question "$quiz_id" "$question_id")
    local answer=$(get_answer "$quiz_id" "$question_id")

    local new_question
    local new_answer
    local values
    local exit_status

    # open fd
    exec 3>&1

    # Use a subshell to capture the output of the dialog command
    values=$(dialog --clear --title "Edit Question" \
        --ok-label "Update" \
        --form "\nEdit the question and its answer:\n" 12 70 0 \
        "Question:" 1 1 "$question" 1 20 200 0 \
        "Answer:" 2 1 "$answer" 2 20 200 0 \
        2>&1 1>&3)

    exit_status=$?

    # close fd
    exec 3>&-

    if [ $exit_status -eq 0 ]; then
        readarray -t lines <<<"$values"

        new_question="${lines[0]}"
        new_answer="${lines[1]}"

        # update the question and answer
        edit_question "$quiz_id" "$question_id" "$new_question" 
        edit_answer "$quiz_id" "$question_id" "$new_answer"

        dialog --clear --title "Edit Question" --msgbox "\nQuestion Updated Successfully!\n" 8 40
        manage_question "$quiz_id" "$question_id"
    else
        manage_question "$quiz_id" "$question_id"
    fi
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
        question_menu "$quiz_id"
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
    choice=$(dialog --clear --title "Quiz Menu" --menu "\nChoose a quiz\n" 20 40 ${#quizzes[@]} "${quiz_option[@]}" 2>&1 >/dev/tty)
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # return the index of the selected quiz (0-based)
        echo $((choice - 1))
    else
        main
    fi
}

function question_selection() {
    local quiz_id=$1
    local quiz_title=$(get_quiz_title "$quiz_id")
    local question_option=()

    local choice
    local exit_status

    readarray -t questions < <(get_all_questions "$quiz_id")

    # create the options from the questions array
    for i in "${!questions[@]}"; do
        question_option+=("$((i + 1))" "${questions[$i]}")
    done

    # display the quiz selection menu
    choice=$(dialog --clear --title "Question Menu: $quiz_title" --menu "\nChoose a question\n" 20 40 ${#questions[@]} "${question_option[@]}" 2>&1 >/dev/tty)

    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # return the index of the selected quiz (0-based)
        echo $((choice - 1))
    else
        manage_quiz "$quiz_id"
    fi
}

function main() {    
    init_db

    while true; do
        local choice
        local exit_status

        choice=$(dialog --backtitle "Quiz Manager" \
            --extra-button \
            --title "Main Menu" \
            --menu "\nChoose an option:\n" 12 60 4 \
            1 "View Quizzes" \
            2 "Create a Quiz" \
            3 "Exit" \
            2>&1 >/dev/tty)

        exit_status=$?

        if [ $exit_status -ne 0 ]; then
            break
        fi

        case $choice in
            1) quiz_menu ;;
            2) break ;;
            3) kill -s SIGINT "$$" ;;
            *) kill -s SIGINT "$$" ;;
        esac
    done

    clear
    exit 0
}

main